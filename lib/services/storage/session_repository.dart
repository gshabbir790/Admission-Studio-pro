import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/face_info.dart';
import '../../data/models/photo_item.dart';
import '../../data/models/photo_session.dart';
import '../../data/models/processing_status.dart';

/// Persists the active [PhotoSession] to a local Hive box and restores it on
/// next launch. Directly mirrors the HTML app's IndexedDB `session` store:
/// - `scheduleAutoSave()` → [scheduleAutoSave] (900ms debounce, same value)
/// - `saveSession()` → [_saveNow]
/// - `loadSessionData()` → [loadSession]
/// - `clearSession()` → [clearSession]
///
/// Register all adapters via [SessionRepository.init] once at app startup,
/// before opening the box.
class SessionRepository {
  SessionRepository._();

  static final SessionRepository instance = SessionRepository._();

  Box<PhotoSession>? _box;
  Timer? _debounceTimer;

  bool get isReady => _box != null && _box!.isOpen;

  /// Registers Hive type adapters and opens the session box. Call once in
  /// `main()` before `runApp`.
  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(FaceInfoAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(PhotoItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(PhotoSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(ProcessingStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(PhotoSizePresetAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(BackgroundModeAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(FileSizeUnitAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(PrintPageSizeAdapter());
    }

    instance._box = await Hive.openBox<PhotoSession>(
      AppConstants.sessionBoxName,
    );
  }

  /// Returns the saved session if one exists with at least one photo,
  /// mirroring the HTML app's resume-only-if-non-empty check.
  PhotoSession? loadSession() {
    final box = _box;
    if (box == null) return null;
    final saved = box.get(AppConstants.sessionKey);
    if (saved == null || saved.photos.isEmpty) return null;
    return saved;
  }

  /// Debounced autosave — call after any meaningful mutation (add photo,
  /// delete photo, rename, retake, edit params). Same 900ms debounce as the
  /// HTML app so rapid typing in the name field doesn't thrash disk I/O.
  void scheduleAutoSave(PhotoSession session) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppConstants.autoSaveDebounce, () {
      _saveNow(session);
    });
  }

  /// Saves immediately, bypassing debounce. Use for app-lifecycle pause
  /// (`AppLifecycleState.paused`) where a pending debounce might not fire.
  Future<void> saveNow(PhotoSession session) => _saveNow(session);

  Future<void> _saveNow(PhotoSession session) async {
    final box = _box;
    if (box == null) return;
    session.touch();
    await box.put(AppConstants.sessionKey, session);
  }

  /// Clears the saved session — mirrors HTML's `clearSession()`, called both
  /// from "New Session" on the resume dialog and from "Clear All".
  Future<void> clearSession() async {
    _debounceTimer?.cancel();
    final box = _box;
    if (box == null) return;
    await box.delete(AppConstants.sessionKey);
  }

  Future<void> dispose() async {
    _debounceTimer?.cancel();
    await _box?.close();
  }
}
