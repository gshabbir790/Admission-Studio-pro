import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';

/// Wraps ML Kit's on-device Selfie Segmenter.
///
/// v2 fix (spec request: "background removal 20+ tasveeron par processing
/// rukk jaati hai" — the app stops responding partway through a large
/// batch): two independent mitigations, both aimed at the same root cause —
/// long-running native ML Kit sessions slowly accumulating native-heap
/// pressure that a normal Dart `try/catch` can't see coming:
///
/// 1. [_maybeRecycle] closes and recreates the native segmenter every
///    [AppConstants.segmenterRecycleEvery] calls, releasing whatever native
///    buffers ML Kit is holding onto instead of letting them build up for
///    the whole batch.
/// 2. After [AppConstants.segmenterMaxConsecutiveFailures] failures in a
///    row, [apply] stops attempting segmentation entirely for the rest of
///    the run and just returns the untouched source image — a batch that
///    hits a bad device/driver state degrades to "no background removal"
///    instead of repeatedly retrying (and potentially crashing on) the same
///    failing native call for every remaining photo.
class SegmentationService {
  SegmentationService() : _segmenter = _newSegmenter();

  static SelfieSegmenter _newSegmenter() => SelfieSegmenter(
        mode: SegmenterMode.single,
        enableRawSizeMask: true,
      );

  SelfieSegmenter _segmenter;
  bool _available = true;
  int _consecutiveFailures = 0;
  int _callsSinceRecycle = 0;
  bool _permanentlyDisabledForThisBatch = false;

  bool get isAvailable => _available && !_permanentlyDisabledForThisBatch;

  /// Call once at the start of each "Process All" batch so a previous run's
  /// failure state doesn't leak into a fresh attempt.
  void resetBatchHealth() {
    _consecutiveFailures = 0;
    _permanentlyDisabledForThisBatch = false;
  }

  Future<void> _maybeRecycle() async {
    _callsSinceRecycle++;
    if (_callsSinceRecycle < AppConstants.segmenterRecycleEvery) return;
    _callsSinceRecycle = 0;
    try {
      await _segmenter.close();
    } catch (e) {
      debugPrint('SegmentationService recycle close failed (ignored): $e');
    }
    _segmenter = _newSegmenter();
  }

  Future<img.Image> apply(
    img.Image source, {
    required BackgroundMode mode,
    required InputImage inputImage,
    int intensity = 100,
  }) async {
    if (mode == BackgroundMode.original) return source;
    if (_permanentlyDisabledForThisBatch) return source;

    try {
      await _maybeRecycle();
      final mask = await _segmenter.processImage(inputImage);
      _available = true;
      _consecutiveFailures = 0;
      if (mask == null) return source;

      final bg = mode == BackgroundMode.white
          ? const [255, 255, 255]
          : const [28, 78, 158]; // royal blue, matches HTML's [28,78,158]

      return _blend(source, mask, bg, intensity.clamp(0, 100).toInt());
    } catch (e, st) {
      debugPrint('SegmentationService.apply failed: $e\n$st');
      _available = false;
      _consecutiveFailures++;
      if (_consecutiveFailures >= AppConstants.segmenterMaxConsecutiveFailures) {
        _permanentlyDisabledForThisBatch = true;
        debugPrint(
          'SegmentationService: disabling background removal for the rest '
          'of this batch after $_consecutiveFailures consecutive failures.',
        );
      }
      return source;
    }
  }

  /// Confidence-mask alpha blend. ML Kit's per-pixel confidence is the
  /// probability the pixel is *foreground* (the person) — near 1.0 for the
  /// subject, near 0.0 for background — so a low-confidence pixel is the one
  /// that should be replaced.
  ///
  /// v2 fix: the transition band used to be a hard-ish 0.5–0.75 ramp with no
  /// smoothing, which on a low-resolution mask (edges land on whole mask
  /// pixels that each cover several image pixels) produced a blocky "color
  /// slapped over part of the subject" look at high intensity rather than a
  /// clean silhouette cut — this is what was reported as "the color that was
  /// supposed to replace the background landed on top of the photo instead".
  /// The wider, smoothed ramp below keeps the same edge logic but spreads the
  /// transition over more of the confidence range so the mask's native low
  /// resolution doesn't read as a hard color block over the subject, plus a
  /// bilinear sample of the mask itself (instead of nearest-pixel) so edges
  /// interpolate smoothly instead of snapping to blocky mask-pixel bounds.
  img.Image _blend(img.Image source, SegmentationMask mask, List<int> bg, int intensity) {
    final out = img.Image.from(source);
    final w = source.width, h = source.height;
    final maskW = mask.width, maskH = mask.height;
    final confidences = mask.confidences; // Float32List/List<double>, row-major

    double sample(int mx, int my) {
      var v = confidences[my * maskW + mx].toDouble();
      if (v > 1) v = v / 255.0;
      return v;
    }

    for (var y = 0; y < h; y++) {
      final myF = (y / h) * maskH;
      final my0 = myF.floor().clamp(0, maskH - 1);
      final my1 = (my0 + 1).clamp(0, maskH - 1);
      final fy = (myF - my0).clamp(0.0, 1.0);
      for (var x = 0; x < w; x++) {
        final mxF = (x / w) * maskW;
        final mx0 = mxF.floor().clamp(0, maskW - 1);
        final mx1 = (mx0 + 1).clamp(0, maskW - 1);
        final fx = (mxF - mx0).clamp(0.0, 1.0);

        final v00 = sample(mx0, my0);
        final v10 = sample(mx1, my0);
        final v01 = sample(mx0, my1);
        final v11 = sample(mx1, my1);
        final v = v00 * (1 - fx) * (1 - fy) +
            v10 * fx * (1 - fy) +
            v01 * (1 - fx) * fy +
            v11 * fx * fy;

        // [replacement] is the confidence-derived background amount, ramped
        // smoothly over a wider band (0.35–0.85) than before so a low-res
        // mask doesn't produce hard blocky edges over the subject.
        final replacement = v < 0.35
            ? 1.0
            : (v < 0.85 ? (1 - (v - 0.35) / 0.50) : 0.0);
        final a = replacement * (intensity / 100.0);
        if (a > 0.004) {
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
