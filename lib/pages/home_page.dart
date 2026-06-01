import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import '../services/supabase_service.dart';
import 'collection_page.dart';
import 'detail_page.dart';
import 'login_page.dart';
import 'search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppUser? currentUser;
  bool isLoadingBooks = true;
  List<OpenLibraryBook> trendingBooks = [];
  List<OpenLibraryBook> recommendations = [];

  @override
  void initState() {
    super.initState();
    loadUser();
    loadBooks();
  }

  Future<void> loadUser() async {
    final user = await SupabaseService.instance.getCurrentUser();
    if (!mounted) return;
    setState(() {
      currentUser = user;
    });
  }

  Future<void> logout() async {
    await SupabaseService.instance.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> loadBooks() async {
    try {
      final results = await Future.wait([
        OpenLibraryService.instance.getTrendingBooks(),
        OpenLibraryService.instance.getRecommendations(),
      ]);

      if (!mounted) return;
      setState(() {
        trendingBooks = results[0];
        recommendations = results[1];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memuat buku: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isLoadingBooks = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        actions: [
          IconButton(
            tooltip: "Keluar",
            onPressed: logout,
            icon: const Icon(Icons.logout, color: Colors.black54),
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Selamat pagi, ${currentUser?.username ?? 'Pembaca'}",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Temukan inspirasi baru untuk hari ini.",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Trending Sekarang",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text("Lihat Semua"),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 260,
                child: isLoadingBooks
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: trendingBooks.length,
                        itemBuilder: (context, index) {
                          final book = trendingBooks[index];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailBookPage(book: book),
                                ),
                              );
                            },
                            child: Container(
                              width: 170,
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      book.coverUrl,
                                      height: 200,
                                      width: 170,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    book.author,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.deepOrange,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Kategori Populer",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: const [
                  Chip(label: Text("Fantasy")),
                  Chip(label: Text("Romance")),
                  Chip(label: Text("Mystery")),
                  Chip(label: Text("Science Fiction")),
                  Chip(label: Text("History")),
                ],
              ),

              const SizedBox(height: 30),

              const Text(
                "Rekomendasi Untukmu",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final book = recommendations[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.book, size: 40),
                      title: Text(book.title),
                      subtitle: Text(book.author),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber),
                          Text(book.ratingText),
                        ],
                      ),
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
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xff9E421E),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
            );
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CollectionPage()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Collection",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
