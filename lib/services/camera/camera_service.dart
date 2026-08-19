import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Wraps the `camera` package. Mirrors the HTML app's `startCamera()` /
/// `stopCamera()` / `flipBtn` behavior: front camera by default, switchable,
/// with graceful fallback signaled via a failed [initialize] so the UI can
/// fall back to a file picker exactly like the HTML's `cameraFallback`
/// block (spec §5, §34).
///
/// NOTE (v2): live frame streaming was removed along with face detection
/// (see `CaptureFlowController`) — this is now a plain preview + still
/// capture wrapper, which also sidesteps the "startImageStream + takePicture
/// at the same time" conflict some devices had.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraLensDirection _lensDirection = CameraLensDirection.front;

  CameraController? get controller => _controller;
  CameraLensDirection get lensDirection => _lensDirection;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<bool> initialize({
    CameraLensDirection preferredDirection = CameraLensDirection.front,
  }) async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;
      _lensDirection = preferredDirection;
      return await _openController(_lensDirection);
    } catch (e, st) {
      debugPrint('CameraService.initialize failed: $e\n$st');
      return false;
    }
  }

  Future<bool> _openController(CameraLensDirection direction) async {
    final match = _cameras.where((c) => c.lensDirection == direction);
    final description = match.isNotEmpty ? match.first : _cameras.first;

    await _controller?.dispose();
    _controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      _lensDirection = description.lensDirection;
      return true;
    } catch (e, st) {
      debugPrint('CameraService._openController failed: $e\n$st');
      _controller = null;
      return false;
    }
  }

  /// Mirrors the HTML `flipBtn` handler: toggles front/rear and restarts.
  Future<bool> switchCamera() {
    final next = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    return _openController(next);
  }

  /// v2 fix: the HTML app mirrored the *preview* for the front camera (like
  /// a bathroom mirror) but `takePicture()` always returns the sensor's true
  /// (unmirrored) frame — so whatever the user composed in the mirrored
  /// preview came out left-right flipped in the saved/confirm-screen photo
  /// (report: "camera mirror ulti tasveer leta hai, dayen-bayen ulat jate
  /// hain"). For an ID/admission photo, a flipped result is actually wrong
  /// (any visible text, badge, watch-hand side etc. reads backwards), so the
  /// correct fix is to never mirror — preview and saved file must match.
  /// Always returns false now, front or back camera.
  bool get shouldMirrorPreview => false;

  Future<XFile?> capturePhoto() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return null;
    try {
      return await c.takePicture();
    } catch (e, st) {
      debugPrint('CameraService.capturePhoto failed: $e\n$st');
      return null;
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
