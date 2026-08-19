import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart'
    show InputImage;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/utils/image_file_utils.dart';
import '../../data/models/photo_item.dart';
import '../segmentation/segmentation_service.dart';
import 'caption_service.dart';
import 'processing_worker.dart';

/// Result of processing one photo, mirroring the HTML's `resizedMap[p.id]`
/// entry (`{printDataUrl, downloadDataUrl, downloadBlob, w, h}`) — kept
/// in-memory for the current session only (see `ExportController`), not
/// persisted, same lifetime as the HTML's in-memory map.
class ProcessedPhotoResult {
  const ProcessedPhotoResult({
    required this.printPath,
    required this.downloadPath,
    required this.width,
    required this.height,
  });

  /// 0.95-quality JPEG, used for the A4 print sheet (spec: `printDataUrl`).
  final String printPath;

  /// Quality-slider or size-limited JPEG, used for ZIP/single download.
  final String downloadPath;

  final int width;
  final int height;
}

/// Orchestrates the full per-photo export pipeline (spec §12–§21), exact
/// order-of-operations port of the HTML app's `processBtn` handler:
///   resize-to-cover-face → (adjust brightness/contrast/sharpen, see note
///   below) → background segmentation → name caption → compress.
///
/// Note vs. HTML: the HTML applied brightness/contrast/sharpen at *edit*
/// time (destructively, before this pipeline ever ran). Since Phase 3 made
/// editing non-destructive, those three parameters are applied here
/// instead, immediately after resize (order is visually equivalent — these
/// are per-pixel ops — and much cheaper at the small target resolution
/// than at the original capture resolution).
///
/// Runs on the calling isolate throughout: the segmentation step uses
/// platform channels and the caption step uses `dart:ui`, both of which
/// require the engine-owning isolate, so there's no benefit to splitting
/// the pure-`package:image` steps into a separate `compute()` isolate
/// without also paying for cross-isolate buffer transfer. Instead, exactly
/// like the HTML's `await new Promise(r=>setTimeout(r,0))` after each
/// photo, callers should `await Future<void>.delayed(Duration.zero)`
/// between photos (done in `ExportController`) so the UI can repaint
/// progress between items.
class ImageProcessingService {
  ImageProcessingService(this._segmentationService);

  final SegmentationService _segmentationService;

  Future<ProcessedPhotoResult> processPhoto(
    PhotoItem photo, {
    required int targetWidth,
    required int targetHeight,
    required BackgroundMode backgroundMode,
    required int backgroundIntensity,
    required int jpegQuality,
    int? sizeLimitBytes,
  }) async {
    final originalBytes = await File(photo.originalPath).readAsBytes();

    // The expensive decode/resize/adjust pipeline runs off the UI isolate.
    // This is the primary ANR fix: large camera JPEGs must never be decoded
    // and pixel-processed on the Android main isolate.
    final preparedBytes = await compute(
      prepareImageInIsolate,
      PrepareImageArgs(
        sourceBytes: originalBytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        brightnessPercent: (photo.brightness * 100).round(),
        contrastPercent: (photo.contrast * 100).round(),
        sharpenPercent: (photo.sharpen * 100).round(),
        faceCx: photo.face?.cx,
        faceCy: photo.face?.cy,
        faceHeightRatio: photo.face?.faceHeightRatio,
      ),
    );

    var working = img.decodeImage(preparedBytes);
    if (working == null) {
      throw StateError('Could not decode the prepared image.');
    }

    // ML Kit is a platform API and therefore remains on the engine isolate.
    // It only receives the already-downscaled target image, not the original
    // multi-megapixel camera frame.
    if (backgroundMode != BackgroundMode.original) {
      final tempPath = await ImageFileUtils.saveOriginalBytes(preparedBytes);
      try {
        final inputImage = InputImage.fromFilePath(tempPath);
        working = await _segmentationService.apply(
          working,
          mode: backgroundMode,
          intensity: backgroundIntensity,
          inputImage: inputImage,
        );
      } finally {
        await ImageFileUtils.deleteIfExists(tempPath);
      }
    }

    // The print sheet deliberately uses the clean, caption-free image.
    // Captioning is done only for the ZIP/download version.
    final captioned = photo.nameEnabled
        ? await CaptionService.withCaption(working, photo.name)
        : working;

    // JPEG encoding and binary-search compression are also CPU-heavy. Move
    // them to a worker isolate so a 20-photo batch does not freeze input.
    final cleanBytes = Uint8List.fromList(
      img.encodeJpg(working, quality: 100),
    );
    final captionedBytes = photo.nameEnabled
        ? Uint8List.fromList(img.encodeJpg(captioned, quality: 100))
        : cleanBytes;

    final encoded = await compute(
      encodeOutputsInIsolate,
      EncodeOutputsArgs(
        printImageBytes: cleanBytes,
        downloadImageBytes: captionedBytes,
        jpegQuality: jpegQuality,
        sizeLimitBytes: sizeLimitBytes,
      ),
    );

    final printPath = await _writeProcessed(photo.id, 'print', encoded.printBytes);
    final downloadPath =
        await _writeProcessed(photo.id, 'download', encoded.downloadBytes);

    return ProcessedPhotoResult(
      printPath: printPath,
      downloadPath: downloadPath,
      width: targetWidth,
      height: targetHeight,
    );

  }

  Future<String> _writeProcessed(String photoId, String kind, Uint8List bytes) async {
    final dir = await ImageFileUtils.processedDir();
    final path = p.join(dir.path, '${photoId}_$kind.jpg');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
