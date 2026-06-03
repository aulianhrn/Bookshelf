import 'package:bookself_/services/review_service.dart';
import 'package:bookself_/services/session_service.dart';
import 'package:flutter/material.dart';
import 'detail_page.dart';
import '../models/app_user.dart';
import '../services/reading_list_service.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  bool isReading = true;
  bool isLoadingReadingList = true;
  List<Map<String, dynamic>> readingList = [];
  List<Map<String, dynamic>> finishedList = [];
  AppUser? currentUser;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await SessionService.getCurrentUser();
    if (mounted) setState(() => currentUser = user);
    await Future.wait([loadReadingList()]);
  }

  Future<void> loadReadingList() async {
    if (currentUser == null) {
      if (mounted) setState(() => isLoadingReadingList = false);
      return;
    }

    try {
      final reading = await ReadingListService().getReadingList(
        userId: currentUser!.id,
        isFinished: false,
      );
      final finished = await ReadingListService().getReadingList(
        userId: currentUser!.id,
        isFinished: true,
      );
      if (!mounted) return;
      setState(() {
        readingList = reading;
        finishedList = finished;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat daftar bacaan: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoadingReadingList = false);
    }
  }

  Future<void> showRatingReviewSheet(Map<String, dynamic> book) async {
    int selectedRating = book['user_rating'] ?? 0;
    final contentController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      if (book['cover_url'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            book['cover_url'],
                            width: 36,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.book, size: 36),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book['book_title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              book['book_author'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bintang rating
                  const Text("Rating kamu"),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setStateSheet(() => selectedRating = index + 1);
                        },
                        child: Icon(
                          index < selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Input komentar
                  const Text("Komentar (opsional)"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Tulis pendapatmu tentang buku ini...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tombol simpan
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedRating == 0
                          ? null
                          : () async {
                              Navigator.pop(context);
                              try {
                                // Simpan rating ke reading_list
                                await ReadingListService().updateUserRating(
                                  id: book['id'],
                                  rating: selectedRating,
                                );

                                // Simpan review ke tabel reviews
                                await ReviewService().createReview(
                                  userId: currentUser!.id,
                                  bookId: book['book_id'],
                                  bookTitle: book['book_title'],
                                  rating: selectedRating,
                                  content: contentController.text,
                                );

                                await loadReadingList();

                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text("Review berhasil disimpan"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(content: Text("Gagal: $e")),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff185FA5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("Simpan Review"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                              "Selesai Dibaca (${finishedList.length})",
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
            child: isLoadingReadingList
                ? const Center(child: CircularProgressIndicator())
                : isReading
                ? readingList.isEmpty
                      ? const Center(
                          child: Text(
                            "Belum ada buku di daftar bacaan.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: readingList.length,
                          itemBuilder: (context, index) {
                            final book = readingList[index];
                            return Dismissible(
                              key: Key(book['id']),
                              // Swipe kanan → selesai dibaca
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xff1D9E75),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      "Selesai dibaca",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Swipe kiri → hapus
                              secondaryBackground: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xffE24B4A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      "Hapus",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  // Konfirmasi selesai dibaca
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Selesai dibaca?"),
                                      content: Text(
                                        "\"${book['book_title']}\" akan dipindah ke Selesai Dibaca.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Batal"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text("Ya"),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  // Konfirmasi hapus
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Hapus buku?"),
                                      content: Text(
                                        "\"${book['book_title']}\" akan dihapus dari daftar bacaan.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Batal"),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xffE24B4A,
                                            ),
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text("Hapus"),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              onDismissed: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  final existingReviews = await ReviewService()
                                      .getReviewsByUser(currentUser!.id);
                                  final bookReview = existingReviews
                                      .where((r) => r.bookId == book['book_id'])
                                      .toList();

                                  final rating = bookReview.isNotEmpty
                                      ? bookReview.first.rating
                                      : 0;
                                  await ReadingListService().markAsFinished(
                                    book['id'],
                                    rating: rating,
                                  );
                                } else {
                                  await ReadingListService()
                                      .removeFromReadingList(
                                        userId: currentUser!.id,
                                        bookId: book['book_id'],
                                      );
                                }
                                await loadReadingList();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () async {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DetailBookPage(
                                          bookId: book['book_id'],
                                          bookTitle: book['book_title'],
                                          bookAuthor: book['book_author'] ?? '',
                                          imageUrl: book['cover_url'] ?? '',
                                        ),
                                      ),
                                    );
                                    await loadReadingList();
                                  },
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      book['cover_url'] ?? '',
                                      width: 44,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 44,
                                        height: 56,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.book, size: 24),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    book['book_title'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    book['book_author'] ?? '',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                ),
                              ),
                            );
                          },
                        )
                : finishedList.isEmpty
                ? const Center(
                    child: Text(
                      "Belum ada buku yang selesai dibaca.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: finishedList.length,
                    itemBuilder: (context, index) {
                      final book = finishedList[index];
                      return Dismissible(
                        key: Key('finished_${book['id']}'),
                        direction:
                            DismissDirection.endToStart, // hanya swipe kiri
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xffE24B4A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                "Hapus",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.delete_outline, color: Colors.white),
                            ],
                          ),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Hapus buku?"),
                              content: Text(
                                "\"${book['book_title']}\" akan dihapus dari daftar selesai dibaca.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Batal"),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xffE24B4A),
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Hapus"),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          await ReadingListService().unmarkFinished(book['id']);
                          await loadReadingList();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: // Ganti trailing dan subtitle di ListTile finishedList
                          ListTile(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailBookPage(
                                    bookId: book['book_id'],
                                    bookTitle: book['book_title'],
                                    bookAuthor: book['book_author'] ?? '',
                                    imageUrl: book['cover_url'] ?? '',
                                  ),
                                ),
                              );
                              await loadReadingList();
                            },
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                book['cover_url'] ?? '',
                                width: 44,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 56,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.book, size: 24),
                                ),
                              ),
                            ),
                            title: Text(
                              book['book_title'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // ✅ Bintang interaktif sebagai subtitle
                            subtitle: GestureDetector(
                              onTap: () => showRatingReviewSheet(book),
                              child: Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    final rating = book['user_rating'] ?? 0;
                                    return Icon(
                                      index < rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 18,
                                    );
                                  }),
                                  const SizedBox(width: 6),
                                  Text(
                                    book['user_rating'] == 0 ||
                                            book['user_rating'] == null
                                        ? "Beri rating"
                                        : "${book['user_rating']}.0",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

    );
  }
}
