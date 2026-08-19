import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';
import '../../core/utils/image_file_utils.dart';
import '../../services/image_processing/image_adjustments_service.dart';
import '../providers/session_provider.dart';
import '../widgets/crop_box_overlay.dart';

/// Brightness/Contrast/Sharpen editor (spec §11). Design note vs. the
/// source HTML: the HTML baked each edit directly into the stored
/// `dataUrl`, destructively, so reopening the editor always started from
/// neutral (100/100/0) sliders over the already-edited image. This Flutter
/// version keeps [PhotoItem.originalPath] untouched and stores
/// brightness/contrast/sharpen as parameters on the item instead (applied
/// later by the export pipeline's `ImageProcessingService`, Phase 5) —
/// same user-visible result (what you see in the grid/export reflects your
/// edits), but non-destructive: reopening the editor prefills the sliders
/// with the photo's *current* params rather than resetting to neutral, and
/// original quality is never re-compressed by repeated edits.
///
/// Live preview only ever processes a ≤480px-wide copy while dragging
/// (spec §11: "Do not run expensive full-resolution processing on every
/// slider movement"); full-resolution processing happens once, later, in
/// the export pipeline — not on Apply here, since nothing needs baking yet.
class PhotoEditorScreen extends ConsumerStatefulWidget {
  const PhotoEditorScreen({super.key, required this.photoId});

  final String photoId;

  @override
  ConsumerState<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends ConsumerState<PhotoEditorScreen> {
  static const _previewMaxDim = 480;

  img.Image? _sourceImage;
  Uint8List? _previewBytes;
  bool _loading = true;

  late int _brightness; // 50..150
  late int _contrast; // 50..150
  late int _sharpen; // 0..100

  // v2 addition: crop tool (spec request — editor only had brightness /
  // contrast / sharpen before, no way to crop). Fractional (0..1) rect
  // relative to the source image; applying it re-encodes a cropped copy and
  // swaps it in as the photo's new original via `replaceOriginalImage`.
  bool _cropMode = false;
  Rect _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
  bool _cropping = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    final photo = ref
        .read(sessionProvider)
        .photos
        .firstWhere((p) => p.id == widget.photoId);
    _brightness = (photo.brightness * 100).round();
    _contrast = (photo.contrast * 100).round();
    _sharpen = (photo.sharpen * 100).round();
    _loadSource(photo.originalPath);
  }

  Future<void> _loadSource(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (!mounted) return;
    setState(() {
      _sourceImage = decoded;
      _loading = false;
    });
    _updatePreview();
  }

  void _scheduleUpdatePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _updatePreview);
  }

  void _updatePreview() {
    final src = _sourceImage;
    if (src == null) return;
    final preview = ImageAdjustmentsService.renderPreview(
      src,
      brightnessPercent: _brightness,
      contrastPercent: _contrast,
      sharpenPercent: _sharpen,
      maxDim: _previewMaxDim,
    );
    final encoded = Uint8List.fromList(img.encodeJpg(preview, quality: 88));
    if (!mounted) return;
    setState(() => _previewBytes = encoded);
  }

  void _reset() {
    setState(() {
      _brightness = 100;
      _contrast = 100;
      _sharpen = 0;
    });
    _updatePreview();
  }

  Future<void> _applyCrop() async {
    final src = _sourceImage;
    if (src == null || _cropping) return;
    // No-op if the crop box is still the full image.
    if (_cropRect.left <= 0.001 &&
        _cropRect.top <= 0.001 &&
        _cropRect.right >= 0.999 &&
        _cropRect.bottom >= 0.999) {
      setState(() => _cropMode = false);
      return;
    }
    setState(() => _cropping = true);
    try {
      final x = (_cropRect.left * src.width).round().clamp(0, src.width - 1);
      final y = (_cropRect.top * src.height).round().clamp(0, src.height - 1);
      final w = (_cropRect.width * src.width).round().clamp(1, src.width - x);
      final h = (_cropRect.height * src.height).round().clamp(1, src.height - y);

      final cropped = img.copyCrop(src, x: x, y: y, width: w, height: h);
      final bytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
      final newPath = await ImageFileUtils.saveOriginalBytes(bytes);

      await ref
          .read(sessionProvider.notifier)
          .replaceOriginalImage(widget.photoId, newPath);

      if (!mounted) return;
      setState(() {
        _sourceImage = cropped;
        _cropMode = false;
        _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
      });
      _updatePreview();
    } finally {
      if (mounted) setState(() => _cropping = false);
    }
  }

  Future<void> _apply() async {
    await ref.read(sessionProvider.notifier).updateEditParams(
          widget.photoId,
          brightness: _brightness / 100.0,
          contrast: _contrast / 100.0,
          sharpen: _sharpen / 100.0,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Photo'),
        actions: [
          if (!_cropMode)
            IconButton(
              icon: const Icon(Icons.crop_rounded),
              tooltip: 'Crop',
              onPressed: _loading ? null : () => setState(() => _cropMode = true),
            ),
          TextButton(onPressed: _reset, child: const Text('Reset')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _previewBytes == null
                          ? const CircularProgressIndicator()
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.passthrough,
                                children: [
                                  Image.memory(_previewBytes!, fit: BoxFit.contain),
                                  if (_cropMode)
                                    Positioned.fill(
                                      child: CropBoxOverlay(
                                        initialRect: _cropRect,
                                        onChanged: (r) => _cropRect = r,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  if (_cropMode) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cropping
                                ? null
                                : () => setState(() {
                                      _cropMode = false;
                                      _cropRect = const Rect.fromLTWH(0, 0, 1, 1);
                                    }),
                            child: const Text('Cancel Crop'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _cropping ? null : _applyCrop,
                            child: _cropping
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Apply Crop'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ] else ...[
                  _EditSlider(
                    label: 'Brightness',
                    value: _brightness,
                    min: AppConstants.brightnessMin * 100,
                    max: AppConstants.brightnessMax * 100,
                    onChanged: (v) {
                      setState(() => _brightness = v);
                      _scheduleUpdatePreview();
                    },
                  ),
                  _EditSlider(
                    label: 'Contrast',
                    value: _contrast,
                    min: AppConstants.contrastMin * 100,
                    max: AppConstants.contrastMax * 100,
                    onChanged: (v) {
                      setState(() => _contrast = v);
                      _scheduleUpdatePreview();
                    },
                  ),
                  _EditSlider(
                    label: 'Sharpen',
                    value: _sharpen,
                    min: AppConstants.sharpenMin * 100,
                    max: AppConstants.sharpenMax * 100,
                    onChanged: (v) {
                      setState(() => _sharpen = v);
                      _scheduleUpdatePreview();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _apply,
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _EditSlider extends StatelessWidget {
  const _EditSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final double min;
  final double max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text('$value%', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
