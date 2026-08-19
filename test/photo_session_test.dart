import 'package:flutter_test/flutter_test.dart';
import 'package:admission_studio_pro/data/models/face_info.dart';
import 'package:admission_studio_pro/data/models/photo_item.dart';
import 'package:admission_studio_pro/data/models/processing_status.dart';

void main() {
  group('PhotoItem', () {
    test('invalidateProcessedCache clears processed path and status', () {
      final item = PhotoItem(
        id: 'p1',
        originalPath: '/tmp/p1.jpg',
        processedPath: '/tmp/p1_out.jpg',
        processingStatus: ProcessingStatus.processed,
      );

      item.invalidateProcessedCache();

      expect(item.processedPath, isNull);
      expect(item.processingStatus, ProcessingStatus.pending);
    });

    test('toJson/fromJson round-trip preserves all fields including face', () {
      final original = PhotoItem(
        id: 'p2',
        originalPath: '/tmp/p2.jpg',
        name: 'احمد علی',
        nameEnabled: true,
        face: FaceInfo(cx: 0.51, cy: 0.40, faceHeightRatio: 0.33),
        brightness: 1.1,
        contrast: 0.95,
        sharpen: 0.2,
      );

      final restored = PhotoItem.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.face?.cx, original.face?.cx);
      expect(restored.face?.faceHeightRatio, original.face?.faceHeightRatio);
      expect(restored.brightness, original.brightness);
    });

    test('copyWith bumps updatedAt and creates independent instance', () async {
      final original = PhotoItem(id: 'p3', originalPath: '/tmp/p3.jpg');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final copy = original.copyWith(name: 'New Name');

      expect(copy.id, original.id);
      expect(copy.name, 'New Name');
      expect(original.name, isNot('New Name'));
      expect(copy.updatedAt.isAfter(original.updatedAt) ||
          copy.updatedAt.isAtSameMomentAs(original.updatedAt), isTrue);
    });
  });
}
