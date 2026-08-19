import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'presentation/providers/session_provider.dart';
import 'presentation/providers/service_providers.dart';
import 'presentation/screens/photo_grid_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/widgets/double_back_to_exit_scope.dart';
import 'presentation/widgets/resume_session_dialog.dart';
import 'services/storage/session_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionRepository.init();
  runApp(const ProviderScope(child: AdmissionStudioProApp()));
}

class AdmissionStudioProApp extends StatefulWidget {
  const AdmissionStudioProApp({super.key});

  @override
  State<AdmissionStudioProApp> createState() => _AdmissionStudioProAppState();
}

class _AdmissionStudioProAppState extends State<AdmissionStudioProApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      // v2: the flat mint-green-on-white palette read as a generic template
      // rather than a finished product (report: "theme color international
      // level ka nahi hai"). Kept the same brand green (it's already used
      // across icons/exports) but deepened it into a proper seeded scheme
      // with real elevation/shadow, rounder corners, and a filled button
      // theme so buttons/cards read as intentionally designed rather than
      // Material defaults.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5C5A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: Color(0xFFF7F9FA),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 2,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      // English is the app's default/global language (per project
      // instruction). RTL/Urdu support (spec §28) returns as a selectable
      // locale in the dedicated localization pass — root layout defaults
      // to LTR for now.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: _showSplash
          ? SplashScreen(onFinished: () => setState(() => _showSplash = false))
          : const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerStatefulWidget {
  const _AppRoot();

  @override
  ConsumerState<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<_AppRoot> with WidgetsBindingObserver {
  bool _resumeDialogHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final session = ref.read(sessionProvider);
      ref.read(sessionRepositoryProvider).saveNow(session);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resumeDialogHandled) return;
    _resumeDialogHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowResumeDialog());
  }

  Future<void> _maybeShowResumeDialog() async {
    final session = ref.read(sessionProvider);
    if (session.photos.isEmpty) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResumeSessionDialog(
        photoCount: session.photos.length,
        savedAt: session.updatedAt,
        onNewSession: () async {
          await ref.read(sessionProvider.notifier).clearAll();
          if (mounted) Navigator.of(context).pop();
        },
        onContinue: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const DoubleBackToExitScope(child: PhotoGridScreen());
  }
}