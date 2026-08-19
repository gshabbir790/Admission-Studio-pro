import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/export_controller.dart';

/// Mirrors the HTML app's progress modal (spec §26): percent bar plus
/// "Processing n of total" text, non-dismissible while running.
class ProcessingProgressDialog extends ConsumerWidget {
  const ProcessingProgressDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      exportControllerProvider.select((s) => s.progress),
    );

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Processing Photos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress.total > 0 ? progress.done / progress.total : 0,
            ),
            const SizedBox(height: 12),
            Text('${progress.percent}% (${progress.done}/${progress.total})'),
            if (progress.failed > 0) ...[
              const SizedBox(height: 6),
              Text(
                '${progress.failed} photo(s) failed to process',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
