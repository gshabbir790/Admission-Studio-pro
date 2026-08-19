import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Ports the HTML app's `renderEditPreview()` / `unsharpMask()` pixel math
/// exactly (spec §11), so brightness/contrast/sharpen produce the same
/// visual result on Android as they did in the browser:
///
///   ctx.filter = 'brightness(b%) contrast(c%)'   // CSS filter chain
///   then, if sharpen>0: 3x3 unsharp mask blended by `amount = sharpen/100`
///
/// CSS `filter` applies brightness first, then contrast, each defined as:
///   brightness(b): v' = v * (b/100)
///   contrast(c):   v' = (v - 127.5) * (c/100) + 127.5
class ImageAdjustmentsService {
  const ImageAdjustmentsService._();

  /// [brightnessPercent]/[contrastPercent]: 50..150 (100 = neutral), matching
  /// the HTML sliders' raw values directly — pass `editBright.value` as-is.
  /// [sharpenPercent]: 0..100.
  static img.Image apply(
    img.Image source, {
    required int brightnessPercent,
    required int contrastPercent,
    required int sharpenPercent,
  }) {
    var result = _brightnessContrast(
      source,
      brightness: brightnessPercent / 100.0,
      contrast: contrastPercent / 100.0,
    );
    if (sharpenPercent > 0) {
      result = _unsharpMask(result, sharpenPercent / 100.0);
    }
    return result;
  }

  /// Downscales to fit within [maxDim] (matches `renderEditPreview`'s
  /// `Math.min(1, maxDim/Math.max(pw,ph))` scale-to-fit, never upscales),
  /// then applies the same brightness/contrast/sharpen chain. Used for the
  /// live-dragging preview (maxDim≈480) and the final Apply pass
  /// (maxDim≈4000, i.e. effectively "don't downscale" for realistic photos).
  static img.Image renderPreview(
    img.Image source, {
    required int brightnessPercent,
    required int contrastPercent,
    required int sharpenPercent,
    required int maxDim,
  }) {
    final scale = math.min(
      1.0,
      maxDim / math.max(source.width, source.height),
    );
    final scaled = scale < 1.0
        ? img.copyResize(
            source,
            width: (source.width * scale).round(),
            height: (source.height * scale).round(),
            interpolation: img.Interpolation.average,
          )
        : source;

    return apply(
      scaled,
      brightnessPercent: brightnessPercent,
      contrastPercent: contrastPercent,
      sharpenPercent: sharpenPercent,
    );
  }

  static img.Image _brightnessContrast(
    img.Image source, {
    required double brightness,
    required double contrast,
  }) {
    final out = img.Image.from(source);
    for (final pixel in out) {
      pixel
        ..r = _clamp((pixel.r * brightness - 127.5) * contrast + 127.5)
        ..g = _clamp((pixel.g * brightness - 127.5) * contrast + 127.5)
        ..b = _clamp((pixel.b * brightness - 127.5) * contrast + 127.5);
    }
    return out;
  }

  /// 3x3 kernel `[0,-1,0, -1,5,-1, 0,-1,0]`, blended as
  /// `out = original*(1-amount) + convolved*amount`, identical to the
  /// HTML's `unsharpMask()`. Border pixels are left untouched (the HTML
  /// loop runs `y=1..h-2, x=1..w-2` only) — [out] starts as a copy of
  /// [source] so edges fall through unmodified automatically.
  static img.Image _unsharpMask(img.Image source, double amount) {
    final out = img.Image.from(source);
    final w = source.width, h = source.height;

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final center = source.getPixel(x, y);
        double sumR = 0, sumG = 0, sumB = 0;
        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final weight = (kx == 0 && ky == 0) ? 5 : (kx == 0 || ky == 0) ? -1 : 0;
            if (weight == 0) continue;
            final p = source.getPixel(x + kx, y + ky);
            sumR += p.r * weight;
            sumG += p.g * weight;
            sumB += p.b * weight;
          }
        }
        final dst = out.getPixel(x, y);
        dst
          ..r = _clamp(center.r * (1 - amount) + sumR * amount)
          ..g = _clamp(center.g * (1 - amount) + sumG * amount)
          ..b = _clamp(center.b * (1 - amount) + sumB * amount);
      }
    }
    return out;
  }

  static num _clamp(num v) => v < 0 ? 0 : (v > 255 ? 255 : v);
}
