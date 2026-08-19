import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/image_file_utils.dart';
import '../controllers/capture_flow_controller.dart';
import '../providers/session_provider.dart';
import 'camera_capture_screen.dart';
import 'photo_naming_screen.dart';

class CaptureChooserScreen extends ConsumerStatefulWidget {
  const CaptureChooserScreen({super.key});

  @override
  ConsumerState<CaptureChooserScreen> createState() =>
      _CaptureChooserScreenState();
}

class _CaptureChooserScreenState extends ConsumerState<CaptureChooserScreen> {
  bool _importing = false;

  Future<void> _pickFromCamera() async {
    await ref.read(captureFlowProvider.notifier).enterLive();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
  }

  Future<void> _pickFromGallery() async {
    setState(() => _importing = true);
    try {
      final picker = ImagePicker();
      final singleMode = ref.read(sessionProvider).singleMode;
      
      List<XFile> files = [];

      if (singleMode) {
      
        final XFile? f = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 100,
        );
        if (f != null) {
          files = [f];
        }
      } else {
        files = await picker.pickMultiImage(imageQuality: 100);
      }

      if (files.isEmpty) return;

      final savedPaths = <String>[];
      for (final f in files) {
        savedPaths.add(await ImageFileUtils.saveOriginalFromPath(f.path));
      }

      ref.read(captureFlowProvider.notifier).startGalleryImport(savedPaths);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PhotoNamingScreen()),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _done() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    // v2 fix: this screen used to be a dead end — after adding a photo it
    // reappeared with no way back except the system back button, which the
    // person reported as confusing ("dobara chooze photos/camera show hota
    // hai, ek Done button bhi hona chahiye"). A "Done" button now returns
    // straight to the home/grid screen; it only shows once there's at least
    // one photo captured, so it never appears on a still-empty session.
    final hasPhotos = session.photos.isNotEmpty;
    final singleComplete = session.singleMode && hasPhotos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admission Photo Studio Pro'),
        actions: [
          if (hasPhotos)
            TextButton(
              onPressed: _done,
              child: const Text('Done'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              '${session.photos.length} / ${session.capacity} photos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ChoiceCard(
                    icon: Icons.camera_alt_outlined,
                    label: 'Take Photo with Camera',
                    onTap: (_importing || singleComplete) ? null : _pickFromCamera,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ChoiceCard(
                    icon: Icons.photo_library_outlined,
                    label: 'Choose from Gallery',
                    onTap: (_importing || singleComplete) ? null : _pickFromGallery,
                    loading: _importing,
                  ),
                ),
              ],
            ),
            if (hasPhotos) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _done,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Done — continue'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
          child: Column(
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 30),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
