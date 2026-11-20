import 'package:flutter/material.dart';

import '../../../split_config/domain/models/background_spec.dart';
import '../../../split_config/domain/models/canvas_spec.dart';
import '../../../split_config/domain/models/overlay_spec.dart';
import '../../../split_config/domain/models/split_config.dart';
import '../../domain/models/exported_clip.dart';
import '../../domain/safe_clip_replacer.dart';

/// Configuration payload returned when confirming the 9:16 Shorts conversion dialog.
class ConvertToShortsParams {
  final List<int> selectedPartIndices;
  final SplitConfig config;
  final ReplaceStrategy replaceStrategy;

  const ConvertToShortsParams({
    required this.selectedPartIndices,
    required this.config,
    required this.replaceStrategy,
  });
}

/// Interactive Material 3 dialog allowing users to convert split video clips
/// into vertical 9:16 Shorts with part numbers, titles, and background styling.
class ConvertToShortsDialog extends StatefulWidget {
  final List<ExportedClip> clips;
  final int? initialSelectedPartIndex;

  const ConvertToShortsDialog({
    super.key,
    required this.clips,
    this.initialSelectedPartIndex,
  });

  @override
  State<ConvertToShortsDialog> createState() => _ConvertToShortsDialogState();
}

class _ConvertToShortsDialogState extends State<ConvertToShortsDialog> {
  late final Set<int> _selectedIndices;
  CanvasFormat _canvasFormat = CanvasFormat.shorts916;
  String _backgroundType = 'blur';
  bool _addPartLabel = true;
  OverlayPosition _labelPosition = OverlayPosition.topCenter;
  ReplaceStrategy _replaceStrategy = ReplaceStrategy.replace;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedPartIndex != null) {
      _selectedIndices = {widget.initialSelectedPartIndex!};
    } else {
      _selectedIndices = widget.clips.map((c) => c.partIndex).toSet();
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndices.length == widget.clips.length) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(widget.clips.map((c) => c.partIndex));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalClips = widget.clips.length;
    final selectedCount = _selectedIndices.length;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Convert to 9:16 Shorts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transform split clips into vertical 9:16 format with auto part labels ({n}/{total}) and background styling.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // 1. Clips Selection Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Clips to Convert ($selectedCount of $totalClips)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _toggleSelectAll,
                    child: Text(
                      selectedCount == totalClips
                          ? 'Deselect All'
                          : 'Select All',
                    ),
                  ),
                ],
              ),
              if (widget.clips.length > 1) ...[
                Material(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final clip in widget.clips)
                            CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                'Part ${clip.partIndex} (${clip.formattedDuration})',
                                style: const TextStyle(fontSize: 12),
                              ),
                              value: _selectedIndices.contains(clip.partIndex),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIndices.add(clip.partIndex);
                                  } else {
                                    _selectedIndices.remove(clip.partIndex);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Canvas Format Selection
              Text(
                'Target Canvas Format',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<CanvasFormat>(
                segments: const [
                  ButtonSegment(
                    value: CanvasFormat.shorts916,
                    label: Text('9:16 Vertical'),
                    icon: Icon(Icons.stay_current_portrait_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: CanvasFormat.square11,
                    label: Text('1:1 Square'),
                    icon: Icon(Icons.crop_square_rounded, size: 16),
                  ),
                ],
                selected: {_canvasFormat},
                onSelectionChanged: (val) =>
                    setState(() => _canvasFormat = val.first),
              ),
              const SizedBox(height: 16),

              // 3. Background Style Selection
              Text(
                'Background Style',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Blurred Background'),
                    avatar: const Icon(Icons.blur_on_rounded, size: 16),
                    selected: _backgroundType == 'blur',
                    onSelected: (_) => setState(() => _backgroundType = 'blur'),
                  ),
                  ChoiceChip(
                    label: const Text('Black Padding'),
                    avatar: const Icon(Icons.crop_original_rounded, size: 16),
                    selected: _backgroundType == 'black',
                    onSelected: (_) =>
                        setState(() => _backgroundType = 'black'),
                  ),
                  ChoiceChip(
                    label: const Text('Crop to Fill'),
                    avatar: const Icon(Icons.crop_rounded, size: 16),
                    selected: _backgroundType == 'crop',
                    onSelected: (_) => setState(() => _backgroundType = 'crop'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Part Label Overlay
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Part Number Label',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Displays "Part 1/$totalClips" on each clip',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _addPartLabel,
                    onChanged: (val) => setState(() => _addPartLabel = val),
                  ),
                ],
              ),
              if (_addPartLabel) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Position: ', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    DropdownButton<OverlayPosition>(
                      value: _labelPosition,
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                          value: OverlayPosition.topCenter,
                          child: Text(
                            'Top Center',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        DropdownMenuItem(
                          value: OverlayPosition.topRight,
                          child: Text(
                            'Top Right',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        DropdownMenuItem(
                          value: OverlayPosition.bottomCenter,
                          child: Text(
                            'Bottom Center',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                      onChanged: (pos) {
                        if (pos != null) setState(() => _labelPosition = pos);
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // 5. File Output Strategy
              Text(
                'Output File Handling',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<ReplaceStrategy>(
                segments: const [
                  ButtonSegment(
                    value: ReplaceStrategy.replace,
                    label: Text('Replace Original'),
                    icon: Icon(Icons.sync_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: ReplaceStrategy.keepBoth,
                    label: Text('Keep Both'),
                    icon: Icon(Icons.copy_rounded, size: 16),
                  ),
                ],
                selected: {_replaceStrategy},
                onSelectionChanged: (val) =>
                    setState(() => _replaceStrategy = val.first),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.movie_filter_rounded, size: 18),
          label: Text('Convert ($selectedCount Shorts)'),
          onPressed: selectedCount == 0
              ? null
              : () {
                  final canvasSpec = switch (_canvasFormat) {
                    CanvasFormat.square11 => const CanvasSpec(
                        format: CanvasFormat.square11,
                      ),
                    _ => const CanvasSpec(
                        format: CanvasFormat.shorts916,
                      ),
                  };

                  final backgroundSpec = switch (_backgroundType) {
                    'blur' => const BlurBackgroundSpec(),
                    'black' =>
                      const SolidColorBackgroundSpec(colorValue: 0xFF000000),
                    _ => const SolidColorBackgroundSpec(colorValue: 0xFFFFFFFF),
                  };

                  final overlaySpec = OverlaySpec(
                    autoLabel: _addPartLabel,
                    partLabelMode: _addPartLabel
                        ? PartLabelMode.auto
                        : PartLabelMode.never,
                    position: _labelPosition,
                  );

                  final config = SplitConfig(
                    canvasSpec: canvasSpec,
                    backgroundSpec: backgroundSpec,
                    overlaySpec: overlaySpec,
                    cropToFill: _backgroundType == 'crop',
                    mode: SplitMode.precise,
                  );

                  final sortedIndices = _selectedIndices.toList()..sort();
                  Navigator.of(context).pop(
                    ConvertToShortsParams(
                      selectedPartIndices: sortedIndices,
                      config: config,
                      replaceStrategy: _replaceStrategy,
                    ),
                  );
                },
        ),
      ],
    );
  }
}
