import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/export_controller.dart';
import 'print_sheet_preview_screen.dart';

/// Mirrors the HTML app's `#processResultActions` (spec §26): shown after
/// "Process All" finishes, offering ZIP download, A4 print-sheet preview,
/// PDF export, and sharing — all offline (spec §18, §21–22, §32).
class ExportResultSheet extends ConsumerStatefulWidget {
  const ExportResultSheet({super.key});

  @override
  ConsumerState<ExportResultSheet> createState() => _ExportResultSheetState();
}

class _ExportResultSheetState extends ConsumerState<ExportResultSheet> {
  bool _busy = false;
  String? _statusLine;

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _statusLine = '$label…';
    });
    try {
      await action();
      if (mounted) setState(() => _statusLine = '$label complete.');
    } catch (e) {
      if (mounted) setState(() => _statusLine = '$label failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(exportControllerProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Export', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text(
              'Photos processed successfully. Choose what to export.',
              style: TextStyle(fontSize: 12.5),
            ),
            if (ref.watch(exportControllerProvider).progress.failed > 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${ref.watch(exportControllerProvider).progress.failed} photo(s) could not be processed. '
                  'Only successfully processed photos will be exported.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 2),
            FilledButton.icon(
              icon: const Icon(Icons.save_alt_outlined),
              label: const Text('Save ZIP to Folder'),
              onPressed: _busy
                  ? null
                  : () => _run('Save ZIP', () async {
                        final saved = await controller.saveZipToFolder();
                        if (saved == null) throw Exception('Save was cancelled or failed');
                      }),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.grid_view_outlined),
              label: const Text('Preview Print Sheet'),
              onPressed: _busy
                  ? null
                  : () => _run('Build print sheet', () async {
                      await controller.buildPrintSheetPages();
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrintSheetPreviewScreen(),
                        ),
                      );
                    }),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Save PDF to Folder'),
              onPressed: _busy
                  ? null
                  : () => _run('Save PDF', () async {
                        final saved = await controller.savePdfToFolder();
                        if (saved == null) throw Exception('Save was cancelled or failed');
                      }),
            ),
            const SizedBox(height: 10),
            // v2 fix: this used to save the tiled A4/4x6 print sheet page(s)
            // into Gallery, which isn't what "save to gallery" means for
            // most people — they want each student's individual photo there
            // (report: "print sheet ki bajaye tasveerein gallery mein save
            // honi chahiye"). Share ZIP / Share PDF were also dropped —
            // Save-to-Folder already covers getting the files out of the
            // app, and two overlapping "give me the file" actions was just
            // extra clutter in this sheet.
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Save Photos to Gallery'),
              onPressed: _busy
                  ? null
                  : () => _run(
                        'Save photos',
                        () => controller.savePhotosToGallery(),
                      ),
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_statusLine != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusLine!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
