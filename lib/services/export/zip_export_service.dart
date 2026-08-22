import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/filename_utils.dart';
import '../../core/utils/image_file_utils.dart';
import '../../data/models/photo_item.dart';

/// Exact port of the HTML app's `downloadZip()` (spec §18): sanitized,
/// collision-safe filenames, all-offline archive generation.
///
/// v2 fix: reads `photo.processedPath` directly (persisted on the model)
/// instead of an in-memory results map, so a batch that was already
/// processed doesn't need reprocessing just because the app restarted —
/// and runs inside a `compute()` isolate (see [_buildZipIsolate]) because
/// zipping ~20 already-large JPEGs on the UI isolate was slow enough to
/// trip Android's ANR watchdog ("app isn't responding").
class ZipExportService {
  const ZipExportService._();

  /// v2: [extension] follows `PhotoSession.outputFormat` ('jpg' or 'png') so
  /// the ZIP entries' filenames match the *actual* encoded bytes on disk
  /// (`ImageProcessingService` now writes `..._download.png` when PNG output
  /// is selected) instead of always assuming `.jpg`.
  static Future<String> buildZip(
    List<PhotoItem> photos, {
    String extension = 'jpg',
  }) async {
    final entries = <_ZipEntryArgs>[];
    var i = 0;
    for (final photo in photos) {
      i++;
      if (photo.processedPath == null) continue;
      entries.add(_ZipEntryArgs(
        sourcePath: photo.processedPath!,
        baseName: FilenameUtils.sanitize(photo.name, 'Student_$i'),
      ));
    }

    final exportsDir = await ImageFileUtils.exportsDir();
    final outPath = p.join(exportsDir.path, 'admission_photos.zip');

    return compute(_buildZipIsolate, _BuildZipArgs(entries, outPath, extension));
  }
}

class _ZipEntryArgs {
  const _ZipEntryArgs({required this.sourcePath, required this.baseName});
  final String sourcePath;
  final String baseName;
}

class _BuildZipArgs {
  const _BuildZipArgs(this.entries, this.outPath, this.extension);
  final List<_ZipEntryArgs> entries;
  final String outPath;
  final String extension;
}

/// Runs on a background isolate via `compute()`. Only primitives/simple
/// value objects cross the isolate boundary — all file I/O happens inside
/// this function, on the worker isolate, not the caller.
Future<String> _buildZipIsolate(_BuildZipArgs args) async {
  final usedNames = <String>{};
  final encoder = ZipFileEncoder();

  // Stream files directly from disk into the ZIP instead of constructing one
  // giant in-memory Archive. This keeps peak RAM bounded for large batches.
  encoder.create(args.outPath);
  try {
    for (final entry in args.entries) {
      final filename = FilenameUtils.uniqueName(
        entry.baseName,
        usedNames,
        extension: args.extension,
      );
      await encoder.addFile(File(entry.sourcePath), filename);
    }
    await encoder.close();
  } catch (_) {
    try {
      await encoder.close();
    } catch (_) {
      // Preserve the original failure.
    }
    rethrow;
  }

  return args.outPath;
}
