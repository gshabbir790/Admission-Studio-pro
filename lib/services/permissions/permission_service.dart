import 'package:permission_handler/permission_handler.dart';

/// Wraps `permission_handler` (spec §30): requests only what's needed, when
/// it's needed (camera right before opening the live preview, photos right
/// before the gallery picker), never up front at app launch.
class PermissionService {
  const PermissionService._();

  static Future<bool> ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// `Permission.photos` maps to `READ_MEDIA_IMAGES` on Android 13+ and
  /// `READ_EXTERNAL_STORAGE` below that automatically via the plugin.
  static Future<bool> ensurePhotosPermission() async {
    final status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;
    final result = await Permission.photos.request();
    return result.isGranted || result.isLimited;
  }

  static Future<bool> isCameraPermanentlyDenied() async {
    return (await Permission.camera.status).isPermanentlyDenied;
  }

  static Future<void> openSettings() => openAppSettings();
}
