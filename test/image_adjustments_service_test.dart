import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:admission_studio_pro/services/image_processing/image_adjustments_service.dart';

void main() {
  group('ImageAdjustmentsService', () {
    test('neutral params (100/100/0) leave pixels unchanged', () {
      final source = img.Image(width: 4, height: 4);
      img.fill(source, color: img.ColorRgb8(120, 90, 200));

      final result = ImageAdjustmentsService.apply(
        source,
        brightnessPercent: 100,
        contrastPercent: 100,
        sharpenPercent: 0,
      );

      final p = result.getPixel(1, 1);
      expect(p.r.round(), 120);
      expect(p.g.round(), 90);
      expect(p.b.round(), 200);
    });

    test('brightness 150% scales channel values up (before contrast clamp)', () {
      final source = img.Image(width: 4, height: 4);
      img.fill(source, color: img.ColorRgb8(100, 100, 100));

      final result = ImageAdjustmentsService.apply(
        source,
        brightnessPercent: 150,
        contrastPercent: 100,
        sharpenPercent: 0,
      );

      final p = result.getPixel(1, 1);
      // 100 * 1.5 = 150, contrast 100% is a no-op pass-through.
      expect(p.r.round(), 150);
    });

    test('brightness 50% darkens', () {
      final source = img.Image(width: 4, height: 4);
      img.fill(source, color: img.ColorRgb8(200, 200, 200));

      final result = ImageAdjustmentsService.apply(
        source,
        brightnessPercent: 50,
        contrastPercent: 100,
        sharpenPercent: 0,
      );

      final p = result.getPixel(1, 1);
      expect(p.r.round(), 100);
    });

    test('renderPreview never upscales beyond source size', () {
      final source = img.Image(width: 200, height: 100);
      img.fill(source, color: img.ColorRgb8(10, 20, 30));

      final result = ImageAdjustmentsService.renderPreview(
        source,
        brightnessPercent: 100,
        contrastPercent: 100,
        sharpenPercent: 0,
        maxDim: 4000, // larger than source — must not upscale
      );

      expect(result.width, 200);
      expect(result.height, 100);
    });

    test('renderPreview scales down to fit maxDim, preserving aspect ratio', () {
      final source = img.Image(width: 1000, height: 500);
      img.fill(source, color: img.ColorRgb8(10, 20, 30));

      final result = ImageAdjustmentsService.renderPreview(
        source,
        brightnessPercent: 100,
        contrastPercent: 100,
        sharpenPercent: 0,
        maxDim: 480,
      );

      expect(result.width, 480);
      expect(result.height, 240);
    });
  });
}
