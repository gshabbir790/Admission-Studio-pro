import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';
import '../../data/models/face_info.dart';
import 'compression_service.dart';
import 'image_adjustments_service.dart';
import 'resize_service.dart';

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
    required this.printImageBytes,
    required this.downloadImageBytes,
    required this.jpegQuality,
    required this.sizeLimitBytes,
  });

  final Uint8List printImageBytes;
  final Uint8List downloadImageBytes;
  final int jpegQuality;
  final int? sizeLimitBytes;
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
  final printImage = img.decodeImage(args.printImageBytes);
  final downloadImage = img.decodeImage(args.downloadImageBytes);
  if (printImage == null || downloadImage == null) {
    throw StateError('Could not decode the processed image for export.');
  }

  final printBytes = Uint8List.fromList(
    img.encodeJpg(printImage, quality: 95),
  );

  final downloadBytes = (args.sizeLimitBytes != null && args.sizeLimitBytes! > 0)
      ? CompressionService.compressToSize(downloadImage, args.sizeLimitBytes!)
      : Uint8List.fromList(
          img.encodeJpg(downloadImage, quality: args.jpegQuality.clamp(
            AppConstants.jpegQualityMin,
            AppConstants.jpegQualityMax,
          ).toInt()),
        );

  return EncodedOutputs(
    printBytes: printBytes,
    downloadBytes: downloadBytes,
  );
}
