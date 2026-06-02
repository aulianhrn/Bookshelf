import '../models/app_user.dart';
import 'supabase_service.dart';

class UserService {
  Future<List<AppUser>> getUsers() async {
    final rows = await SupabaseService.client
        .from('users')
        .select('id,email,username');

    return rows
        .map<AppUser>(
          (e) => AppUser.fromJson(e),
        )
        .toList();
  }

  Future<AppUser> updateUser({
    required String id,
    required String username,
    required String email,
  }) async {
    final row = await SupabaseService.client
        .from('users')
        .update({
          'username': username,
          'email': email,
        })
        .eq('id', id)
        .select('id,email,username')
        .single();

    return AppUser.fromJson(row);
  }

  Future<void> deleteUser(
    String id,
  ) async {
    await SupabaseService.client
        .from('users')
        .delete()
        .eq('id', id);
  }
}