import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/open_library_book.dart';

class ReadingListService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> isInReadingList({
    required String userId,
    required String bookId,
  }) async {
    final rows = await _client
        .from('reading_list')
        .select('id')
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> addToReadingList({
    required String userId,
    required OpenLibraryBook book,
  }) async {
    await _client.from('reading_list').insert({
      'user_id': userId,
      'book_id': book.id,
      'book_title': book.title,
      'book_author': book.author,
      'cover_url': book.coverUrl,
    });
  }

  Future<void> removeFromReadingList({
    required String userId,
    required String bookId,
  }) async {
    await _client
        .from('reading_list')
        .delete()
        .eq('user_id', userId)
        .eq('book_id', bookId);
  }

  // Pindah kembali ke daftar bacaan (batal selesai)
  Future<void> unmarkFinished(String id) async {
    await _client
        .from('reading_list')
        .update({'is_finished': false, 'finished_at': null})
        .eq('id', id);
  }

  // Cek apakah buku sudah selesai dibaca
  Future<bool> isFinished({
    required String userId,
    required String bookId,
  }) async {
    final rows = await _client
        .from('reading_list')
        .select('is_finished')
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .limit(1);

    if (rows.isEmpty) return false;
    return rows.first['is_finished'] == true;
  }

  Future<void> markAsFinished(String id, {int rating = 0}) async {
    await _client
        .from('reading_list')
        .update({
          'is_finished': true,
          'finished_at': DateTime.now().toIso8601String(),
          'user_rating': rating,
        })
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getReadingList({
    required String userId,
    required bool isFinished,
  }) async {
    final rows = await _client
        .from('reading_list')
        .select()
        .eq('user_id', userId)
        .eq('is_finished', isFinished)
        .order('added_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> updateUserRating({
    required String id,
    required int rating,
  }) async {
    await _client
        .from('reading_list')
        .update({'user_rating': rating})
        .eq('id', id);
  }
}
