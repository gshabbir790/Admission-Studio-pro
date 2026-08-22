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

  /// 0.95-quality JPEG, used for the print sheet / PDF (spec: `printDataUrl`).
  final String printPath;

  /// Quality-slider or size-limited output, used for ZIP/single download.
  /// File format follows `PhotoSession.outputFormat` (JPEG or PNG, v2).
  final String downloadPath;

  final int width;
  final int height;
}

/// Orchestrates the full per-photo export pipeline (spec §12–§21), exact
/// order-of-operations port of the HTML app's `processBtn` handler:
///   resize-to-cover-face → (adjust brightness/contrast/sharpen) →
///   background segmentation → compress/encode.
///
/// v2 fix (spec request: "naam tasveer ke upar watermark ki tarah print ho
/// raha hai, sirf file ka naam badalna chahiye"): the pipeline used to burn
/// the student's name onto the *image pixels* of the download/ZIP copy via
/// `CaptionService` — that is a watermark, not a filename, and the person
/// explicitly does not want it. Naming a photo now only ever affects the
/// *filename* used at export time (`FilenameUtils`, `ZipExportService`) and
/// the label already printed cleanly *below* each photo on the print
/// sheet/PDF (`PrintSheetService`) — the photo's own pixels are never
/// captioned. `CaptionService` is no longer called from this pipeline.
///
/// v2 speed fix: removing captioning also collapses what used to be two
/// near-identical "clean" and "captioned" JPEG re-encodes into one, and the
/// final print/download encode now shares a single decoded source image
/// (see `processing_worker.dart` doc) instead of decoding two copies of the
/// same bytes — noticeably fewer JPEG codec passes per photo across a batch.
///
/// Runs on the calling isolate throughout except for the two CPU-heavy
/// `compute()` stages: the segmentation step uses platform channels and
/// therefore must stay on the engine-owning isolate. Exactly like the HTML's
/// `await new Promise(r=>setTimeout(r,0))` after each photo, callers should
/// `await Future<void>.delayed(Duration.zero)` between photos (done in
/// `ExportController`) so the UI can repaint progress between items.
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
    required ImageOutputFormat outputFormat,
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
    // multi-megapixel camera frame. `isAvailable` is false once the
    // segmenter has hit too many consecutive failures in this batch (see
    // SegmentationService doc) — in that case we deliberately skip straight
    // to the original image instead of trying (and likely failing) again.
    if (backgroundMode != BackgroundMode.original && _segmentationService.isAvailable) {
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

    // Single clean, caption-free encode shared by both the print and
    // download outputs (see class + processing_worker docs for why this
    // used to be two separate encodes).
    final sourceBytes = Uint8List.fromList(img.encodeJpg(working, quality: 100));

    // JPEG/PNG encoding and binary-search compression are also CPU-heavy.
    // Move them to a worker isolate so a large batch does not freeze input.
    final encoded = await compute(
      encodeOutputsInIsolate,
      EncodeOutputsArgs(
        sourceImageBytes: sourceBytes,
        jpegQuality: jpegQuality,
        sizeLimitBytes: sizeLimitBytes,
        downloadFormat: outputFormat,
      ),
    );

    final printPath = await _writeProcessed(photo.id, 'print', encoded.printBytes, 'jpg');
    final downloadPath = await _writeProcessed(
      photo.id,
      'download',
      encoded.downloadBytes,
      outputFormat.extension,
    );

    return ProcessedPhotoResult(
      printPath: printPath,
      downloadPath: downloadPath,
      width: targetWidth,
      height: targetHeight,
    );
  }

  Future<String> _writeProcessed(
    String photoId,
    String kind,
    Uint8List bytes,
    String extension,
  ) async {
    final dir = await ImageFileUtils.processedDir();
    final path = p.join(dir.path, '${photoId}_$kind.$extension');
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }
}
