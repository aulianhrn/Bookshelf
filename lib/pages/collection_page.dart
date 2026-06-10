import 'package:bookself_/services/review_service.dart';
import 'package:bookself_/services/session_service.dart';
import 'package:flutter/material.dart';
import 'detail_page.dart';
import '../models/app_user.dart';
import '../services/reading_list_service.dart';

const _bg = Color(0xFFF4EAE1);
const _blue = Color(0xFF2563EB);
const _blueDark = Color(0xFF1E40AF);
const _blueLight = Color(0xFFDBEAFE);
const _ink = Color(0xFF1E1B4B);
const _muted = Color(0xFF6B7280);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFF59E0B);
const _card = Color(0xFFFFFFFF);

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key, this.isActive = false});
  final bool isActive;
  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> readingList = [];
  List<Map<String, dynamic>> finishedList = [];
  AppUser? currentUser;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CollectionPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _load();
    }
  }

  Future<void> _init() async {
    final u = await SessionService.getCurrentUser();
    if (mounted) setState(() => currentUser = u);
    await _load();
  }

  Future<void> _load() async {
    if (currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final r = await ReadingListService().getReadingList(
        userId: currentUser!.id,
        isFinished: false,
      );
      final f = await ReadingListService().getReadingList(
        userId: currentUser!.id,
        isFinished: true,
      );
      if (!mounted) return;
      setState(() {
        readingList = r;
        finishedList = f;
      });
    } catch (e) {
      if (mounted) _snack('Gagal memuat: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Koleksiku',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tab switcher
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: _ink.withOpacity(.05), blurRadius: 10),
                      ],
                    ),
                    child: TabBar(
                      controller: _tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: _muted,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      indicator: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_blue, _blueDark],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: [
                        const Tab(text: 'Daftar Bacaan'),
                        Tab(text: 'Selesai (${finishedList.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _blue))
                  : TabBarView(
                      controller: _tab,
                      children: [
                        _bookList(readingList, isReading: true),
                        _bookList(finishedList, isReading: false),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookList(List<Map<String, dynamic>> list, {required bool isReading}) {
    if (list.isEmpty)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReading
                  ? Icons.menu_book_outlined
                  : Icons.check_circle_outline_rounded,
              size: 64,
              color: _muted.withOpacity(.4),
            ),
            const SizedBox(height: 12),
            Text(
              isReading
                  ? 'Belum ada buku di daftar bacaan'
                  : 'Belum ada buku yang selesai dibaca',
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ],
        ),
      );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final b = list[i];
        return Dismissible(
          key: Key(isReading ? b['id'] : 'f_${b['id']}'),
          direction: isReading
              ? DismissDirection.horizontal
              : DismissDirection.endToStart,
          background: _swipeBg(
            isReading ? _green : _red,
            isReading
                ? Icons.check_circle_outline_rounded
                : Icons.delete_outline_rounded,
            isReading ? 'Selesai' : 'Hapus',
            Alignment.centerLeft,
          ),
          secondaryBackground: isReading
              ? _swipeBg(
                  _red,
                  Icons.delete_outline_rounded,
                  'Hapus',
                  Alignment.centerRight,
                )
              : null,
          confirmDismiss: (dir) => _confirmDismiss(dir, b, isReading),
          onDismissed: (dir) => _onDismissed(dir, b, isReading),
          child: _bookCard(b, isReading),
        );
      },
    );
  }

  Widget _swipeBg(Color col, IconData icon, String label, Alignment align) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: col,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (align == Alignment.centerLeft) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (align == Alignment.centerRight) ...[
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, color: Colors.white, size: 20),
            ],
          ],
        ),
      );

  Future<bool?> _confirmDismiss(
    DismissDirection dir,
    Map<String, dynamic> b,
    bool isReading,
  ) async {
    final toFinish = isReading && dir == DismissDirection.startToEnd;
    final toDelete = (!isReading) || dir == DismissDirection.endToStart;
    if (!toFinish && !toDelete) return false;
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(toFinish ? 'Tandai selesai?' : 'Hapus buku?'),
        content: Text(
          toFinish
              ? '"${b['book_title']}" akan dipindah ke Selesai Dibaca.'
              : '"${b['book_title']}" akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: toFinish ? _green : _red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(toFinish ? 'Ya' : 'Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _onDismissed(
    DismissDirection dir,
    Map<String, dynamic> b,
    bool isReading,
  ) async {
    if (isReading && dir == DismissDirection.startToEnd) {
      final rev = await ReviewService().getReviewsByUser(currentUser!.id);
      final rat = rev.where((r) => r.bookId == b['book_id']).isNotEmpty
          ? rev.firstWhere((r) => r.bookId == b['book_id']).rating
          : 0;
      await ReadingListService().markAsFinished(b['id'], rating: rat);
    } else if (!isReading || dir == DismissDirection.endToStart) {
      if (!isReading) {
        await ReadingListService().unmarkFinished(b['id']);
      } else {
        await ReadingListService().removeFromReadingList(
          userId: currentUser!.id,
          bookId: b['book_id'],
        );
      }
    }
    await _load();
  }

  Widget _bookCard(Map<String, dynamic> b, bool isReading) {
    final rating = b['user_rating'] ?? 0;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailBookPage(bookId: b['book_id']),
          ),
        );
        await _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _ink.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                b['cover_url'] ?? '',
                width: 48,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 64,
                  color: _blueLight,
                  child: const Icon(Icons.book_rounded, color: _blue, size: 26),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b['book_title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b['book_author'] ?? '',
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),

                  // if (!isReading) ...[
                  //   const SizedBox(height: 8),
                  //   Row(
                  //     children: [
                  //       ...List.generate(
                  //         5,
                  //         (i) => Icon(
                  //           i < rating
                  //               ? Icons.star_rounded
                  //               : Icons.star_outline_rounded,
                  //           color: _amber,
                  //           size: 16,
                  //         ),
                  //       ),
                  //       const SizedBox(width: 6),
                  //       Text(
                  //         rating == 0 ? 'Belum dirating' : '$rating.0',
                  //         style: const TextStyle(color: _muted, fontSize: 12),
                  //       ),
                  //     ],
                  //   ),
                  // ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: _muted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}