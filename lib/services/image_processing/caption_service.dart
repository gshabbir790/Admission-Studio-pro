import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

class CaptionService {
  const CaptionService._();

  static Future<img.Image> withCaption(img.Image source, String name) async {
    if (name.trim().isEmpty) return source;

    final w = source.width;
    final h = source.height;
    final fontSize = (h * 0.052).clamp(13.0, double.infinity);
    final barHeight = fontSize * 2.3;

    final overlayBytes = await _rasterizeOverlay(
      width: w,
      barHeight: barHeight,
      fontSize: fontSize,
      name: name,
    );
    if (overlayBytes == null) return source;

    return _compositeOverlay(source, overlayBytes, w, h);
  }

  static Future<Uint8List?> _rasterizeOverlay({
    required int width,
    required double barHeight,
    required double fontSize,
    required String name,
  }) async {
    final overlayHeight = barHeight.ceil().clamp(1, 512).toInt();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), overlayHeight.toDouble()),
    );

    final gradientPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, overlayHeight.toDouble()),
        [Colors.black.withOpacity(0), Colors.black.withOpacity(0.58)],
      );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), overlayHeight.toDouble()),
      gradientPaint,
    );

    final textSpan = TextSpan(
      text: name,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(0, 1)),
        ],
      ),
    );
    final painter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      maxLines: 1,
      ellipsis: '…',
    );
    painter.layout(maxWidth: width * 0.94);
    final dx = (width - painter.width) / 2;
    final dy = (overlayHeight - painter.height) / 2;
    painter.paint(canvas, Offset(dx, dy));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, overlayHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    picture.dispose();
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  static img.Image _compositeOverlay(
    img.Image source,
    Uint8List overlayRgba,
    int w,
    int h,
  ) {
    final out = img.Image.from(source);
    final barHeight = (overlayRgba.lengthInBytes ~/ 4) ~/ w;
    var i = 0;
    final startY = (h - barHeight).clamp(0, h).toInt();

    for (var y = startY; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final r = overlayRgba[i];
        final g = overlayRgba[i + 1];
        final b = overlayRgba[i + 2];
        final a = overlayRgba[i + 3] / 255.0;
        i += 4;
        if (a <= 0) continue;
        final dst = out.getPixel(x, y);
        dst
          ..r = (r * a + dst.r * (1 - a)).round()
          ..g = (g * a + dst.g * (1 - a)).round()
          ..b = (b * a + dst.b * (1 - a)).round();
      }
    }
    return out;
  }
}
