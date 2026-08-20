// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoItemAdapter extends TypeAdapter<PhotoItem> {
  @override
  final int typeId = 1;

  @override
  PhotoItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhotoItem(
      id: fields[0] as String,
      originalPath: fields[1] as String,
      thumbnailPath: fields[2] as String?,
      processedPath: fields[3] as String?,
      name: fields[4] as String,
      nameEnabled: fields[5] as bool,
      face: fields[6] as FaceInfo?,
      brightness: fields[7] as double,
      contrast: fields[8] as double,
      sharpen: fields[9] as double,
      createdAt: fields[10] as DateTime?,
      updatedAt: fields[11] as DateTime?,
      processingStatus: fields[12] as ProcessingStatus,
      printPath: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PhotoItem obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.originalPath)
      ..writeByte(2)
      ..write(obj.thumbnailPath)
      ..writeByte(3)
      ..write(obj.processedPath)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.nameEnabled)
      ..writeByte(6)
      ..write(obj.face)
      ..writeByte(7)
      ..write(obj.brightness)
      ..writeByte(8)
      ..write(obj.contrast)
      ..writeByte(9)
      ..write(obj.sharpen)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.processingStatus)
      ..writeByte(13)
      ..write(obj.printPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
