import 'package:flutter/material.dart';

import '../../domain/models/split_config.dart';

class ModeSelector extends StatelessWidget {
  final SplitMode selectedMode;
  final bool isReencodeForced;
  final ValueChanged<SplitMode> onModeChanged;

  const ModeSelector({
    super.key,
    required this.selectedMode,
    required this.isReencodeForced,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _ModeOptionCard(
                title: 'Fast',
                subtitle: 'No re-encode (Stream copy)\nNear-instant split',
                icon: Icons.bolt_rounded,
                isSelected: selectedMode == SplitMode.fast && !isReencodeForced,
                isEnabled: !isReencodeForced,
                onTap: isReencodeForced
                    ? null
                    : () => onModeChanged(SplitMode.fast),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModeOptionCard(
                title: 'Precise',
                subtitle: 'Frame-accurate cuts\nH.264 re-encode',
                icon: Icons.precision_manufacturing_outlined,
                isSelected:
                    selectedMode == SplitMode.precise || isReencodeForced,
                isEnabled: true,
                badgeText: isReencodeForced ? 'Required for 9:16' : null,
                onTap: () => onModeChanged(SplitMode.precise),
              ),
            ),
          ],
        ),
        if (isReencodeForced)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: colorScheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Vertical 9:16 crop or blur transforms require video re-encoding.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isEnabled;
  final String? badgeText;
  final VoidCallback? onTap;

  const _ModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isEnabled,
    this.badgeText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : (isEnabled
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    )),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? colorScheme.primary
                      : (isEnabled
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.outline),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? colorScheme.primary
                          : (isEnabled
                              ? colorScheme.onSurface
                              : colorScheme.outline),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isEnabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.outline,
                height: 1.25,
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
