import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/models/merge_project.dart';

/// Reorderable tile representing a single video clip inside the merge sequence.
class MergeClipTile extends StatelessWidget {
  final int index;
  final MergeClipItem clip;
  final VoidCallback onTrimPressed;
  final VoidCallback onDuplicatePressed;
  final VoidCallback onDeletePressed;

  const MergeClipTile({
    super.key,
    required this.index,
    required this.clip,
    required this.onTrimPressed,
    required this.onDuplicatePressed,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTrimmed = clip.startTrimSeconds > 0 || clip.endTrimSeconds != null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.spaceXs),
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusMd,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXs,
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.spaceSm),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clip.fileName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: AppTokens.spaceXs,
                    runSpacing: 2,
                    children: [
                      _badge(
                        context,
                        clip.formattedDuration,
                        Icons.timer_outlined,
                      ),
                      _badge(
                        context,
                        clip.resolutionString,
                        Icons.aspect_ratio_rounded,
                      ),
                      if (!clip.hasAudio)
                        _badge(
                          context,
                          'Silent',
                          Icons.volume_off_rounded,
                          color: colorScheme.error,
                        ),
                      if (isTrimmed)
                        _badge(
                          context,
                          'Trimmed',
                          Icons.content_cut_rounded,
                          color: colorScheme.tertiary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.content_cut_rounded,
                size: AppTokens.iconSm,
              ),
              tooltip: 'Trim Clip',
              onPressed: onTrimPressed,
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: AppTokens.iconSm),
              tooltip: 'Duplicate',
              onPressed: onDuplicatePressed,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                size: AppTokens.iconSm,
                color: colorScheme.error,
              ),
              tooltip: 'Remove',
              onPressed: onDeletePressed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(
    BuildContext context,
    String label,
    IconData icon, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: badgeColor),
        const SizedBox(width: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: badgeColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
