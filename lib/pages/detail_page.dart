import 'package:bookself_/services/review_service.dart';
import 'package:bookself_/services/session_service.dart';
import 'package:flutter/material.dart';
import '../models/open_library_book.dart';
import '../models/review.dart';
import '../services/open_library_service.dart';
import '../models/app_user.dart';
import '../services/reading_list_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailBookPage extends StatefulWidget {
  const DetailBookPage({
    super.key,
    this.book,
    this.bookId = '',
    this.bookTitle = '',
    this.bookAuthor = '',
    this.imageUrl = '',
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
  int? get effectiveEditionCount => book?.editionCount;

  @override
  State<DetailBookPage> createState() => _DetailBookPageState();
}

class _DetailBookPageState extends State<DetailBookPage> {
  bool expanded = false;
  bool isLoadingReviews = true;
  bool isInReadingList = false;
  bool isLoadingReadingList = false;
  bool isFinished = false;
  List<Review> reviews = [];
  AppUser? currentUser;
  String? synopsis;
  bool isLoadingSynopsis = false;

  @override
  void initState() {
    super.initState();
    loadReviews();
    loadSynopsis();
    _loadCurrentUser().then((_) => checkReadingList());
  }

  Future<void> _loadCurrentUser() async {
    final user = await SessionService.getCurrentUser();
    if (mounted) setState(() => currentUser = user);
  }

  Future<void> checkReadingList() async {
    if (currentUser == null) return;

    final inList = await ReadingListService().isInReadingList(
      userId: currentUser!.id,
      bookId: widget.effectiveBookId,
    );

    final finished = await ReadingListService().isFinished(
      userId: currentUser!.id,
      bookId: widget.effectiveBookId,
    );

    if (mounted) {
      setState(() {
        isInReadingList = inList;
        isFinished = finished;
      });
    }
  }

  Future<void> toggleReadingList() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan login terlebih dahulu")),
      );
      return;
    }

    setState(() => isLoadingReadingList = true);

    try {
      if (isFinished) {
        // Jika sudah selesai → pindah kembali ke daftar bacaan
        final rows = await Supabase.instance.client
            .from('reading_list')
            .select('id')
            .eq('user_id', currentUser!.id)
            .eq('book_id', widget.effectiveBookId)
            .limit(1);

        if (rows.isNotEmpty) {
          await ReadingListService().unmarkFinished(rows.first['id']);
        }

        if (mounted)
          setState(() {
            isFinished = false;
            isInReadingList = true;
          });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Buku dipindahkan kembali ke daftar bacaan"),
            ),
          );
        }
      } else if (isInReadingList) {
        // Jika di daftar bacaan → hapus dari perpustakaan
        await ReadingListService().removeFromReadingList(
          userId: currentUser!.id,
          bookId: widget.effectiveBookId,
        );
        if (mounted) setState(() => isInReadingList = false);
      } else {
        // Belum ada → tambah ke daftar bacaan
        await ReadingListService().addToReadingList(
          userId: currentUser!.id,
          book: widget.book!,
        );
        if (mounted) setState(() => isInReadingList = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
      }
    } finally {
      if (mounted) setState(() => isLoadingReadingList = false);
    }
  }

  Future<void> loadSynopsis() async {
    final workKey = widget.book?.id; // id dari OpenLibraryBook adalah key-nya
    if (workKey == null) return;

    setState(() => isLoadingSynopsis = true);

    try {
      final result = await OpenLibraryService.instance.getBookDescription(
        workKey,
      );
      if (!mounted) return;
      setState(() => synopsis = result);
    } catch (_) {
      // Gagal ambil sinopsis, biarkan null — fallback ke teks default
    } finally {
      if (mounted) setState(() => isLoadingSynopsis = false);
    }
  }

  Future<void> loadReviews() async {
    setState(() {
      isLoadingReviews = true;
    });

    try {
      final rows = await ReviewService().getReviewsByBook(
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
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan login untuk menulis review")),
      );
      return;
    }

    var rating = 5;
    final contentController = TextEditingController();
    // ✅ Simpan context sebelum dialog dibuka
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          // ✅ Ganti nama parameter agar tidak menimpa dialogContext
          builder: (_, setDialogState) {
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
                          setDialogState(() => rating = index + 1);
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final content = contentController.text.trim();
                    Navigator.pop(dialogContext);
                    try {
                      await ReviewService().createReview(
                        userId: currentUser!.id,
                        bookId: widget.effectiveBookId,
                        bookTitle: widget.effectiveBookTitle,
                        rating: rating,
                        content: content,
                      );

                      await loadReviews();

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text("Review berhasil disimpan"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (error) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text("Gagal: $error")),
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

  Future<void> showEditReviewDialog(Review review) async {
    final contentController = TextEditingController(text: review.content);
    int selectedRating = review.rating;
    // ✅ Simpan scaffoldMessenger sebelum dialog dibuka
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          // ✅ Ganti (context, setStateDialog) → (_, setStateDialog)
          builder: (_, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit Review"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setStateDialog(() => selectedRating = index + 1);
                        },
                      );
                    }),
                  ),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "Isi review"),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await ReviewService().deleteReview(review.id);
                      if (currentUser != null) {
                        final rows = await Supabase.instance.client
                            .from('reading_list')
                            .select('id')
                            .eq('user_id', currentUser!.id)
                            .eq('book_id', widget.effectiveBookId)
                            .limit(1);
                        if (rows.isNotEmpty) {
                          await ReadingListService().updateUserRating(
                            id: rows.first['id'],
                            rating: 0,
                          );
                        }
                      }
                      await loadReviews();
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text("Gagal menghapus: $e")),
                      );
                    }
                  },
                  child: const Text(
                    "Hapus",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await ReviewService().updateReview(
                        id: review.id,
                        rating: selectedRating,
                        content: contentController.text,
                      );
                      await loadReviews();
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text("Gagal mengupdate: $e")),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: isLoadingReadingList ? null : toggleReadingList,
                  icon: isLoadingReadingList
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isFinished
                              ? Icons.check_circle
                              : isInReadingList
                              ? Icons.library_books
                              : Icons.library_add,
                        ),
                  label: Text(
                    isFinished
                        ? "Selesai dibaca"
                        : isInReadingList
                        ? "Hapus dari perpustakaan"
                        : "Tambah ke perpustakaan",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFinished
                        ? Colors
                              .grey
                              .shade400 // abu-abu jika selesai
                        : isInReadingList
                        ? const Color(0xff9E421E) // merah jika di daftar bacaan
                        : const Color(
                            0xff185FA5,
                          ), // biru jika belum ditambahkan
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: showReviewDialog,
                  icon: const Icon(Icons.rate_review),
                  label: const Text("Tulis Review"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff031632),
                    side: const BorderSide(color: Color(0xff031632)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
            // Teks fallback jika API tidak punya sinopsis
            Builder(
              builder: (context) {
                const fallback = "Sinopsis tidak tersedia untuk buku ini.";
                final fullSynopsis = synopsis ?? fallback;
                final shortSynopsis = fullSynopsis.length > 150
                    ? '${fullSynopsis.substring(0, 150)}...'
                    : fullSynopsis;

                if (isLoadingSynopsis) {
                  return const Center(child: CircularProgressIndicator());
                }

                return AnimatedCrossFade(
                  firstChild: Text(shortSynopsis),
                  secondChild: Text(fullSynopsis),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                );
              },
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                itemBuilder: (context, index) => reviewCard(reviews[index]),
              ),
          ],
        ),
      ),
    );
  }

  Widget reviewCard(Review review) {
    final name = (review.username == null || review.username!.isEmpty)
        ? "Pembaca"
        : review.username!;
    // Cek apakah review ini milik user yang sedang login
    final isOwner = currentUser?.id == review.userId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P'),
                ),
                const SizedBox(width: 12),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                // ✅ Tampilkan tombol edit hanya jika milik sendiri
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => showEditReviewDialog(review),
                  ),
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
