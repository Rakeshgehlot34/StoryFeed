import 'package:flutter/material.dart';

import '../../../../app/constants.dart';
import '../../../split_config/domain/models/clip_plan.dart';
import '../../domain/models/clip_processing_state.dart';

/// List tile representing an individual planned clip segment with quick editing actions,
/// selective checkbox, and live processing lifecycle status.
class PlanPartTile extends StatelessWidget {
  final ClipPlanItem item;
  final bool isLast;
  final ClipPlanItem? nextItem;
  final bool isSelected;
  final ClipProcessingStatus status;
  final ValueChanged<bool?>? onToggleSelect;
  final VoidCallback? onRetry;
  final VoidCallback onEditMessage;
  final VoidCallback? onAdjustBoundary;
  final VoidCallback? onMergeWithNext;
  final VoidCallback onSplitPart;

  const PlanPartTile({
    super.key,
    required this.item,
    required this.isLast,
    this.nextItem,
    this.isSelected = true,
    this.status = ClipProcessingStatus.notProcessed,
    this.onToggleSelect,
    this.onRetry,
    required this.onEditMessage,
    this.onAdjustBoundary,
    this.onMergeWithNext,
    required this.onSplitPart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canMerge =
        !isLast &&
        nextItem != null &&
        (item.durationSeconds + nextItem!.durationSeconds) <=
            AppConstants.maxClipDurationSeconds;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.6)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopRow(theme, colorScheme),
            const SizedBox(height: 8),
            _buildMessagePreview(theme, colorScheme),
            const SizedBox(height: 8),
            _buildActionButtons(theme, colorScheme, canMerge),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Checkbox(
          value: isSelected,
          onChanged: onToggleSelect,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 13,
          backgroundColor: colorScheme.secondaryContainer,
          child: Text(
            '${item.index}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.formattedTimeRange,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                item.formattedName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _buildStatusChip(theme, colorScheme),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            item.formattedDuration,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(ThemeData theme, ColorScheme colorScheme) {
    switch (status) {
      case ClipProcessingStatus.processed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 12, color: Colors.green),
              SizedBox(width: 3),
              Text(
                'Processed',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        );

      case ClipProcessingStatus.processing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Processing',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        );

      case ClipProcessingStatus.failed:
        return InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 12,
                  color: colorScheme.error,
                ),
                const SizedBox(width: 3),
                Text(
                  'Failed (Retry)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        );

      case ClipProcessingStatus.stale:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: Colors.amber),
              SizedBox(width: 3),
              Text(
                'Modified',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        );

      case ClipProcessingStatus.missing:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                size: 12,
                color: colorScheme.error,
              ),
              const SizedBox(width: 3),
              Text(
                'Missing',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
        );

      case ClipProcessingStatus.notProcessed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Not processed',
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        );
    }
  }

  Widget _buildMessagePreview(ThemeData theme, ColorScheme colorScheme) {
    final hasMessage =
        item.resolvedMessage != null && item.resolvedMessage!.isNotEmpty;
    return InkWell(
      onTap: onEditMessage,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.subtitles_outlined,
              size: 14,
              color: hasMessage
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                hasMessage
                    ? item.resolvedMessage!
                    : 'No overlay message (tap to add)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: hasMessage ? FontStyle.normal : FontStyle.italic,
                  color: hasMessage
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    ThemeData theme,
    ColorScheme colorScheme,
    bool canMerge,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.call_split_rounded, size: 18),
          tooltip: 'Split Part',
          onPressed: onSplitPart,
        ),
        if (!isLast) ...[
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 18),
            tooltip: 'Adjust Boundary with Next',
            onPressed: onAdjustBoundary,
          ),
          IconButton(
            icon: const Icon(Icons.merge_type_rounded, size: 18),
            tooltip: canMerge
                ? 'Merge with Next Part'
                : 'Cannot merge (would exceed 180s)',
            onPressed: canMerge ? onMergeWithNext : null,
          ),
        ],
        IconButton(
          icon: const Icon(Icons.edit_note_rounded, size: 20),
          tooltip: 'Edit Part Message',
          onPressed: onEditMessage,
        ),
      ],
    );
  }
}
