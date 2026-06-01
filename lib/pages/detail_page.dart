import 'package:flutter/material.dart';

import '../models/open_library_book.dart';
import '../models/review.dart';
import '../services/supabase_service.dart';

class DetailBookPage extends StatefulWidget {
  const DetailBookPage({
    super.key,
    this.book,
    this.bookId = 'silent-alchemist',
    this.bookTitle = 'The Silent Alchemist',
    this.bookAuthor = 'Elias Thornewood',
    this.imageUrl = 'https://images.unsplash.com/photo-1544947950-fa07a98d237f',
  });

  final OpenLibraryBook? book;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String imageUrl;

  String get effectiveBookId => book?.id ?? bookId;
  String get effectiveBookTitle => book?.title ?? bookTitle;
  String get effectiveBookAuthor => book?.author ?? bookAuthor;
  String get effectiveImageUrl => book?.coverUrl ?? imageUrl;
  int? get effectivePublishYear => book?.firstPublishYear;
  int? get effectiveEditionCount => book?.editionCount;

  @override
  State<DetailBookPage> createState() => _DetailBookPageState();
}

class _DetailBookPageState extends State<DetailBookPage> {
  bool expanded = false;
  bool isLoadingReviews = true;
  List<Review> reviews = [];

  @override
  void initState() {
    super.initState();
    loadReviews();
  }

  Future<void> loadReviews() async {
    setState(() {
      isLoadingReviews = true;
    });

    try {
      final rows = await SupabaseService.instance.getReviewsByBook(
        widget.effectiveBookId,
      );
      if (!mounted) return;
      setState(() {
        reviews = rows;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal memuat review: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isLoadingReviews = false;
        });
      }
    }
  }

  Future<void> showReviewDialog() async {
    final user = await SupabaseService.instance.getCurrentUser();
    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan login untuk menulis review")),
      );
      return;
    }

    var rating = 5;
    final contentController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Tulis Review"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Rating"),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        onPressed: () {
                          setDialogState(() {
                            rating = index + 1;
                          });
                        },
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Isi review",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await SupabaseService.instance.createReview(
                        userId: user.id,
                        bookId: widget.effectiveBookId,
                        bookTitle: widget.effectiveBookTitle,
                        rating: rating,
                        content: contentController.text,
                      );

                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      await loadReviews();
                    } catch (error) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text("Gagal menyimpan review: $error"),
                        ),
                      );
                    }
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );

    contentController.dispose();
  }

  double get averageRating {
    if (reviews.isEmpty) return 0;
    final total = reviews.fold<int>(0, (sum, review) => sum + review.rating);
    return total / reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final ratingText = reviews.isEmpty
        ? widget.book?.ratingText ?? "-"
        : averageRating.toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xffFBF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xffFBF9F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xff031632),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "BookShelf",
          style: TextStyle(
            color: Color(0xff031632),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 240,
                height: 360,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(blurRadius: 15, color: Colors.black12),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.effectiveImageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffCFE8DD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Sastra Klasik",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                widget.effectiveBookTitle,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff031632),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.effectiveBookAuthor,
                style: const TextStyle(fontSize: 18, color: Color(0xff9E421E)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 4),
                Text(ratingText),
                const SizedBox(width: 16),
                Text("${reviews.length} Review"),
                const SizedBox(width: 16),
                Text(
                  widget.effectiveEditionCount == null
                      ? "Open Library"
                      : "${widget.effectiveEditionCount} Edisi",
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.bookmark),
                    label: const Text("Simpan"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff9E421E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: showReviewDialog,
                    icon: const Icon(Icons.rate_review),
                    label: const Text("Review"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff031632),
                      side: const BorderSide(color: Color(0xff031632)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "Sinopsis",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            AnimatedCrossFade(
              firstChild: const Text(
                "Di jantung kota yang tak pernah tidur, seorang alkemis tua menyimpan rahasia yang dapat mengubah tatanan dunia. Novel ini mengikuti perjalanan seorang pemuda yang menemukan catatan kuno di sebuah perpustakaan terbengkalai...",
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: const Text(
                "Data buku diambil dari Open Library. Gunakan review pembaca di BookShelf untuk menyimpan catatan dan penilaian pribadi terhadap buku ini.",
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  expanded = !expanded;
                });
              },
              child: Text(expanded ? "Tutup" : "Baca Selengkapnya"),
            ),
            const SizedBox(height: 20),
            const Text(
              "Review Pembaca",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isLoadingReviews)
              const Center(child: CircularProgressIndicator())
            else if (reviews.isEmpty)
              const Text("Belum ada review untuk buku ini.")
            else
              ...reviews.map(reviewCard),
          ],
        ),
      ),
    );
  }

  Widget reviewCard(Review review) {
    final name = review.username ?? "Pembaca";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(name[0].toUpperCase())),
                const SizedBox(width: 12),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                5,
                (index) => Icon(
                  index < review.rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              review.content?.isEmpty ?? true
                  ? "Tidak ada komentar."
                  : review.content!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
