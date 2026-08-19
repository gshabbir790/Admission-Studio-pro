import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/image_file_utils.dart';
import '../../services/camera/camera_service.dart';
import '../controllers/capture_flow_controller.dart';
import '../providers/service_providers.dart';
import '../widgets/oval_guide_overlay.dart';
import 'photo_naming_screen.dart';

/// Live camera screen: static oval framing guide + manual shutter + confirm
/// step. Mirrors the HTML app's `#liveCameraWrap` / `#confirmOverlay` block
/// (spec §5, §7) and the permission-denied fallback (spec §34: manual
/// capture / file picker still work even if the camera API fails).
///
/// NOTE (v2): auto-capture/face-detection UI was removed — see
/// `CaptureFlowController`'s class doc for why.
class CameraCaptureScreen extends ConsumerStatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  ConsumerState<CameraCaptureScreen> createState() =>
      _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen> {
  bool _navigatedToNaming = false;

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(captureFlowProvider);
    final camera = ref.watch(cameraServiceProvider);

    ref.listen(captureFlowProvider, (prev, next) {
      if (next.mode == CaptureMode.naming && !_navigatedToNaming) {
        _navigatedToNaming = true;
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const PhotoNamingScreen()))
            .then((_) => _navigatedToNaming = false);
      }
      if (next.mode == CaptureMode.chooser) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ref.read(captureFlowProvider.notifier).goToChooser();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ref.read(captureFlowProvider.notifier).goToChooser(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => ref.read(captureFlowProvider.notifier).switchCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: !flow.cameraAvailable
                  ? _CameraFallback(onPicked: _handleFallbackPick)
                  : AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPreviewOrFrozen(camera, flow),
                            if (flow.mode == CaptureMode.live)
                              const OvalGuideOverlay(),
                            if (flow.mode == CaptureMode.confirm)
                              _ConfirmControls(
                                onReject: () => ref
                                    .read(captureFlowProvider.notifier)
                                    .retakeFromConfirm(),
                                onAccept: () => ref
                                    .read(captureFlowProvider.notifier)
                                    .acceptFromConfirm(),
                              ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (flow.mode == CaptureMode.live && flow.cameraAvailable)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: GestureDetector(
                  onTap: () => ref.read(captureFlowProvider.notifier).capturePhoto(),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF1F4B3F), width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF7A2E2E),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPreviewOrFrozen(CameraService camera, CaptureFlowState flow) {
    if (flow.mode == CaptureMode.confirm && flow.pendingImagePath != null) {
      return Image.file(File(flow.pendingImagePath!), fit: BoxFit.cover);
    }
    final controller = camera.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return Transform(
      alignment: Alignment.center,
      transform: camera.shouldMirrorPreview
          ? (Matrix4.identity()..scale(-1.0, 1.0))
          : Matrix4.identity(),
      child: CameraPreview(controller as CameraController),
    );
  }

  Future<void> _handleFallbackPick() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;
    final saved = await ImageFileUtils.saveOriginalFromPath(xfile.path);
    // Route straight to confirm using the same state the live flow would.
    ref.read(captureFlowProvider.notifier).acceptFallbackCapture(saved);
  }
}

class _ConfirmControls extends StatelessWidget {
  const _ConfirmControls({required this.onReject, required this.onAccept});

  final VoidCallback onReject;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 26,
      right: 26,
      bottom: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(
            icon: Icons.close,
            color: const Color(0xFF7A2E2E),
            onTap: onReject,
          ),
          _CircleButton(
            icon: Icons.check,
            color: const Color(0xFF2E7D5B),
            onTap: onAccept,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback({required this.onPicked});

  final Future<void> Function() onPicked;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Camera not available',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onPicked, child: const Text('Choose Photo')),
        ],
      ),
    );
  }
}
