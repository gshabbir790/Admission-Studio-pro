import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/photo_item.dart';
import '../controllers/capture_flow_controller.dart';
import '../controllers/export_controller.dart';
import '../providers/session_provider.dart';
import '../widgets/branded_app_bar.dart';
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
      // v2 fix (spec request: "home screen ko mazeed khoobsurat banayen" +
      // "har screen par appbar khoobsurat/professional banayen"): shared
      // BrandedAppBar instead of a plain AppBar, matching every other
      // screen now. The standalone Reset icon that used to live up here has
      // moved down next to Settings/Add Photos — see the bottom panel below
      // (spec request: "Reset button ko Add Photos aur Settings ke saath
      // ek hi line mein adjust karein").
      appBar: BrandedAppBar(
        title: 'Admission Studio Pro',
        subtitle: 'Student Photo Workspace',
        leadingIcon: Icons.badge_outlined,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'about') {
                showAboutDialog(
                  context: context,
                  applicationName: 'Admission Studio Pro',
                  applicationVersion: '1.2.0',
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
      // v2 fix (spec request: "Reset button ko Add Photos aur Settings ke
      // saath ek hi line mein adjust karein"): Reset, Settings, and Add
      // Photos are now one unified bottom panel (was previously an isolated
      // Reset icon up in the app bar plus a separate floating-button row) —
      // a single `bottomNavigationBar` with two rows instead of a
      // `floatingActionButton` also avoids the FAB potentially overlapping
      // grid content.
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (filled > 0) ...[
                  SizedBox(
                    width: 52,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => _confirmReset(context, ref),
                      child: const Icon(Icons.restart_alt_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => _openExportSettings(context),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Settings'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _startAddPhotos(context, ref, session.photos.isEmpty),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Add Photos'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (!session.singleMode) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: session.capacity >= AppConstants.maxBatchCapacity
                          ? null
                          : () => ref.read(sessionProvider.notifier).addCapacityPage(),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        session.capacity >= AppConstants.maxBatchCapacity
                            ? 'Max ${AppConstants.maxBatchCapacity}'
                            : '20 more',
                      ),
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
          ],
        ),
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

  /// v2 rework (spec request: "How many photos wale option mein do options
  /// hone chahiye: [Single Photo], [Multiple Photos]. Multiple Photos mein
  /// max 60 tasveerein aur ek Done button hona chahiye"): step 1 picks
  /// Single vs. Multiple; choosing Multiple opens a second step — a capacity
  /// stepper capped at [AppConstants.maxBatchCapacity] — instead of always
  /// silently defaulting to 20. ("Done" already exists as soon as the grid
  /// has 1+ photos, on the capture-chooser screen — see that screen's app
  /// bar actions.) Only asked when the session is empty (so an in-progress
  /// batch never gets its mode switched mid-way).
  Future<void> _startAddPhotos(BuildContext context, WidgetRef ref, bool canChooseMode) async {
    if (!canChooseMode) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CaptureChooserScreen()),
      );
      return;
    }

    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How many photos?'),
        content: const Text(
          'Choose single-photo mode for one quick capture, or multiple '
          'photos for a full session.',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Multiple Photos'),
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

    if (choice) {
      ref.read(sessionProvider.notifier).setSingleMode(true);
    } else {
      if (!context.mounted) return;
      final capacity = await _pickBatchCapacity(context);
      if (capacity == null) return; // person backed out of step 2
      ref.read(sessionProvider.notifier).setSingleMode(false, batchCapacity: capacity);
    }

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CaptureChooserScreen()),
      );
    }
  }

  /// Step 2 of "Multiple Photos": how many, up to the hard 60-photo ceiling.
  Future<int?> _pickBatchCapacity(BuildContext context) {
    var value = AppConstants.defaultCapacity;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('How many photos?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value photos',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Slider(
                value: value.toDouble(),
                min: AppConstants.minBatchCapacity.toDouble(),
                max: AppConstants.maxBatchCapacity.toDouble(),
                divisions: AppConstants.maxBatchCapacity - AppConstants.minBatchCapacity,
                label: '$value',
                onChanged: (v) => setState(() => value = v.round()),
              ),
              Text(
                'Maximum ${AppConstants.maxBatchCapacity} photos per session.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(value),
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
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
