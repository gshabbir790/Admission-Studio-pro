import 'package:hive/hive.dart';

part 'processing_status.g.dart';

/// Tracks whether a [PhotoItem]'s processed/export cache is still valid.
/// Mirrors the HTML app's implicit contract: any edit to name/photo/params
/// deletes `resizedMap[p.id]`, forcing reprocessing before export.
@HiveType(typeId: 3)
enum ProcessingStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  processing,

  @HiveField(2)
  processed,

  @HiveField(3)
  failed,
}
