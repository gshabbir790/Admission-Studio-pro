import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/image_file_utils.dart';
import '../controllers/capture_flow_controller.dart';
import '../providers/session_provider.dart';
import '../widgets/branded_app_bar.dart';
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

  @override
  void initState() {
    super.initState();
    // v2 fix: warm the camera up in the background the moment this screen
    // appears, well before the person taps "Take Photo" — see
    // CaptureFlowController.prewarmCamera doc.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(captureFlowProvider.notifier).prewarmCamera();
    });
  }

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
      final session = ref.read(sessionProvider);
      final singleMode = session.singleMode;

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

      // v2 fix (spec request: "Multiple Photos mein maximum 60 tasveer
      // upload ka option hona chahiye"): gallery multi-select has no
      // built-in cap, so a person could pick more images than the session's
      // remaining capacity (itself capped at AppConstants.maxBatchCapacity —
      // see PhotoSession.growCapacityIfNeeded). Trim to what actually fits
      // and tell them, rather than silently dropping/erroring later.
      if (!singleMode) {
        final remaining =
            (session.capacity - session.photos.length).clamp(0, session.capacity);
        if (files.length > remaining) {
          final trimmed = files.length - remaining;
          files = files.take(remaining).toList();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  remaining == 0
                      ? 'Session is full — increase capacity first.'
                      : 'Only the first $remaining photo(s) were added '
                          '($trimmed skipped — session limit reached).',
                ),
              ),
            );
          }
        }
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
      // v2 fix (spec request: "Take Photo / Choose from Gallery screen par
      // app ka naam pura nazar nahi aata, overflow ho jaata hai"): switched
      // to a shorter, screen-specific title ("Add Photos" instead of the
      // full app name) plus the shared BrandedAppBar, whose title text
      // always ellipsizes instead of overflowing even if a long "Done"
      // action sits right next to it.
      appBar: BrandedAppBar(
        title: 'Add Photos',
        subtitle: session.singleMode ? 'Single photo' : '${session.capacity} photo session',
        onLeadingTap: () => Navigator.of(context).maybePop(),
        actions: [
          if (hasPhotos)
            TextButton(
              onPressed: _done,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
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
