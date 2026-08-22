import 'package:hive/hive.dart';

import '../../core/constants/app_constants.dart';
import 'photo_item.dart';

part 'photo_session.g.dart';

/// The whole active batch. Mirrors the HTML app's top-level state:
/// `photos`, `capacity`, plus the settings panel values (size preset,
/// background mode, quality, size limit) so a resumed session restores
/// the exact same export configuration, not just the photos.
@HiveType(typeId: 2)
class PhotoSession extends HiveObject {
  PhotoSession({
    required this.id,
    List<PhotoItem>? photos,
    this.capacity = AppConstants.defaultCapacity,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.targetWidth = 413,
    this.targetHeight = 531,
    this.sizePreset = PhotoSizePreset.passport,
    this.backgroundMode = BackgroundMode.original,
    this.backgroundIntensity = 100,
    this.jpegQuality = AppConstants.jpegQualityDefault,
    this.sizeLimitEnabled = false,
    this.sizeLimitValue = 0,
    this.sizeLimitUnit = FileSizeUnit.kb,
    this.autoCaptureEnabled = true,
    this.printPageSize = PrintPageSize.photo4x6,
    this.singleMode = false,
    this.outputFormat = ImageOutputFormat.jpeg,
  })  : photos = photos ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  @HiveField(0)
  final String id;

  @HiveField(1)
  List<PhotoItem> photos;

  @HiveField(2)
  int capacity;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  int targetWidth;

  @HiveField(6)
  int targetHeight;

  @HiveField(7)
  PhotoSizePreset sizePreset;

  @HiveField(8)
  BackgroundMode backgroundMode;

  @HiveField(9)
  int jpegQuality;

  /// Strength of background replacement: 0 keeps the original background,
  /// 100 applies the full segmentation result. Persisted with the session so
  /// the preview and export always use the same setting.
  @HiveField(16)
  int backgroundIntensity;

  @HiveField(10)
  bool sizeLimitEnabled;

  @HiveField(11)
  double sizeLimitValue;

  @HiveField(12)
  FileSizeUnit sizeLimitUnit;

  @HiveField(13)
  bool autoCaptureEnabled;

  /// v2: which physical page size to render print sheets/PDF at — see
  /// `PrintPageSize` doc for why 4x6 (photo-lab standard) is now the
  /// default instead of A4.
  @HiveField(14)
  PrintPageSize printPageSize;

  /// v2: "single photo" mode caps capacity at 1 and skips the 20-slot grid
  /// UI for someone who just wants to shoot and export one photo (spec
  /// request: a separate flow for 1 photo vs. a full batch of 20+).
  @HiveField(15)
  bool singleMode;

  /// v2 addition: actual file format (JPEG/PNG) written for the ZIP/
  /// download/Gallery copy of each processed photo. See [ImageOutputFormat].
  @HiveField(17)
  ImageOutputFormat outputFormat;

  /// Grow capacity in fixed 20-photo pages, same as HTML's `capacity += 20`
  /// — capped at [AppConstants.maxBatchCapacity] (v2: "Multiple Photos"
  /// mode must never silently grow past the 60-photo ceiling the user
  /// picked/was offered).
  void growCapacityIfNeeded() {
    if (singleMode) return;
    while (photos.length >= capacity && capacity < AppConstants.maxBatchCapacity) {
      capacity += AppConstants.capacityIncrement;
    }
    if (capacity > AppConstants.maxBatchCapacity) {
      capacity = AppConstants.maxBatchCapacity;
    }
  }

  void touch() => updatedAt = DateTime.now();
}
