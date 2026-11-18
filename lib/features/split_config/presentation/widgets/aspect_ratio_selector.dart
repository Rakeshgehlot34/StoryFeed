import 'package:flutter/material.dart';

import '../../domain/models/split_config.dart';

class AspectRatioSelector extends StatelessWidget {
  final AspectRatioOption selectedOption;
  final ValueChanged<AspectRatioOption> onOptionChanged;

  const AspectRatioSelector({
    super.key,
    required this.selectedOption,
    required this.onOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildOptionTile(
          context,
          option: AspectRatioOption.original,
          title: 'Keep Original',
          subtitle:
              'Preserves input dimensions & aspect ratio without modification.',
          icon: Icons.aspect_ratio,
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          context,
          option: AspectRatioOption.cropVertical,
          title: 'Crop to 9:16 Vertical',
          subtitle: 'Centers and crops video to full-bleed vertical (ideal for Shorts).',
          icon: Icons.crop_portrait_rounded,
        ),
        const SizedBox(height: 8),
        _buildOptionTile(
          context,
          option: AspectRatioOption.blurVertical,
          title: 'Blur-Background 9:16',
          subtitle: 'Fills 9:16 vertical canvas with blurred background & centered video.',
          icon: Icons.blur_on_rounded,
        ),
      ],
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required AspectRatioOption option,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = selectedOption == option;

    return InkWell(
      onTap: () => onOptionChanged(option),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? colorScheme.primary : colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
