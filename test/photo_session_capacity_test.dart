import 'package:flutter_test/flutter_test.dart';
import 'package:admission_studio_pro/core/constants/app_constants.dart';
import 'package:admission_studio_pro/data/models/photo_item.dart';
import 'package:admission_studio_pro/data/models/photo_session.dart';

void main() {
  group('PhotoSession.growCapacityIfNeeded', () {
    test('does nothing while photos.length < capacity', () {
      final session = PhotoSession(id: 's1', capacity: 20);
      session.photos.addAll(List.generate(
        5,
        (i) => PhotoItem(id: 'p$i', originalPath: '/tmp/$i.jpg'),
      ));
      session.growCapacityIfNeeded();
      expect(session.capacity, 20);
    });

    test('grows by 20 once photos fill the current capacity', () {
      final session = PhotoSession(id: 's2', capacity: 20);
      session.photos.addAll(List.generate(
        20,
        (i) => PhotoItem(id: 'p$i', originalPath: '/tmp/$i.jpg'),
      ));
      session.growCapacityIfNeeded();
      expect(session.capacity, 40);
    });

    test('single-photo mode never grows beyond one slot', () {
      final session = PhotoSession(id: 'single', capacity: 1, singleMode: true);
      session.photos.add(PhotoItem(id: 'p1', originalPath: '/tmp/1.jpg'));
      session.growCapacityIfNeeded();
      expect(session.capacity, 1);
    });

    test('grows repeatedly if far over capacity (defensive)', () {
      final session = PhotoSession(id: 's3', capacity: 20);
      session.photos.addAll(List.generate(
        45,
        (i) => PhotoItem(id: 'p$i', originalPath: '/tmp/$i.jpg'),
      ));
      session.growCapacityIfNeeded();
      expect(session.capacity, 60);
    });
  });

  group('PhotoSession defaults', () {
    test('starts with default capacity, passport preset, original background', () {
      final session = PhotoSession(id: 's4');
      expect(session.capacity, AppConstants.defaultCapacity);
      expect(session.sizePreset, PhotoSizePreset.passport);
      expect(session.backgroundMode, BackgroundMode.original);
      expect(session.backgroundIntensity, 100);
      expect(session.jpegQuality, AppConstants.jpegQualityDefault);
      expect(session.autoCaptureEnabled, isTrue);
    });

    test('touch() updates updatedAt to a later or equal timestamp', () async {
      final session = PhotoSession(id: 's5');
      final before = session.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      session.touch();
      expect(session.updatedAt.isAfter(before), isTrue);
    });
  });
}
