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
      case 5:
        return PhotoSizePreset.usPassport;
      case 6:
        return PhotoSizePreset.cnic;
      case 7:
        return PhotoSizePreset.visa;
      case 8:
        return PhotoSizePreset.wallet;
      case 9:
        return PhotoSizePreset.postcard;
      case 10:
        return PhotoSizePreset.a4Portrait;
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
      case PhotoSizePreset.usPassport:
        writer.writeByte(5);
        break;
      case PhotoSizePreset.cnic:
        writer.writeByte(6);
        break;
      case PhotoSizePreset.visa:
        writer.writeByte(7);
        break;
      case PhotoSizePreset.wallet:
        writer.writeByte(8);
        break;
      case PhotoSizePreset.postcard:
        writer.writeByte(9);
        break;
      case PhotoSizePreset.a4Portrait:
        writer.writeByte(10);
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

class ImageOutputFormatAdapter extends TypeAdapter<ImageOutputFormat> {
  @override
  final int typeId = 8;

  @override
  ImageOutputFormat read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ImageOutputFormat.jpeg;
      case 1:
        return ImageOutputFormat.png;
      default:
        return ImageOutputFormat.jpeg;
    }
  }

  @override
  void write(BinaryWriter writer, ImageOutputFormat obj) {
    switch (obj) {
      case ImageOutputFormat.jpeg:
        writer.writeByte(0);
        break;
      case ImageOutputFormat.png:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageOutputFormatAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
