import 'package:hive/hive.dart';
part 'riwayat_pencarian.g.dart';

// bikin box
@HiveType(typeId: 0)
class RiwayatPencarian extends HiveObject {
  @HiveField(0)
  final String uuid;

  @HiveField(1)
  final String riwayat;

  @HiveField(2)
  final String userId;

  @HiveField(3)
  final int searchedAtMillis;

  RiwayatPencarian({
    required this.uuid,
    required this.riwayat,
    required this.userId,
    required this.searchedAtMillis,
  });
}
