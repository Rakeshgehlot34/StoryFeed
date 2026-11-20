import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../domain/models/custom_clip_plan.dart';
import '../../domain/models/custom_split_config.dart';
import '../controllers/custom_split_controller.dart';

class CustomSplitPlanReviewScreen extends ConsumerWidget {
  const CustomSplitPlanReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splitState = ref.watch(customSplitControllerProvider);
    final controller = ref.read(customSplitControllerProvider.notifier);
    final plan = splitState.plan;

    if (plan == null || plan.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Split Plan')),
        body: EmptyState(
          icon: Icons.checklist_rtl_rounded,
          title: 'No Plan Configured',
          message:
              'Configure your custom split settings before reviewing the plan.',
          actionLabel: 'Go Back',
          onAction: () => context.pop(),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Split Plan')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              children: [
                _buildHeaderCard(context, plan),
                const SizedBox(height: AppTokens.spaceMd),
                if (plan.splitMethod == SplitMethod.fast) ...[
                  const InfoBanner(
                    message:
                        'Fast mode cuts snap to nearest keyframes. Boundaries may shift ~0.5s - 2.0s without re-encoding.',
                    type: InfoBannerType.warning,
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                ],
                Text(
                  'Planned Clips (${plan.totalParts})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                ...plan.items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return _buildClipItemTile(
                    context,
                    item,
                    idx,
                    plan,
                    controller,
                  );
                }),
                const SizedBox(height: AppTokens.spaceLg),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: PrimaryButton(
                label: 'Start Split (${plan.totalParts} Clips)',
                icon: Icons.flash_on_rounded,
                onPressed: () async {
                  try {
                    await controller.enqueueSplitJob();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Custom split queued! Running in background service...',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      context.go(AppRoutes.jobs);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to start split: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, CustomClipPlan plan) {
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Split Overview',
      icon: Icons.splitscreen_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.baseName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn('Total Clips', '${plan.totalParts}'),
              _buildMetricColumn(
                'Covered',
                Formatters.formatSeconds(plan.coveredDuration),
              ),
              _buildMetricColumn(
                'Est. Size',
                '~${Formatters.formatFileSize(plan.estimatedTotalSizeBytes)}',
              ),
              _buildMetricColumn(
                'Method',
                plan.splitMethod == SplitMethod.fast ? 'Fast' : 'Precise',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildClipItemTile(
    BuildContext context,
    CustomClipItem item,
    int index,
    CustomClipPlan plan,
    CustomSplitController controller,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLast = index == plan.items.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusMd,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    '${item.index}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    item.displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Rename Clip',
                  onPressed: () =>
                      _showRenameDialog(context, item, index, controller),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${Formatters.formatSeconds(item.startSeconds)} → ${Formatters.formatSeconds(item.endSeconds)} (${item.durationSeconds.toStringAsFixed(1)}s)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '~${Formatters.formatFileSize(item.estimatedSizeBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: AppTokens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isLast)
                  TextButton.icon(
                    icon: const Icon(Icons.merge_type_rounded, size: 16),
                    label: const Text('Merge Next'),
                    onPressed: () => controller.mergeWithNext(index),
                  ),
                if (item.durationSeconds >= 2.0)
                  TextButton.icon(
                    icon: const Icon(Icons.call_split_rounded, size: 16),
                    label: const Text('Split Half'),
                    onPressed: () {
                      final mid =
                          item.startSeconds + (item.durationSeconds / 2.0);
                      controller.splitClip(index, mid);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    CustomClipItem item,
    int index,
    CustomSplitController controller,
  ) {
    final textController = TextEditingController(text: item.displayName);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Clip'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                controller.updateClipCustomName(index, newName);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
