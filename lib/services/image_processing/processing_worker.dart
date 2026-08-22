import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';
import '../../data/models/face_info.dart';
import 'compression_service.dart';
import 'image_adjustments_service.dart';
import 'resize_service.dart';

// v2 speed fix (spec request: "processing bohat slow hai" — see also the
// class doc on `ImageProcessingService`): the pipeline used to encode the
// same working image to JPEG bytes twice (a "clean" copy and a byte-identical
// "captioned" copy, since captioning has been removed — see
// `ImageProcessingService`) and then decode *both* of those separately in
// [encodeOutputsInIsolate] before re-encoding each at its final quality —
// four extra JPEG codec passes per photo for no visual difference. Now there
// is exactly one shared source image decoded once here and reused for both
// the print and download encodes.

/// CPU-heavy, platform-independent image work.
///
/// This worker deliberately accepts/returns byte buffers and primitive values
/// so it can run in a Dart isolate without touching Flutter UI/platform APIs.
class PrepareImageArgs {
  const PrepareImageArgs({
    required this.sourceBytes,
    required this.targetWidth,
    required this.targetHeight,
    required this.brightnessPercent,
    required this.contrastPercent,
    required this.sharpenPercent,
    this.faceCx,
    this.faceCy,
    this.faceHeightRatio,
  });

  final Uint8List sourceBytes;
  final int targetWidth;
  final int targetHeight;
  final int brightnessPercent;
  final int contrastPercent;
  final int sharpenPercent;
  final double? faceCx;
  final double? faceCy;
  final double? faceHeightRatio;
}

Uint8List prepareImageInIsolate(PrepareImageArgs args) {
  final decoded = img.decodeImage(args.sourceBytes);
  if (decoded == null) {
    throw StateError('Could not decode the source image.');
  }

  var working = ResizeService.resizeToCoverFace(
    decoded,
    targetW: args.targetWidth,
    targetH: args.targetHeight,
    face: args.faceCx != null && args.faceCy != null && args.faceHeightRatio != null
        ? FaceInfo(
            cx: args.faceCx!,
            cy: args.faceCy!,
            faceHeightRatio: args.faceHeightRatio!,
          )
        : null,
  );

  working = ImageAdjustmentsService.apply(
    working,
    brightnessPercent: args.brightnessPercent,
    contrastPercent: args.contrastPercent,
    sharpenPercent: args.sharpenPercent,
  );

  return Uint8List.fromList(img.encodeJpg(working, quality: 92));
}

class EncodeOutputsArgs {
  const EncodeOutputsArgs({
    required this.sourceImageBytes,
    required this.jpegQuality,
    required this.sizeLimitBytes,
    this.downloadFormat = ImageOutputFormat.jpeg,
  });

  /// The single clean (caption-free) processed image, shared as the source
  /// for both the print copy and the download/ZIP copy.
  final Uint8List sourceImageBytes;
  final int jpegQuality;
  final int? sizeLimitBytes;

  /// v2: actual output format for the download/ZIP/Gallery copy. The print
  /// copy always stays JPEG internally (used only for print-sheet/PDF
  /// compositing, never exposed to the user as a standalone file).
  final ImageOutputFormat downloadFormat;
}

class EncodedOutputs {
  const EncodedOutputs({
    required this.printBytes,
    required this.downloadBytes,
  });

  final Uint8List printBytes;
  final Uint8List downloadBytes;
}

EncodedOutputs encodeOutputsInIsolate(EncodeOutputsArgs args) {
  final source = img.decodeImage(args.sourceImageBytes);
  if (source == null) {
    throw StateError('Could not decode the processed image for export.');
  }

  final printBytes = Uint8List.fromList(
    img.encodeJpg(source, quality: 95),
  );

  final Uint8List downloadBytes;
  if (args.downloadFormat == ImageOutputFormat.png) {
    // PNG is lossless — there's no quality knob to binary-search against a
    // size limit, so we just use maximum (level 9) compression. The
    // "Limit file size" control is disabled in the UI for PNG output (see
    // ExportSettingsSheet) so this branch is a defensive fallback, not the
    // primary path.
    downloadBytes = Uint8List.fromList(img.encodePng(source, level: 9));
  } else if (args.sizeLimitBytes != null && args.sizeLimitBytes! > 0) {
    downloadBytes = CompressionService.compressToSize(source, args.sizeLimitBytes!);
  } else {
    downloadBytes = Uint8List.fromList(
      img.encodeJpg(
        source,
        quality: args.jpegQuality
            .clamp(AppConstants.jpegQualityMin, AppConstants.jpegQualityMax)
            .toInt(),
      ),
    );
  }

  return EncodedOutputs(
    printBytes: printBytes,
    downloadBytes: downloadBytes,
  );
}
