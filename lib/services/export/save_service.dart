import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

/// v2 addition: exports were only ever written to the app's private sandbox
/// directory, so a ZIP/PDF/JPG export never showed up in Gallery or Files —
/// this service actually puts a copy somewhere the user can find it.
///
/// - [saveFileToFolder]: any file type (ZIP, PDF, JPG) via Android's Storage
///   Access Framework document picker (`file_picker`'s `saveFile`, which
///   writes the bytes itself — no separate storage permission needed on
///   modern Android since the user is explicitly granting a SAF write).
/// - [saveImageToGallery]: images only, into Photos/Gallery via `gal`
///   (uses `READ_MEDIA_IMAGES`/`ADD_MEDIA` under the hood, prompts if needed).
class SaveService {
  const SaveService._();

  static Future<String?> saveFileToFolder(
    String sourcePath, {
    required String suggestedName,
  }) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save $suggestedName',
        fileName: suggestedName,
        bytes: bytes,
      );
      return result;
    } catch (e, st) {
      debugPrint('SaveService.saveFileToFolder failed: $e\n$st');
      return null;
    }
  }

  static Future<bool> saveImageToGallery(String sourcePath) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) return false;
      }
      await Gal.putImage(sourcePath, album: 'Admission Studio Pro');
      return true;
    } catch (e, st) {
      debugPrint('SaveService.saveImageToGallery failed: $e\n$st');
      return false;
    }
  }
}
