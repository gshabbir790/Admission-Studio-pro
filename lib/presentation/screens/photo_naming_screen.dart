import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/capture_flow_controller.dart';
import '../providers/session_provider.dart';

/// Mirrors the HTML app's `#namingPanel` (spec §9): preview, name field,
/// with/without-name radios, confirm. For retakes the previous student's
/// name is prefilled (HTML: `acceptBtn` looks up `photos.find(retakeTargetId)`).
class PhotoNamingScreen extends ConsumerStatefulWidget {
  const PhotoNamingScreen({super.key});

  @override
  ConsumerState<PhotoNamingScreen> createState() => _PhotoNamingScreenState();
}

class _PhotoNamingScreenState extends ConsumerState<PhotoNamingScreen> {
  late final TextEditingController _nameController;
  bool _nameEnabled = true;
  bool _initializedPrefill = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _prefillIfRetake() {
    if (_initializedPrefill) return;
    _initializedPrefill = true;
    final flow = ref.read(captureFlowProvider);
    final retakeId = flow.retakeTargetId;
    if (retakeId == null) return;
    final existing = ref
        .read(sessionProvider)
        .photos
        .where((p) => p.id == retakeId);
    if (existing.isNotEmpty) {
      _nameController.text = existing.first.name;
      _nameEnabled = existing.first.nameEnabled;
    }
  }

  Future<void> _confirm() async {
    final name = _nameEnabled ? _nameController.text.trim() : '';
    await ref
        .read(captureFlowProvider.notifier)
        .confirmNaming(name: name, nameEnabled: _nameEnabled);
  }

  @override
  Widget build(BuildContext context) {
    _prefillIfRetake();
    final flow = ref.watch(captureFlowProvider);

    ref.listen(captureFlowProvider, (prev, next) {
      // Gallery batch: stay on this same screen for the next item instead of
      // popping, mirroring processNextGalleryItem() reusing the naming panel.
      final stillNaming = next.mode == CaptureMode.naming;
      if (!stillNaming && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else if (stillNaming && next.pendingImagePath != prev?.pendingImagePath) {
        setState(() {
          _nameController.clear();
          _nameEnabled = true;
          _initializedPrefill = false;
        });
      }
    });

    final previewPath = flow.pendingImagePath;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ref.read(captureFlowProvider.notifier).goToChooser();
        }
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text(
          flow.galleryQueueLength > 0
              ? 'Name Student (${flow.galleryQueueLength} remaining)'
              : 'Name Student',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (previewPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(previewPath),
                  width: 110,
                  height: 138,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: _nameEnabled,
              textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                hintText: 'Student name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('With Name'),
                  selected: _nameEnabled,
                  onSelected: (_) => setState(() => _nameEnabled = true),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Without Name'),
                  selected: !_nameEnabled,
                  onSelected: (_) => setState(() => _nameEnabled = false),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirm,
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
