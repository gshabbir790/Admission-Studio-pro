import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/photo_item.dart';
import '../controllers/capture_flow_controller.dart';
import '../controllers/export_controller.dart';
import '../providers/session_provider.dart';
import '../widgets/photo_grid_card.dart';
import '../widgets/processing_progress_dialog.dart';
import 'camera_capture_screen.dart';
import 'capture_chooser_screen.dart';
import 'export_result_sheet.dart';
import 'export_settings_sheet.dart';
import 'photo_editor_screen.dart';

/// Main hub screen (spec §10): fixed-capacity grid, "+20 more", per-card
/// edit/retake/delete, and the settings/process/export entry points.
/// Deleting a photo or changing its name invalidates its processed/export
/// cache — enforced in `SessionNotifier`, not here (spec §10 last line).
class PhotoGridScreen extends ConsumerWidget {
  const PhotoGridScreen({super.key});

  Future<void> _rename(BuildContext context, WidgetRef ref, PhotoItem photo) async {
    final controller = TextEditingController(text: photo.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Student Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref.read(sessionProvider.notifier).renamePhoto(photo.id, result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7A2E2E)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) ref.read(sessionProvider.notifier).deletePhoto(id);
  }

  void _openExportSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ExportSettingsSheet(),
    );
  }

  Future<void> _processAll(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider);
    if (session.photos.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ProcessingProgressDialog(),
    );

    await ref.read(exportControllerProvider.notifier).processAll();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    final result = ref.read(exportControllerProvider);
    if (result.progress.done == 0 || result.progress.done == result.progress.failed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No photos were processed successfully. '
            '${result.progress.failed} photo(s) failed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ExportResultSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filled = session.photos.length;
    final remaining = (session.capacity - filled).clamp(0, session.capacity).toInt();
    final progress = session.capacity == 0 ? 0.0 : (filled / session.capacity).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admission Studio Pro',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Student Photo Workspace',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          if (filled > 0)
            IconButton(
              tooltip: 'Reset session',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => _confirmReset(context, ref),
            ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'about') {
                showAboutDialog(
                  context: context,
                  applicationName: 'Admission Studio Pro',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(Icons.camera_alt_rounded, size: 32),
                  children: const [
                    SizedBox(height: 8),
                    Text(
                      'Offline student-photo capture, editing, batch processing, '
                      'background replacement and print/export tools.',
                    ),
                    SizedBox(height: 12),
                    Text('Developed & Maintained by Ghulam Shabbir'),
                  ],
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _SessionOverviewCard(
                  filled: filled,
                  capacity: session.capacity,
                  remaining: remaining,
                  progress: progress,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      filled == 0 ? 'Start your session' : 'Student photos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (filled > 0)
                      Text(
                        '$filled captured',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (session.photos.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                sliver: SliverGrid(
                // v2 fix: was maxCrossAxisExtent:150, which only ever
                // rendered 3 thumbnails per row on a typical phone width
                // (report: "teen teen ke thumbnail hain, kam az kam 4 hone
                // chahiye"). A fixed 4-column count guarantees 4-per-row on
                // phones regardless of exact screen width.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final photo =
                          i < session.photos.length ? session.photos[i] : null;
                      return PhotoGridCard(
                        index: i + 1,
                        photo: photo,
                        onEdit: photo == null
                            ? () {}
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PhotoEditorScreen(photoId: photo.id),
                                  ),
                                ),
                        onRetake: photo == null
                            ? () {}
                            : () {
                                ref
                                    .read(captureFlowProvider.notifier)
                                    .beginRetake(photo.id);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CameraCaptureScreen(),
                                  ),
                                );
                              },
                        onDelete: photo == null
                            ? () {}
                            : () => _confirmDelete(context, ref, photo.id),
                        onRenameTap: photo == null
                            ? () {}
                            : () => _rename(context, ref, photo),
                      );
                    },
                    childCount: session.photos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            if (!session.singleMode) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(sessionProvider.notifier)
                      .addCapacityPage(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('20 more'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: filled == 0 ? null : () => _processAll(context, ref),
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: Text(filled == 0 ? 'Process photos' : 'Process $filled photos'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // v2: export-settings entry point moved here, right next to "Add
          // Photos", per request ("settings ka button add photos button ke
          // saath, usi style mein bana dein") — previously it was a small
          // icon tucked in the app bar where it was easy to miss.
          FloatingActionButton.extended(
            heroTag: 'export_settings_fab',
            tooltip: 'Export settings',
            onPressed: () => _openExportSettings(context),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Settings'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add_photos_fab',
            onPressed: () => _startAddPhotos(context, ref, session.photos.isEmpty),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add Photos'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset session?'),
        content: const Text(
          'All selected photos and the current session settings will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).clearAll();
    }
  }

  /// v2: asks Single vs. Batch only when the session is empty (so an
  /// in-progress batch never gets its mode switched mid-way) — fixes the
  /// complaint that a single photo forced the full 20-slot grid on screen.
  Future<void> _startAddPhotos(BuildContext context, WidgetRef ref, bool canChooseMode) async {
    if (!canChooseMode) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CaptureChooserScreen()),
      );
      return;
    }

    // v2 fix: the two choices used to be visually unequal (a plain
    // TextButton next to a FilledButton, stacked oddly in the actions row —
    // report: "ye ek hi line mein, aamne saamne hona chahiye"). Both options
    // are now equal-weight buttons side by side in one row.
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How many photos?'),
        content: const Text('Choose single-photo mode for one quick capture, '
            'or batch mode for a full session (20+ photos).'),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Batch (20+)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Single Photo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (choice == null) return;

    ref.read(sessionProvider.notifier).setSingleMode(choice);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CaptureChooserScreen()),
      );
    }
  }
}

class _SessionOverviewCard extends StatelessWidget {
  const _SessionOverviewCard({
    required this.filled,
    required this.capacity,
    required this.remaining,
    required this.progress,
  });

  final int filled;
  final int capacity;
  final int remaining;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (progress * 100).round();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withOpacity(0.82)],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withOpacity(0.22),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.photo_camera_front_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filled == 0 ? 'Ready for a new session' : 'Session in progress',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$filled of $capacity photos captured • $remaining slots available',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.85),
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress.clamp(0.0, 1.0).toDouble(),
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.badge_outlined,
              size: 44,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No student photos yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Capture a photo with the camera or import existing photos. '
            'Your session is saved locally so you can continue later.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FeaturePill(icon: Icons.offline_bolt_outlined, label: 'Offline'),
              SizedBox(width: 8),
              _FeaturePill(icon: Icons.lock_outline, label: 'Private'),
              SizedBox(width: 8),
              _FeaturePill(icon: Icons.print_outlined, label: 'Print-ready'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
