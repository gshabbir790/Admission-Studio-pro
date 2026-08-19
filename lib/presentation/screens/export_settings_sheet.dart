import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';
import '../../core/utils/image_file_utils.dart';
import '../../services/segmentation/segmentation_service.dart';
import '../../data/models/photo_item.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import '../providers/session_provider.dart';
import '../providers/service_providers.dart';

/// Mirrors the HTML app's settings panel (spec §13–§16): size preset with
/// physical-size labels, background mode, JPEG quality slider, optional
/// file-size limit with KB/MB unit.
class ExportSettingsSheet extends ConsumerStatefulWidget {
  const ExportSettingsSheet({super.key});

  @override
  ConsumerState<ExportSettingsSheet> createState() => _ExportSettingsSheetState();
}

class _ExportSettingsSheetState extends ConsumerState<ExportSettingsSheet> {
  late TextEditingController _customW;
  late TextEditingController _customH;
  late TextEditingController _limitValue;
  final Map<String, Future<Uint8List?>> _previewCache = {};

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider);
    _customW = TextEditingController(text: s.targetWidth.toString());
    _customH = TextEditingController(text: s.targetHeight.toString());
    _limitValue = TextEditingController(
      text: s.sizeLimitValue > 0 ? s.sizeLimitValue.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _customW.dispose();
    _customH.dispose();
    _limitValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          Text('Export Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          Text('Photo Size', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<PhotoSizePreset>(
            value: session.sizePreset,
            decoration: const InputDecoration(
              labelText: 'Output size',
              prefixIcon: Icon(Icons.photo_size_select_small_outlined),
            ),
            items: PhotoSizePreset.values.map((preset) {
              return DropdownMenuItem(
                value: preset,
                child: Text(
                  preset.physical != null
                      ? '${preset.label} • ${preset.physical}'
                      : preset.label,
                ),
              );
            }).toList(),
            onChanged: (preset) {
              if (preset == null) return;
              _previewCache.clear();
              notifier.setSizePreset(preset);
            },
          ),
          if (session.sizePreset == PhotoSizePreset.custom) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customW,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Width (px)'),
                    onChanged: (v) => notifier.setCustomSize(
                      int.tryParse(v) ?? session.targetWidth,
                      int.tryParse(_customH.text) ?? session.targetHeight,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _customH,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (px)'),
                    onChanged: (v) => notifier.setCustomSize(
                      int.tryParse(_customW.text) ?? session.targetWidth,
                      int.tryParse(v) ?? session.targetHeight,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${AppConstants.customSizeMin}–${AppConstants.customSizeMax}px',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${session.targetWidth} × ${session.targetHeight}px',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

          const SizedBox(height: 20),
          Text('Background', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<BackgroundMode>(
            value: session.backgroundMode,
            decoration: const InputDecoration(
              labelText: 'Background',
              prefixIcon: Icon(Icons.layers_outlined),
            ),
            items: const [
              DropdownMenuItem(value: BackgroundMode.original, child: Text('Original')),
              DropdownMenuItem(value: BackgroundMode.white, child: Text('White')),
              DropdownMenuItem(value: BackgroundMode.royalBlue, child: Text('Royal Blue')),
            ],
            onChanged: (mode) {
              if (mode == null) return;
              _previewCache.clear();
              notifier.setBackgroundMode(mode);
            },
          ),
          if (session.backgroundMode != BackgroundMode.original) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Background intensity',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${session.backgroundIntensity}%',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            Slider(
              value: session.backgroundIntensity.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '${session.backgroundIntensity}%',
              onChanged: (v) {
                _previewCache.clear();
                notifier.setBackgroundIntensity(v.round());
              },
            ),
            const SizedBox(height: 4),
            Text(
              '0% keeps the original background; 100% applies the full replacement.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _BackgroundPreviewGrid(
  photos: session.photos,
  mode: session.backgroundMode,
  intensity: session.backgroundIntensity,
  cache: _previewCache,
  segmenter: ref.read(segmentationServiceProvider),
            ),
          ],

          const SizedBox(height: 20),
          Text('Print Page Size', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            '4×6in is the industry-standard photo-lab paper size for printing '
            'ID/passport photos — use A4 if printing on an office/home printer instead.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PrintPageSize.values.map((size) {
              return ChoiceChip(
                label: Text(size.label),
                selected: session.printPageSize == size,
                onSelected: (_) => notifier.setPrintPageSize(size),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
          Text('JPEG Quality: ${session.jpegQuality}%',
              style: Theme.of(context).textTheme.titleSmall),
          Slider(
            value: session.jpegQuality.toDouble(),
            min: AppConstants.jpegQualityMin.toDouble(),
            max: AppConstants.jpegQualityMax.toDouble(),
            divisions: AppConstants.jpegQualityMax - AppConstants.jpegQualityMin,
            onChanged: (v) => notifier.setJpegQuality(v.round()),
          ),

          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Limit file size'),
            value: session.sizeLimitEnabled,
            onChanged: (v) => notifier.setSizeLimit(enabled: v),
          ),
          if (session.sizeLimitEnabled)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _limitValue,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max size'),
                    onChanged: (v) => notifier.setSizeLimit(
                      value: double.tryParse(v) ?? 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<FileSizeUnit>(
                  value: session.sizeLimitUnit,
                  items: const [
                    DropdownMenuItem(value: FileSizeUnit.kb, child: Text('KB')),
                    DropdownMenuItem(value: FileSizeUnit.mb, child: Text('MB')),
                  ],
                  onChanged: (v) {
                    if (v != null) notifier.setSizeLimit(unit: v);
                  },
                ),
              ],
            ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'For print output, maximum available quality is always retained '
              'regardless of the size-limit setting above (size limit only '
              'applies to the ZIP/download copy).',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundPreviewGrid extends StatelessWidget {
  const _BackgroundPreviewGrid({
    required this.photos,
    required this.mode,
    required this.intensity,
    required this.cache,
    required this.segmenter,
  });

  final List<PhotoItem> photos;
  final BackgroundMode mode;
  final int intensity;
  final Map<String, Future<Uint8List?>> cache;
  final SegmentationService segmenter;

  Future<Uint8List?> _buildPreview(PhotoItem photo) async {
    try {
      final bytes = await File(photo.originalPath).readAsBytes();
      final source = img.decodeImage(bytes);
      if (source == null) return null;
      final scale = 220 /
          (source.width > source.height ? source.width : source.height);
      final preview = scale < 1
          ? img.copyResize(
              source,
              width: (source.width * scale).round(),
              height: (source.height * scale).round(),
            )
          : source;

      final temp = await ImageFileUtils.saveOriginalBytes(
        Uint8List.fromList(img.encodeJpg(preview, quality: 80)),
      );
      try {
        final segmented = await segmenter.apply(
          preview,
          mode: mode,
          intensity: intensity,
          inputImage: InputImage.fromFilePath(temp),
        );
        return Uint8List.fromList(img.encodeJpg(segmented, quality: 78));
      } finally {
        await ImageFileUtils.deleteIfExists(temp);
      }
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _future(PhotoItem photo) {
    final key = '${photo.id}:$mode:$intensity';
    return cache.putIfAbsent(key, () => _buildPreview(photo));
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('Add photos to see the background effect preview.'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live preview • ${photos.length} photo${photos.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, index) {
              final photo = photos[index];
              return FutureBuilder<Uint8List?>(
                future: _future(photo),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final bytes = snapshot.data;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: bytes == null
                        ? const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.broken_image_outlined),
                          )
                        : Image.memory(bytes, fit: BoxFit.cover),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
