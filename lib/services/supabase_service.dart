import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/review.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static const supabaseUrl = 'https://ioibwzbdgkwkzpgvyyeh.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvaWJ3emJkZ2t3a3pwZ3Z5eWVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzMjUwMDcsImV4cCI6MjA5NTkwMTAwN30.n1C9nTt4IF55p3mtsA8iDq6aC31x7HHLmR72XRh99oU';

  static const _sessionUserKey = 'session_user';

  SupabaseClient get _client => Supabase.instance.client;

  String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Future<AppUser?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUser = prefs.getString(_sessionUserKey);
    if (rawUser == null) return null;

    return AppUser.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
  }

  Future<void> saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionUserKey, jsonEncode(user.toJson()));
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUserKey);
  }

  Future<AppUser> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final existingUser = await findUserByEmail(normalizedEmail);
    if (existingUser != null) {
      throw const AuthException('Email sudah terdaftar.');
    }

    final row = await _client
        .from('users')
        .insert({
          'email': normalizedEmail,
          'username': username.trim(),
          'password_hash': hashPassword(password),
        })
        .select('id,email,username')
        .single();

    final user = AppUser.fromJson(row);
    await saveSession(user);
    return user;
  }

  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    final row = await _client
        .from('users')
        .select('id,email,username,password_hash')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();

    if (row == null) return null;
    if (row['password_hash'] != hashPassword(password)) return null;

    final user = AppUser.fromJson(row);
    await saveSession(user);
    return user;
  }

  Future<AppUser?> findUserByEmail(String email) async {
    final row = await _client
        .from('users')
        .select('id,email,username')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();

    return row == null ? null : AppUser.fromJson(row);
  }

  Future<List<AppUser>> getUsers() async {
    final rows = await _client
        .from('users')
        .select('id,email,username')
        .order('created_at', ascending: false);

    return rows.map<AppUser>((row) => AppUser.fromJson(row)).toList();
  }

  Future<AppUser> updateUser({
    required String id,
    required String username,
    required String email,
  }) async {
    final row = await _client
        .from('users')
        .update({
          'username': username.trim(),
          'email': email.trim().toLowerCase(),
        })
        .eq('id', id)
        .select('id,email,username')
        .single();

    final user = AppUser.fromJson(row);
    await saveSession(user);
    return user;
  }

  Future<void> deleteUser(String id) async {
    await _client.from('users').delete().eq('id', id);
    await logout();
  }

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

  Future<Review> createReview({
    required String userId,
    required String bookId,
    required String bookTitle,
    required int rating,
    String? content,
  }) async {
    final row = await _client
        .from('reviews')
        .insert({
          'user_id': userId,
          'book_id': bookId,
          'book_title': bookTitle,
          'rating': rating,
          'content': content?.trim(),
        })
        .select('id,user_id,book_id,book_title,rating,content,created_at')
        .single();

    return Review.fromJson(row);
  }

  Future<Review> updateReview({
    required String id,
    required int rating,
    String? content,
  }) async {
    final row = await _client
        .from('reviews')
        .update({'rating': rating, 'content': content?.trim()})
        .eq('id', id)
        .select('id,user_id,book_id,book_title,rating,content,created_at')
        .single();

    return Review.fromJson(row);
  }

  Future<void> deleteReview(String id) async {
    await _client.from('reviews').delete().eq('id', id);
  }
}
