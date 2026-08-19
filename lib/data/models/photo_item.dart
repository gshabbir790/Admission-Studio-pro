import 'package:hive/hive.dart';

import 'face_info.dart';
import 'processing_status.dart';

part 'photo_item.g.dart';

/// One student photo in the batch. Mirrors the HTML app's `photos[]` entries
/// (`{id, dataUrl, name, face}`) plus the fields needed for file-backed
/// storage, editing, and processing-cache invalidation on Android.
@HiveType(typeId: 1)
class PhotoItem extends HiveObject {
  PhotoItem({
    required this.id,
    required this.originalPath,
    this.thumbnailPath,
    this.processedPath,
    this.printPath,
    this.name = '',
    this.nameEnabled = true,
    this.face,
    this.brightness = 1.0,
    this.contrast = 1.0,
    this.sharpen = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.processingStatus = ProcessingStatus.pending,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Stable unique id (uuid string) — replaces the HTML app's incrementing
  /// `nextId` int so ids survive session merges safely.
  @HiveField(0)
  final String id;

  /// Path to the original full-resolution captured/imported image on disk.
  @HiveField(1)
  String originalPath;

  /// Path to a small cached thumbnail used for fast grid rendering.
  @HiveField(2)
  String? thumbnailPath;

  /// Path to the last fully processed (resized/bg/caption/compressed) image.
  /// Null/stale whenever [processingStatus] != processed.
  @HiveField(3)
  String? processedPath;

  @HiveField(4)
  String name;

  /// false => "Without Name" mode (HTML: `namingNoRadio`), no caption printed.
  @HiveField(5)
  bool nameEnabled;

  @HiveField(6)
  FaceInfo? face;

  @HiveField(7)
  double brightness;

  @HiveField(8)
  double contrast;

  @HiveField(9)
  double sharpen;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime updatedAt;

  @HiveField(12)
  ProcessingStatus processingStatus;

  /// Path to the 0.95-quality "clean" (pre-caption) version used by the
  /// print sheet (v2 fix: was only ever kept in an in-memory map before,
  /// which meant navigating back and re-entering the app forced a full
  /// reprocess even for photos already exported).
  @HiveField(13)
  String? printPath;

  /// Call whenever original image, name, or edit params change — mirrors the
  /// HTML app deleting `resizedMap[p.id]` so the next export re-processes.
  void invalidateProcessedCache() {
    processedPath = null;
    printPath = null;
    processingStatus = ProcessingStatus.pending;
    updatedAt = DateTime.now();
  }

  /// Marks this photo as processed with its output paths (v2 fix — see
  /// [printPath] doc). Called by `ExportController` after a successful
  /// `ImageProcessingService.processPhoto()` so results survive app
  /// restarts instead of living only in an in-memory map.
  void markProcessed({required String processedPath, required String printPath}) {
    this.processedPath = processedPath;
    this.printPath = printPath;
    processingStatus = ProcessingStatus.processed;
    updatedAt = DateTime.now();
  }

  PhotoItem copyWith({
    String? originalPath,
    String? thumbnailPath,
    String? processedPath,
    String? printPath,
    String? name,
    bool? nameEnabled,
    FaceInfo? face,
    double? brightness,
    double? contrast,
    double? sharpen,
    ProcessingStatus? processingStatus,
  }) {
    return PhotoItem(
      id: id,
      originalPath: originalPath ?? this.originalPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      processedPath: processedPath ?? this.processedPath,
      printPath: printPath ?? this.printPath,
      name: name ?? this.name,
      nameEnabled: nameEnabled ?? this.nameEnabled,
      face: face ?? this.face,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      sharpen: sharpen ?? this.sharpen,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      processingStatus: processingStatus ?? this.processingStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalPath': originalPath,
        'thumbnailPath': thumbnailPath,
        'processedPath': processedPath,
        'printPath': printPath,
        'name': name,
        'nameEnabled': nameEnabled,
        'face': face?.toJson(),
        'brightness': brightness,
        'contrast': contrast,
        'sharpen': sharpen,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'processingStatus': processingStatus.index,
      };

  factory PhotoItem.fromJson(Map<String, dynamic> json) => PhotoItem(
        id: json['id'] as String,
        originalPath: json['originalPath'] as String,
        thumbnailPath: json['thumbnailPath'] as String?,
        processedPath: json['processedPath'] as String?,
        printPath: json['printPath'] as String?,
        name: json['name'] as String? ?? '',
        nameEnabled: json['nameEnabled'] as bool? ?? true,
        face: json['face'] != null
            ? FaceInfo.fromJson(json['face'] as Map<String, dynamic>)
            : null,
        brightness: (json['brightness'] as num?)?.toDouble() ?? 1.0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
        sharpen: (json['sharpen'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        processingStatus:
            ProcessingStatus.values[json['processingStatus'] as int? ?? 0],
      );
}
