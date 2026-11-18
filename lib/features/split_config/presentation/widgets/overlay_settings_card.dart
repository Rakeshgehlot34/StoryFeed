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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto Part Labels'),
              subtitle: Text(
                'Overlays sequentially numbered label on clips.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: overlaySpec.autoLabel,
              onChanged: (val) {
                onOverlayChanged(overlaySpec.copyWith(autoLabel: val));
              },
            ),
            if (overlaySpec.autoLabel) ...[
              const SizedBox(height: 8),
              _buildTemplateInput(context),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('Overlay Safe Position', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            _buildPositionSelector(),
            const SizedBox(height: 12),
            _buildTimingSwitch(theme, colorScheme),
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
