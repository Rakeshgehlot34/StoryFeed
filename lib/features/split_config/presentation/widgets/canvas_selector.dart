import 'package:flutter/material.dart';

import '../../domain/models/canvas_spec.dart';
import '../../domain/models/fit_layout.dart';

/// Selector for output canvas aspect ratio, crop-to-fill, and vertical alignment.
class CanvasSelector extends StatelessWidget {
  final CanvasSpec selectedCanvas;
  final bool cropToFill;
  final VerticalPosition verticalPosition;
  final double verticalOffsetFraction;
  final ValueChanged<CanvasSpec> onCanvasChanged;
  final ValueChanged<bool> onCropToFillChanged;
  final ValueChanged<VerticalPosition> onVerticalPositionChanged;
  final ValueChanged<double> onVerticalOffsetChanged;

  const CanvasSelector({
    super.key,
    required this.selectedCanvas,
    required this.cropToFill,
    this.verticalPosition = VerticalPosition.center,
    this.verticalOffsetFraction = 0.0,
    required this.onCanvasChanged,
    required this.onCropToFillChanged,
    required this.onVerticalPositionChanged,
    required this.onVerticalOffsetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warning = selectedCanvas.warningMessage;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CanvasFormat.values.map((format) {
                final isSelected = selectedCanvas.format == format;
                return ChoiceChip(
                  label: Text(format.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      onCanvasChanged(CanvasSpec(format: format));
                    }
                  },
                );
              }).toList(),
            ),
            if (warning != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Crop to Fill Canvas'),
              subtitle: Text(
                cropToFill
                    ? 'Zooms & crops video edges to fill canvas bleed.'
                    : 'Scales to fit without cropping (adds background fill).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: cropToFill,
              onChanged: onCropToFillChanged,
            ),
            if (!cropToFill) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Vertical Position',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<VerticalPosition>(
                  segments: const [
                    ButtonSegment(
                      value: VerticalPosition.top,
                      label: Text('Top'),
                      icon: Icon(Icons.vertical_align_top_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: VerticalPosition.center,
                      label: Text('Center'),
                      icon: Icon(Icons.vertical_align_center_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: VerticalPosition.bottom,
                      label: Text('Bottom'),
                      icon: Icon(Icons.vertical_align_bottom_rounded, size: 16),
                    ),
                  ],
                  selected: {verticalPosition},
                  onSelectionChanged: (newSelection) {
                    onVerticalPositionChanged(newSelection.first);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vertical Offset: ${(verticalOffsetFraction * 100).round()}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (verticalOffsetFraction != 0.0)
                    TextButton(
                      onPressed: () => onVerticalOffsetChanged(0.0),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Reset'),
                    ),
                ],
              ),
              Slider(
                value: verticalOffsetFraction,
                min: -0.20,
                max: 0.20,
                divisions: 20,
                label: '${(verticalOffsetFraction * 100).round()}%',
                onChanged: onVerticalOffsetChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
