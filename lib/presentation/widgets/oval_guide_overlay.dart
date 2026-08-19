import 'package:flutter/material.dart';

/// Static portrait-framing guide (spec §5): darkened area outside the oval,
/// gold border. No live position/readiness feedback anymore (v2 removed
/// face detection — see `CaptureFlowController`'s class doc) — this is now
/// purely a compositional aid, same visual footprint as before.
class OvalGuideOverlay extends StatelessWidget {
  const OvalGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _OvalMaskPainter(),
      size: Size.infinite,
    );
  }
}

class _OvalMaskPainter extends CustomPainter {
  const _OvalMaskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.44),
      width: size.width * 0.6,
      height: size.height * 0.76,
    );

    final maskPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addOval(ovalRect),
    );
    canvas.drawPath(maskPath, Paint()..color = Colors.black.withOpacity(0.35));

    canvas.drawOval(
      ovalRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFD9C8A1),
    );
  }

  @override
  bool shouldRepaint(covariant _OvalMaskPainter oldDelegate) => false;
}
