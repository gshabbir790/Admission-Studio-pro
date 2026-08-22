import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/image_file_utils.dart';
import '../../services/permissions/permission_service.dart';
import '../providers/service_providers.dart';
import '../providers/session_provider.dart';

/// Mirrors the HTML app's `mode` variable (spec §5–§9).
///
/// NOTE (v2): live face detection / auto-capture was removed — it never
/// triggered reliably on-device and ML Kit Face Detection was pulling in a
/// large chunk of the APK for a feature that didn't work. Capture is now
/// manual-shutter only. The oval guide stays as a static framing aid.
/// `ResizeService` already falls back to a center-crop when no face info is
/// present, so removing detection doesn't break resize/export — it just
/// means every photo uses the center-crop path now instead of face-centered.
enum CaptureMode { chooser, live, confirm, naming }

enum NamingSource { camera, gallery, retake }

class CaptureFlowState {
  const CaptureFlowState({
    this.mode = CaptureMode.chooser,
    this.pendingImagePath,
    this.retakeTargetId,
    this.namingSource,
    this.galleryQueueLength = 0,
    this.cameraAvailable = true,
  });

  final CaptureMode mode;
  final String? pendingImagePath;
  final String? retakeTargetId;
  final NamingSource? namingSource;
  final int galleryQueueLength;
  final bool cameraAvailable;

  CaptureFlowState copyWith({
    CaptureMode? mode,
    String? pendingImagePath,
    bool clearPendingImagePath = false,
    String? retakeTargetId,
    bool clearRetakeTargetId = false,
    NamingSource? namingSource,
    int? galleryQueueLength,
    bool? cameraAvailable,
  }) {
    return CaptureFlowState(
      mode: mode ?? this.mode,
      pendingImagePath:
          clearPendingImagePath ? null : (pendingImagePath ?? this.pendingImagePath),
      retakeTargetId:
          clearRetakeTargetId ? null : (retakeTargetId ?? this.retakeTargetId),
      namingSource: namingSource ?? this.namingSource,
      galleryQueueLength: galleryQueueLength ?? this.galleryQueueLength,
      cameraAvailable: cameraAvailable ?? this.cameraAvailable,
    );
  }
}

class CaptureFlowController extends StateNotifier<CaptureFlowState> {
  CaptureFlowController(this._ref) : super(const CaptureFlowState());

  final Ref _ref;
  final Queue<String> _galleryQueue = Queue<String>();

  /// v2 addition (spec request: "camera jaldi launch nahi hota") — kicks off
  /// camera initialization in the background as soon as the capture chooser
  /// screen appears, well before the person taps "Take Photo with Camera",
  /// so by the time [enterLive] actually needs the controller it's often
  /// already warm. Safe to call repeatedly / when permission isn't granted
  /// yet — [CameraService.prewarm] is a no-op once already initializing.
  Future<void> prewarmCamera() async {
    final granted = await PermissionService.hasCameraPermission();
    if (!granted) return;
    _ref.read(cameraServiceProvider).prewarm();
  }

  /// Starts the live camera preview. Mirrors `goLive()`. Requests camera
  /// permission first (spec §30) — a denial routes to the same
  /// `cameraAvailable: false` fallback UI as a hardware failure (spec §34:
  /// never crash, manual file-picker capture stays available).
  Future<void> enterLive({bool isRetake = false}) async {
    final granted = await PermissionService.ensureCameraPermission();
    if (!granted) {
      state = state.copyWith(cameraAvailable: false, mode: CaptureMode.live);
      return;
    }

    final camera = _ref.read(cameraServiceProvider);
    if (!camera.isInitialized) {
      final ok = await camera.initialize();
      if (!ok) {
        state = state.copyWith(cameraAvailable: false, mode: CaptureMode.live);
        return;
      }
    }
    state = state.copyWith(
      mode: CaptureMode.live,
      cameraAvailable: true,
      clearPendingImagePath: true,
    );
  }

  Future<void> switchCamera() async {
    final camera = _ref.read(cameraServiceProvider);
    await camera.switchCamera();
  }

  /// Manual shutter (spec §7 — now the only capture path, see class note).
  Future<void> capturePhoto() async {
    final camera = _ref.read(cameraServiceProvider);
    final xfile = await camera.capturePhoto();
    if (xfile == null) return;
    final savedPath = await ImageFileUtils.saveOriginalFromPath(xfile.path);
    state = state.copyWith(mode: CaptureMode.confirm, pendingImagePath: savedPath);
  }

  /// Used by the permission-denied/no-camera fallback path (spec §5, §34):
  /// a photo picked via the system camera intent goes straight to the same
  /// confirm step a live capture would reach.
  Future<void> acceptFallbackCapture(String savedPath) async {
    state = state.copyWith(mode: CaptureMode.confirm, pendingImagePath: savedPath);
  }

  /// Reject the pending capture → back to live preview, mirrors `rejectBtn`.
  Future<void> retakeFromConfirm() async {
    if (state.pendingImagePath != null) {
      await ImageFileUtils.deleteIfExists(state.pendingImagePath);
    }
    state = state.copyWith(mode: CaptureMode.live, clearPendingImagePath: true);
  }

  /// Accept the pending capture → naming screen, mirrors `acceptBtn`.
  void acceptFromConfirm() {
    state = state.copyWith(mode: CaptureMode.naming, namingSource: NamingSource.camera);
  }

  /// Starts a batch gallery import. Sequential naming, one at a time,
  /// mirrors `galleryQueue`/`processNextGalleryItem()`.
  void startGalleryImport(List<String> importedPaths) {
    if (_ref.read(sessionProvider).singleMode &&
        _ref.read(sessionProvider).photos.isNotEmpty) {
      state = state.copyWith(mode: CaptureMode.chooser, clearPendingImagePath: true);
      return;
    }
    _galleryQueue
      ..clear()
      ..addAll(importedPaths);
    state = state.copyWith(galleryQueueLength: _galleryQueue.length);
    _advanceGalleryQueue();
  }

  void _advanceGalleryQueue() {
    if (_galleryQueue.isEmpty) {
      state = state.copyWith(mode: CaptureMode.chooser, clearPendingImagePath: true);
      return;
    }
    final next = _galleryQueue.removeFirst();
    state = state.copyWith(
      mode: CaptureMode.naming,
      pendingImagePath: next,
      namingSource: NamingSource.gallery,
      galleryQueueLength: _galleryQueue.length,
    );
  }

  /// Sets up a retake: remembers which photo id is being replaced, jumps
  /// straight to live camera. Mirrors the grid's retake button handler.
  void beginRetake(String photoId) {
    state = state.copyWith(retakeTargetId: photoId, namingSource: NamingSource.retake);
    enterLive(isRetake: true);
  }

  void cancelRetake() {
    state = state.copyWith(clearRetakeTargetId: true);
  }

  /// Finalizes naming and commits the photo to the session — mirrors
  /// `finalizeAddPhoto()`. Returns to the gallery queue if mid-batch,
  /// otherwise back to live camera (new capture) or chooser (retake done).
  Future<void> confirmNaming({required String name, required bool nameEnabled}) async {
    final path = state.pendingImagePath;
    if (path == null) return;

    final retakeId = state.retakeTargetId;
    final session = _ref.read(sessionProvider);
    if (retakeId == null && session.singleMode && session.photos.isNotEmpty) {
      state = state.copyWith(mode: CaptureMode.chooser, clearPendingImagePath: true);
      return;
    }
    await _ref.read(sessionProvider.notifier).addOrReplacePhoto(
          originalPath: path,
          name: name,
          nameEnabled: nameEnabled,
          face: null, // no live face detection anymore — resize falls back to center-crop
          retakeTargetId: retakeId,
        );

    if (retakeId != null) {
      state = state.copyWith(
        mode: CaptureMode.chooser,
        clearRetakeTargetId: true,
        clearPendingImagePath: true,
      );
      return;
    }

    // v2 fix: single-photo mode has capacity locked to 1 (see
    // `PhotoSession.growCapacityIfNeeded`), but this used to unconditionally
    // loop back into `enterLive()` for "one more shot" after every camera
    // capture — in single mode that let a 2nd/3rd photo get added on top of
    // a capacity of 1 (report: "2 of 1 photos captured … 200%") and left the
    // user stuck several screens deep in a camera loop they never asked for,
    // which is also what made the hardware back button feel like it was
    // closing the whole app instead of returning to the home screen. Single
    // mode now stops after exactly one photo and returns straight to the
    // chooser, which pops all the way back to the home/grid screen.
    final singleMode = _ref.read(sessionProvider).singleMode;
    if (state.namingSource == NamingSource.gallery) {
      _advanceGalleryQueue();
    } else if (singleMode) {
      state = state.copyWith(mode: CaptureMode.chooser, clearPendingImagePath: true);
    } else {
      state = state.copyWith(clearPendingImagePath: true);
      await enterLive();
    }
  }

  Future<void> goToChooser() async {
    _galleryQueue.clear();
    state = state.copyWith(
      mode: CaptureMode.chooser,
      clearPendingImagePath: true,
      clearRetakeTargetId: true,
    );
  }
}

final captureFlowProvider =
    StateNotifierProvider<CaptureFlowController, CaptureFlowState>((ref) {
  return CaptureFlowController(ref);
});
