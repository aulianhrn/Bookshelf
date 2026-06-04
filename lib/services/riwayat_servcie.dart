import 'package:hive/hive.dart';

import '../models/riwayat_pencarian.dart';

class RiwayatService {
  RiwayatService({Box<RiwayatPencarian>? box})
    : _box = box ?? Hive.box<RiwayatPencarian>('riwayat');

  final Box<RiwayatPencarian> _box;

  String _key(String userId, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    return '$userId::$normalizedQuery';
  }

  Future<void> saveSearch({
    required String userId,
    required String query,
  }) async {
    final cleanQuery = query.trim();
    if (userId.isEmpty || cleanQuery.isEmpty) return;

    final key = _key(userId, cleanQuery);
    await _box.put(
      key,
      RiwayatPencarian(
        uuid: key,
        riwayat: cleanQuery,
        userId: userId,
        searchedAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  List<String> getByUser(String userId, {int limit = 10}) {
    if (userId.isEmpty) return [];

    final rows = _box.values.where((item) => item.userId == userId).toList()
      ..sort((a, b) => b.searchedAtMillis.compareTo(a.searchedAtMillis));

    return rows.map((item) => item.riwayat).take(limit).toList();
  }

  Future<void> clearByUser(String userId) async {
    if (userId.isEmpty) return;

    final keys = _box.keys.where((key) {
      final item = _box.get(key);
      return item?.userId == userId;
    }).toList();

    await _box.deleteAll(keys);
  }
}

// Kept for existing imports that use the original typo in the filename/class.
class RiwayatServcie extends RiwayatService {}
