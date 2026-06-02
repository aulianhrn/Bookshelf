import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/app_user.dart';
import 'session_service.dart';
import 'supabase_service.dart';

class AuthService {
  String hashPassword(String password) {
    return sha256.convert(
      utf8.encode(password),
    ).toString();
  }

  Future<AppUser> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final row = await SupabaseService.client
        .from('users')
        .insert({
          'username': username,
          'email': email,
          'password_hash': hashPassword(password),
        })
        .select('id,email,username')
        .single();

    final user = AppUser.fromJson(row);

    await SessionService.saveSession(user);

    return user;
  }

  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    final row = await SupabaseService.client
        .from('users')
        .select(
          'id,email,username,password_hash',
        )
        .eq('email', email)
        .maybeSingle();

    if (row == null) return null;

    if (row['password_hash'] !=
        hashPassword(password)) {
      return null;
    }

    final user = AppUser.fromJson(row);

    await SessionService.saveSession(user);

    return user;
  }
}