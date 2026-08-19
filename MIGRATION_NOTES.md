# Admission Studio Pro — v2 Patch: Migration Notes

اردو خلاصہ نیچے انگریزی تفصیل کے بعد ہے۔

## How to apply this patch

1. Copy every file in this zip into your project at the **same relative
   path**, overwriting what's there. All paths already match your project
   structure (`lib/...`, `android/...`, `pubspec.yaml`, `assets/icon/...`).
2. **Delete these files** (removed, no longer used — see item 3 below):
   - `lib/services/face_detection/face_detection_service.dart`
   - `lib/services/face_detection/face_position_evaluator.dart`
   - `lib/core/localization/face_hint_strings.dart`
   - `lib/presentation/widgets/countdown_overlay.dart`
   - `test/face_position_evaluator_test.dart`
   - the whole `assets/models/face_detector/` folder (if you added any files there)
3. Run, in order:
   ```bash
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   flutter clean
   flutter run
   ```
   The `build_runner` step is **required** — several models (`PhotoItem`,
   `PhotoSession`, `app_constants.dart`'s enums) gained new fields, so the
   generated `*.g.dart` files must be rebuilt. `--delete-conflicting-outputs`
   handles overwriting the stale ones automatically, no manual deletion needed.
4. New launcher icon and adaptive-icon XML are already dropped into
   `android/app/src/main/res/mipmap-*` — nothing else to do for that.

---

## Every complaint, mapped to its fix

**1. ZIP/PDF export buttons did nothing when pressed**
Root cause: `ZipExportService`, `PrintSheetService`, and `PdfExportService`
were doing all their heavy work (JPEG encoding, big-canvas compositing, PDF
page assembly) synchronously on the UI thread. For a full batch this was
slow enough to trip Android's ANR watchdog — which is exactly what your
first screenshot shows ("Admission Studio Pro isn't responding"). It wasn't
that the buttons didn't work; the app was frozen mid-export.
**Fix:** all three services now run their heavy work inside a `compute()`
background isolate (`_buildZipIsolate`, `_buildPagesIsolate`,
`_buildPdfIsolate`). The UI thread stays responsive throughout.

**2. Had to re-process everything again after pressing back**
Root cause: processed results (`ProcessedPhotoResult`) were kept in an
in-memory map on `ExportController` only — nothing was ever written back to
the photo itself, so if that provider got recreated (app restart, or was
tied to your back-button-closes-app issue in #11) the results were gone.
**Fix:** `PhotoItem` now has a `printPath` field alongside the existing
`processedPath`, and a `markProcessed()` method. `ExportController.processAll()`
checks each photo first — if it's already `processed` and both output files
still exist on disk, it's skipped entirely. Editing, renaming, deleting, or
retaking a photo still correctly invalidates its cache (unchanged behavior),
so only what actually needs reprocessing gets reprocessed.

**3. Auto-capture / face detector never worked — remove it, it's bloating the app**
Removed entirely: `not included in the stable build` dependency, the whole
`services/face_detection/` folder, the countdown overlay, the auto-capture
checkbox, and the live position-hint UI. Camera capture is now manual-shutter
only. The oval guide stays as a plain static framing aid (no live feedback).
Since `ResizeService` already falls back to a center-crop whenever face info
is missing, nothing else needed to change — every photo just uses that path
now. This should measurably shrink the APK (ML Kit Face Detection's native
libraries were a meaningful chunk of that 103MB); Selfie Segmentation
(the White/Blue background feature) is untouched and still works.
*You mentioned deleting your own uploaded face-detector model asset files —
that's correct and expected, the app no longer references them at all.*

**4. Splash screen (5 seconds, with developer name)**
New file: `lib/presentation/screens/splash_screen.dart`, wired into
`lib/main.dart`. Visual language ported from your `index.html`'s splash
(exact same colors: `#123B4A` sea-dark → `#198754` green → `#D4AF37` gold,
same icon pop-in / fade-up / divider-grow animation choreography), with a
camera+portrait-frame icon instead of the graduation cap, "Admission Studio
Pro" as the title, and "Developed & Maintained by Ghulam Shabbir" as the
footer. Shows for exactly 5 seconds, then fades into the app.

**5. Professional app icon, legible at small sizes**
Generated a real icon (not a placeholder) — gold-bordered white portrait-
frame oval on a sea-dark→green diagonal gradient, with a small camera-lens
badge, matching the splash's palette. Dropped in at every required Android
density (`mipmap-mdpi` through `mipmap-xxxhdpi`) plus a proper adaptive icon
(`mipmap-anydpi-v26/ic_launcher.xml` + foreground layer) for Android 8+, and
a 512px Play Store listing icon in `assets/icon/`. Checked it at actual
48×48px render size — the portrait-frame + camera badge silhouette is still
clearly readable.

**6. What's the standard photo-print page size?**
Confirmed via research: **4×6 inch (10×15cm)** is the standard photo-lab
paper size for printing passport/ID photos — not A4. This is now the
default (`PrintPageSize.photo4x6`), with A4 kept as an alternative for
batches printed on an office/home printer instead of a photo lab. The grid
(how many photos fit per page) is now computed dynamically from the chosen
page size and your target photo dimensions, instead of a fixed 4×5 grid
that only made sense for A4. PDF page size now exactly matches whichever
page size was used to build the sheet, so "Actual Size / 100%" printing
is accurate. Choose the page size in the Export Settings sheet (⚙ icon).

**7. Save to Folder / Save to Gallery — exports were invisible in Gallery/Files**
Root cause: exports only ever lived in the app's private sandbox directory.
**Fix:** new `SaveService` using two packages:
- `file_picker` → **Save to Folder** (ZIP, PDF): opens Android's document
  picker, writes the file wherever you choose. Works for any file type.
- `gal` → **Save to Gallery** (print-sheet JPGs only — ZIP/PDF aren't valid
  gallery media): saves into Photos under an "Admission Studio Pro" album.
Both buttons are now on the Export sheet and the Print Sheet Preview screen.

**8. Interface doesn't look "international standard"; no developer name on screen**
Added an **ⓘ About** button in the grid screen's app bar (`showAboutDialog`)
showing app name, version, a one-line description, and "Developed &
Maintained by Ghulam Shabbir" — plus the splash screen already carries the
same credit every time the app opens.

**9. "Choose from Gallery" gave a permission error**
Root cause found: the app was manually gating on
`PermissionService.ensurePhotosPermission()` *before* calling `image_picker`.
On Android 13+, `image_picker` uses the system Photo Picker, which needs
**no runtime permission at all** — so that manual check was reporting
"denied" forever (the OS never actually prompts in that flow) and blocking
the picker from ever opening, regardless of what the user tapped.
**Fix:** removed the manual gate; `image_picker` is called directly and
handles whatever permission it actually needs internally, on any Android
version.

**10. Single photo vs. batch (20+) — needs separate options**
The "Add Photos" button now asks **Single Photo** or **Batch (20+)** the
first time you use it in an empty session. Single mode locks the grid to 1
slot (no 20 empty boxes, no "+20 More" button); batch mode is unchanged.

**11. Back button on the home screen closed the app immediately**
New reusable widget `DoubleBackToExitScope`, wired around the root screen in
`main.dart`. Standard Android pattern: first back press shows "Press back
again to exit" and is absorbed; a second press within 2 seconds actually
exits.

**12. (Process note, not a bug)**
This delivery is exactly what you asked for: only the changed/added files,
with a clear list of what to delete and where everything goes — not the
whole project again.

---

## Bonus fix found while auditing

While rewriting `SessionNotifier`, I found `_cloneWithTouch()` was
reconstructing the session on every autosave by manually listing every
field — and it had already drifted out of sync with the model (missing
`autoCaptureEnabled` at minimum before this patch). I added the two new
fields (`printPageSize`, `singleMode`) to that list, but flag this pattern
as fragile: any future field added to `PhotoSession` needs to be added
there too, or it'll silently reset on every autosave. Worth refactoring to
a generated `copyWith` (e.g. via `freezed`, already in your `pubspec.yaml`
as an unused dependency) at some point.

---

## Files in this patch

```
pubspec.yaml                                            (2 deps added, 1 removed)
lib/main.dart                                            (splash + double-back-exit)
lib/core/constants/app_constants.dart                    (PrintPageSize enum)
lib/data/models/photo_item.dart                          (printPath field)
lib/data/models/photo_session.dart                       (printPageSize, singleMode fields)
lib/presentation/controllers/capture_flow_controller.dart (face detection removed)
lib/presentation/controllers/export_controller.dart      (persisted-path skip logic)
lib/presentation/providers/service_providers.dart        (face detection provider removed)
lib/presentation/providers/session_provider.dart         (new setters, clone bug fix)
lib/presentation/screens/camera_capture_screen.dart      (auto-capture UI removed)
lib/presentation/screens/capture_chooser_screen.dart     (permission-gate bug fix)
lib/presentation/screens/export_result_sheet.dart        (save-to-folder buttons)
lib/presentation/screens/export_settings_sheet.dart      (page size picker)
lib/presentation/screens/photo_grid_screen.dart          (mode dialog, About, single-mode UI)
lib/presentation/screens/print_sheet_preview_screen.dart (save-to-gallery button)
lib/presentation/screens/splash_screen.dart               (NEW)
lib/presentation/widgets/oval_guide_overlay.dart          (now static)
lib/presentation/widgets/double_back_to_exit_scope.dart   (NEW)
lib/services/camera/camera_service.dart                  (streaming removed)
lib/services/export/save_service.dart                     (NEW)
lib/services/export/zip_export_service.dart               (compute() isolate)
lib/services/pdf/pdf_export_service.dart                  (compute() isolate, dynamic page size)
lib/services/pdf/print_sheet_service.dart                 (compute() isolate, dynamic page size)
lib/services/storage/session_repository.dart              (new Hive adapter registered)
android/app/src/main/AndroidManifest.xml                  (mlkit meta-data, storage permission)
android/app/src/main/res/values/colors.xml                (icon background color)
android/app/src/main/res/mipmap-anydpi-v26/*.xml          (NEW — adaptive icon)
android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/*.png (NEW — launcher icons)
assets/icon/*.png                                          (NEW — master + Play Store icon)
```

---

## اردو خلاصہ

یہ پیچ آپ کی بھیجی گئی 12 شکایات میں سے ہر ایک کو حل کرتا ہے:

1. **ZIP/PDF بٹن کام نہیں کرتے تھے** — اصل وجہ یہ تھی کہ یہ کام UI تھریڈ پر
   ہی چل رہا تھا، جس سے ایپ "isn't responding" ہو جاتی تھی۔ اب یہ کام
   بیک گراؤنڈ آئسولیٹ میں چلتا ہے۔
2. **بیک بٹن سے دوبارہ پروسیس کرنا پڑتا تھا** — اب پروسیس شدہ نتائج فائل میں
   محفوظ ہوتے ہیں، دوبارہ پروسیس کرنے کی ضرورت نہیں۔
3. **فیس ڈیٹیکٹر مکمل ختم** — کوڈ اور پیکج دونوں حذف، APK سائز کم ہوگا۔
4. **5 سیکنڈ کی سپلیش سکرین** — ڈیویلپر کا نام سمیت، آپ کی HTML جیسے رنگوں میں۔
5. **پروفیشنل آئیکون** — چھوٹی سکرین پر بھی واضح۔
6. **پرنٹ کا معیاری سائز 4×6 انچ** — اے فور نہیں، فوٹو لیب کا اصل سٹینڈرڈ۔
7. **گیلری/فولڈر میں سیو** — اب فائلیں واقعی نظر آئیں گی۔
8. **گیلری پرمیشن ایرر** — اصل بگ مل گیا اور ٹھیک کر دیا۔
9. **سنگل فوٹو بمقابلہ بیچ موڈ** — الگ آپشن اب موجود ہے۔
10. **بیک بٹن سے ایپ فوراً بند** — اب "دوبارہ پریس کریں" سسٹم لاگو ہے۔

`build_runner` دوبارہ چلانا ضروری ہے کیونکہ ماڈلز میں نئے فیلڈز شامل کیے گئے ہیں۔
