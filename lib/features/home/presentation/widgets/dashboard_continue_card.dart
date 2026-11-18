import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../plan_review/presentation/controllers/plan_controller.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';

/// Card showing option to resume or discard an in-progress plan.
class DashboardContinueCard extends ConsumerWidget {
  final String videoName;

  const DashboardContinueCard({super.key, required this.videoName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: AppTokens.borderRadiusLg,
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, color: colorScheme.primary),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  AppStrings.dashContinueTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            'Ready to export: $videoName',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ref.read(videoPickerControllerProvider.notifier).clear();
                  ref.invalidate(planReviewControllerProvider);
                },
                child: const Text(AppStrings.actionDiscard),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              FilledButton(
                onPressed: () => context.push(AppRoutes.planReview),
                child: const Text(AppStrings.actionContinue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
