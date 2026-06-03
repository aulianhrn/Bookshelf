import 'package:bookself_/services/review_service.dart';
import 'package:bookself_/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/open_library_book.dart';
import '../models/review.dart';
import '../services/open_library_service.dart';
import '../models/app_user.dart';
import '../services/reading_list_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Design tokens (selaras dengan seluruh app) ─────────────────────────────
const _bg        = Color(0xFFF4EAE1);
const _blue      = Color(0xFF2563EB);
const _blueDark  = Color(0xFF1E40AF);
const _blueLight = Color(0xFFDBEAFE);
const _ink       = Color(0xFF1E1B4B);
const _muted     = Color(0xFF6B7280);
const _card      = Color(0xFFFFFFFF);
const _green     = Color(0xFF1D9E75);
const _danger    = Color(0xFFE24B4A);
const _amber     = Color(0xFFF59E0B);
// ───────────────────────────────────────────────────────────────────────────

class DetailBookPage extends StatefulWidget {
  const DetailBookPage({
    super.key,
    this.book,
    this.bookId = '',
    this.bookTitle = '',
    this.bookAuthor = '',
    this.imageUrl = '',
  });

  final OpenLibraryBook? book;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String imageUrl;

  String get effectiveBookId    => book?.id ?? bookId;
  String get effectiveBookTitle => book?.title ?? bookTitle;
  String get effectiveBookAuthor => book?.author ?? bookAuthor;
  String get effectiveImageUrl  => book?.coverUrl ?? imageUrl;
  int?   get effectiveEditionCount => book?.editionCount;

  @override
  State<DetailBookPage> createState() => _DetailBookPageState();
}

class _DetailBookPageState extends State<DetailBookPage>
    with SingleTickerProviderStateMixin {
  bool expanded             = false;
  bool isLoadingReviews     = true;
  bool isInReadingList      = false;
  bool isLoadingReadingList = false;
  bool isFinished           = false;
  List<Review> reviews      = [];
  AppUser? currentUser;
  String? synopsis;
  bool isLoadingSynopsis    = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    loadReviews();
    loadSynopsis();
    _loadCurrentUser().then((_) => checkReadingList());

    Future.delayed(const Duration(milliseconds: 100), _fadeCtrl.forward);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadCurrentUser() async {
    final user = await SessionService.getCurrentUser();
    if (mounted) setState(() => currentUser = user);
  }

  Future<void> checkReadingList() async {
    if (currentUser == null) return;
    final inList = await ReadingListService().isInReadingList(
        userId: currentUser!.id, bookId: widget.effectiveBookId);
    final finished = await ReadingListService().isFinished(
        userId: currentUser!.id, bookId: widget.effectiveBookId);
    if (mounted) setState(() { isInReadingList = inList; isFinished = finished; });
  }

  Future<void> toggleReadingList() async {
    if (currentUser == null) {
      _snack('Silakan login terlebih dahulu');
      return;
    }
    setState(() => isLoadingReadingList = true);
    try {
      if (isFinished) {
        final rows = await Supabase.instance.client
            .from('reading_list').select('id')
            .eq('user_id', currentUser!.id)
            .eq('book_id', widget.effectiveBookId).limit(1);
        if (rows.isNotEmpty) {
          await ReadingListService().unmarkFinished(rows.first['id']);
        }
        if (mounted) setState(() { isFinished = false; isInReadingList = true; });
        if (mounted) _snack('Buku dipindahkan kembali ke daftar bacaan');
      } else if (isInReadingList) {
        await ReadingListService().removeFromReadingList(
            userId: currentUser!.id, bookId: widget.effectiveBookId);
        if (mounted) setState(() => isInReadingList = false);
      } else {
        await ReadingListService().addToReadingList(
            userId: currentUser!.id, book: widget.book!);
        if (mounted) setState(() => isInReadingList = true);
      }
    } catch (e) {
      if (mounted) _snack('Gagal: $e', color: _danger);
    } finally {
      if (mounted) setState(() => isLoadingReadingList = false);
    }
  }

  Future<void> loadSynopsis() async {
    final workKey = widget.book?.id;
    if (workKey == null) return;
    setState(() => isLoadingSynopsis = true);
    try {
      final result =
          await OpenLibraryService.instance.getBookDescription(workKey);
      if (!mounted) return;
      setState(() => synopsis = result);
    } catch (_) {
      // fallback ke teks default
    } finally {
      if (mounted) setState(() => isLoadingSynopsis = false);
    }
  }

  Future<void> loadReviews() async {
    setState(() => isLoadingReviews = true);
    try {
      final rows =
          await ReviewService().getReviewsByBook(widget.effectiveBookId);
      if (!mounted) return;
      setState(() => reviews = rows);
    } catch (error) {
      if (!mounted) return;
      _snack('Gagal memuat review: $error', color: _danger);
    } finally {
      if (mounted) setState(() => isLoadingReviews = false);
    }
  }

  // ── Review dialogs ────────────────────────────────────────────────────────

  Future<void> showReviewDialog() async {
    if (currentUser == null) {
      _snack('Silakan login untuk menulis review');
      return;
    }
    var rating = 5;
    final ctrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSheet) => _reviewSheet(
          title: 'Tulis Review',
          rating: rating,
          controller: ctrl,
          onRatingChanged: (r) => setSheet(() => rating = r),
          onSave: () async {
            Navigator.pop(ctx);
            try {
              await ReviewService().createReview(
                userId: currentUser!.id,
                bookId: widget.effectiveBookId,
                bookTitle: widget.effectiveBookTitle,
                rating: rating,
                content: ctrl.text.trim(),
              );
              await loadReviews();
              messenger.showSnackBar(
                  _buildSnackBar('Review berhasil disimpan', color: _green));
            } catch (e) {
              messenger.showSnackBar(_buildSnackBar('Gagal: $e', color: _danger));
            }
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
    );
    ctrl.dispose();
  }

  Future<void> showEditReviewDialog(Review review) async {
    final ctrl = TextEditingController(text: review.content);
    int selectedRating = review.rating;
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSheet) => _reviewSheet(
          title: 'Edit Review',
          rating: selectedRating,
          controller: ctrl,
          onRatingChanged: (r) => setSheet(() => selectedRating = r),
          onSave: () async {
            Navigator.pop(ctx);
            try {
              await ReviewService().updateReview(
                  id: review.id,
                  rating: selectedRating,
                  content: ctrl.text);
              await loadReviews();
              messenger.showSnackBar(
                  _buildSnackBar('Review diperbarui', color: _green));
            } catch (e) {
              messenger.showSnackBar(
                  _buildSnackBar('Gagal mengupdate: $e', color: _danger));
            }
          },
          onCancel: () => Navigator.pop(ctx),
          onDelete: () async {
            Navigator.pop(ctx);
            try {
              await ReviewService().deleteReview(review.id);
              if (currentUser != null) {
                final rows = await Supabase.instance.client
                    .from('reading_list').select('id')
                    .eq('user_id', currentUser!.id)
                    .eq('book_id', widget.effectiveBookId).limit(1);
                if (rows.isNotEmpty) {
                  await ReadingListService()
                      .updateUserRating(id: rows.first['id'], rating: 0);
                }
              }
              await loadReviews();
              messenger.showSnackBar(
                  _buildSnackBar('Review dihapus'));
            } catch (e) {
              messenger.showSnackBar(
                  _buildSnackBar('Gagal menghapus: $e', color: _danger));
            }
          },
        ),
      ),
    );
    ctrl.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double get averageRating {
    if (reviews.isEmpty) return 0;
    return reviews.fold<int>(0, (s, r) => s + r.rating) / reviews.length;
  }

  void _snack(String msg, {Color? color}) =>
      ScaffoldMessenger.of(context).showSnackBar(_buildSnackBar(msg, color: color));

  SnackBar _buildSnackBar(String msg, {Color? color}) => SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color ?? _ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ratingText = reviews.isEmpty
        ? (widget.book?.ratingText ?? '-')
        : averageRating.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── Hero cover ───────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHero(ratingText)),

            // ── Body content ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 28),
                    _buildSynopsisSection(),
                    const SizedBox(height: 28),
                    _buildReviewsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.menu_book_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              const Text('BookShelf',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Hero section (cover + info) ───────────────────────────────────────────

  Widget _buildHero(String ratingText) {
    return Stack(
      children: [
        // ── Blurred cover background ──────────────────────────────────
        SizedBox(
          height: 420,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background: blurred cover
              Image.network(
                widget.effectiveImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: _ink),
              ),
              // Dark gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xCC1E1B4B),
                      Color(0x881E1B4B),
                      Color(0xEE1E1B4B),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Foreground content ────────────────────────────────────────
        Positioned.fill(
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Book cover card
                Container(
                  width: 140,
                  height: 210,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.45),
                          blurRadius: 30,
                          offset: const Offset(0, 12)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      widget.effectiveImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _blueLight,
                        child: const Icon(Icons.menu_book_rounded,
                            color: _blue, size: 48),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    widget.effectiveBookTitle,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -.3,
                        height: 1.25),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 8),

                // Author
                Text(
                  widget.effectiveBookAuthor,
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(.7),
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Meta pills (rating · reviews · edisi)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _metaPill(
                      icon: Icons.star_rounded,
                      iconColor: _amber,
                      label: ratingText,
                    ),
                    _metaDot(),
                    _metaPill(
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: Colors.white70,
                      label: '${reviews.length} Review',
                    ),
                    _metaDot(),
                    _metaPill(
                      icon: Icons.layers_outlined,
                      iconColor: Colors.white70,
                      label: widget.effectiveEditionCount == null
                          ? 'Open Library'
                          : '${widget.effectiveEditionCount} Edisi',
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ── White rounded top edge ────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 28,
            decoration: const BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _metaPill({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(children: [
      Icon(icon, size: 14, color: iconColor),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _metaDot() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
            width: 3, height: 3,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.4),
                shape: BoxShape.circle)),
      );

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    // Determine state
    final Color btnColor;
    final IconData btnIcon;
    final String btnLabel;

    if (isFinished) {
      btnColor = Colors.grey.shade400;
      btnIcon  = Icons.check_circle_rounded;
      btnLabel = 'Selesai dibaca';
    } else if (isInReadingList) {
      btnColor = _danger;
      btnIcon  = Icons.library_books_rounded;
      btnLabel = 'Hapus dari perpustakaan';
    } else {
      btnColor = _blue;
      btnIcon  = Icons.library_add_rounded;
      btnLabel = 'Tambah ke perpustakaan';
    }

    return Row(children: [
      // Primary action button
      Expanded(
        flex: 3,
        child: _gradientButton(
          label: btnLabel,
          icon: btnIcon,
          isLoading: isLoadingReadingList,
          gradient: isFinished
              ? null
              : LinearGradient(
                  colors: isInReadingList
                      ? [_danger, const Color(0xFFC0392B)]
                      : [_blue, _blueDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          solidColor: isFinished ? Colors.grey.shade400 : null,
          glowColor: isFinished
              ? null
              : (isInReadingList ? _danger : _blue),
          onTap: isLoadingReadingList ? null : toggleReadingList,
        ),
      ),
      const SizedBox(width: 10),
      // Review button (icon only)
      _iconActionButton(
        icon: Icons.rate_review_rounded,
        tooltip: 'Tulis Review',
        onTap: showReviewDialog,
      ),
    ]);
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    LinearGradient? gradient,
    Color? solidColor,
    Color? glowColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: gradient,
          color: solidColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: glowColor == null
              ? []
              : [
                  BoxShadow(
                      color: glowColor.withOpacity(.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _ink.withOpacity(.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(icon, color: _blue, size: 22),
        ),
      ),
    );
  }

  // ── Synopsis section ──────────────────────────────────────────────────────

  Widget _buildSynopsisSection() {
    const fallback = 'Sinopsis tidak tersedia untuk buku ini.';
    final fullText = synopsis ?? fallback;
    final shortText = fullText.length > 200
        ? '${fullText.substring(0, 200)}...'
        : fullText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.article_outlined,
          label: 'Sinopsis',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: _ink.withOpacity(.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isLoadingSynopsis)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                        color: _blue, strokeWidth: 2),
                  ),
                )
              else
                AnimatedCrossFade(
                  firstChild: Text(shortText,
                      style: TextStyle(
                          fontSize: 14,
                          color: _ink.withOpacity(.75),
                          height: 1.65)),
                  secondChild: Text(fullText,
                      style: TextStyle(
                          fontSize: 14,
                          color: _ink.withOpacity(.75),
                          height: 1.65)),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              if (!isLoadingSynopsis && fullText.length > 200) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => expanded = !expanded),
                  child: Row(children: [
                    Text(
                      expanded ? 'Tutup' : 'Baca selengkapnya',
                      style: const TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _blue, size: 18),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Reviews section ───────────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader(
              icon: Icons.star_rounded,
              label: 'Review Pembaca',
              iconColor: _amber,
            ),
            const Spacer(),
            if (!isLoadingReviews && reviews.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _amber.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.star_rounded, color: _amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                        color: _amber,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ]),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
            ),
          )
        else if (reviews.isEmpty)
          _emptyReviews()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _reviewCard(reviews[i]),
          ),
      ],
    );
  }

  Widget _emptyReviews() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _ink.withOpacity(.04),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
              color: _amber.withOpacity(.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.rate_review_outlined,
              color: _amber, size: 26),
        ),
        const SizedBox(height: 12),
        const Text('Belum ada review',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: _ink, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Jadilah yang pertama menulis review!',
            style: TextStyle(color: _muted, fontSize: 13)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: showReviewDialog,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_blue, _blueDark],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: _blue.withOpacity(.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: const Text('Tulis Review',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  Widget _reviewCard(Review review) {
    final name = (review.username == null || review.username!.isEmpty)
        ? 'Pembaca'
        : review.username!;
    final isOwner = currentUser?.id == review.userId;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _ink.withOpacity(.05),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            // Avatar
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _blue.withOpacity(.7),
                    _blueDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          fontSize: 14)),
                  const SizedBox(height: 3),
                  // Star row
                  Row(children: List.generate(5, (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i < review.rating ? _amber : Colors.grey.shade300,
                    size: 15,
                  ))),
                ],
              ),
            ),
            if (isOwner)
              GestureDetector(
                onTap: () => showEditReviewDialog(review),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: _blue.withOpacity(.08),
                      borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.edit_outlined,
                      color: _blue, size: 16),
                ),
              ),
          ]),
          if ((review.content?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            Text(
              review.content!,
              style: TextStyle(
                  fontSize: 13,
                  color: _ink.withOpacity(.72),
                  height: 1.55),
            ),
          ],
        ],
      ),
    );
  }

  // ── Review bottom sheet ───────────────────────────────────────────────────

  Widget _reviewSheet({
    required String title,
    required int rating,
    required TextEditingController controller,
    required ValueChanged<int> onRatingChanged,
    required VoidCallback onSave,
    required VoidCallback onCancel,
    VoidCallback? onDelete,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),

          // Header
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: _amber.withOpacity(.12),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.rate_review_rounded,
                  color: _amber, size: 20)),
            const SizedBox(width: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _ink)),
            if (onDelete != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: _danger.withOpacity(.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Hapus',
                      style: TextStyle(
                          color: _danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 22),

          // Stars
          const Text('Rating kamu',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) => GestureDetector(
                  onTap: () => onRatingChanged(i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      i < rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i < rating ? _amber : Colors.grey.shade300,
                      size: 36,
                    ),
                  ),
                )),
          ),
          const SizedBox(height: 20),

          // Text input
          const Text('Komentar (opsional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _muted)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200)),
            child: TextField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: InputDecoration(
                hintText: 'Tulis pendapatmu tentang buku ini...',
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Buttons
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: onCancel,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14)),
                  child: const Center(
                    child: Text('Batal',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: _muted)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: onSave,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_blue, _blueDark],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: _blue.withOpacity(.35),
                          blurRadius: 12,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: const Center(
                    child: Text('Simpan Review',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _sectionHeader({
    required IconData icon,
    required String label,
    Color iconColor = _blue,
  }) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: iconColor.withOpacity(.1),
            borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: iconColor, size: 17),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -.2)),
    ]);
  }
}
