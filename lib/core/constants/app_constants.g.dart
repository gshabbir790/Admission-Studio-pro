// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_constants.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PhotoSizePresetAdapter extends TypeAdapter<PhotoSizePreset> {
  @override
  final int typeId = 4;

  @override
  PhotoSizePreset read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PhotoSizePreset.passport;
      case 1:
        return PhotoSizePreset.stamp;
      case 2:
        return PhotoSizePreset.square;
      case 3:
        return PhotoSizePreset.board;
      case 4:
        return PhotoSizePreset.custom;
      default:
        return PhotoSizePreset.passport;
    }
  }

  @override
  void write(BinaryWriter writer, PhotoSizePreset obj) {
    switch (obj) {
      case PhotoSizePreset.passport:
        writer.writeByte(0);
        break;
      case PhotoSizePreset.stamp:
        writer.writeByte(1);
        break;
      case PhotoSizePreset.square:
        writer.writeByte(2);
        break;
      case PhotoSizePreset.board:
        writer.writeByte(3);
        break;
      case PhotoSizePreset.custom:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoSizePresetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BackgroundModeAdapter extends TypeAdapter<BackgroundMode> {
  @override
  final int typeId = 5;

  @override
  BackgroundMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BackgroundMode.original;
      case 1:
        return BackgroundMode.white;
      case 2:
        return BackgroundMode.royalBlue;
      default:
        return BackgroundMode.original;
    }
  }

  @override
  void write(BinaryWriter writer, BackgroundMode obj) {
    switch (obj) {
      case BackgroundMode.original:
        writer.writeByte(0);
        break;
      case BackgroundMode.white:
        writer.writeByte(1);
        break;
      case BackgroundMode.royalBlue:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackgroundModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FileSizeUnitAdapter extends TypeAdapter<FileSizeUnit> {
  @override
  final int typeId = 6;

  @override
  FileSizeUnit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FileSizeUnit.kb;
      case 1:
        return FileSizeUnit.mb;
      default:
        return FileSizeUnit.kb;
    }
  }

  @override
  void write(BinaryWriter writer, FileSizeUnit obj) {
    switch (obj) {
      case FileSizeUnit.kb:
        writer.writeByte(0);
        break;
      case FileSizeUnit.mb:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileSizeUnitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrintPageSizeAdapter extends TypeAdapter<PrintPageSize> {
  @override
  final int typeId = 7;

  @override
  PrintPageSize read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PrintPageSize.photo4x6;
      case 1:
        return PrintPageSize.a4;
      default:
        return PrintPageSize.photo4x6;
    }
  }

  @override
  void write(BinaryWriter writer, PrintPageSize obj) {
    switch (obj) {
      case PrintPageSize.photo4x6:
        writer.writeByte(0);
        break;
      case PrintPageSize.a4:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintPageSizeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
