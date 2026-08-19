// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'face_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FaceInfoAdapter extends TypeAdapter<FaceInfo> {
  @override
  final int typeId = 0;

  @override
  FaceInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FaceInfo(
      cx: fields[0] as double,
      cy: fields[1] as double,
      faceHeightRatio: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, FaceInfo obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.cx)
      ..writeByte(1)
      ..write(obj.cy)
      ..writeByte(2)
      ..write(obj.faceHeightRatio);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaceInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
