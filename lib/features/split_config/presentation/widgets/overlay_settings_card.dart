import 'package:flutter/material.dart';

import '../../domain/models/overlay_spec.dart';

/// Configuration card for text overlays, part auto-labels, and safe area positioning.
class OverlaySettingsCard extends StatelessWidget {
  final OverlaySpec overlaySpec;
  final ValueChanged<OverlaySpec> onOverlayChanged;

  const OverlaySettingsCard({
    super.key,
    required this.overlaySpec,
    required this.onOverlayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            Text(
              'Part Numbering Label',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              overlaySpec.partLabelMode.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<PartLabelMode>(
                segments: const [
                  ButtonSegment<PartLabelMode>(
                    value: PartLabelMode.auto,
                    label: Text('Auto'),
                    icon: Icon(Icons.auto_awesome, size: 16),
                  ),
                  ButtonSegment<PartLabelMode>(
                    value: PartLabelMode.always,
                    label: Text('Always'),
                    icon: Icon(Icons.check_circle_outline, size: 16),
                  ),
                  ButtonSegment<PartLabelMode>(
                    value: PartLabelMode.never,
                    label: Text('Never'),
                    icon: Icon(Icons.block_outlined, size: 16),
                  ),
                ],
                selected: {overlaySpec.partLabelMode},
                onSelectionChanged: (newSelection) {
                  onOverlayChanged(
                    overlaySpec.copyWith(partLabelMode: newSelection.first),
                  );
                },
              ),
            ),
            if (overlaySpec.partLabelMode != PartLabelMode.never) ...[
              const SizedBox(height: 16),
              _buildTemplateInput(context),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Text(
                'Overlay Safe Position',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Guarantees text remains inside YouTube Shorts & Reels safe zones.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _buildPositionSelector(),
              const SizedBox(height: 16),
              _buildTimingSwitch(theme, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateInput(BuildContext context) {
    return TextFormField(
      initialValue: overlaySpec.template,
      decoration: const InputDecoration(
        labelText: 'Label Template',
        hintText: 'Part {n}/{total}',
        isDense: true,
        border: OutlineInputBorder(),
        helperText: 'Available tokens: {n}, {total}, {name}',
      ),
      onChanged: (val) {
        onOverlayChanged(overlaySpec.copyWith(template: val));
      },
    );
  }

  Widget _buildPositionSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: OverlayPosition.values.map((pos) {
        final isSelected = overlaySpec.position == pos;
        return ChoiceChip(
          label: Text(pos.label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              onOverlayChanged(overlaySpec.copyWith(position: pos));
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildTimingSwitch(ThemeData theme, ColorScheme colorScheme) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Display Timing'),
      subtitle: Text(
        overlaySpec.displayWholeClip
            ? 'Visible throughout entire clip'
            : 'Fades after first ${overlaySpec.displayDurationSeconds.toStringAsFixed(0)}s',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      value: overlaySpec.displayWholeClip,
      onChanged: (val) {
        onOverlayChanged(overlaySpec.copyWith(displayWholeClip: val));
      },
    );
  }
}
