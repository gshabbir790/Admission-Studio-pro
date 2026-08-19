import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:admission_studio_pro/data/models/face_info.dart';
import 'package:admission_studio_pro/services/image_processing/resize_service.dart';

void main() {
  group('ResizeService.computeCropRect', () {
    test('no face → center crop matching target aspect ratio exactly', () {
      final crop = ResizeService.computeCropRect(
        sw: 1000,
        sh: 1000,
        targetW: 413,
        targetH: 531, // passport ratio, taller than wide
      );
      // target ratio ~0.7778; source is square, so crop should be full
      // height, width reduced to match ratio.
      expect(crop.height, 1000);
      expect((crop.width / crop.height - 413 / 531).abs() < 0.001, isTrue);
      // Centered horizontally.
      expect((crop.x - (1000 - crop.width) / 2).abs() < 0.5, isTrue);
    });

    test('with face info → crop sized from face height, centered on face', () {
      final face = FaceInfo(cx: 0.5, cy: 0.42, faceHeightRatio: 0.3);
      final crop = ResizeService.computeCropRect(
        sw: 2000,
        sh: 3000,
        targetW: 413,
        targetH: 531,
        face: face,
      );
      // cropH = faceHeightRatio*sh / 0.5 = 0.3*3000/0.5 = 1800
      expect((crop.height - 1800).abs() < 1, isTrue);
      expect((crop.width / crop.height - 413 / 531).abs() < 0.001, isTrue);
    });

    test('crop never exceeds source bounds even with extreme face position', () {
      final face = FaceInfo(cx: 0.02, cy: 0.02, faceHeightRatio: 0.5);
      final crop = ResizeService.computeCropRect(
        sw: 800,
        sh: 800,
        targetW: 300,
        targetH: 300,
        face: face,
      );
      expect(crop.x >= 0, isTrue);
      expect(crop.y >= 0, isTrue);
      expect(crop.x + crop.width <= 800.001, isTrue);
      expect(crop.y + crop.height <= 800.001, isTrue);
    });

    test('face crop never distorts: width/height ratio always equals target ratio', () {
      final face = FaceInfo(cx: 0.6, cy: 0.35, faceHeightRatio: 0.45);
      final crop = ResizeService.computeCropRect(
        sw: 1200,
        sh: 900,
        targetW: 300,
        targetH: 300, // square
        face: face,
      );
      expect((crop.width - crop.height).abs() < 0.5, isTrue);
    });
  });

  group('ResizeService.resizeToCoverFace', () {
    test('output image is exactly the requested target dimensions', () {
      final source = img.Image(width: 1600, height: 1200);
      img.fill(source, color: img.ColorRgb8(120, 130, 140));

      final result = ResizeService.resizeToCoverFace(
        source,
        targetW: 413,
        targetH: 531,
        face: FaceInfo(cx: 0.5, cy: 0.4, faceHeightRatio: 0.3),
      );

      expect(result.width, 413);
      expect(result.height, 531);
    });

    test('falls back to center crop cleanly when face is null', () {
      final source = img.Image(width: 900, height: 900);
      img.fill(source, color: img.ColorRgb8(50, 60, 70));

      final result = ResizeService.resizeToCoverFace(
        source,
        targetW: 300,
        targetH: 300,
      );

      expect(result.width, 300);
      expect(result.height, 300);
    });
  });
}
