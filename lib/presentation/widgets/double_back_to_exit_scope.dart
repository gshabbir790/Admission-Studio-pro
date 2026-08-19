import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

/// v2 fix: the hardware back button on the app's root screen used to close
/// the app immediately with no warning. This wraps [child] with the
/// standard Android "press back again to exit" pattern instead — first
/// back press shows a snackbar and is absorbed, a second press within
/// [window] actually exits.
class DoubleBackToExitScope extends StatefulWidget {
  const DoubleBackToExitScope({
    super.key,
    required this.child,
    this.window = const Duration(seconds: 2),
    this.message = 'Press back again to exit',
  });

  final Widget child;
  final Duration window;
  final String message;

  @override
  State<DoubleBackToExitScope> createState() => _DoubleBackToExitScopeState();
}

class _DoubleBackToExitScopeState extends State<DoubleBackToExitScope> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        final isSecondPress =
            _lastBackPress != null && now.difference(_lastBackPress!) < widget.window;

        if (isSecondPress) {
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          }
          return;
        }

        _lastBackPress = now;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(widget.message),
            duration: widget.window,
          ));
      },
      child: widget.child,
    );
  }
}
