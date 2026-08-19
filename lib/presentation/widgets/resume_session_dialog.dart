import 'package:flutter/material.dart';

/// Mirrors the HTML app's `#resumeModal` (spec §24): shown once at launch
/// if a saved session with photos exists. "New Session" clears it safely;
/// "Continue" keeps the already-resumed in-memory session as is (the
/// session was already loaded into [sessionProvider] at construction —
/// this dialog only decides whether to keep or discard it).
class ResumeSessionDialog extends StatelessWidget {
  const ResumeSessionDialog({
    super.key,
    required this.photoCount,
    required this.savedAt,
    required this.onNewSession,
    required this.onContinue,
  });

  final int photoCount;
  final DateTime savedAt;
  final VoidCallback onNewSession;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Previous Session Found'),
      content: Text(
        '$photoCount photo(s) found from your last session '
        '(${savedAt.toLocal()}).',
      ),
      actions: [
        TextButton(onPressed: onNewSession, child: const Text('New Session')),
        FilledButton(onPressed: onContinue, child: const Text('Continue')),
      ],
    );
  }
}
