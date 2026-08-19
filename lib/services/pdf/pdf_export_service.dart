import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants/app_constants.dart';
import '../../core/utils/image_file_utils.dart';
import 'print_sheet_service.dart';

/// Multi-page PDF export (spec §21–22): one page per print-sheet page, at
/// the exact physical page size that was used to build the sheet (v2 fix —
/// previously hard-coded to A4 even when the sheet itself was a 4x6in photo-
/// lab page, so "Actual Size / 100%" printing would have been wrong).
///
/// Runs inside a `compute()` isolate — the `pdf` package's page composition
/// is pure Dart and CPU-bound; on the UI isolate this was slow enough with
/// several full-resolution page images to trip Android's ANR watchdog.
class PdfExportService {
  const PdfExportService._();

  static Future<String> buildPdf(
    List<PrintSheetPage> pages, {
    required PrintPageSize pageSize,
  }) async {
    final dir = await ImageFileUtils.exportsDir();
    final outPath = p.join(dir.path, 'admission_photos.pdf');

    return compute(
      _buildPdfIsolate,
      _BuildPdfArgs(
        pagePaths: pages.map((e) => e.path).toList(),
        outPath: outPath,
        widthPts: pageSize.widthInches * PdfPageFormat.inch,
        heightPts: pageSize.heightInches * PdfPageFormat.inch,
      ),
    );
  }
}

class _BuildPdfArgs {
  const _BuildPdfArgs({
    required this.pagePaths,
    required this.outPath,
    required this.widthPts,
    required this.heightPts,
  });
  final List<String> pagePaths;
  final String outPath;
  final double widthPts;
  final double heightPts;
}

Future<String> _buildPdfIsolate(_BuildPdfArgs args) async {
  final doc = pw.Document();
  final pageFormat = PdfPageFormat(args.widthPts, args.heightPts, marginAll: 0);

  for (final path in args.pagePaths) {
    final bytes = File(path).readAsBytesSync();
    final image = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.FullPage(ignoreMargins: true, child: pw.Image(image)),
      ),
    );
  }

  final bytes = await doc.save();
  File(args.outPath).writeAsBytesSync(bytes, flush: true);
  return args.outPath;
}