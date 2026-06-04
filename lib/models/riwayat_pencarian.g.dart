// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'riwayat_pencarian.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RiwayatPencarianAdapter extends TypeAdapter<RiwayatPencarian> {
  @override
  final int typeId = 0;

  @override
  RiwayatPencarian read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RiwayatPencarian(
      uuid: fields[0] as String,
      riwayat: fields[1] as String,
      userId: fields[2] as String? ?? '',
      searchedAtMillis: fields[3] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, RiwayatPencarian obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.uuid)
      ..writeByte(1)
      ..write(obj.riwayat)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.searchedAtMillis);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiwayatPencarianAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
