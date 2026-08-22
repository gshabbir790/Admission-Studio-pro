// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoSessionAdapter extends TypeAdapter<PhotoSession> {
  @override
  final int typeId = 2;

  @override
  PhotoSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PhotoSession(
      id: fields[0] as String,
      photos: (fields[1] as List?)?.cast<PhotoItem>(),
      capacity: fields[2] as int,
      createdAt: fields[3] as DateTime?,
      updatedAt: fields[4] as DateTime?,
      targetWidth: fields[5] as int,
      targetHeight: fields[6] as int,
      sizePreset: fields[7] as PhotoSizePreset,
      backgroundMode: fields[8] as BackgroundMode,
      jpegQuality: fields[9] as int,
      backgroundIntensity: (fields[16] as int?) ?? 100,
      printPageSize: (fields[14] as PrintPageSize?) ?? PrintPageSize.photo4x6,
      singleMode: (fields[15] as bool?) ?? false,
      sizeLimitEnabled: fields[10] as bool,
      sizeLimitValue: fields[11] as double,
      sizeLimitUnit: fields[12] as FileSizeUnit,
      autoCaptureEnabled: fields[13] as bool,
      outputFormat: (fields[17] as ImageOutputFormat?) ?? ImageOutputFormat.jpeg,
    );
  }

  @override
  void write(BinaryWriter writer, PhotoSession obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.photos)
      ..writeByte(2)
      ..write(obj.capacity)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.targetWidth)
      ..writeByte(6)
      ..write(obj.targetHeight)
      ..writeByte(7)
      ..write(obj.sizePreset)
      ..writeByte(8)
      ..write(obj.backgroundMode)
      ..writeByte(9)
      ..write(obj.jpegQuality)
      ..writeByte(10)
      ..write(obj.sizeLimitEnabled)
      ..writeByte(11)
      ..write(obj.sizeLimitValue)
      ..writeByte(12)
      ..write(obj.sizeLimitUnit)
      ..writeByte(13)
      ..write(obj.autoCaptureEnabled)
      ..writeByte(14)
      ..write(obj.printPageSize)
      ..writeByte(15)
      ..write(obj.singleMode)
      ..writeByte(16)
      ..write(obj.backgroundIntensity)
      ..writeByte(17)
      ..write(obj.outputFormat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
