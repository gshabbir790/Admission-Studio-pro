// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processing_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProcessingStatusAdapter extends TypeAdapter<ProcessingStatus> {
  @override
  final int typeId = 3;

  @override
  ProcessingStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ProcessingStatus.pending;
      case 1:
        return ProcessingStatus.processing;
      case 2:
        return ProcessingStatus.processed;
      case 3:
        return ProcessingStatus.failed;
      default:
        return ProcessingStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, ProcessingStatus obj) {
    switch (obj) {
      case ProcessingStatus.pending:
        writer.writeByte(0);
        break;
      case ProcessingStatus.processing:
        writer.writeByte(1);
        break;
      case ProcessingStatus.processed:
        writer.writeByte(2);
        break;
      case ProcessingStatus.failed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessingStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
