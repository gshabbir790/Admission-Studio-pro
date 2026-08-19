import 'package:flutter/material.dart';

/// Mirrors the HTML app's `.countdown-num` pop animation (3-2-1, spec §7).
class CountdownOverlay extends StatelessWidget {
  const CountdownOverlay({super.key, required this.value});

  /// Current countdown number to display (3, 2, 1). Widget is not shown by
  /// the caller when countdown is inactive.
  final int value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween(begin: 0.5, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) => Transform.scale(
          scale: scale,
          child: child,
        ),
        child: Text(
          '$value',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Inter',
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
        ),
      ),
    );
  }
}
