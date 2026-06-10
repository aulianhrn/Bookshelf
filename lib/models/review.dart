class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.bookTitle,
    required this.rating,
    this.content,
    this.username,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String bookId;
  final String bookTitle;
  final int rating;
  final String? content;
  final String? username;
  final DateTime? createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    final user = json['users'];
    final ratingValue = json['rating'];

    return Review(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      bookId: json['book_id']?.toString() ?? '',
      bookTitle: json['book_title']?.toString() ?? '',
      rating: ratingValue is num
          ? ratingValue.toInt()
          : int.tryParse(ratingValue?.toString() ?? '') ?? 0,
      content: json['content']?.toString(),
      username:
          json['username']?.toString() ??
          (user is Map<String, dynamic> ? user['username']?.toString() : null),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
