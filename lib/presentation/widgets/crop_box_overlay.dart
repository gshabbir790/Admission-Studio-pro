import 'package:flutter/material.dart';

/// A draggable, resizable rectangle overlay for the photo editor's Crop
/// tool (spec request: editor only had brightness/contrast/sharpen, no
/// crop). Works purely in fractional (0..1) coordinates relative to
/// whatever box it's laid out in, so the caller just maps the resulting
/// [rect] onto the actual source image's pixel dimensions.
///
/// Kept dependency-free (no image_cropper/crop packages) — this is a plain
/// Stack of drag handles over the image, which is enough for a passport/ID
/// photo crop (rectangle in, rectangle out) without adding new native
/// platform code to the project.
class CropBoxOverlay extends StatefulWidget {
  const CropBoxOverlay({
    super.key,
    required this.initialRect,
    required this.onChanged,
  });

  /// Fractional rect (0..1 on both axes) — starting crop box.
  final Rect initialRect;
  final ValueChanged<Rect> onChanged;

  @override
  State<CropBoxOverlay> createState() => _CropBoxOverlayState();
}

class _CropBoxOverlayState extends State<CropBoxOverlay> {
  late Rect _rect = widget.initialRect;
  static const double _minSize = 0.12;

  Rect _clamp(Rect r) {
    double left = r.left.clamp(0.0, 1.0 - _minSize);
    double top = r.top.clamp(0.0, 1.0 - _minSize);
    double right = r.right.clamp(left + _minSize, 1.0);
    double bottom = r.bottom.clamp(top + _minSize, 1.0);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _update(Rect r) {
    setState(() => _rect = _clamp(r));
    widget.onChanged(_rect);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final boxPx = Rect.fromLTRB(
          _rect.left * size.width,
          _rect.top * size.height,
          _rect.right * size.width,
          _rect.bottom * size.height,
        );

        Offset deltaToFractional(Offset delta) =>
            Offset(delta.dx / size.width, delta.dy / size.height);

        return Stack(
          children: [
            // Dim everything outside the crop box.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MaskPainter(boxPx),
                ),
              ),
            ),
            // Move the whole box by dragging inside it.
            Positioned.fromRect(
              rect: boxPx,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  final f = deltaToFractional(d.delta);
                  final w = _rect.width;
                  final h = _rect.height;
                  var left = (_rect.left + f.dx).clamp(0.0, 1.0 - w);
                  var top = (_rect.top + f.dy).clamp(0.0, 1.0 - h);
                  _update(Rect.fromLTWH(left, top, w, h));
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ),
            _corner(
              alignment: Alignment.topLeft,
              boxPx: boxPx,
              onDrag: (d) => _update(Rect.fromLTRB(
                _rect.left + d.dx, _rect.top + d.dy, _rect.right, _rect.bottom,
              )),
            ),
            _corner(
              alignment: Alignment.topRight,
              boxPx: boxPx,
              onDrag: (d) => _update(Rect.fromLTRB(
                _rect.left, _rect.top + d.dy, _rect.right + d.dx, _rect.bottom,
              )),
            ),
            _corner(
              alignment: Alignment.bottomLeft,
              boxPx: boxPx,
              onDrag: (d) => _update(Rect.fromLTRB(
                _rect.left + d.dx, _rect.top, _rect.right, _rect.bottom + d.dy,
              )),
            ),
            _corner(
              alignment: Alignment.bottomRight,
              boxPx: boxPx,
              onDrag: (d) => _update(Rect.fromLTRB(
                _rect.left, _rect.top, _rect.right + d.dx, _rect.bottom + d.dy,
              )),
            ),
          ],
        );
      },
    );
  }

  Widget _corner({
    required Alignment alignment,
    required Rect boxPx,
    required void Function(Offset fractionalDelta) onDrag,
  }) {
    const handle = 26.0;
    final dx = alignment.x < 0 ? boxPx.left - handle / 2 : boxPx.right - handle / 2;
    final dy = alignment.y < 0 ? boxPx.top - handle / 2 : boxPx.bottom - handle / 2;
    return Positioned(
      left: dx,
      top: dy,
      width: handle,
      height: handle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          final ctx = context.findRenderObject() as RenderBox?;
          final size = ctx?.size ?? const Size(1, 1);
          onDrag(Offset(d.delta.dx / size.width, d.delta.dy / size.height));
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1F4B3F), width: 2),
          ),
        ),
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  _MaskPainter(this.hole);
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()..addRect(hole);
    final mask = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(mask, Paint()..color = Colors.black.withOpacity(0.55));
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) => oldDelegate.hole != hole;
}
