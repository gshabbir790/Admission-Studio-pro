import 'package:flutter/material.dart';

/// Branded splash screen, ported from the sibling "BISE Bulk Result
/// Downloader" app's `splash_screen.dart` / `index.html` splash (same
/// visual language: radial sea-dark background, icon pop-in, gold-gradient
/// divider, "Developed & Maintained by Ghulam Shabbir" footer) — modified
/// for Admission Studio Pro: camera/portrait-frame icon instead of the
/// graduation cap, and shown for 5 seconds (per request) before fading into
/// the app.
///
/// Colors match the source HTML's `:root` variables exactly:
///   --sea-dark:#123b4a  --sea-mid:#1b3d49  --green:#198754  --gold:#d4af37
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _seaDark = Color(0xFF0B5C5A);
  static const _seaMid = Color(0xFF123E4A);
  static const _green = Color(0xFF0B8F84);
  static const _gold = Color(0xFFD4AF37);
  static const _bgDeep = Color(0xFF0F2027);

  late final AnimationController _iconController;
  late final AnimationController _fadeUpController;
  late final AnimationController _dividerController;
  late final AnimationController _footerController;
  late final AnimationController _exitController;

  @override
  void initState() {
    super.initState();

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _fadeUpController.forward();
    });

    _dividerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _dividerController.forward();
    });

    _footerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _footerController.forward();
    });

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 5-second splash, then fade out and hand off to the app (per request).
    Future.delayed(const Duration(milliseconds: 1400), () async {
      if (!mounted) return;
      await _exitController.forward();
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _fadeUpController.dispose();
    _dividerController.dispose();
    _footerController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_exitController),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.3,
              colors: [_seaMid, _bgDeep],
              stops: [0.0, 0.7],
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _iconController,
                        curve: const Cubic(0.2, 0.9, 0.25, 1.2),
                      ),
                      child: FadeTransition(
                        opacity: _iconController,
                        child: const _AppIconGlyph(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _fadeUpController,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(_fadeUpController),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Admission Studio Pro',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedBuilder(
                      animation: _dividerController,
                      builder: (context, child) => Container(
                        width: 120,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _dividerController.value,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: const LinearGradient(
                                  colors: [_seaDark, _green, _gold],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: FadeTransition(
                  opacity: _footerController,
                  child: const Column(
                    children: [
                      Text(
                        'Developed & Maintained by',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ghulam Shabbir',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Camera + portrait-frame glyph — the app's own icon motif (see
/// `assets/icon/README.md`), not the sibling app's graduation cap.
class _AppIconGlyph extends StatelessWidget {
  const _AppIconGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
      ),
      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 30),
    );
  }
}
