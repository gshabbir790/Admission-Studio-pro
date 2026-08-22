import 'dart:io';
import '../../data/models/processing_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/filename_utils.dart';
import '../../data/models/photo_item.dart';
import '../../services/export/save_service.dart';
import '../../services/export/zip_export_service.dart';
import '../../services/pdf/pdf_export_service.dart';
import '../../services/pdf/print_sheet_service.dart';
import '../../services/segmentation/segmentation_service.dart';
import '../providers/service_providers.dart';
import '../providers/session_provider.dart';

class ExportProgress {
  const ExportProgress({this.done = 0, this.total = 0, this.failed = 0});
  final int done;
  final int total;
  final int failed;

  int get percent => total > 0 ? ((done / total) * 100).round() : 0;
}

class ExportState {
  const ExportState({
    this.progress = const ExportProgress(),
    this.isProcessing = false,
    this.hasResults = false,
    this.zipPath,
    this.pdfPath,
    this.printPages = const [],
  });

  final ExportProgress progress;
  final bool isProcessing;
  final bool hasResults;
  final String? zipPath;
  final String? pdfPath;
  final List<PrintSheetPage> printPages;

  ExportState copyWith({
    ExportProgress? progress,
    bool? isProcessing,
    bool? hasResults,
    String? zipPath,
    String? pdfPath,
    List<PrintSheetPage>? printPages,
  }) {
    return ExportState(
      progress: progress ?? this.progress,
      isProcessing: isProcessing ?? this.isProcessing,
      hasResults: hasResults ?? this.hasResults,
      zipPath: zipPath ?? this.zipPath,
      pdfPath: pdfPath ?? this.pdfPath,
      printPages: printPages ?? this.printPages,
    );
  }
}

/// Orchestrates the whole export flow (spec §26, §18–§22), exact behavioral
/// port of the HTML's `processBtn` → `downloadZip`/`openSheetPreview` → PDF
/// chain.
///
/// v2 fix: processed results are now read from/written to `PhotoItem`
/// itself (`processedPath`/`printPath`/`processingStatus`, persisted via
/// Hive) instead of an in-memory map. [processAll] skips any photo that's
/// already `processed` with both output files still present on disk — so
/// pressing back (or the app restarting) after a batch finishes no longer
/// forces a full reprocess; only photos that are `pending` (new, retaken,
/// or edited/renamed since — `invalidateProcessedCache()` resets them to
/// `pending`) actually get (re)processed.
class ExportController extends StateNotifier<ExportState> {
  ExportController(this._ref) : super(const ExportState());

  final Ref _ref;

  Future<void> processAll() async {
    if (state.isProcessing) return;
    final session = _ref.read(sessionProvider);
    if (session.photos.isEmpty) return;

    final service = _ref.read(imageProcessingServiceProvider);
    final sessionNotifier = _ref.read(sessionProvider.notifier);
    final total = session.photos.length;
    var done = 0;
    var failed = 0;

    // v2 fix: clear any "segmentation disabled after repeated failures"
    // state left over from a previous run before starting a fresh batch —
    // see SegmentationService doc.
    _ref.read(segmentationServiceProvider).resetBatchHealth();

    state = state.copyWith(
      isProcessing: true,
      hasResults: false,
      progress: ExportProgress(done: 0, total: total),
    );

    final sizeLimitBytes = session.sizeLimitEnabled && session.sizeLimitValue > 0
        ? (session.sizeLimitValue *
                (session.sizeLimitUnit == FileSizeUnit.mb ? 1024 * 1024 : 1024))
            .round()
        : null;

    for (final photo in session.photos) {
      final alreadyDone = photo.processingStatus == ProcessingStatus.processed &&
          photo.processedPath != null &&
          photo.printPath != null &&
          File(photo.processedPath!).existsSync() &&
          File(photo.printPath!).existsSync();

      if (!alreadyDone) {
        try {
          final result = await service.processPhoto(
            photo,
            targetWidth: session.targetWidth,
            targetHeight: session.targetHeight,
            backgroundMode: session.backgroundMode,
            backgroundIntensity: session.backgroundIntensity,
            jpegQuality: session.jpegQuality,
            outputFormat: session.outputFormat,
            sizeLimitBytes: sizeLimitBytes,
          );
          sessionNotifier.markPhotoProcessed(
            photo.id,
            processedPath: result.downloadPath,
            printPath: result.printPath,
          );
        } catch (e, st) {
          debugPrint('ExportController.processAll failed for ${photo.id}: $e\n$st');
          failed++;
        }
      }

      done++;
      state = state.copyWith(progress: ExportProgress(done: done, total: total, failed: failed));
      // Same cooperative yield as the HTML's `await new Promise(r=>setTimeout(r,0))`.
      await Future<void>.delayed(Duration.zero);
    }

    final processedCount =
        _ref.read(sessionProvider).photos.where((p) => p.processedPath != null).length;
    state = state.copyWith(isProcessing: false, hasResults: processedCount > 0);
  }

  Future<String> exportZip() async {
    final session = _ref.read(sessionProvider);
    final path = await ZipExportService.buildZip(
      session.photos,
      extension: session.outputFormat.extension,
    );
    state = state.copyWith(zipPath: path);
    return path;
  }

  Future<List<PrintSheetPage>> buildPrintSheetPages() async {
    final session = _ref.read(sessionProvider);
    final pages = await PrintSheetService.buildPages(
      session.photos,
      pageSize: session.printPageSize,
      targetWidth: session.targetWidth,
      targetHeight: session.targetHeight,
    );
    state = state.copyWith(printPages: pages);
    return pages;
  }

  Future<String> exportPdf() async {
    final session = _ref.read(sessionProvider);
    // Always rebuild from the current session/page-size settings so a
    // previous PDF cannot become stale after the user changes print options.
    final pages = await buildPrintSheetPages();
    final path = await PdfExportService.buildPdf(pages, pageSize: session.printPageSize);
    state = state.copyWith(pdfPath: path);
    return path;
  }

  // ---- v2: Save to Gallery / Save to Folder (spec request — exports were
  // invisible in Gallery/Files because they only ever lived in the app's
  // private sandbox directory before). ----

  /// Saves the ZIP to a user-chosen folder via Android's document picker
  /// (SAF) — works for any file type, so it's used for ZIP/PDF.
  Future<String?> saveZipToFolder() async {
    final path = await exportZip();
    return SaveService.saveFileToFolder(path, suggestedName: 'admission_photos.zip');
  }

  Future<String?> savePdfToFolder() async {
    final path = await exportPdf();
    return SaveService.saveFileToFolder(path, suggestedName: 'admission_photos.pdf');
  }

  /// Saves each student's individually processed photo (the same clean
  /// per-photo JPG that goes into the ZIP) to the device's Photos/Gallery.
  /// The print-sheet layout is intentionally not written to the Gallery.
  Future<int> savePhotosToGallery() async {
    final session = _ref.read(sessionProvider);
    var saved = 0;
    for (final photo in session.photos) {
      final path = photo.processedPath;
      if (path == null || !File(path).existsSync()) continue;
      final ok = await SaveService.saveImageToGallery(path);
      if (ok) saved++;
    }
    return saved;
  }

  /// Exposed for tests / UI display of what a filename would sanitize to.
  static String previewFilename(String? name, String fallback) =>
      FilenameUtils.sanitize(name, fallback);
}

final exportControllerProvider =
    StateNotifierProvider<ExportController, ExportState>((ref) {
  return ExportController(ref);
});
