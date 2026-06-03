import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';

class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AppUser> updateUser({
    required String id,
    required String username,
    required String email,
  }) async {
    final row = await _client
        .from('users')
        .update({'username': username, 'email': email})
        .eq('id', id)
        .select('id,email,username,avatar_url')
        .single();
    return AppUser.fromJson(row);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final path = '$userId/$fileName';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(upsert: true),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    await _client.from('users').update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  Future<void> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    // Verifikasi password lama dulu
    final row = await _client
        .from('users')
        .select('password_hash')
        .eq('id', userId)
        .single();

    // Gunakan hash yang sama seperti di AuthService
    final crypto = await _hashPassword(oldPassword);
    if (row['password_hash'] != crypto) {
      throw Exception('Password lama tidak sesuai');
    }

    final newHash = await _hashPassword(newPassword);
    await _client
        .from('users')
        .update({'password_hash': newHash})
        .eq('id', userId);
  }

  Future<String> _hashPassword(String password) async {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<Map<String, int>> getReadingStats(String userId) async {
    final reading = await _client
        .from('reading_list')
        .select('id')
        .eq('user_id', userId)
        .eq('is_finished', false);

    final finished = await _client
        .from('reading_list')
        .select('id')
        .eq('user_id', userId)
        .eq('is_finished', true);

    final reviews = await _client
        .from('reviews')
        .select('id')
        .eq('user_id', userId);

    return {
      'reading': reading.length,
      'finished': finished.length,
      'reviews': reviews.length,
    };
  }

  Future<void> removeAvatar(String userId) async {
    // Hapus file dari storage
    await _client.storage.from('avatars').remove([
      '$userId/avatar.jpg',
      '$userId/avatar.png',
      '$userId/avatar.jpeg',
    ]);

    // Kosongkan avatar_url di database
    await _client.from('users').update({'avatar_url': null}).eq('id', userId);
  }
}
