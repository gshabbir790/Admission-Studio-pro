import 'package:hive/hive.dart';
part 'app_constants.g.dart';
class AppConstants {
  AppConstants._();

  // ---- Grid / capacity ----
  static const int defaultCapacity = 20;
  static const int capacityIncrement = 20;
  // v2: hard ceiling for "Multiple Photos" mode (spec request — the batch
  // picker must never grow past 60 photos in one session).
  static const int maxBatchCapacity = 60;
  static const int minBatchCapacity = 2;

  // ---- Auto-capture ----
  static const int readyStreakNeeded = 12; // consecutive good frames before countdown
  static const int countdownSeconds = 3;
  static const Duration countdownTick = Duration(milliseconds: 800);

  // ---- Face position/size tolerances (oval guide) ----
  static const double faceCenterXTarget = 0.5;
  static const double faceCenterYTarget = 0.42;
  static const double faceCenterTolerance = 0.13; // ±13%
  static const double faceHeightRatioMin = 0.20;
  static const double faceHeightRatioMax = 0.58;
  static const double desiredFaceHeightRatioInCrop = 0.5;

  // ---- Editor ranges ----
  static const double brightnessMin = 0.5;
  static const double brightnessMax = 1.5;
  static const double brightnessDefault = 1.0;
  static const double contrastMin = 0.5;
  static const double contrastMax = 1.5;
  static const double contrastDefault = 1.0;
  static const double sharpenMin = 0.0;
  static const double sharpenMax = 1.0;
  static const double sharpenDefault = 0.0;

  // ---- JPEG quality ----
  static const int jpegQualityMin = 70;
  static const int jpegQualityMax = 100;
  static const int jpegQualityDefault = 93;

  // ---- File-size-limited compression (binary search) ----
  static const double compressQualityLow = 0.25;
  static const double compressQualityHigh = 0.97;
  // v2: reduced from 8 → 6 rounds and given a smarter first guess (see
  // CompressionService) — fewer JPEG re-encodes per photo for the same
  // final accuracy, which matters a lot once a batch is 20-60 photos.
  static const int compressIterations = 6;

  // ---- Segmentation batch health (background-removal stability) ----
  // v2 fix: on some devices, calling Selfie Segmentation back-to-back for a
  // long batch (20+ photos) gradually starves native memory and the whole
  // app could stop responding partway through "Process". Two mitigations:
  // 1) recycle (close + recreate) the native segmenter every N photos to
  //    release accumulated native buffers, and 2) after several consecutive
  //    segmentation failures in a row, stop attempting segmentation for the
  //    rest of the batch (falling back to the original background) instead
  //    of repeatedly hitting whatever is failing.
  static const int segmenterRecycleEvery = 12;
  static const int segmenterMaxConsecutiveFailures = 3;

  // ---- Custom size bounds ----
  static const int customSizeMin = 50;
  static const int customSizeMax = 4000;

  // ---- Print sheet (300 DPI). v2: page size is now selectable —
  // industry-standard 4x6in (10x15cm) photo-lab paper by default (the
  // globally standard size for printing passport/ID photos — a 4x6 sheet
  // fits several 2x2in-equivalent photos per print, same as what walk-in
  // photo labs use), with A4 kept as an alternative for larger batches
  // printed on an office/home printer. Grid (cols/rows) is computed
  // dynamically from the chosen page size and the photo's target pixel
  // dimensions rather than a fixed 4x5, so it fits the maximum clean copies
  // for whatever size/page combination is selected.
  static const int printDpi = 300;
  static const double a4WidthInches = 8.27;
  static const double a4HeightInches = 11.69;
  static const double photo4x6WidthInches = 4.0;
  static const double photo4x6HeightInches = 6.0;
  static const double printMarginInches = 0.25;
  static const double printGutterInches = 0.12;

  // ---- Storage ----
  static const String sessionBoxName = 'admission_photo_session';
  static const String sessionKey = 'current';
  static const Duration autoSaveDebounce = Duration(milliseconds: 900);

  // ---- App identity ----
  static const String appName = 'Admission Studio Pro';
  static const String androidPackageName = 'com.gshabbir.photostudio';
}

/// Built-in size presets (width, height in px @300DPI) plus their physical
/// size labels for display.
///
/// v2: added several common admission/ID document sizes on top of the
/// original four (spec request: "Photo size mein mazeed default sizes add
/// karein") — all still expressed as exact 300 DPI pixel dimensions so they
/// drop straight into the existing resize/print pipeline unchanged.
@HiveType(typeId: 4)
enum PhotoSizePreset {
  @HiveField(0)
  passport(width: 413, height: 531, label: 'Passport', physical: '35 × 45 mm'),
  @HiveField(1)
  stamp(width: 295, height: 413, label: 'Stamp', physical: '25 × 35 mm'),
  @HiveField(2)
  square(width: 300, height: 300, label: 'Square', physical: '1 × 1 in'),
  @HiveField(3)
  board(width: 200, height: 260, label: 'Board', physical: null),
  @HiveField(4)
  custom(width: 413, height: 531, label: 'Custom', physical: null),
  @HiveField(5)
  usPassport(width: 600, height: 600, label: 'US Passport/Visa', physical: '2 × 2 in'),
  @HiveField(6)
  cnic(width: 413, height: 531, label: 'CNIC/NADRA', physical: '35 × 45 mm'),
  @HiveField(7)
  visa(width: 443, height: 591, label: 'Visa (35×50mm)', physical: '35 × 50 mm'),
  @HiveField(8)
  wallet(width: 236, height: 354, label: 'Wallet', physical: '2 × 3 in'),
  @HiveField(9)
  postcard(width: 1200, height: 1800, label: 'Postcard', physical: '4 × 6 in'),
  @HiveField(10)
  a4Portrait(width: 2481, height: 3507, label: 'A4 Full Page', physical: '210 × 297 mm');

  const PhotoSizePreset({
    required this.width,
    required this.height,
    required this.label,
    required this.physical,
  });

  final int width;
  final int height;
  final String label;
  final String? physical;
}

/// v2 addition: actual output file format for the ZIP/download/Gallery copy
/// of each photo (spec request — previously the app only ever wrote JPEG
/// regardless of what a user might expect from a ".png" filename). The
/// print-sheet/PDF copy always stays JPEG internally since PDF/print
/// compositing doesn't benefit from PNG's lossless-but-larger output.
@HiveType(typeId: 8)
enum ImageOutputFormat {
  @HiveField(0)
  jpeg(label: 'JPEG', extension: 'jpg'),
  @HiveField(1)
  png(label: 'PNG', extension: 'png');

  const ImageOutputFormat({required this.label, required this.extension});

  final String label;
  final String extension;
}

@HiveType(typeId: 5)
enum BackgroundMode {
  @HiveField(0)
  original,
  @HiveField(1)
  white,
  @HiveField(2)
  royalBlue,
}

@HiveType(typeId: 6)
enum FileSizeUnit {
  @HiveField(0)
  kb,
  @HiveField(1)
  mb,
}

/// v2: print/PDF page size choice. [photo4x6] is the global standard for
/// photo-lab printing (confirmed against current photo-lab/print-shop
/// guidance: a 4x6in/10x15cm sheet is "the industry standard" for tiling
/// multiple wallet/passport-size photos for cutting). [a4] suits larger
/// batches printed on an office/home printer instead of at a photo lab.
@HiveType(typeId: 7)
enum PrintPageSize {
  @HiveField(0)
  photo4x6(
    widthInches: AppConstants.photo4x6WidthInches,
    heightInches: AppConstants.photo4x6HeightInches,
    label: '4×6 in (Photo Lab Standard)',
    shortLabel: '4×6 in',
  ),
  @HiveField(1)
  a4(
    widthInches: AppConstants.a4WidthInches,
    heightInches: AppConstants.a4HeightInches,
    label: 'A4',
    shortLabel: 'A4',
  );

  const PrintPageSize({
    required this.widthInches,
    required this.heightInches,
    required this.label,
    required this.shortLabel,
  });

  final double widthInches;
  final double heightInches;
  final String label;

  /// v2 addition: a compact form of [label] for places with limited
  /// horizontal room (e.g. the print-preview app bar) — see
  /// PrintSheetPreviewScreen doc for the overflow bug this fixes.
  final String shortLabel;
}
