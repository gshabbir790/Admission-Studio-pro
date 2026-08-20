import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/image_file_utils.dart';
import '../../data/models/face_info.dart';
import '../../data/models/photo_item.dart';
import '../../data/models/photo_session.dart';
import 'service_providers.dart';

const _uuid = Uuid();

/// Owns the active [PhotoSession] and every mutation the HTML app performs
/// on its global `photos[]`/`capacity`: add, retake-replace, delete, rename,
/// clear-all. Every mutation calls [_autosave], mirroring `scheduleAutoSave()`
/// after every one of those operations in the source app.
class SessionNotifier extends StateNotifier<PhotoSession> {
  SessionNotifier(this._ref, PhotoSession initial) : super(initial);

  final Ref _ref;

  void _autosave() {
    _ref.read(sessionRepositoryProvider).scheduleAutoSave(state);
    // Trigger listeners with a shallow copy so Riverpod diff detects change.
    state = _cloneWithTouch(state);
  }

  PhotoSession _cloneWithTouch(PhotoSession s) {
    s.touch();
    return PhotoSession(
      id: s.id,
      photos: s.photos,
      capacity: s.capacity,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
      targetWidth: s.targetWidth,
      targetHeight: s.targetHeight,
      sizePreset: s.sizePreset,
      backgroundMode: s.backgroundMode,
      backgroundIntensity: s.backgroundIntensity,
      jpegQuality: s.jpegQuality,
      sizeLimitEnabled: s.sizeLimitEnabled,
      sizeLimitValue: s.sizeLimitValue,
      sizeLimitUnit: s.sizeLimitUnit,
      autoCaptureEnabled: s.autoCaptureEnabled,
      printPageSize: s.printPageSize,
      singleMode: s.singleMode,
    );
  }

  /// Adds a brand-new photo (capture or gallery import), or — if
  /// [retakeTargetId] is set — replaces that photo's original image, name,
  /// and face info in place. Mirrors `finalizeAddPhoto()` exactly, including
  /// growing capacity by 20 once the batch fills (HTML: `capacity += 20`).
  Future<PhotoItem> addOrReplacePhoto({
    required String originalPath,
    required String name,
    required bool nameEnabled,
    FaceInfo? face,
    String? retakeTargetId,
  }) async {
    if (retakeTargetId != null) {
      final idx = state.photos.indexWhere((p) => p.id == retakeTargetId);
      if (idx != -1) {
        final old = state.photos[idx];
        await ImageFileUtils.deleteIfExists(old.originalPath);
        await ImageFileUtils.deleteIfExists(old.processedPath);
        await ImageFileUtils.deleteIfExists(old.printPath);
        await ImageFileUtils.deleteIfExists(old.thumbnailPath);
        final updated = old.copyWith(
          originalPath: originalPath,
          name: name,
          nameEnabled: nameEnabled,
          face: face,
          clearFace: face == null,
        )..invalidateProcessedCache();
        state.photos[idx] = updated;
        _autosave();
        return updated;
      }
    }

    if (state.singleMode && state.photos.isNotEmpty) {
      throw StateError('Single-photo mode already contains a photo.');
    }

    state.growCapacityIfNeeded();
    final item = PhotoItem(
      id: _uuid.v4(),
      originalPath: originalPath,
      name: name,
      nameEnabled: nameEnabled,
      face: face,
    );
    state.photos.add(item);
    _autosave();
    return item;
  }

  void deletePhoto(String id) {
    final idx = state.photos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final removed = state.photos.removeAt(idx);
    ImageFileUtils.deleteIfExists(removed.originalPath);
    ImageFileUtils.deleteIfExists(removed.processedPath);
    ImageFileUtils.deleteIfExists(removed.printPath);
    ImageFileUtils.deleteIfExists(removed.thumbnailPath);
    _autosave();
  }

  Future<void> renamePhoto(String id, String name) async {
    final idx = state.photos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final old = state.photos[idx];
    await ImageFileUtils.deleteIfExists(old.processedPath);
    await ImageFileUtils.deleteIfExists(old.printPath);
    state.photos[idx] = old.copyWith(name: name)
      ..invalidateProcessedCache();
    _autosave();
  }

  /// v2 addition: swaps in a cropped replacement for a photo's original
  /// image (spec request: the editor's brightness/contrast/sharpen panel had
  /// no way to crop). Mirrors the retake path — old original file is
  /// deleted, brightness/contrast/sharpen params are kept as-is (crop is
  /// independent of those), and any cached processed/print output is
  /// invalidated so the next export re-renders from the newly cropped image.
  Future<void> replaceOriginalImage(String id, String newOriginalPath) async {
    final idx = state.photos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final old = state.photos[idx];
    await ImageFileUtils.deleteIfExists(old.originalPath);
    await ImageFileUtils.deleteIfExists(old.processedPath);
    await ImageFileUtils.deleteIfExists(old.printPath);
    state.photos[idx] = old.copyWith(originalPath: newOriginalPath)
      ..invalidateProcessedCache();
    _autosave();
  }

  Future<void> updateEditParams(
    String id, {
    double? brightness,
    double? contrast,
    double? sharpen,
  }) async {
    final idx = state.photos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final old = state.photos[idx];
    await ImageFileUtils.deleteIfExists(old.processedPath);
    await ImageFileUtils.deleteIfExists(old.printPath);
    state.photos[idx] = old.copyWith(
      brightness: brightness,
      contrast: contrast,
      sharpen: sharpen,
    )..invalidateProcessedCache();
    _autosave();
  }

  void addCapacityPage() {
    state.capacity += AppConstants.capacityIncrement;
    _autosave();
  }

  /// Persists a processed result onto the photo (v2 fix) so it survives
  /// app restarts and `ExportController` can skip already-processed photos
  /// on the next "Process All" instead of redoing the whole batch.
  void markPhotoProcessed(String id, {required String processedPath, required String printPath}) {
    final idx = state.photos.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    state.photos[idx].markProcessed(processedPath: processedPath, printPath: printPath);
    _autosave();
  }

  void _invalidateProcessedForExportSettings() {
    for (final photo in state.photos) {
      photo.invalidateProcessedCache();
    }
  }

  /// Applies a built-in size preset's pixel dimensions (spec §13). Custom
  /// keeps whatever targetWidth/targetHeight are already set (see
  /// [setCustomSize]).
  void setSizePreset(PhotoSizePreset preset) {
    _invalidateProcessedForExportSettings();
    state.sizePreset = preset;
    if (preset != PhotoSizePreset.custom) {
      state.targetWidth = preset.width;
      state.targetHeight = preset.height;
    }
    _autosave();
  }

  /// [width]/[height] clamped to the HTML app's custom-size bounds
  /// (50..4000px, spec §13).
  void setCustomSize(int width, int height) {
    _invalidateProcessedForExportSettings();
    state.sizePreset = PhotoSizePreset.custom;
    state.targetWidth = width.clamp(
      AppConstants.customSizeMin,
      AppConstants.customSizeMax,
    ).toInt();
    state.targetHeight = height.clamp(
      AppConstants.customSizeMin,
      AppConstants.customSizeMax,
    ).toInt();
    _autosave();
  }

  void setBackgroundMode(BackgroundMode mode) {
    _invalidateProcessedForExportSettings();
    state.backgroundMode = mode;
    _autosave();
  }

  void setBackgroundIntensity(int intensity) {
    _invalidateProcessedForExportSettings();
    state.backgroundIntensity = intensity.clamp(0, 100).toInt();
    _autosave();
  }

  /// [quality] clamped to 70..100 (spec §15).
  void setJpegQuality(int quality) {
    _invalidateProcessedForExportSettings();
    state.jpegQuality = quality.clamp(
      AppConstants.jpegQualityMin,
      AppConstants.jpegQualityMax,
    ).toInt();
    _autosave();
  }

  void setSizeLimit({bool? enabled, double? value, FileSizeUnit? unit}) {
    _invalidateProcessedForExportSettings();
    if (enabled != null) state.sizeLimitEnabled = enabled;
    if (value != null) state.sizeLimitValue = value;
    if (unit != null) state.sizeLimitUnit = unit;
    _autosave();
  }

  void setPrintPageSize(PrintPageSize size) {
    state.printPageSize = size;
    _autosave();
  }

  /// v2: choose single-photo (capacity locked to 1) vs. batch mode
  /// (standard 20-slot paged grid). Only meaningful to call while the
  /// session is empty — switching modes mid-batch is intentionally not
  /// supported (mirrors the HTML app never having had this distinction at
  /// all; this is an additive UX improvement, not a spec behavior to match).
  void setSingleMode(bool single) {
    state.singleMode = single;
    state.capacity = single ? 1 : AppConstants.defaultCapacity;
    _autosave();
  }

  Future<void> clearAll() async {
    for (final p in state.photos) {
      await ImageFileUtils.deleteIfExists(p.originalPath);
      await ImageFileUtils.deleteIfExists(p.processedPath);
      await ImageFileUtils.deleteIfExists(p.printPath);
      await ImageFileUtils.deleteIfExists(p.thumbnailPath);
    }

    state = PhotoSession(id: state.id);
    await _ref.read(sessionRepositoryProvider).clearSession();
    // Do not schedule an autosave here: "New Session" must actually remove
    // the persisted resume point instead of immediately writing an empty
    // session back into Hive.
  }

  void toggleAutoCapture(bool enabled) {
    state.autoCaptureEnabled = enabled;
    _autosave();
  }
}

/// Resolves the initial session on app start: a resumed one if present,
/// otherwise a fresh empty session — mirrors `checkResume()` gating on
/// `saved.photos.length>0` before offering resume.
final sessionProvider =
    StateNotifierProvider<SessionNotifier, PhotoSession>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  final resumed = repo.loadSession();
  final initial = resumed ?? PhotoSession(id: _uuid.v4());
  return SessionNotifier(ref, initial);
});
