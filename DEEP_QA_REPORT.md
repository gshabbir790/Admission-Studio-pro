# Admission Studio Pro — Deep QA & UX Remediation Report

## Findings

### Capture flow
- Single/Batch choices were already side-by-side, but the single-mode flow could accept a second gallery import after the first photo. Because capacity remained 1, the UI could display `2 of 1` / `200%`.
- The capture chooser had a Done action, but it did not prevent adding another image in completed single mode.
- Back navigation from camera/naming screens could leave the capture state active instead of returning cleanly to the workspace.
- The gallery/camera chooser is now disabled after a single photo is committed, and Done returns to the workspace.
- Capture state cleanup now clears a pending gallery queue when leaving the flow.

### Progress/grid
- Progress was calculated from `filled / capacity` and displayed without clamping, allowing 200%.
- The grid used the session capacity as its child count, so empty placeholders consumed the grid and made the screen feel less polished.
- Grid is now four columns and renders actual selected photos rather than a full set of empty capacity slots. Progress is clamped to 0–100%.

### Camera
- The preview mirror flag was already hard-coded off. It is now retained as a deliberate invariant: front and rear previews are not mirrored, so the saved admission photo is not left/right reversed.
- System back now routes through the capture state machine instead of simply abandoning the screen.

### Editing
- Crop support was already present and is retained.

### Export
- Share actions were removed from the UI and the unused share implementation/dependency was removed.
- Gallery export now saves the individual processed student photos, not tiled print-sheet pages.
- Print-sheet preview no longer exposes a Share JPGs action.
- Save PDF/ZIP to a user-selected folder remains available.

### Export settings
- Photo size presets are now a single dropdown, including Custom.
- Custom width/height inputs remain available when Custom is selected.
- Background mode is now a dropdown.
- Added persisted background intensity (0–100%).
- Background replacement uses intensity as a controlled blend factor, so 0% preserves the original background and 100% applies the full replacement.
- Added a live contact-sheet preview of all selected photos while changing background mode/intensity.

### Persistence
- The checked-in Hive `PhotoSession` adapter was stale: it did not serialize `printPageSize` or `singleMode` even though the model declared those fields. This was corrected.
- Background intensity is persisted as a new Hive field with a backward-compatible default of 100.

### Home screen / theme
- The app theme was tightened around a cleaner teal/navy product palette, softer neutral surface, Material 3 controls, elevation, spacing, and consistent rounded components.
- Settings is now an extended floating button matching the Add Photos button style.

## Validation notes

The source was statically reviewed and the modified Dart files were checked for balanced delimiters and stale share/capture UI references. A Flutter SDK was not available in the execution environment, so `flutter analyze`, `flutter test`, and a device build could not be executed here.

Before release, run:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release
```

The generated Hive files should remain committed after code generation.
