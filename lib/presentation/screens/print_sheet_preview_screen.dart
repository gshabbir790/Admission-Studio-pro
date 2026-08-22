import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/session_provider.dart';
import '../controllers/export_controller.dart';
import '../widgets/branded_app_bar.dart';

/// Print-sheet preview (spec §20): paged viewer over the pages built by
/// `PrintSheetService`, with Save Photos to Gallery / Save PDF to Folder.
/// Page size (4x6 photo-lab standard or A4) is whatever was chosen in
/// Export Settings — see `PrintPageSize` (v2).
class PrintSheetPreviewScreen extends ConsumerStatefulWidget {
  const PrintSheetPreviewScreen({super.key});

  @override
  ConsumerState<PrintSheetPreviewScreen> createState() =>
      _PrintSheetPreviewScreenState();
}

class _PrintSheetPreviewScreenState extends ConsumerState<PrintSheetPreviewScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = ref.watch(exportControllerProvider.select((s) => s.printPages));
    final controller = ref.read(exportControllerProvider.notifier);
    final pageSize = ref.watch(sessionProvider.select((s) => s.printPageSize));

    return Scaffold(
      // v2 fix (spec request: "PDF print preview screen par title bar
      // mukammal nazar nahi aata"): the old plain AppBar Text had no
      // maxLines/overflow handling, so the long combined
      // "Page 1 / 3 · 4×6 in (Photo Lab Standard)" string would wrap and get
      // clipped by the toolbar's fixed height. BrandedAppBar always
      // single-lines + ellipsizes the title, and the page size now uses its
      // short form as a subtitle instead of being crammed into the title.
      appBar: BrandedAppBar(
        title: pages.isEmpty ? 'Print Sheet' : 'Page ${_currentPage + 1} / ${pages.length}',
        subtitle: pages.isEmpty ? null : pageSize.shortLabel,
        onLeadingTap: () => Navigator.of(context).maybePop(),
      ),
      body: pages.isEmpty
          ? const Center(child: Text('No pages to preview.'))
          : PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: pageSize.widthInches / pageSize.heightInches,
                    child: Image.file(File(pages[i].path), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: pages.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _run(
                                      controller.savePhotosToGallery,
                                      'Photos saved to Gallery.',
                                    ),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Save Photos to Gallery'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  final saved = await controller.savePdfToFolder();
                                  if (saved == null) throw Exception('Save cancelled');
                                }, 'PDF saved.'),
                        child: const Text('Save PDF to Folder'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
