import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists images to app-private storage so [PhotoItem.originalPath] always
/// points at a real file rather than an in-memory data URL (HTML kept
/// everything as base64 `dataUrl` strings; Flutter must be file-backed to
/// avoid holding many full-resolution images in RAM — see spec §25).
class ImageFileUtils {
  ImageFileUtils._();

  static const _uuid = Uuid();

  /// Root directory for originals, kept separate from thumbnails/processed
  /// output so cache clearing can target one subtree without touching others.
  static Future<Directory> _originalsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'originals'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> thumbnailsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'thumbnails'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> processedDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'processed'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> exportsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies an existing file (e.g. from `camera` package's `takePicture()`
  /// or `image_picker`'s `XFile`) into the app's originals directory under a
  /// fresh uuid name, and returns the new path.
  static Future<String> saveOriginalFromPath(String sourcePath) async {
    final dir = await _originalsDir();
    final ext = p.extension(sourcePath).isNotEmpty
        ? p.extension(sourcePath)
        : '.jpg';
    final dest = File(p.join(dir.path, '${_uuid.v4()}$ext'));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  static Future<String> saveOriginalBytes(Uint8List bytes,
      {String ext = '.jpg'}) async {
    final dir = await _originalsDir();
    final dest = File(p.join(dir.path, '${_uuid.v4()}$ext'));
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  }

  static Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
