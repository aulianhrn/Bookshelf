import 'package:flutter/material.dart';

import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import 'collection_page.dart';
import 'detail_page.dart';
import 'home_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final searchController = TextEditingController();
  final genres = const ["Fiksi", "Sains", "Sejarah", "Klasik"];
  final recentSearches = const [
    "The Great Gatsby",
    "Haruki Murakami",
    "Design Systems",
  ];

  bool isLoading = false;
  String query = "popular books";
  List<OpenLibraryBook> books = [];

  @override
  void initState() {
    super.initState();
    searchBooks(query);
  }

  Future<void> searchBooks(String value) async {
    final nextQuery = value.trim();
    if (nextQuery.isEmpty) return;

    setState(() {
      isLoading = true;
      query = nextQuery;
    });

    try {
      final results = await OpenLibraryService.instance.searchBooks(
        query: nextQuery,
        limit: 20,
      );

      if (!mounted) return;
      setState(() {
        books = results;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Pencarian gagal: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFBF9F5),
      appBar: AppBar(
        title: const Text("BookShelf"),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: searchBooks,
              decoration: InputDecoration(
                hintText: "Search books, authors...",
                prefixIcon: IconButton(
                  onPressed: () {
                    searchBooks(searchController.text);
                  },
                  icon: const Icon(Icons.search),
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    searchController.clear();
                  },
                  icon: const Icon(Icons.close),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pencarian Terakhir",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    searchController.clear();
                  },
                  child: const Text("Clear All"),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: recentSearches
                  .map(
                    (item) => ActionChip(
                      label: Text(item),
                      onPressed: () {
                        searchController.text = item;
                        searchBooks(item);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              "Genre Jelajah",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: genres.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) {
                final genre = genres[index];

                return Card(
                  child: InkWell(
                    onTap: () {
                      searchController.text = genre;
                      searchBooks(genre);
                    },
                    child: Center(
                      child: Text(
                        genre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              "Hasil: $query",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (books.isEmpty)
              const Text("Tidak ada buku ditemukan.")
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                        ),
                      ),
                      title: Text(book.title),
                      subtitle: Text(
                        [
                          book.author,
                          if (book.firstPublishYear != null)
                            "${book.firstPublishYear}",
                        ].join(" • "),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailBookPage(book: book),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: const Color(0xff9E421E),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CollectionPage()),
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
    );
  }
}
