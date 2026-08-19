import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';

class SegmentationService {
  SegmentationService()
      : _segmenter = SelfieSegmenter(
          mode: SegmenterMode.single,
          enableRawSizeMask: true,
        );

  final SelfieSegmenter _segmenter;
  bool _available = true;

  bool get isAvailable => _available;

  Future<img.Image> apply(
    img.Image source, {
    required BackgroundMode mode,
    required InputImage inputImage,
    int intensity = 100,
  }) async {
    if (mode == BackgroundMode.original) return source;

    try {
      final mask = await _segmenter.processImage(inputImage);
      _available = true;
      if (mask == null) return source;

      final bg = mode == BackgroundMode.white
          ? const [255, 255, 255]
          : const [28, 78, 158]; // royal blue, matches HTML's [28,78,158]

      return _blend(source, mask, bg, intensity.clamp(0, 100).toInt());
    } catch (e, st) {
      debugPrint('SegmentationService.apply failed: $e\n$st');
      _available = false;
      return source;
    }
  }

  img.Image _blend(img.Image source, SegmentationMask mask, List<int> bg, int intensity) {
    final out = img.Image.from(source);
    final w = source.width, h = source.height;
    final maskW = mask.width, maskH = mask.height;
    final confidences = mask.confidences; // Float32List/List<double>, row-major

    for (var y = 0; y < h; y++) {
      final my = ((y / h) * maskH).floor().clamp(0, maskH - 1);
      for (var x = 0; x < w; x++) {
        final mx = ((x / w) * maskW).floor().clamp(0, maskW - 1);
        double v = confidences[my * maskW + mx].toDouble();
        if (v > 1) v = v / 255.0;

        // [replacement] is the confidence-derived background amount.
        // Intensity scales that amount so users can preview a softer/stronger
        // replacement without changing the subject edge logic.
        final replacement = v < 0.5
            ? 1.0
            : (v < 0.75 ? (1 - (v - 0.5) / 0.25) : 0.0);
        final a = replacement * (intensity / 100.0);
        if (a > 0) {
          final p = out.getPixel(x, y);
          p
            ..r = (p.r * (1 - a) + bg[0] * a).round()
            ..g = (p.g * (1 - a) + bg[1] * a).round()
            ..b = (p.b * (1 - a) + bg[2] * a).round();
        }
      
      }
    }
    return out;
  }

  Future<void> dispose() async {
    await _segmenter.close();
  }
}
