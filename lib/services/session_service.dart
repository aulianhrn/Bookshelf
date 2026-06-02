import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

class SessionService {
  static const String _sessionUserKey =
      'session_user';

  static Future<void> saveSession(
    AppUser user,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _sessionUserKey,
      jsonEncode(user.toJson()),
    );
  }

  static Future<AppUser?> getCurrentUser() async {
    final prefs =
        await SharedPreferences.getInstance();

    final rawUser =
        prefs.getString(_sessionUserKey);

    if (rawUser == null) {
      return null;
    }

    return AppUser.fromJson(
      jsonDecode(rawUser),
    );
  }

  static Future<bool> isLoggedIn() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.containsKey(
      _sessionUserKey,
    );
  }

  static Future<void> logout() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _sessionUserKey,
    );
  }
}