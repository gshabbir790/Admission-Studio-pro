import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';
import '../../data/models/face_info.dart';

class CropRect {
  const CropRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

/// Face-aware crop + resize, ported line-for-line from the HTML app's
/// `computeCropRect()` / `resizeToCoverFace()` (spec §12, §18). Never
/// distorts the image — always crops to the exact target aspect ratio
/// first, then resizes. Falls back to a plain center crop when no face
/// info is available (spec §12: "If face information is unavailable: use
/// center crop").
class ResizeService {
  const ResizeService._();

  /// [sw]/[sh]: source width/height. [targetW]/[targetH]: output size.
  static CropRect computeCropRect({
    required int sw,
    required int sh,
    required int targetW,
    required int targetH,
    FaceInfo? face,
  }) {
    final targetRatio = targetW / targetH;
    double cropW, cropH, cropCx, cropCy;

    if (face != null && face.faceHeightRatio > 0) {
      const desiredFaceHeightRatio = AppConstants.desiredFaceHeightRatioInCrop;
      cropH = (face.faceHeightRatio * sh) / desiredFaceHeightRatio;
      if (cropH > sh) cropH = sh.toDouble();
      cropW = cropH * targetRatio;
      if (cropW > sw) {
        cropW = sw.toDouble();
        cropH = cropW / targetRatio;
      }
      cropCx = face.cx * sw;
      // Oval target center is at 0.42 of the frame height, not 0.5 — shift
      // the crop up so the face lands where the guide expects it, exactly
      // mirroring `cropCY = face.cy*sh - (0.5-0.42)*cropH`.
      cropCy = face.cy * sh -
          (AppConstants.desiredFaceHeightRatioInCrop -
                  AppConstants.faceCenterYTarget) *
              cropH;
    } else {
      final srcRatio = sw / sh;
      if (srcRatio > targetRatio) {
        cropH = sh.toDouble();
        cropW = sh * targetRatio;
      } else {
        cropW = sw.toDouble();
        cropH = sw / targetRatio;
      }
      cropCx = sw / 2;
      cropCy = sh / 2;
    }

    var cropX = cropCx - cropW / 2;
    var cropY = cropCy - cropH / 2;
    cropX = cropX.clamp(0, (sw - cropW).clamp(0, double.infinity));
    cropY = cropY.clamp(0, (sh - cropH).clamp(0, double.infinity));

    return CropRect(x: cropX, y: cropY, width: cropW, height: cropH);
  }

  /// Crops to [computeCropRect] then resizes to exactly `targetW x targetH`
  /// using progressive halving for large downscales (avoids the aliasing a
  /// single huge downscale produces) followed by one final high-quality
  /// resize — same two-stage approach as the HTML app's canvas pipeline.
  static img.Image resizeToCoverFace(
    img.Image source, {
    required int targetW,
    required int targetH,
    FaceInfo? face,
  }) {
    final crop = computeCropRect(
      sw: source.width,
      sh: source.height,
      targetW: targetW,
      targetH: targetH,
      face: face,
    );

    img.Image current = img.copyCrop(
      source,
      x: crop.x.round(),
      y: crop.y.round(),
      width: crop.width.round().clamp(1, source.width),
      height: crop.height.round().clamp(1, source.height),
    );

    // Progressive halving: repeatedly resize to 50% until within 2x of the
    // target, then do one final precise resize — mirrors the HTML comment
    // "progressive halving downscale + final high-quality draw" (spec §18).
    while (current.width > targetW * 2 && current.height > targetH * 2) {
      current = img.copyResize(
        current,
        width: (current.width / 2).round(),
        height: (current.height / 2).round(),
        interpolation: img.Interpolation.average,
      );
    }

    return img.copyResize(
      current,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.cubic,
    );
  }
}
