import 'package:hive/hive.dart';
part 'app_constants.g.dart';
class AppConstants {
  AppConstants._();

  // ---- Grid / capacity ----
  static const int defaultCapacity = 20;
  static const int capacityIncrement = 20;

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
  static const int compressIterations = 8;

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

/// The four built-in size presets from the HTML app (width, height in px @300DPI)
/// plus their physical size labels for display.
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
  custom(width: 413, height: 531, label: 'Custom', physical: null);

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
  ),
  @HiveField(1)
  a4(
    widthInches: AppConstants.a4WidthInches,
    heightInches: AppConstants.a4HeightInches,
    label: 'A4',
  );

  const PrintPageSize({
    required this.widthInches,
    required this.heightInches,
    required this.label,
  });

  final double widthInches;
  final double heightInches;
  final String label;
}
