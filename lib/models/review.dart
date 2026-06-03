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

    return Review(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      bookTitle: json['book_title'] as String,
      rating: json['rating'] as int,
      content: json['content'] as String?,
      username: json['username'] as String? ??
          (user is Map<String, dynamic>
          ? user['username'] as String?
          : null),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'] as String),
    );
  }
}
