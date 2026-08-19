import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/camera/camera_service.dart';
import '../../services/image_processing/image_processing_service.dart';
import '../../services/segmentation/segmentation_service.dart';
import '../../services/storage/session_repository.dart';

/// Single long-lived CameraService for the app's capture flow. Kept alive
/// (not autoDispose) because the chooser/live/confirm/naming screens all
/// share one underlying camera session, mirroring the HTML app keeping one
/// `stream` global across its state-machine transitions.
final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(() => service.dispose());
  return service;
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository.instance;
});

final segmentationServiceProvider = Provider<SegmentationService>((ref) {
  final service = SegmentationService();
  ref.onDispose(() => service.dispose());
  return service;
});

final imageProcessingServiceProvider = Provider<ImageProcessingService>((ref) {
  return ImageProcessingService(ref.watch(segmentationServiceProvider));
});
