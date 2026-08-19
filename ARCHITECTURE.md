# Admission Studio Pro — Migration Blueprint
Source of truth: `admission-photo-camera.html` (1178 lines, vanilla JS, MediaPipe via CDN, JSZip, jsPDF)
Package: `com.gshabbir.photostudio` — App name: **Admission Studio Pro**

## A. Complete Feature Inventory (from HTML)

| # | Feature | HTML mechanism |
|---|---|---|
| 1 | Camera/Gallery chooser | radio toggle, `captureChooser` |
| 2 | Live camera, front/rear switch | `getUserMedia`, `facingMode` toggle |
| 3 | Oval guide, darkened mask, green when ready | CSS `.oval-guide` + `box-shadow` mask |
| 4 | Real-time face detection | MediaPipe `FaceDetector` (BlazeFace short-range, CDN model) |
| 5 | Position/size validation | `cx≈0.5±0.13`, `cy≈0.42±0.13`, `faceH∈(0.20,0.58)` |
| 6 | Live hint text (7 states) | `handleDetectionResult()` |
| 7 | Auto-capture streak + 3-2-1 countdown | `READY_STREAK_NEEDED=12`, `setInterval` 800ms |
| 8 | Manual shutter always available | `shutterBtn` click → `doCapture()` |
| 9 | Capture confirm (accept/retake) | `goConfirm()`, frozen frame overlay |
| 10 | Camera permission fallback (file input) | `cameraFallback` + `<input type=file capture>` |
| 11 | Gallery batch import, sequential queue | `galleryQueue`, `processNextGalleryItem()` |
| 12 | Naming panel (with/without name), retake prefill | `goNaming()`, `namingWithRadio/namingNoRadio` |
| 13 | Photo grid, 20-slot pages, "+20 more" | `renderGrid()`, `capacity+=20` |
| 14 | Per-card edit/retake/delete, inline name edit | grid cell button handlers |
| 15 | Delete/name-change invalidates processed cache | `delete resizedMap[p.id]` |
| 16 | Image editor: brightness 50–150, contrast 50–150, sharpen 0–100 | `editBright/editContrast/editSharp` canvas filters |
| 17 | Face-aware crop (never distorts) | `computeCropRect()` — crop sized from `faceH`, centered on `(cx,cy)`, offset by `0.5-0.42` |
| 18 | Progressive halving downscale + final high-quality draw | `resizeToCoverFace()` |
| 19 | Size presets: Passport 413×531, Stamp 295×413, Square 300×300, Board 200×260, Custom (50–4000) | `sizePreset` |
| 20 | Background removal: Original/White/Royal-Blue with soft-edge alpha blend | `removeBackground()` — MediaPipe `ImageSegmenter`, confidence mask, 0.5/0.75 feather band |
| 21 | Name caption: bottom gradient, centered, Urdu-safe font, shadow | `withCaption()` |
| 22 | JPEG quality slider 70–100 (default 93) | `qualityRange` |
| 23 | File-size limit (KB/MB) via binary-search quality | `compressToSize()` — 8-iteration bisection, lo=0.25/hi=0.97 |
| 24 | Filename sanitize + collision-safe numbering | `sanitizeFilename()`, `usedNames` map |
| 25 | ZIP export of all processed photos | JSZip, `admission_photos.zip` |
| 26 | A4 print sheet: 300 DPI, 4×5 grid, name below photo, multi-page | `buildSheetCanvases()` |
| 27 | A4 preview before export | `sheetPages` modal |
| 28 | Export sheet as JPG (per page) and PDF (multi-page) | jsPDF |
| 29 | Progress modal (%, "n of total") | `openProcessModal/updateModalProgress` |
| 30 | Session auto-save (debounced 900ms) + resume-on-load | IndexedDB `admissionPhotoDB`/`session`, `scheduleAutoSave` |
| 31 | AI soft-failure: camera/manual capture still work if AI unavailable | `aiReady` flag gates auto-capture & bg removal only |
| 32 | Urdu/RTL UI throughout, Noto Nastaliq Urdu font | `dir="rtl"`, `lang="ur"` |

## B. HTML → Flutter Migration Map

| HTML Feature | Flutter Screen | Service | Package / Native API |
|---|---|---|---|
| Chooser | `CaptureChooserScreen` | — | — |
| Live camera + oval + hints | `CameraCaptureScreen` | `CameraService`, `static framing guide` | `camera`, `not included in the stable build` |
| Auto-capture countdown | `CameraCaptureScreen` (controller) | `static framing guide` | Dart `Timer` |
| Confirm accept/retake | `CaptureConfirmSheet` | — | — |
| Gallery batch | `GalleryImportFlow` | `GalleryService` | `image_picker` (multi) or `photo_manager` |
| Naming | `PhotoNamingScreen` | — | — |
| Grid | `PhotoGridScreen` | `SessionController` (Riverpod) | — |
| Editor (brightness/contrast/sharpen) | `PhotoEditorScreen` | `ImageProcessingService` | `image` pkg, isolate via `compute` |
| Face-aware resize | (no screen) | `ResizeService.computeCropRect/resizeToCoverFace` | `image` pkg canvas-equivalent ops |
| Background removal | Settings + processing pipeline | `SegmentationService` | ML Kit Selfie Segmentation (bundled model) or TFLite selfie-segmenter, MethodChannel if needed |
| Caption | (pipeline step) | `ImageProcessingService.withCaption` | `image` pkg text draw (custom glyph raster, see note) |
| Quality / size-limit compression | Settings + pipeline | `CompressionService.compressToSize` | `image` JPEG encoder, binary search identical to HTML |
| ZIP export | Result sheet | `ZipExportService` | `archive` |
| A4 sheet build/preview | `PrintSheetPreviewScreen` | `PrintSheetService` | `image` (canvas raster) |
| JPG/PDF export | `PrintSheetPreviewScreen` | `PdfExportService` | `pdf`, `printing` |
| Progress modal | `ProcessingProgressDialog` | all pipeline services report via `StreamController`/Riverpod `AsyncNotifier` | isolates/`compute()` |
| Session autosave/resume | App start `SplashScreen`/`ResumeSessionDialog` | `SessionRepository` | `Hive` (chosen over Isar — no codegen/native build step, equally offline, simpler one-shot delivery; swappable later) |
| Urdu/RTL UI | global `MaterialApp` | `l10n/` | `flutter_localizations`, `Directionality.rtl`, Noto Nastaliq Urdu font asset |

**Note on caption text rendering:** the `image` package cannot shape Arabic/Urdu script (no complex text layout). The reliable on-device approach is to render the caption using Flutter's own text layout (`TextPainter`, which does shape Urdu correctly) onto a `ui.PictureRecorder`/`Canvas`, rasterize to bytes, and composite that onto the processed image buffer — rather than trying to draw Urdu glyphs inside the `image` package's canvas. This is called out explicitly in `ImageProcessingService` in Phase 3.

## C. Recommended Architecture
Clean Architecture + MVVM, **Riverpod** for state management, feature pipeline services fully decoupled from widgets, all heavy image ops run inside `compute()`/isolates, disk-backed originals (never hold >2–3 full-res bitmaps in RAM at once).

## D. Folder Structure
```
lib/
  core/{constants,errors,extensions,utils,theme,localization}
  data/{models,repositories,local}
  domain/{entities,repositories,usecases}
  presentation/{screens,widgets,controllers,providers}
  services/{camera,face_detection,segmentation,image_processing,export,pdf,storage}
  l10n/
  main.dart
assets/models/{face_detector,selfie_segmenter}
android/app/src/main/kotlin/...
test/
```
(Created on disk in this delivery — see project tree.)

## E. Dependency List (pinned ranges, verified against pub.dev stable channel as of this delivery)
```yaml
camera: ^0.11.0+2
image_picker: ^1.1.2
not included in the stable build: ^0.13.1
image: ^4.2.0
path_provider: ^2.1.4
permission_handler: ^11.3.1
archive: ^3.6.1
pdf: ^3.11.1
printing: ^5.13.4
share_plus: ^10.1.2
hive: ^2.2.3
hive_flutter: ^1.1.0
flutter_riverpod: ^2.6.1
riverpod_annotation: ^2.6.1
freezed_annotation: ^2.4.4
json_annotation: ^4.9.0
uuid: ^4.5.1
```
Dev: `build_runner`, `hive_generator`, `freezed`, `json_serializable`, `riverpod_generator`.

**Segmentation note:** ML Kit's Selfie Segmentation ships its own bundled model via Play Services / on-device — it satisfies "offline, no runtime download" but still needs `google_mlkit_selfie_segmentation`; if that plugin proves unstable on the target Flutter version, the fallback is a bundled TFLite `selfie_segmenter.tflite` (same model family the HTML already uses) invoked through `tflite_flutter`, loaded from `assets/models/selfie_segmenter/`. Both are wired through the same `SegmentationService` interface so the choice doesn't affect the rest of the app — this gets finalized and pinned in Phase 3 when the segmentation service is built.

---
**Status:** All 7 phases delivered. A–E complete (architecture/migration map/dependencies). Phases 1–7 implemented — see README for the full file list and phase-by-phase notes.
App default/global language is **English** per project instruction (Urdu strings retained in `face_hint_strings.dart` for a future selectable-locale pass; student-name fields and printed captions still render Urdu/Arabic correctly since that's user data, not UI chrome).

## Acceptance-test walkthrough (spec §43) mapped to implementation
1–10 (permission → live camera → oval green → countdown → capture → confirm → accept → name → grid): `PermissionService` → `CameraCaptureScreen`/`OvalGuideOverlay` → `CaptureFlowController` (manual capture/confirm/naming) → confirm overlay → `PhotoNamingScreen` → `PhotoGridScreen`.
11–18 (more captures, edit brightness/contrast/sharpen, retake, rename, passport preset, white bg, process all, progress): `PhotoEditorScreen` → grid retake/rename actions → `ExportSettingsSheet` → `PhotoGridScreen._processAll` → `ProcessingProgressDialog`.
19–27 (ZIP, A4 sheet, preview, JPG/PDF export): `ExportResultSheet` → `ZipExportService` / `PrintSheetService` / `PrintSheetPreviewScreen` / `PdfExportService`.
28–32 (close/reopen/resume): `SessionRepository` autosave + `ResumeSessionDialog` in `main.dart`.
