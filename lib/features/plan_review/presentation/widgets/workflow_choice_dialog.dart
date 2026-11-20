import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';

enum SplitWorkflowType {
  twoStage,
  singleStep,
}

class WorkflowChoiceDialog extends StatelessWidget {
  final int totalParts;
  final double totalDurationSeconds;

  const WorkflowChoiceDialog({
    super.key,
    required this.totalParts,
    required this.totalDurationSeconds,
  });

  bool get isTwoStageRecommended =>
      totalDurationSeconds >= 1200 || totalParts >= 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.alt_route_rounded, size: 28),
          SizedBox(width: 12),
          Expanded(child: Text('Choose Export Workflow')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This project has $totalParts parts (${(totalDurationSeconds / 60).toStringAsFixed(1)} min). How would you like to process it?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _WorkflowOptionCard(
            title: 'Split and convert now (Precise 9:16 Shorts)',
            subtitle:
                '1-step export: Frame-accurate fixed-duration (3:00 max) vertical 9:16 Shorts with part labels ({n}/{total}) and background styling.',
            icon: Icons.auto_awesome_rounded,
            isRecommended: true,
            color: colorScheme.primary,
            onTap: () =>
                Navigator.of(context).pop(SplitWorkflowType.singleStep),
          ),
          const SizedBox(height: 12),
          _WorkflowOptionCard(
            title: 'Split first, convert later (Fast 2-Stage)',
            subtitle:
                'Super fast stream-copy split of raw video first. Saves raw clips instantly; convert chosen parts to 9:16 Shorts from the results page.\nNote: Stream-copy cuts snap to keyframes (±2-5s) before precise conversion.',
            icon: Icons.bolt_rounded,
            isRecommended: false,
            color: colorScheme.secondary,
            onTap: () => Navigator.of(context).pop(SplitWorkflowType.twoStage),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _WorkflowOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isRecommended;
  final Color color;
  final VoidCallback onTap;

  const _WorkflowOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isRecommended,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: isRecommended ? color : theme.colorScheme.outlineVariant,
            width: isRecommended ? 2.0 : 1.0,
          ),
          color: isRecommended
              ? color.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
