import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';

class ReviewService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Review>> getReviewsByBook(String bookId) async {
    final rows = await _client
        .from('reviews')
        .select(
          'id,user_id,book_id,book_title,rating,content,created_at,users(username)',
        )
        .eq('book_id', bookId)
        .order('created_at', ascending: false);

    return rows.map<Review>((row) => Review.fromJson(row)).toList();
  }

  Future<List<Review>> getReviewsByUser(String userId) async {
    final rows = await _client
        .from('reviews')
        .select('id,user_id,book_id,book_title,rating,content,created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows.map<Review>((row) => Review.fromJson(row)).toList();
  }

  Future<void> createReview({
    required String userId,
    required String bookId,
    required String bookTitle,
    required int rating,
    String? content,
  }) async {
    await _client.from('reviews').insert({
      'user_id': userId,
      'book_id': bookId,
      'book_title': bookTitle,
      'rating': rating,
      'content': content?.trim(),
    });
  }

  Future<void> updateReview({
    required String id,
    required int rating,
    String? content,
  }) async {
    await _client
        .from('reviews')
        .update({'rating': rating, 'content': content?.trim()})
        .eq('id', id);
  }

  Future<void> deleteReview(String id) async {
    await _client.from('reviews').delete().eq('id', id);
  }
}
