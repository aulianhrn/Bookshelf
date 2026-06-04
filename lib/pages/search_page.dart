import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import '../services/riwayat_servcie.dart';
import '../services/session_service.dart';
import 'detail_page.dart';

const _bg = Color(0xFFF4EAE1);
const _blue = Color(0xFF2563EB);
const _blueLight = Color(0xFFDBEAFE);
const _ink = Color(0xFF1E1B4B);
const _muted = Color(0xFF6B7280);
const _accent = Color(0xFF9E421E);
const _card = Color(0xFFFFFFFF);

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery,
    this.queryVersion = 0,
    this.isActive = false,
  });

  final String? initialQuery;
  final int queryVersion;
  final bool isActive;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _riwayatService = RiwayatService();
  final _genres = const ['Fiksi', 'Sains', 'Sejarah', 'Klasik'];

  AppUser? currentUser;
  List<String> recentSearches = [];
  List<OpenLibraryBook> books = [];
  bool _loading = false;
  bool _hasSearched = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _initHistory();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    if (widget.initialQuery?.isNotEmpty == true) {
      _searchInitialQuery();
    }
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.queryVersion != oldWidget.queryVersion &&
        widget.initialQuery?.isNotEmpty == true) {
      _searchInitialQuery();
    }
    if (widget.isActive && !oldWidget.isActive) {
      _initHistory();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _searchInitialQuery() {
    final query = widget.initialQuery!;
    _ctrl.text = query;
    _focus.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _search(query);
    });
  }

  Future<void> _search(String val) async {
    final q = val.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    await _saveHistory(q);
    try {
      final res = await OpenLibraryService.instance.searchBooks(
        query: q,
        limit: 20,
      );
      if (!mounted) return;
      setState(() => books = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Pencarian gagal: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    _ctrl.clear();
    _focus.unfocus();
    setState(() {
      _hasSearched = false;
      books = [];
      _focused = false;
    });
  }

  Future<void> _initHistory() async {
    final user = await SessionService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      currentUser = user;
      recentSearches = user == null ? [] : _riwayatService.getByUser(user.id);
    });
  }

  Future<void> _saveHistory(String q) async {
    final user = currentUser ?? await SessionService.getCurrentUser();
    if (user == null) return;

    await _riwayatService.saveSearch(userId: user.id, query: q);
    if (!mounted) return;
    setState(() {
      currentUser = user;
      recentSearches = _riwayatService.getByUser(user.id);
    });
  }

  Future<void> _clearHistory() async {
    final user = currentUser ?? await SessionService.getCurrentUser();
    if (user == null) return;

    await _riwayatService.clearByUser(user.id);
    if (mounted) setState(() => recentSearches = []);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasSearched,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _hasSearched) _clear();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    if (_hasSearched)
                      GestureDetector(
                        onTap: _clear,
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _ink.withOpacity(.06),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: _ink,
                            size: 20,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _ink.withOpacity(.06),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _focus,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _search,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: _ink, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Cari buku, penulis...',
                            hintStyle: const TextStyle(
                              color: _muted,
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: _muted,
                              size: 20,
                            ),
                            suffixIcon: _ctrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: _muted,
                                      size: 18,
                                    ),
                                    onPressed: _clear,
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: _hasSearched ? _buildResults() : _buildDiscovery(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscovery() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pencarian terakhir',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              TextButton(
                onPressed: _clearHistory,
                child: const Text(
                  'Hapus semua',
                  style: TextStyle(color: _accent, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: recentSearches
                .map(
                  (item) => GestureDetector(
                    onTap: () {
                      _ctrl.text = item;
                      _focus.unfocus();
                      _search(item);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _ink.withOpacity(.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 14,
                            color: _muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item,
                            style: const TextStyle(fontSize: 13, color: _ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        if (_focused) ...[
          const Text(
            'Jelajah genre',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _genres.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, i) {
              final g = _genres[i];
              return GestureDetector(
                onTap: () {
                  _ctrl.text = g;
                  _focus.unfocus();
                  _search(g);
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_blue.withOpacity(.08), _blueLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _blue.withOpacity(.15)),
                  ),
                  child: Center(
                    child: Text(
                      g,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    ),
  );

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (books.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: _muted),
            SizedBox(height: 12),
            Text(
              'Tidak ada buku ditemukan.',
              style: TextStyle(color: _muted, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: books.length,
      itemBuilder: (_, i) {
        final b = books[i];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailBookPage(bookId: b.id)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _ink.withOpacity(.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    b.coverUrl,
                    width: 44,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 60,
                      color: _blueLight,
                      child: const Icon(
                        Icons.book_rounded,
                        color: _blue,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          b.author,
                          if (b.firstPublishYear != null)
                            '${b.firstPublishYear}',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
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
      },
    );
  }
}
