import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/utils/filename_utils.dart';
import '../../core/utils/image_file_utils.dart';
import '../../data/models/photo_item.dart';

class PrintSheetPage {
  const PrintSheetPage({required this.path, required this.pageNumber});
  final String path;
  final int pageNumber;
}

/// Print-sheet builder (spec §19–21), now with a selectable page size
/// (v2 fix — see [PrintPageSize]): 300 DPI raster, name printed *below*
/// each photo (never over it), auto-paginated, grid (cols/rows) computed
/// dynamically from the chosen page size and the target photo's pixel
/// dimensions instead of a fixed 4x5 — that fixed grid made no sense once
/// the page could be a small 4x6in sheet instead of A4.
///
/// v2 fix: reads `photo.printPath` directly (persisted on the model, see
/// `PhotoItem.markProcessed`) instead of an in-memory results map, and the
/// actual compositing work runs inside a `compute()` isolate — building a
/// full-resolution page by hand-drawing 6-20 photos onto one big canvas in
/// pure Dart was slow enough on the UI isolate to trigger Android's ANR
/// watchdog ("app isn't responding") on real devices.
class PrintSheetService {
  const PrintSheetService._();

  static Future<List<PrintSheetPage>> buildPages(
    List<PhotoItem> photos, {
    required PrintPageSize pageSize,
    required int targetWidth,
    required int targetHeight,
  }) async {
    final entries = <_PagePhotoArgs>[];
    var i = 0;
    for (final photo in photos) {
      i++;
      if (photo.printPath == null) continue;
      entries.add(_PagePhotoArgs(
        printPath: photo.printPath!,
        label: FilenameUtils.sanitize(photo.name, 'Student $i').replaceAll('_', ' '),
      ));
    }
    if (entries.isEmpty) return [];

    final exportsDir = await ImageFileUtils.exportsDir();

    final pageCount = await compute(
      _buildPagesIsolate,
      _BuildPagesArgs(
        entries: entries,
        outDir: exportsDir.path,
        pageWidthIn: pageSize.widthInches,
        pageHeightIn: pageSize.heightInches,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      ),
    );

    return List.generate(
      pageCount,
      (idx) => PrintSheetPage(
        path: p.join(exportsDir.path, 'print_sheet_page_${idx + 1}.jpg'),
        pageNumber: idx + 1,
      ),
    );
  }
}

class _PagePhotoArgs {
  const _PagePhotoArgs({required this.printPath, required this.label});
  final String printPath;
  final String label;
}

class _BuildPagesArgs {
  const _BuildPagesArgs({
    required this.entries,
    required this.outDir,
    required this.pageWidthIn,
    required this.pageHeightIn,
    required this.targetWidth,
    required this.targetHeight,
  });
  final List<_PagePhotoArgs> entries;
  final String outDir;
  final double pageWidthIn;
  final double pageHeightIn;
  final int targetWidth;
  final int targetHeight;
}

/// Runs on a background isolate via `compute()`. Returns the number of
/// pages written; filenames are deterministic (`print_sheet_page_N.jpg`)
/// so the caller doesn't need paths crossing the isolate boundary.
int _buildPagesIsolate(_BuildPagesArgs args) {
  const dpi = AppConstants.printDpi;
  final pageW = (args.pageWidthIn * dpi).round();
  final pageH = (args.pageHeightIn * dpi).round();
  final margin = (AppConstants.printMarginInches * dpi).round();
  final gutter = (AppConstants.printGutterInches * dpi).round();

  // Cell reserves ~54px under the photo for the name label.
  const labelHeight = 54;
  final cellW = args.targetWidth;
  final cellH = args.targetHeight + labelHeight;

  final usableW = pageW - margin * 2;
  final usableH = pageH - margin * 2;
  final cols = ((usableW + gutter) / (cellW + gutter)).floor().clamp(1, 999);
  final rows = ((usableH + gutter) / (cellH + gutter)).floor().clamp(1, 999);
  final perPage = cols * rows;

  final totalPages = (args.entries.length / perPage).ceil();

  for (var pg = 0; pg < totalPages; pg++) {
    final canvas = img.Image(width: pageW, height: pageH);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final pagePhotos = args.entries.skip(pg * perPage).take(perPage).toList();
    for (var i = 0; i < pagePhotos.length; i++) {
      final entry = pagePhotos[i];
      final col = i % cols;
      final row = i ~/ cols;
      final x = margin + col * (cellW + gutter);
      final y = margin + row * (cellH + gutter);

      final printBytes = File(entry.printPath).readAsBytesSync();
      final decoded = img.decodeImage(printBytes);
      if (decoded == null) continue;
      final fitted = img.copyResize(decoded, width: args.targetWidth, height: args.targetHeight);

      _strokeRect(canvas, x - 3, y - 3, args.targetWidth + 6, args.targetHeight + 6,
          img.ColorRgb8(216, 207, 184));
      img.compositeImage(canvas, fitted, dstX: x, dstY: y);
      _strokeRect(canvas, x, y, args.targetWidth, args.targetHeight,
          img.ColorRgb8(176, 141, 87), thickness: 2);

      _drawCenteredLabel(
        canvas,
        entry.label,
        x + args.targetWidth ~/ 2,
        y + args.targetHeight + 30,
        args.targetWidth,
      );
    }

    final pageBytes = Uint8List.fromList(img.encodeJpg(canvas, quality: 95));
    final path = p.join(args.outDir, 'print_sheet_page_${pg + 1}.jpg');
    File(path).writeAsBytesSync(pageBytes, flush: true);
  }

  return totalPages;
}

void _strokeRect(
  img.Image canvas,
  int x,
  int y,
  int w,
  int h,
  img.Color color, {
  int thickness = 1,
}) {
  for (var t = 0; t < thickness; t++) {
    img.drawRect(canvas, x1: x - t, y1: y - t, x2: x + w + t, y2: y + h + t, color: color);
  }
}

/// Centered-label rasterizer using `package:image`'s built-in bitmap font
/// — fine here since labels are sanitized (Latin-safe) filename-style text;
/// the caption printed *on* the photo itself (needs true Urdu shaping)
/// uses `CaptionService`/`TextPainter` instead, before this stage ever runs.
void _drawCenteredLabel(
  img.Image canvas,
  String text,
  int centerX,
  int baselineY,
  int maxWidth,
) {
  const avgGlyphWidth = 11;
  final estimatedWidth = (text.length * avgGlyphWidth).clamp(0, maxWidth);
  final startX = (centerX - estimatedWidth / 2).round().clamp(0, canvas.width - 1);

  img.drawString(
    canvas,
    text,
    font: img.arial24,
    x: startX,
    y: baselineY,
    color: img.ColorRgb8(27, 36, 31),
  );
}
