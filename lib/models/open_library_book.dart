class OpenLibraryBook {
  const OpenLibraryBook({
    required this.id,
    required this.title,
    required this.author,
    this.coverId,
    this.firstPublishYear,
    this.editionCount,
    this.ratingsAverage,
  });

  final String id;
  final String title;
  final String author;
  final int? coverId;
  final int? firstPublishYear;
  final int? editionCount;
  final double? ratingsAverage;

  factory OpenLibraryBook.fromJson(Map<String, dynamic> json) {
    final key = json['key']?.toString() ?? '';
    final authors = json['author_name'];
    final rating = json['ratings_average'];

    return OpenLibraryBook(
      id: key.replaceFirst('/works/', ''),
      title: json['title']?.toString() ?? 'Tanpa Judul',
      author: authors is List && authors.isNotEmpty
          ? authors.first.toString()
          : 'Penulis tidak diketahui',
      coverId: json['cover_i'] is int ? json['cover_i'] as int : null,
      firstPublishYear: json['first_publish_year'] is int
          ? json['first_publish_year'] as int
          : null,
      editionCount: json['edition_count'] is int
          ? json['edition_count'] as int
          : null,
      ratingsAverage: rating is num ? rating.toDouble() : null,
    );
  }

  String get coverUrl {
    if (coverId == null) {
      return 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=500';
    }

    return 'https://covers.openlibrary.org/b/id/$coverId-L.jpg';
  }

  String get ratingText {
    return ratingsAverage == null ? '-' : ratingsAverage!.toStringAsFixed(1);
  }
}
