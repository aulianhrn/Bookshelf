import 'package:bookself_/services/session_service.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/open_library_book.dart';
import '../services/open_library_service.dart';
import '../services/bookstore_service.dart';
import 'collection_page.dart';
import 'detail_page.dart';
import 'login_page.dart';
import 'search_page.dart';
import 'profile_page.dart';

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
    final user = await SessionService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      currentUser = user;
    });
  }

  Future<void> logout() async {
    await SessionService.logout();
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

  Future<void> _findNearbyBookstore() async {
    final messenger = ScaffoldMessenger.of(context);

    final position = await BookstoreService.getCurrentLocation();

    if (position == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Tidak dapat mengakses lokasi. Pastikan GPS aktif dan izin lokasi diberikan.",
          ),
        ),
      );
      return;
    }

    await BookstoreService.openGoogleMapsBookstore(position);
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
                "Selamat Datang, ${currentUser?.username ?? 'Pembaca'}!",
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
              const Text(
                "Kategori Populer",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children:
                      [
                            "Fantasy",
                            "Romance",
                            "Mystery",
                            "Science Fiction",
                            "History",
                            "Horror",
                            "Biography",
                            "Thriller",
                          ]
                          .map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(category),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SearchPage(initialQuery: category),
                                    ),
                                  );
                                },
                                shape: const StadiumBorder(),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Banner toko buku terdekat
              GestureDetector(
                onTap: _findNearbyBookstore,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xffE6F1FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xff185FA5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.map_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Temukan toko buku terdekat",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff0C447C),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Cari toko buku di sekitar lokasimu",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xff185FA5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xff185FA5)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const SizedBox(height: 30),
              const Text(
                "Trending Sekarang",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
          if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
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
