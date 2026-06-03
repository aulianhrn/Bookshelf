import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';

class ReviewService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Review>> getReviewsByBook(String bookId) async {
    final rows = await _client
        .from('reviews')
        .select(
          'id,user_id,book_id,book_title,rating,content,created_at',
        )
        .eq('book_id', bookId)
        .order('created_at', ascending: false);

    final userIds = rows
        .map<String>((row) => row['user_id'] as String)
        .toSet()
        .toList();
    final usernames = <String, String>{};

    if (userIds.isNotEmpty) {
      final users = await _client
          .from('users')
          .select('id,username')
          .inFilter('id', userIds);

      for (final user in users) {
        final id = user['id'] as String?;
        final username = user['username'] as String?;
        if (id != null && username != null) {
          usernames[id] = username;
        }
      }
    }

    return rows.map<Review>((row) {
      final userId = row['user_id'] as String;
      return Review.fromJson({...row, 'username': usernames[userId]});
    }).toList();
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
    final existing = await _client
        .from('reviews')
        .select('id')
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .maybeSingle();

    final values = {
      'book_title': bookTitle,
      'rating': rating,
      'content': content?.trim(),
    };

    if (existing == null) {
      await _client.from('reviews').insert({
        'user_id': userId,
        'book_id': bookId,
        ...values,
      });
      return;
    }

    await _client.from('reviews').update(values).eq('id', existing['id']);
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
