import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// v2 addition (spec request: "camera ya gallery se jo bhi tasveer select
/// karein uska asal size aur dimension likha hona chahiye"): a small pill
/// that reads a photo's real pixel width × height and file size straight off
/// disk and displays it — used on the capture-confirm and naming screens so
/// the person can see exactly what they're about to add, not just a preview
/// thumbnail.
class ImageDimensionsBadge extends StatefulWidget {
  const ImageDimensionsBadge({super.key, required this.path, this.dark = true});

  final String path;
  final bool dark;

  @override
  State<ImageDimensionsBadge> createState() => _ImageDimensionsBadgeState();
}

class _ImageDimensionsBadgeState extends State<ImageDimensionsBadge> {
  String? _label;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ImageDimensionsBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _label = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final file = File(widget.path);
      final bytes = await file.readAsBytes();
      // decodeImage only needs to read headers for size in most formats, but
      // package:image doesn't expose a header-only fast path, so this does a
      // full decode — acceptable here since it only ever runs once per
      // single confirmed/named photo, not per-photo in a batch loop.
      final decoded = compute(_decodeSize, bytes);
      final size = await decoded;
      final kb = bytes.lengthInBytes / 1024;
      final sizeLabel = kb >= 1024 ? '${(kb / 1024).toStringAsFixed(2)} MB' : '${kb.round()} KB';
      if (!mounted) return;
      setState(() {
        _label = size == null ? null : '${size.$1} × ${size.$2} px  •  $sizeLabel';
        _failed = size == null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static (int, int)? _decodeSize(List<int> bytes) {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return null;
    return (decoded.width, decoded.height);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final fg = widget.dark ? Colors.white : Colors.black87;
    final bg = widget.dark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.06);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: _label == null
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Container(
              key: ValueKey(_label),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten_rounded, size: 13, color: fg),
                  const SizedBox(width: 5),
                  Text(
                    _label!,
                    style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
    );
  }
}
