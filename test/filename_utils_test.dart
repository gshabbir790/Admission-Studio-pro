import 'package:flutter_test/flutter_test.dart';
import 'package:admission_studio_pro/core/utils/filename_utils.dart';

void main() {
  group('FilenameUtils.sanitize', () {
    test('strips filesystem-invalid characters', () {
      expect(FilenameUtils.sanitize('Ali/Khan:Test*?"<>|', 'fallback'),
          'AliKhanTest');
    });

    test('collapses whitespace to underscores', () {
      expect(FilenameUtils.sanitize('Ali   Khan  Malik', 'fallback'),
          'Ali_Khan_Malik');
    });

    test('falls back when name is blank', () {
      expect(FilenameUtils.sanitize('', 'Student_1'), 'Student_1');
      expect(FilenameUtils.sanitize('   ', 'Student_2'), 'Student_2');
      expect(FilenameUtils.sanitize(null, 'Student_3'), 'Student_3');
    });

    test('caps length at 60 characters', () {
      final longName = 'A' * 100;
      expect(FilenameUtils.sanitize(longName, 'fallback').length, 60);
    });

    test('preserves Urdu/Unicode characters (only ASCII path chars stripped)', () {
      expect(FilenameUtils.sanitize('احمد علی', 'fallback'), 'احمد_علی');
    });
  });

  group('FilenameUtils.uniqueJpgName', () {
    test('first use of a base name has no suffix', () {
      final used = <String>{};
      expect(FilenameUtils.uniqueJpgName('Ali', used), 'Ali.jpg');
    });

    test('collisions get _2, _3, ... suffixes', () {
      final used = <String>{};
      expect(FilenameUtils.uniqueJpgName('Ali', used), 'Ali.jpg');
      expect(FilenameUtils.uniqueJpgName('Ali', used), 'Ali_2.jpg');
      expect(FilenameUtils.uniqueJpgName('Ali', used), 'Ali_3.jpg');
    });

    test('different base names do not collide with each other', () {
      final used = <String>{};
      expect(FilenameUtils.uniqueJpgName('Ali', used), 'Ali.jpg');
      expect(FilenameUtils.uniqueJpgName('Ahmed', used), 'Ahmed.jpg');
    });
  });
}
