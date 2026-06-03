import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import 'collection_page.dart';
import 'detail_page.dart';
import 'home_page.dart';
import 'profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final searchController = TextEditingController();
  final genres = const ["Fiksi", "Sains", "Sejarah", "Klasik"];
  List<String> recentSearches = [];
  static const _prefKey = 'recent_searches';
  bool isSearchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();
  bool isLoading = false;
  bool hasSearched = false; // ✅ track apakah user sudah search
  List<OpenLibraryBook> books = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchFocusNode.addListener(() {
      setState(() => isSearchFocused = _searchFocusNode.hasFocus);
    });
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        searchBooks(widget.initialQuery!);
      });
    }
  }

  Future<void> searchBooks(String value) async {
    final nextQuery = value.trim();
    if (nextQuery.isEmpty) return;

    setState(() {
      isLoading = true;
      hasSearched = true; // ✅ tandai sudah search
    });

    await _saveToHistory(nextQuery);

    try {
      final results = await OpenLibraryService.instance.searchBooks(
        query: nextQuery,
        limit: 20,
      );
      if (!mounted) return;
      setState(() => books = results);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Pencarian gagal: $error")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _clearSearch() {
    searchController.clear();
    _searchFocusNode.unfocus(); // ✅
    setState(() {
      hasSearched = false;
      books = [];
      isSearchFocused = false;
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => recentSearches = prefs.getStringList(_prefKey) ?? []);
    }
  }

  Future<void> _saveToHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    recentSearches.remove(query);
    recentSearches.insert(0, query);
    if (recentSearches.length > 10) {
      recentSearches = recentSearches.sublist(0, 10);
    }
    await prefs.setStringList(_prefKey, recentSearches);
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    if (mounted) setState(() => recentSearches = []);
  }

  @override
  void dispose() {
    searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasSearched,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && hasSearched) {
          _clearSearch();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xffFBF9F5),
        appBar: AppBar(
          backgroundColor: const Color(0xffFBF9F5),
          elevation: 0,
          title: const Row(
            children: [
              Icon(Icons.menu_book, color: Color(0xff031632)),
              SizedBox(width: 8),
              Text(
                "BookShelf",
                style: TextStyle(
                  color: Color(0xff031632),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ✅ Search bar fixed di atas, tidak ikut scroll
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: searchBooks,
                decoration: InputDecoration(
                  hintText: "Cari buku, penulis...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.close),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  // Refresh suffixIcon saat teks berubah
                  setState(() {});
                },
              ),
            ),

            // ✅ Konten berubah tergantung state
            Expanded(
              child: hasSearched ? _buildSearchResults() : _buildDiscovery(),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 1,
          selectedItemColor: const Color(0xff9E421E),
          unselectedItemColor: Colors.grey,
          onTap: (index) {
            if (index == 0) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            }
            if (index == 2) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const CollectionPage()),
                (route) => false,
              );
            }
            if (index == 3) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
                (_) => false,
              );
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories),
              label: "Collection",
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }

  // ✅ Tampilan sebelum search — history + genre
  Widget _buildDiscovery() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // History — selalu tampil jika ada
          if (recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pencarian terakhir",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _clearHistory,
                  child: const Text("Hapus semua"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: recentSearches
                  .map(
                    (item) => ActionChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(item),
                      onPressed: () {
                        searchController.text = item;
                        _searchFocusNode.unfocus();
                        searchBooks(item);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // ✅ Genre hanya tampil saat search bar difokuskan
          if (isSearchFocused) ...[
            const Text(
              "Cari berdasarkan genre",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: genres.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final genre = genres[index];
                return InkWell(
                  onTap: () {
                    searchController.text = genre;
                    _searchFocusNode
                        .unfocus(); // ✅ tutup keyboard saat genre dipilih
                    searchBooks(genre);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Center(
                      child: Text(
                        genre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
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
  }

  // ✅ Tampilan setelah search — hasil saja
  Widget _buildSearchResults() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (books.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Tidak ada buku ditemukan.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                book.coverUrl,
                width: 42,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 42,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.book, size: 24),
                ),
              ),
            ),
            title: Text(book.title),
            subtitle: Text(
              [
                book.author,
                if (book.firstPublishYear != null) "${book.firstPublishYear}",
              ].join(" • "),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailBookPage(book: book)),
              );
            },
          ),
        );
      },
    );
  }
}
