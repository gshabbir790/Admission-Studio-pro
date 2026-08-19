import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:admission_studio_pro/core/constants/app_constants.dart';
import 'package:admission_studio_pro/services/image_processing/compression_service.dart';

void main() {
  group('A4 print-sheet dimensions (spec §19)', () {
    test('A4 page size at 300 DPI matches 8.27in x 11.69in', () {
      const dpi = AppConstants.printDpi;
      final a4w = (AppConstants.a4WidthInches * dpi).round();
      final a4h = (AppConstants.a4HeightInches * dpi).round();
      expect(a4w, 2481); // 8.27 * 300 rounded
      expect(a4h, 3507); // 11.69 * 300 rounded
    });

    test('4x5 grid yields 20 photos per page', () {
      expect(AppConstants.printCols * AppConstants.printRows, 20);
    });

    test('margin/gutter at 300 DPI match HTML app constants', () {
      const dpi = AppConstants.printDpi;
      expect((AppConstants.printMarginInches * dpi).round(), 150); // 0.5in
      expect((AppConstants.printGutterInches * dpi).round(), 45); // 0.15in
    });
  });

  group('CompressionService.compressToSize', () {
    test('binary search never exceeds the requested byte budget', () {
      final image = img.Image(width: 800, height: 600);
      // Noisy fill so JPEG can't trivially compress to near-zero, giving the
      // binary search something real to converge on.
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          image.setPixelRgb(x, y, (x * 7) % 255, (y * 13) % 255, (x ^ y) % 255);
        }
      }

      const maxBytes = 30000;
      final result = CompressionService.compressToSize(image, maxBytes);
      expect(result.lengthInBytes <= maxBytes, isTrue);
    });

    test('encodeAtQuality respects the requested quality parameter range', () {
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(100, 150, 200));

      final low = CompressionService.encodeAtQuality(image, 70);
      final high = CompressionService.encodeAtQuality(image, 100);
      // Higher quality should generally not produce a smaller file for the
      // same source image.
      expect(high.lengthInBytes >= low.lengthInBytes, isTrue);
    });
  });
}
