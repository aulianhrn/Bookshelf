import 'package:bookself_/services/session_service.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import '../services/bookstore_service.dart';
import 'detail_page.dart';
import 'login_page.dart';
import 'search_page.dart';

const _bg        = Color(0xFFF4EAE1);
const _blue      = Color(0xFF2563EB);
const _blueDark  = Color(0xFF1E40AF);
const _blueLight = Color(0xFFDBEAFE);
const _ink       = Color(0xFF1E1B4B);
const _muted     = Color(0xFF6B7280);
const _accent    = Color(0xFF9E421E);
const _card      = Color(0xFFFFFFFF);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppUser? currentUser;
  bool isLoadingBooks = true;
  List<OpenLibraryBook> trending       = [];
  List<OpenLibraryBook> recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadBooks();
  }

  Future<void> _loadUser() async {
    final u = await SessionService.getCurrentUser();
    if (!mounted) return;
    setState(() => currentUser = u);
  }

  Future<void> _logout() async {
    await SessionService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  Future<void> _loadBooks() async {
    try {
      final r = await Future.wait([
        OpenLibraryService.instance.getTrendingBooks(),
        OpenLibraryService.instance.getRecommendations(),
      ]);
      if (!mounted) return;
      setState(() { trending = r[0]; recommendations = r[1]; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat buku: $e')));
    } finally {
      if (mounted) setState(() => isLoadingBooks = false);
    }
  }

  Future<void> _findBookstore() async {
    final m = ScaffoldMessenger.of(context);
    final pos = await BookstoreService.getCurrentLocation();
    if (pos == null) {
      m.showSnackBar(const SnackBar(content: Text(
          'Tidak dapat mengakses lokasi. Pastikan GPS aktif.')));
      return;
    }
    await BookstoreService.openGoogleMapsBookstore(pos);
  }

  void _toDetail(OpenLibraryBook book) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => DetailBookPage(book: book)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(slivers: [
        // ── AppBar ──────────────────────────────────────────────
        SliverAppBar(
          backgroundColor: _bg,
          elevation: 0,
          floating: true,
          snap: true,
          title: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_blue, _blueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.menu_book_rounded,
                  color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            const Text('BookShelf', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: _ink, letterSpacing: -.3)),
          ]),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: _card, borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: _ink.withOpacity(.06), blurRadius: 8)]),
                child: const Icon(Icons.logout_rounded,
                    color: _accent, size: 18)),
              onPressed: _logout),
            const SizedBox(width: 8),
          ]),

        // ── Body ────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList(delegate: SliverChildListDelegate([

            // Greeting
            RichText(text: TextSpan(
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800,
                  color: _ink, height: 1.3),
              children: [
                const TextSpan(text: 'Halo, '),
                TextSpan(
                  text: '${currentUser?.username ?? 'Pembaca'}! 👋',
                  style: const TextStyle(color: _blue)),
              ])),
            const SizedBox(height: 4),
            const Text('Temukan inspirasi baru untuk hari ini.',
                style: TextStyle(color: _muted, fontSize: 14)),
            const SizedBox(height: 24),

            // Kategori label
            _sectionLabel('Kategori'),
            const SizedBox(height: 10),
            SizedBox(height: 38, child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Fantasy','Romance','Mystery',
                'Science Fiction','History','Horror',
                'Biography','Thriller']
                .map((cat) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _chip(cat, () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>
                          SearchPage(initialQuery: cat))))))
                .toList())),
            const SizedBox(height: 20),

            // Banner toko buku
            GestureDetector(
              onTap: _findBookstore,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFEFF6FF), _blueLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _blue.withOpacity(.15))),
                child: Row(children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_blue, _blueDark]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                          color: _blue.withOpacity(.25),
                          blurRadius: 12, offset: const Offset(0, 4))]),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 22)),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Temukan toko buku terdekat',
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w700, color: _blueDark)),
                      SizedBox(height: 2),
                      Text('Cari toko buku di sekitar lokasimu',
                          style: TextStyle(fontSize: 12, color: _blue)),
                    ])),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: _blue, size: 14),
                ]))),
            const SizedBox(height: 28),

            // Trending
            _sectionLabel('Trending Sekarang'),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: isLoadingBooks
                  ? const Center(child: CircularProgressIndicator(color: _blue))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: trending.length,
                      itemBuilder: (_, i) {
                        final b = trending[i];
                        return GestureDetector(
                          onTap: () => _toDetail(b),
                          child: Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(b.coverUrl,
                                    height: 180, width: 140,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 180, width: 140,
                                      color: _blueLight,
                                      child: const Icon(Icons.book_rounded,
                                          color: _blue, size: 40)))),
                                const SizedBox(height: 8),
                                Text(b.author,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _accent, fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(b.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _ink, fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              ])));
                      })),
            const SizedBox(height: 28),

            // Rekomendasi
            _sectionLabel('Rekomendasi Untukmu'),
            const SizedBox(height: 12),
            if (isLoadingBooks)
              const Center(child: CircularProgressIndicator(color: _blue))
            else
              ...recommendations.map((b) => _recoCard(b)),
          ]))),
      ]),
    );
  }

  Widget _sectionLabel(String t) => Text(t, style: const TextStyle(
      fontSize: 17, fontWeight: FontWeight.w800, color: _ink,
      letterSpacing: -.2));

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blue.withOpacity(.2)),
        boxShadow: [BoxShadow(
            color: _ink.withOpacity(.04), blurRadius: 6)]),
      child: Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _blue))));

  Widget _recoCard(OpenLibraryBook b) => GestureDetector(
    onTap: () => _toDetail(b),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: _ink.withOpacity(.05),
            blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(b.coverUrl,
            width: 48, height: 64, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 48, height: 64, color: _blueLight,
              child: const Icon(Icons.book_rounded,
                  color: _blue, size: 28)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 4),
            Text(b.author, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
              const SizedBox(width: 4),
              Text(b.ratingText,
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600, color: _ink)),
            ]),
          ])),
        const Icon(Icons.arrow_forward_ios_rounded,
            color: _muted, size: 14),
      ])));
}