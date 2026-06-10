import 'package:flutter/material.dart';
import '../models/review.dart';
import '../models/app_user.dart';
import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import '../services/review_service.dart';
import '../services/reading_list_service.dart';
import '../services/session_service.dart';

class DetailBookPage extends StatefulWidget {
  const DetailBookPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<DetailBookPage> createState() => _DetailBookPageState();
}

class _DetailBookPageState extends State<DetailBookPage> {

  bool _loadingBook = true;
  bool _loadingReviews = true;

  String _title = '';
  String _author = '';
  String _coverUrl = '';
  String? _description;
  int? _editionCount;
  int? _firstPublishYear;
  OpenLibraryBook? _currentBook;

  List<Review> _reviews = [];
  double _avgRating = 0;

  AppUser? _currentUser;

  bool _isInReadingList = false;
  bool _isFinished = false;
  bool _readingListLoading = false;
  Review? _myReview;

  final _readingListService = ReadingListService();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentUser = await SessionService.getCurrentUser();
    await Future.wait([
      _fetchBookFromApi(),
      _fetchReviews(),
      if (_currentUser != null) _checkFinishedStatus(),
      if (_currentUser != null) _checkReadingListStatus(),
    ]);
  }

  Future<void> _fetchBookFromApi() async {
    try {
      final book = await OpenLibraryService.instance.fetchBookById(widget.bookId);
      final desc = await OpenLibraryService.instance.getBookDescription(widget.bookId);
      if (!mounted) return;
      if (book != null) {
        setState(() {
          _currentBook = book;
          _title = book.title;
          _author = book.author;
          _coverUrl = book.coverUrl;
          _editionCount = book.editionCount;
          _firstPublishYear = book.firstPublishYear;
          _description = desc;
          _loadingBook = false;
        });
      } else {
        setState(() => _loadingBook = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBook = false);
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final reviews = await ReviewService().getReviewsByBook(widget.bookId);
      if (!mounted) return;
      final avg = reviews.isEmpty
          ? 0.0
          : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
      setState(() {
        _reviews = reviews;
        _avgRating = avg;
        _myReview = _currentUser == null
            ? null
            : reviews.cast<Review?>().firstWhere(
                (r) => r?.userId == _currentUser!.id,
                orElse: () => null,
              );
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _checkFinishedStatus() async {
    if (_currentUser == null) return;
    try {
      final finished = await _readingListService.isFinished(
        userId: _currentUser!.id,
        bookId: widget.bookId,
      );
      if (mounted) setState(() => _isFinished = finished);
    } catch (_) {}
  }

  Future<void> _checkReadingListStatus() async {
    if (_currentUser == null) return;
    try {
      final inList = await _readingListService.isInReadingList(
        userId: _currentUser!.id,
        bookId: widget.bookId,
      );
      if (mounted) setState(() => _isInReadingList = inList);
    } catch (_) {}
  }

  Future<void> _toggleReadingList() async {
    if (_currentUser == null) return;
    setState(() => _readingListLoading = true);
    try {
      if (_isInReadingList) {
        await _readingListService.removeFromReadingList(
          userId: _currentUser!.id,
          bookId: widget.bookId,
        );
        if (mounted) {
          setState(() {
            _isInReadingList = false;
            _isFinished = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Buku dihapus dari daftar bacaan.'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        await _readingListService.addToReadingList(
          userId: _currentUser!.id,
          book: _currentBook!,
        );
        if (mounted) {
          setState(() => _isInReadingList = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Buku ditambahkan ke daftar bacaan!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _readingListLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loadingBook = true;
      _loadingReviews = true;
    });
    await Future.wait([
      _fetchBookFromApi(),
      _fetchReviews(),
      if (_currentUser != null) _checkFinishedStatus(),
      if (_currentUser != null) _checkReadingListStatus(),
    ]);
  }

  Future<void> _openReviewSheet() async {
    if (!_isFinished) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Selesaikan membaca buku ini terlebih dahulu untuk menulis review.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final contentCtrl = TextEditingController(text: _myReview?.content ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        initialRating: _myReview?.rating ?? 0,
        contentCtrl: contentCtrl,
        isEditing: _myReview != null,
        onSubmit: (rating, content) async {
          Navigator.pop(context);
          await ReviewService().createReview(
            userId: _currentUser!.id,
            bookId: widget.bookId,
            bookTitle: _title,
            rating: rating,
            content: content.trim().isEmpty ? null : content.trim(),
          );
          await _fetchReviews();
        },
      ),
    );
  }

  Future<void> _deleteReview() async {
    if (_myReview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus review?'),
        content: const Text('Review kamu akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ReviewService().deleteReview(_myReview!.id);
      await _fetchReviews();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EAE1),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 0,
              floating: true,
              snap: true,
              backgroundColor: const Color(0xFFF4EAE1),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E1B4B).withOpacity(.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: const Color(0xFF1E1B4B)),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: _loadingBook
                  ? null
                  : Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: const Color(0xFF1E1B4B),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),

            SliverToBoxAdapter(
              child: _loadingBook
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  _coverUrl,
                                  width: 140,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 140,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.book_rounded,
                                        color: Color(0xFF2563EB), size: 56),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E1B4B),
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _author,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ...List.generate(5, (i) {
                                    if (i < _avgRating.floor()) {
                                      return const Icon(Icons.star_rounded,
                                          color: Color(0xFFF59E0B), size: 20);
                                    } else if (i < _avgRating) {
                                      return const Icon(Icons.star_half_rounded,
                                          color: Color(0xFFF59E0B), size: 20);
                                    }
                                    return const Icon(Icons.star_outline_rounded,
                                        color: Color(0xFFF59E0B), size: 20);
                                  }),
                                  const SizedBox(width: 8),
                                  Text(
                                    _avgRating == 0
                                        ? 'Belum ada rating'
                                        : '${_avgRating.toStringAsFixed(1)} (${_reviews.length} ulasan)',
                                    style: const TextStyle(
                                        color: Color(0xFF6B7280), fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (_currentUser != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _readingListLoading || _isFinished || _currentBook == null
                                    ? null
                                    : _toggleReadingList,
                                icon: _readingListLoading
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _isFinished
                                              ? Colors.white
                                              : _isInReadingList
                                                  ? const Color(0xFFDC2626)
                                                  : Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _isFinished
                                            ? Icons.check_circle_rounded
                                            : _isInReadingList
                                                ? Icons.bookmark_remove_rounded
                                                : Icons.bookmark_add_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  _isFinished
                                      ? 'Selesai Baca'
                                      : _isInReadingList
                                          ? 'Hapus dari Daftar Bacaan'
                                          : 'Tambah ke Daftar Bacaan',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFinished
                                      ? const Color(0xFF059669)
                                      : _isInReadingList
                                          ? const Color(0xFFDC2626).withOpacity(.1)
                                          : const Color(0xFF2563EB),
                                  foregroundColor: _isFinished
                                      ? Colors.white
                                      : _isInReadingList
                                          ? const Color(0xFFDC2626)
                                          : Colors.white,
                                  disabledBackgroundColor: _isFinished
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF2563EB).withOpacity(.5),
                                  disabledForegroundColor: _isFinished
                                      ? Colors.white
                                      : Colors.white.withOpacity(.5),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: _isInReadingList && !_isFinished
                                        ? BorderSide(
                                            color: const Color(0xFFDC2626).withOpacity(.4))
                                        : BorderSide.none,
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 4),

                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E1B4B).withOpacity(.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informasi Edisi',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E1B4B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.layers_rounded,
                                              color: Color(0xFF2563EB), size: 20),
                                          const SizedBox(height: 8),
                                          const Text('Jumlah Edisi',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 2),
                                          Text(
                                            _editionCount != null
                                                ? '$_editionCount edisi'
                                                : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF1E1B4B),
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.calendar_today_rounded,
                                              color: Color(0xFF2563EB), size: 20),
                                          const SizedBox(height: 8),
                                          const Text('Pertama Terbit',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 2),
                                          Text(
                                            _firstPublishYear != null
                                                ? '$_firstPublishYear'
                                                : '-',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF1E1B4B),
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        if (_description != null && _description!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E1B4B).withOpacity(.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sinopsis',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E1B4B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _ExpandableText(text: _description!),
                              ],
                            ),
                          ),

                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E1B4B).withOpacity(.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Ulasan Pembaca',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                  ),
                                  if (_currentUser != null)
                                    GestureDetector(
                                      onTap: _openReviewSheet,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _isFinished
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF6B7280).withOpacity(.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _myReview != null
                                                  ? Icons.edit_rounded
                                                  : Icons.rate_review_rounded,
                                              size: 14,
                                              color: _isFinished
                                                  ? Colors.white
                                                  : const Color(0xFF6B7280),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              _myReview != null
                                                  ? 'Edit Ulasan'
                                                  : 'Tulis Ulasan',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _isFinished
                                                    ? Colors.white
                                                    : const Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              if (!_isFinished && _currentUser != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFF59E0B).withOpacity(.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded,
                                          color: Color(0xFFF59E0B), size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Selesaikan membaca untuk dapat menulis ulasan.',
                                          style: TextStyle(
                                              fontSize: 12, color: Color(0xFFF59E0B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),

                              if (_myReview != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDBEAFE),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFF2563EB).withOpacity(.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const CircleAvatar(
                                            radius: 14,
                                            backgroundColor: Color(0xFF2563EB),
                                            child: Icon(Icons.person_rounded,
                                                color: Colors.white, size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      _myReview!.username ?? 'Kamu',
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 13,
                                                        color: Color(0xFF1E1B4B),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF2563EB),
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                      ),
                                                      child: const Text(
                                                        'Ulasanmu',
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                _StarRow(rating: _myReview!.rating),
                                              ],
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (v) {
                                              if (v == 'edit') _openReviewSheet();
                                              if (v == 'delete') _deleteReview();
                                            },
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12)),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(children: [
                                                  Icon(Icons.edit_rounded,
                                                      size: 16, color: Color(0xFF2563EB)),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ]),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(children: [
                                                  Icon(Icons.delete_rounded,
                                                      size: 16, color: Color(0xFFDC2626)),
                                                  SizedBox(width: 8),
                                                  Text('Hapus',
                                                      style: TextStyle(
                                                          color: Color(0xFFDC2626))),
                                                ]),
                                              ),
                                            ],
                                            child: const Icon(Icons.more_vert_rounded,
                                                color: Color(0xFF6B7280), size: 18),
                                          ),
                                        ],
                                      ),
                                      if (_myReview!.content != null &&
                                          _myReview!.content!.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          _myReview!.content!,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF1E1B4B),
                                              height: 1.5),
                                        ),
                                      ],
                                      if (_myReview!.createdAt != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDate(_myReview!.createdAt!),
                                          style: const TextStyle(
                                              fontSize: 11, color: Color(0xFF6B7280)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_reviews.length > 1) ...[
                                  const Divider(height: 24),
                                  const Text(
                                    'Ulasan Lainnya',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],

                              if (_loadingReviews)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF2563EB)),
                                  ),
                                )
                              else if (_reviews.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Text(
                                      'Belum ada ulasan untuk buku ini.',
                                      style: TextStyle(
                                          color: Color(0xFF6B7280), fontSize: 14),
                                    ),
                                  ),
                                )
                              else
                                ..._reviews
                                    .where((r) =>
                                        _myReview == null || r.id != _myReview!.id)
                                    .map(
                                      (r) => Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor:
                                                      const Color(0xFFDBEAFE),
                                                  child: Text(
                                                    (r.username?.isNotEmpty == true
                                                            ? r.username![0]
                                                            : '?')
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF2563EB),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        r.username ?? 'Anonim',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                          color: Color(0xFF1E1B4B),
                                                        ),
                                                      ),
                                                      _StarRow(rating: r.rating),
                                                    ],
                                                  ),
                                                ),
                                                if (r.createdAt != null)
                                                  Text(
                                                    _formatDate(r.createdAt!),
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(0xFF6B7280)),
                                                  ),
                                              ],
                                            ),
                                            if (r.content != null &&
                                                r.content!.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(left: 38),
                                                child: Text(
                                                  r.content!,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF6B7280),
                                                      height: 1.5),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            const Divider(height: 1),
                                          ],
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  static const int _maxLines = 4;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : _maxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Tampilkan lebih sedikit' : 'Selengkapnya',
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}


class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: const Color(0xFFF59E0B),
          size: 14,
        ),
      ),
    );
  }
}


class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({
    required this.initialRating,
    required this.contentCtrl,
    required this.isEditing,
    required this.onSubmit,
  });

  final int initialRating;
  final TextEditingController contentCtrl;
  final bool isEditing;
  final void Function(int rating, String content) onSubmit;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF6B7280).withOpacity(.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.isEditing ? 'Edit Ulasan' : 'Tulis Ulasan',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E1B4B)),
          ),
          const SizedBox(height: 20),
          const Text('Rating',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          const Text('Ulasan (opsional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280))),
          const SizedBox(height: 8),
          TextField(
            controller: widget.contentCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Ceritakan pendapatmu tentang buku ini...',
              hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF4EAE1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating == 0
                  ? null
                  : () => widget.onSubmit(_rating, widget.contentCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF6B7280).withOpacity(.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                widget.isEditing ? 'Simpan Perubahan' : 'Kirim Ulasan',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
