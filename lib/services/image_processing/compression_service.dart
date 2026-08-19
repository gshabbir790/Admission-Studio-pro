import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';

/// Exact port of the HTML app's `compressToSize()` (spec §16): 8-round
/// binary search over JPEG quality in [0.25, 0.97], keeping the highest
/// quality whose encoded size still fits [maxBytes]. Never shrinks
/// dimensions — quality-only, matching "Do NOT unnecessarily reduce
/// dimensions unless explicitly configured to do so."
class CompressionService {
  const CompressionService._();

  static Uint8List compressToSize(img.Image image, int maxBytes) {
    var lo = AppConstants.compressQualityLow;
    var hi = AppConstants.compressQualityHigh;
    Uint8List? best;

    for (var i = 0; i < AppConstants.compressIterations; i++) {
      final mid = (lo + hi) / 2;
      final qualityPercent = (mid * 100).round();
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: qualityPercent));
      if (bytes.lengthInBytes <= maxBytes) {
        best = bytes;
        lo = mid;
      } else {
        hi = mid;
      }
    }

    best ??= Uint8List.fromList(
      img.encodeJpg(image, quality: (AppConstants.compressQualityLow * 100).round()),
    );
    return best;
  }

  /// Fixed-quality encode (no size limit), used when the size-limit toggle
  /// is off. [qualityPercent]: 70..100.
  static Uint8List encodeAtQuality(img.Image image, int qualityPercent) {
    return Uint8List.fromList(img.encodeJpg(image, quality: qualityPercent));
  }
}
