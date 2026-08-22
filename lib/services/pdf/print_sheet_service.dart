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
/// each photo (never over it), auto-paginated.
///
/// v3 fix (spec request: "4x6 sheet par 3x3 tasveerein fit aani chahiyen,
/// A4 par 4x5, chahe output size koi bhi ho"): the grid is now a *fixed*
/// layout per page size — always exactly 3 columns × 3 rows (9 photos) on a
/// 4×6in sheet, and always exactly 4 columns × 5 rows (20 photos) on A4 —
/// regardless of which photo size preset (Passport/Stamp/Square/Visa/…) is
/// selected in Export Settings. Each photo is fitted (aspect-preserving,
/// never distorted or stretched) into its fixed cell instead of the cell
/// growing/shrinking to match the photo's own pixel dimensions, which is
/// what the previous dynamic-grid version did.
///
/// v2 fix: reads `photo.printPath` directly (persisted on the model, see
/// `PhotoItem.markProcessed`) instead of an in-memory results map, and the
/// actual compositing work runs inside a `compute()` isolate — building a
/// full-resolution page by hand-drawing many photos onto one big canvas in
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

  // v3 fix: fixed grid per page size (see class doc) instead of a grid
  // derived from the selected photo's pixel dimensions.
  final int cols;
  final int rows;
  if (args.pageWidthIn <= AppConstants.photo4x6WidthInches + 0.01 &&
      args.pageHeightIn <= AppConstants.photo4x6HeightInches + 0.01) {
    cols = 3;
    rows = 3;
  } else {
    cols = 4;
    rows = 5;
  }
  final perPage = cols * rows;

  // Cell reserves space under the photo for the name label.
  const labelHeight = 54;
  final usableW = pageW - margin * 2;
  final usableH = pageH - margin * 2;

  // The photo area within each cell, sized to fill the fixed grid exactly
  // (minus gutters/label), then the actual photo is fitted into that area
  // preserving its own aspect ratio (never stretched/distorted).
  final cellOuterW = (usableW - gutter * (cols - 1)) / cols;
  final cellOuterH = (usableH - gutter * (rows - 1)) / rows;
  final photoAreaW = cellOuterW.floor();
  final photoAreaH = (cellOuterH - labelHeight).floor().clamp(1, cellOuterH.floor());

  final targetAspect = args.targetWidth / args.targetHeight;
  var drawW = photoAreaW;
  var drawH = (drawW / targetAspect).round();
  if (drawH > photoAreaH) {
    drawH = photoAreaH;
    drawW = (drawH * targetAspect).round();
  }

  final totalPages = (args.entries.length / perPage).ceil();

  for (var pg = 0; pg < totalPages; pg++) {
    final canvas = img.Image(width: pageW, height: pageH);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));

    final pagePhotos = args.entries.skip(pg * perPage).take(perPage).toList();
    for (var i = 0; i < pagePhotos.length; i++) {
      final entry = pagePhotos[i];
      final col = i % cols;
      final row = i ~/ cols;
      final cellX = margin + col * (cellOuterW + gutter);
      final cellY = margin + row * (cellOuterH + gutter);
      // Center the (aspect-preserving) drawn photo within its fixed cell.
      final x = (cellX + (photoAreaW - drawW) / 2).round();
      final y = (cellY + (photoAreaH - drawH) / 2).round();

      final printBytes = File(entry.printPath).readAsBytesSync();
      final decoded = img.decodeImage(printBytes);
      if (decoded == null) continue;
      final fitted = img.copyResize(decoded, width: drawW, height: drawH);

      _strokeRect(canvas, x - 3, y - 3, drawW + 6, drawH + 6, img.ColorRgb8(216, 207, 184));
      img.compositeImage(canvas, fitted, dstX: x, dstY: y);
      _strokeRect(canvas, x, y, drawW, drawH, img.ColorRgb8(176, 141, 87), thickness: 2);

      _drawCenteredLabel(
        canvas,
        entry.label,
        (cellX + photoAreaW / 2).round(),
        y + drawH + 30,
        photoAreaW,
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
