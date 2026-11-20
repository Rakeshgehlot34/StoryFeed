import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/models/clip_segment.dart';
import '../../domain/models/split_config.dart';

class SplitSummaryCard extends StatefulWidget {
  final Duration totalDuration;
  final SplitConfig config;
  final String baseName;
  final ValueChanged<bool> onMergeToggle;

  const SplitSummaryCard({
    super.key,
    required this.totalDuration,
    required this.config,
    required this.baseName,
    required this.onMergeToggle,
  });

  @override
  State<SplitSummaryCard> createState() => _SplitSummaryCardState();
}

class _SplitSummaryCardState extends State<SplitSummaryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalVideoSeconds = widget.totalDuration.inMilliseconds / 1000.0;
    final trimStart = widget.config.trimRange?.startSeconds ?? 0.0;
    final trimEnd = widget.config.trimRange?.endSeconds ?? totalVideoSeconds;
    final activeDuration = (trimEnd - trimStart).clamp(0.0, totalVideoSeconds);
    final isTrimmed = widget.config.trimRange != null &&
        (trimStart > 0.05 || (totalVideoSeconds - trimEnd).abs() > 0.05);

    final segments = ClipSegment.calculateSegments(
      totalDurationSeconds: activeDuration,
      startOffsetSeconds: trimStart,
      targetClipDurationSeconds: widget.config.targetDurationSeconds,
      mergeShortTrailingClip: widget.config.mergeShortTrailingClip,
      baseName: widget.baseName,
    );

    final summaryText = _buildSummaryText(
      activeDuration,
      segments,
      isTrimmed: isTrimmed,
    );

    return Card(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Planned Split Summary',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live breakdown text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                summaryText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Merge trailing clip toggle
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Merge trailing clip under 3s'),
              subtitle: Text(
                'Prevents exporting tiny leftover clips (e.g. 1-2 sec) by appending to previous clip.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: widget.config.mergeShortTrailingClip,
              onChanged: widget.onMergeToggle,
            ),

            const Divider(),

            // Expandable clips list preview
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Preview ${segments.length} Planned ${segments.length == 1 ? 'Clip' : 'Clips'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),

            if (_isExpanded) ...[
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: segments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final seg = segments[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            '${seg.index}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seg.formattedName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                seg.formattedTimeRange +
                                    (seg.isMergedTrailing
                                        ? ' (Merged remainder)'
                                        : ''),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildSummaryText(
    double totalSeconds,
    List<ClipSegment> segments, {
    bool isTrimmed = false,
  }) {
    if (segments.isEmpty) return 'No clips planned.';

    final totalFormatted = Formatters.formatSeconds(totalSeconds);
    final count = segments.length;
    final targetSec = widget.config.targetDurationSeconds;
    final prefix =
        isTrimmed ? 'Trimmed $totalFormatted' : 'Video $totalFormatted';

    if (count == 1) {
      final clipSec = segments.first.durationSeconds.round();
      return '$prefix → 1 clip of ${clipSec}s';
    }

    final lastSegment = segments.last;
    final lastSec = lastSegment.durationSeconds.round();

    if (lastSegment.isMergedTrailing) {
      return '$prefix → $count clips of ${targetSec}s (last clip extended to ${lastSec}s)';
    } else if (lastSec != targetSec) {
      return '$prefix → $count clips of ${targetSec}s (last clip ${lastSec}s)';
    } else {
      return '$prefix → $count clips of ${targetSec}s';
    }
  }
}
