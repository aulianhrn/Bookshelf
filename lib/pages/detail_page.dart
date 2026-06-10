import 'package:flutter/material.dart';
import '../models/review.dart';
import '../models/app_user.dart';
import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import '../services/review_service.dart';
import '../services/reading_list_service.dart';
import '../services/session_service.dart';

// ─── Konstanta warna (sesuai tema koleksi) ─────────────────────────────────
const _bg = Color(0xFFF4EAE1);
const _blue = Color(0xFF2563EB);
const _blueDark = Color(0xFF1E40AF);
const _blueLight = Color(0xFFDBEAFE);
const _ink = Color(0xFF1E1B4B);
const _muted = Color(0xFF6B7280);
const _green = Color(0xFF059669);
const _amber = Color(0xFFF59E0B);
const _card = Color(0xFFFFFFFF);
const _red = Color(0xFFDC2626);

// ─────────────────────────────────────────────────────────────────────────────
// DetailBookPage
// ─────────────────────────────────────────────────────────────────────────────

/// Halaman detail buku.
///
/// Menerima hanya [bookId] (work key Open Library, misal "OL27516W").
/// Semua data buku (cover, sinopsis, edisi) selalu di-fetch dari API,
/// tidak bergantung pada data yang diteruskan dari halaman sebelumnya.
class DetailBookPage extends StatefulWidget {
  const DetailBookPage({super.key, required this.bookId});

  final String bookId;

  @override
  State<DetailBookPage> createState() => _DetailBookPageState();
}

class _DetailBookPageState extends State<DetailBookPage> {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _loadingBook = true;
  bool _loadingReviews = true;

  // Data dari API Open Library
  String _title = '';
  String _author = '';
  String _coverUrl = '';
  String? _description;
  int? _editionCount;
  int? _firstPublishYear;
  OpenLibraryBook? _currentBook; // Objek buku untuk addToReadingList

  // Data dari Supabase
  List<Review> _reviews = [];
  double _avgRating = 0;

  // Session
  AppUser? _currentUser;

  // Status buku milik user saat ini
  bool _isInReadingList = false;
  bool _isFinished = false;
  bool _readingListLoading = false;
  Review? _myReview; // review milik user (null = belum review)

  final _readingListService = ReadingListService();

  // ── Inisialisasi ──────────────────────────────────────────────────────────
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

  // ── Fetch buku dari Open Library API ─────────────────────────────────────
  Future<void> _fetchBookFromApi() async {
    try {
      final book =
          await OpenLibraryService.instance.fetchBookById(widget.bookId);
      final desc = await OpenLibraryService.instance
          .getBookDescription(widget.bookId);

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

  // ── Fetch review dari Supabase ────────────────────────────────────────────
  Future<void> _fetchReviews() async {
    try {
      final reviews =
          await ReviewService().getReviewsByBook(widget.bookId);
      if (!mounted) return;

      final avg = reviews.isEmpty
          ? 0.0
          : reviews.map((r) => r.rating).reduce((a, b) => a + b) /
              reviews.length;

      setState(() {
        _reviews = reviews;
        _avgRating = avg;
        _myReview = _currentUser == null
            ? null
            : reviews
                .cast<Review?>()
                .firstWhere(
                  (r) => r?.userId == _currentUser!.id,
                  orElse: () => null,
                );
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  // ── Cek apakah buku sudah selesai dibaca ─────────────────────────────────
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

  // ── Cek apakah buku ada di daftar bacaan ─────────────────────────────────
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

  // ── Toggle daftar bacaan ──────────────────────────────────────────────────
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
              backgroundColor: _green,
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
            backgroundColor: _red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _readingListLoading = false);
    }
  }

  // ── Refresh semua data ────────────────────────────────────────────────────
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

  // ── Buka bottom sheet tulis review ───────────────────────────────────────
  Future<void> _openReviewSheet() async {
    if (!_isFinished) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Selesaikan membaca buku ini terlebih dahulu untuk menulis review.',
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: _red,
        ),
      );
      return;
    }

    int pickedRating = _myReview?.rating ?? 0;
    final contentCtrl =
        TextEditingController(text: _myReview?.content ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        initialRating: pickedRating,
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

  // ── Hapus review ──────────────────────────────────────────────────────────
  Future<void> _deleteReview() async {
    if (_myReview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus review?'),
        content:
            const Text('Review kamu akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _blue,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: _loadingBook
                  ? const _LoadingSection()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BookHero(
                          coverUrl: _coverUrl,
                          title: _title,
                          author: _author,
                          avgRating: _avgRating,
                          reviewCount: _reviews.length,
                          editionCount: _editionCount,
                          firstPublishYear: _firstPublishYear,
                        ),
                        if (_currentUser != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                            child: _ReadingListButton(
                              isInReadingList: _isInReadingList,
                              isFinished: _isFinished,
                              loading: _readingListLoading,
                              onPressed: _currentBook != null ? _toggleReadingList : null,
                            ),
                          ),
                        const SizedBox(height: 4),
                        // ← Informasi Edisi dipindah ke atas Sinopsis
                        _SectionCard(
                          title: 'Informasi Edisi',
                          child: _EditionInfo(
                            editionCount: _editionCount,
                            firstPublishYear: _firstPublishYear,
                          ),
                        ),
                        if (_description != null && _description!.isNotEmpty)
                          _SectionCard(
                            title: 'Sinopsis',
                            child: _ExpandableText(text: _description!),
                          ),
                        _ReviewsSection(
                          reviews: _reviews,
                          loading: _loadingReviews,
                          currentUserId: _currentUser?.id,
                          myReview: _myReview,
                          isFinished: _isFinished,
                          onWriteReview: _openReviewSheet,
                          onDeleteReview: _deleteReview,
                          onEditReview: _openReviewSheet,
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

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _card,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _ink.withOpacity(.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _ink),
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
                color: _ink,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: Hero bagian atas
// ─────────────────────────────────────────────────────────────────────────────

class _BookHero extends StatelessWidget {
  const _BookHero({
    required this.coverUrl,
    required this.title,
    required this.author,
    required this.avgRating,
    required this.reviewCount,
    this.editionCount,
    this.firstPublishYear,
  });

  final String coverUrl;
  final String title;
  final String author;
  final double avgRating;
  final int reviewCount;
  final int? editionCount;
  final int? firstPublishYear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // color: _card dihapus → background transparan, ikut warna _bg scaffold
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          // Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              coverUrl,
              width: 140,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  color: _blueLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.book_rounded, color: _blue, size: 56),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Judul
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          // Penulis
          Text(
            author,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
          const SizedBox(height: 16),
          // Rating bar
          _RatingBar(avg: avgRating, count: reviewCount),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.avg, required this.count});

  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(5, (i) {
          if (i < avg.floor()) {
            return const Icon(Icons.star_rounded, color: _amber, size: 20);
          } else if (i < avg) {
            return const Icon(Icons.star_half_rounded,
                color: _amber, size: 20);
          }
          return const Icon(Icons.star_outline_rounded,
              color: _amber, size: 20);
        }),
        const SizedBox(width: 8),
        Text(
          avg == 0
              ? 'Belum ada rating'
              : '${avg.toStringAsFixed(1)} ($count ulasan)',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: Section Card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _ink.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: Expandable text (sinopsis)
// ─────────────────────────────────────────────────────────────────────────────

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
            color: _muted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Tampilkan lebih sedikit' : 'Selengkapnya',
            style: const TextStyle(
              color: _blue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: Informasi Edisi
// ─────────────────────────────────────────────────────────────────────────────

class _EditionInfo extends StatelessWidget {
  const _EditionInfo({this.editionCount, this.firstPublishYear});

  final int? editionCount;
  final int? firstPublishYear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoTile(
            icon: Icons.layers_rounded,
            label: 'Jumlah Edisi',
            value: editionCount != null ? '$editionCount edisi' : '-',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoTile(
            icon: Icons.calendar_today_rounded,
            label: 'Pertama Terbit',
            value: firstPublishYear != null ? '$firstPublishYear' : '-',
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blueLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _blue, size: 20),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  color: _ink,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: Seksi Review
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.loading,
    required this.isFinished,
    required this.onWriteReview,
    required this.onDeleteReview,
    required this.onEditReview,
    this.currentUserId,
    this.myReview,
  });

  final List<Review> reviews;
  final bool loading;
  final String? currentUserId;
  final Review? myReview;
  final bool isFinished;
  final VoidCallback onWriteReview;
  final VoidCallback onDeleteReview;
  final VoidCallback onEditReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _ink.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ulasan Pembaca',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              if (currentUserId != null)
                _WriteReviewButton(
                  isFinished: isFinished,
                  hasReview: myReview != null,
                  onTap: onWriteReview,
                ),
            ],
          ),

          // Pesan jika belum selesai baca
          if (!isFinished && currentUserId != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _amber.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withOpacity(.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline_rounded, color: _amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selesaikan membaca untuk dapat menulis ulasan.',
                      style: TextStyle(fontSize: 12, color: _amber),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Review milik user (jika ada)
          if (myReview != null) ...[
            _MyReviewCard(
              review: myReview!,
              onEdit: onEditReview,
              onDelete: onDeleteReview,
            ),
            if (reviews.length > 1) ...[
              const Divider(height: 24),
              const Text(
                'Ulasan Lainnya',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          // Loading
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: _blue),
              ),
            )
          // Kosong
          else if (reviews.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Belum ada ulasan untuk buku ini.',
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
              ),
            )
          // Daftar review (exclude milik sendiri jika sudah ditampilkan)
          else
            ...reviews
                .where((r) =>
                    myReview == null || r.id != myReview!.id)
                .map((r) => _ReviewCard(review: r)),
        ],
      ),
    );
  }
}

class _WriteReviewButton extends StatelessWidget {
  const _WriteReviewButton({
    required this.isFinished,
    required this.hasReview,
    required this.onTap,
  });

  final bool isFinished;
  final bool hasReview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isFinished ? _blue : _muted.withOpacity(.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasReview ? Icons.edit_rounded : Icons.rate_review_rounded,
              size: 14,
              color: isFinished ? Colors.white : _muted,
            ),
            const SizedBox(width: 5),
            Text(
              hasReview ? 'Edit Ulasan' : 'Tulis Ulasan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isFinished ? Colors.white : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyReviewCard extends StatelessWidget {
  const _MyReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
  });

  final Review review;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blueLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: _blue,
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
                          review.username ?? 'Kamu',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(8),
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
                    _StarRow(rating: review.rating),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 16, color: _blue),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded, size: 16, color: _red),
                      SizedBox(width: 8),
                      Text('Hapus', style: TextStyle(color: _red)),
                    ]),
                  ),
                ],
                child: const Icon(Icons.more_vert_rounded,
                    color: _muted, size: 18),
              ),
            ],
          ),
          if (review.content != null && review.content!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content!,
              style: const TextStyle(
                  fontSize: 13, color: _ink, height: 1.5),
            ),
          ],
          if (review.createdAt != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatDate(review.createdAt!),
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _blueLight,
                child: Text(
                  (review.username?.isNotEmpty == true
                          ? review.username![0]
                          : '?')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.username ?? 'Anonim',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: _ink,
                      ),
                    ),
                    _StarRow(rating: review.rating),
                  ],
                ),
              ),
              if (review.createdAt != null)
                Text(
                  _formatDate(review.createdAt!),
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
            ],
          ),
          if (review.content != null && review.content!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                review.content!,
                style: const TextStyle(
                    fontSize: 13, color: _muted, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
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
          color: _amber,
          size: 14,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: Review Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

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
        color: _card,
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _muted.withOpacity(.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.isEditing ? 'Edit Ulasan' : 'Tulis Ulasan',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 20),
          // Bintang interaktif
          const Text('Rating',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    i < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _amber,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Text field ulasan
          const Text('Ulasan (opsional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted)),
          const SizedBox(height: 8),
          TextField(
            controller: widget.contentCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Ceritakan pendapatmu tentang buku ini...',
              hintStyle: const TextStyle(color: _muted, fontSize: 13),
              filled: true,
              fillColor: _bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 20),
          // Tombol submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _rating == 0
                  ? null
                  : () => widget.onSubmit(
                      _rating, widget.contentCtrl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _muted.withOpacity(.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                widget.isEditing ? 'Simpan Perubahan' : 'Kirim Ulasan',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: Loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingSection extends StatelessWidget {
  const _LoadingSection();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 80),
        child: CircularProgressIndicator(color: _blue),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widget: Tombol Daftar Bacaan
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingListButton extends StatelessWidget {
  const _ReadingListButton({
    required this.isInReadingList,
    required this.isFinished,
    required this.loading,
    required this.onPressed,
  });

  final bool isInReadingList;
  final bool isFinished;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Tentukan label & warna berdasarkan status
    final String label;
    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    if (isFinished) {
      label = 'Selesai Baca';
      bgColor = _green;
      fgColor = Colors.white;
      icon = Icons.check_circle_rounded;
    } else if (isInReadingList) {
      label = 'Hapus dari Daftar Bacaan';
      bgColor = _red.withOpacity(.1);
      fgColor = _red;
      icon = Icons.bookmark_remove_rounded;
    } else {
      label = 'Tambah ke Daftar Bacaan';
      bgColor = _blue;
      fgColor = Colors.white;
      icon = Icons.bookmark_add_rounded;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading || isFinished ? null : onPressed,
        icon: loading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fgColor,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          disabledBackgroundColor: isFinished ? bgColor : bgColor.withOpacity(.5),
          disabledForegroundColor: isFinished ? fgColor : fgColor.withOpacity(.5),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isInReadingList && !isFinished
                ? BorderSide(color: _red.withOpacity(.4))
                : BorderSide.none,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}