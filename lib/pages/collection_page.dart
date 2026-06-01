import 'package:flutter/material.dart';

import '../models/review.dart';
import '../services/supabase_service.dart';
import 'detail_page.dart';
import 'home_page.dart';
import 'search_page.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  bool isReading = true;
  bool isLoadingReviews = true;
  List<Review> myReviews = [];

  final List<Map<String, String>> readingBooks = [
    {
      "title": "Meditations",
      "author": "Marcus Aurelius",
      "image":
          "https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=500",
    },
    {
      "title": "Crime and Punishment",
      "author": "Fyodor Dostoevsky",
      "image":
          "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=500",
    },
    {
      "title": "Ulysses",
      "author": "James Joyce",
      "image":
          "https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=500",
    },
    {
      "title": "To The Lighthouse",
      "author": "Virginia Woolf",
      "image":
          "https://images.unsplash.com/photo-1495446815901-a7297e633e8d?w=500",
    },
  ];

  @override
  void initState() {
    super.initState();
    loadMyReviews();
  }

  Future<void> loadMyReviews() async {
    final user = await SupabaseService.instance.getCurrentUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        isLoadingReviews = false;
      });
      return;
    }

    try {
      final rows = await SupabaseService.instance.getReviewsByUser(user.id);
      if (!mounted) return;
      setState(() {
        myReviews = rows;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memuat koleksi review: $error")),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReviews = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFBF9F5),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xffFBF9F5),
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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_outlined, color: Color(0xff031632)),
          ),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "My Collection",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff031632),
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),

                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              isReading = true;
                            });
                          },

                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),

                            decoration: BoxDecoration(
                              color: isReading
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: Text(
                              "Daftar Bacaan",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isReading
                                    ? const Color(0xff031632)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              isReading = false;
                            });
                          },

                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),

                            decoration: BoxDecoration(
                              color: !isReading
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: Text(
                              "Selesai Dibaca",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: !isReading
                                    ? const Color(0xff031632)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: isReading
                ? GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),

                    itemCount: readingBooks.length,

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: .55,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),

                    itemBuilder: (context, index) {
                      final book = readingBooks[index];

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailBookPage(
                                bookId: book["title"]!.toLowerCase().replaceAll(
                                  ' ',
                                  '-',
                                ),
                                bookTitle: book["title"]!,
                                bookAuthor: book["author"]!,
                                imageUrl: book["image"]!,
                              ),
                            ),
                          );
                        },

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),

                                child: Image.network(
                                  book["image"]!,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              book["author"]!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              book["title"]!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : isLoadingReviews
                ? const Center(child: CircularProgressIndicator())
                : myReviews.isNotEmpty
                ? ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: myReviews.length,
                    itemBuilder: (context, index) {
                      final review = myReviews[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.rate_review),
                          title: Text(review.bookTitle),
                          subtitle: Text(
                            review.content?.isEmpty ?? true
                                ? "Tanpa komentar"
                                : review.content!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber),
                              Text("${review.rating}"),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 120,
                            color: Colors.orange.shade300,
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "Belum ada review",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            "Review yang Anda buat akan muncul di sini.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),

                          const SizedBox(height: 30),

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff9E421E),
                            ),
                            onPressed: () {
                              setState(() {
                                isReading = true;
                              });
                            },
                            child: const Text("Lihat Daftar Bacaan"),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,

        selectedItemColor: const Color(0xff9E421E),

        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SearchPage()),
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
