# Admission Studio Pro 1.1.0 — Stability & UX Upgrade

## Primary issue fixed

The Android screenshot shows a real ANR ("Application Not Responding"). The original export pipeline performed expensive JPEG decode, resize, pixel adjustment, JPEG encoding, binary-search compression, and large archive/page work in ways that could monopolize the UI isolate.

This release moves the CPU-heavy image stages to Dart isolates and streams ZIP entries from disk. Flutter's UI isolate is kept responsive during batch processing.

## Changes

- Added `processing_worker.dart` for isolate-based decode/resize/adjust/JPEG work.
- Moved final JPEG encoding and size-limit compression to an isolate.
- ZIP creation now uses `ZipFileEncoder` and streams files from disk instead of building one giant in-memory `Archive`.
- Print/PDF generation remains isolate-based.
- Caption rasterization now creates only the bottom caption band instead of a full-image RGBA overlay.
- Added lifecycle autosave on pause/detach.
- Fixed "Clear/New Session" writing an empty session back into Hive after clearing.
- Fixed stale processed files when a photo is retaken, renamed, or edited.
- Export settings now invalidate processed output so old files cannot be exported after a setting change.
- Export PDF/ZIP actions rebuild from current data instead of trusting stale cached paths.
- Added failure handling and partial-failure reporting to the export result sheet.
- Added Save Print Sheet to Gallery and Share PDF actions.
- Improved home screen with a proper app bar, session overview/progress, responsive grid, empty state, and Material 3 styling.
- Reduced splash duration from 5 seconds to 1.4 seconds.
- Added image cache sizing to grid cards to reduce memory pressure.
- Removed the missing `assets/models/selfie_segmenter/` pubspec reference that could break builds.
- Updated `file_picker` and `gal` to current stable-compatible versions for the project's Dart 3.4 floor.
- Version bumped to 1.1.0+2.

## Important scope note

The stable capture flow intentionally uses manual shutter capture with a static portrait guide. Live ML face detection/auto-capture is not claimed as implemented in this build. This is preferable to advertising a feature that was removed for device reliability.

## Verification limitation

The provided environment does not contain the Flutter/Dart SDK, so `flutter pub get`, `dart analyze`, `flutter test`, and an APK build could not be executed here. The project was inspected statically and the uploaded project structure/assets were checked. Final device QA should run:

```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze
flutter test
flutter build apk --release
```

For ANR verification, test a 20-photo batch and ZIP/PDF export on a physical low/mid-range Android device, not only an emulator.
