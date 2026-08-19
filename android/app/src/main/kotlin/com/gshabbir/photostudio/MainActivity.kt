package com.gshabbir.photostudio

import io.flutter.embedding.android.FlutterActivity

/**
 * No custom platform channels are required — every native capability used
 * by this app (camera, ML Kit, file picking, sharing) is already exposed
 * through the Flutter plugin packages declared in pubspec.yaml (spec §37
 * services stay in the Dart layer). This class is intentionally minimal;
 * add MethodChannel registration here only if a future phase needs a
 * genuinely native-only implementation (spec §39).
 */
class MainActivity : FlutterActivity()
