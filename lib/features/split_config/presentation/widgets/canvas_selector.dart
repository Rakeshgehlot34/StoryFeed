import 'package:flutter/material.dart';

import '../../domain/models/canvas_spec.dart';

/// Selector for output canvas aspect ratio and explicit crop-to-fill toggle.
class CanvasSelector extends StatelessWidget {
  final CanvasSpec selectedCanvas;
  final bool cropToFill;
  final ValueChanged<CanvasSpec> onCanvasChanged;
  final ValueChanged<bool> onCropToFillChanged;

  const CanvasSelector({
    super.key,
    required this.selectedCanvas,
    required this.cropToFill,
    required this.onCanvasChanged,
    required this.onCropToFillChanged,
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
          ],
        ),
      ),
    );
  }
}
