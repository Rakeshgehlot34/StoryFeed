import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/permission_utils.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../jobs/domain/job_queue_controller.dart';
import '../../../jobs/domain/models/job_record.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../processing/domain/export_job_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/creator_tips_carousel.dart';
import '../widgets/dashboard_continue_card.dart';
import '../widgets/dashboard_stats_grid.dart';
import '../widgets/greeting_header.dart';
import '../widgets/recent_projects_section.dart';
import '../widgets/studio_tools_grid.dart';

/// Primary Home Hub screen featuring 7 studio tools, active queue tracking,
/// recent projects, and quick storage management.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(dashboardControllerProvider);
    final outputDirAsync = ref.watch(outputDirectoryProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => controller.refresh(),
          child: stateAsync.when(
            loading: () => _buildLoadingState(),
            error: (err, _) => ErrorState(
              message: err.toString(),
              onRetry: () => controller.refresh(),
            ),
            data: (state) =>
                _buildContent(context, ref, state, outputDirAsync, controller),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      children: [
        LoadingSkeleton.card(height: 50),
        const SizedBox(height: AppTokens.spaceLg),
        LoadingSkeleton.card(height: 140),
        const SizedBox(height: AppTokens.spaceLg),
        LoadingSkeleton.card(height: 160),
        const SizedBox(height: AppTokens.spaceLg),
        LoadingSkeleton.tile(),
        const SizedBox(height: AppTokens.spaceSm),
        LoadingSkeleton.tile(),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DashboardState state,
    AsyncValue<String> outputDirAsync,
    DashboardController controller,
  ) {
    final queueState = ref.watch(jobQueueControllerProvider);
    final legacyJobState = ref.watch(exportJobControllerProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull;
    final hasStoragePermission = settings?.hasStoragePermission ?? true;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceLg,
        vertical: AppTokens.spaceMd,
      ),
      children: [
        const GreetingHeader(),
        if (!hasStoragePermission) ...[
          const SizedBox(height: AppTokens.spaceMd),
          InfoBanner(
            message:
                'Storage & media permission required to access and export videos.',
            type: InfoBannerType.warning,
            trailing: TextButton(
              onPressed: () async {
                await PermissionUtils.requestAllAppPermissions(
                  context: context,
                );
                ref.invalidate(settingsControllerProvider);
              },
              child: const Text('Grant'),
            ),
          ),
        ],
        if (queueState.activeJob != null) ...[
          const SizedBox(height: AppTokens.spaceLg),
          _buildActiveJobCard(context, queueState.activeJob!),
        ] else if (legacyJobState.isExporting) ...[
          const SizedBox(height: AppTokens.spaceLg),
          _buildLegacyExportCard(context, legacyJobState),
        ],
        if (legacyJobState.hasInterruptedJob &&
            !legacyJobState.isExporting &&
            queueState.activeJob == null) ...[
          const SizedBox(height: AppTokens.spaceLg),
          // Discard or resume interrupted export if one was left behind
          _buildInterruptedJobCard(
            context,
            ref,
            legacyJobState.interruptedJob as ExportJobRecord,
          ),
        ],
        const SizedBox(height: AppTokens.spaceLg),
        const StudioToolsGrid(),
        if (state.hasUnfinishedPlan && state.unfinishedVideoName != null) ...[
          const SizedBox(height: AppTokens.spaceXl),
          DashboardContinueCard(videoName: state.unfinishedVideoName ?? ''),
        ],
        const SizedBox(height: AppTokens.spaceXl),
        DashboardStatsGrid(stats: state.stats),
        const SizedBox(height: AppTokens.spaceXl),
        RecentProjectsSection(projects: state.recentProjects),
        const SizedBox(height: AppTokens.spaceLg),
        _buildSaveLocationCard(context, ref, outputDirAsync),
        if (!state.isTipsDismissed) ...[
          const SizedBox(height: AppTokens.spaceLg),
          CreatorTipsCarousel(onDismiss: () => controller.dismissTips()),
        ],
        const SizedBox(height: AppTokens.spaceXxl),
      ],
    );
  }

  Widget _buildActiveJobCard(BuildContext context, JobRecord job) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pct = (job.progress * 100).toInt();

    return Card(
      elevation: 2,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusLg,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: job.progress > 0 ? job.progress : null,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    job.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$pct%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),
            LinearProgressIndicator(
              value: job.progress > 0 ? job.progress : null,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.assignment_rounded, size: 16),
                  label: const Text('View Queue'),
                  onPressed: () => context.push(AppRoutes.jobs),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyExportCard(BuildContext context, ExportJobState jobState) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = jobState.progress;
    final pct = (progress.overallProgress * 100).toInt();

    return Card(
      elevation: 2,
      color: colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusLg,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    'Exporting Clip ${progress.currentClipIndex} of ${progress.totalClips}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),
            LinearProgressIndicator(
              value: progress.overallProgress > 0
                  ? progress.overallProgress
                  : null,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    progress.currentClipName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('View Progress'),
                  onPressed: () => context.push(AppRoutes.processing),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterruptedJobCard(
    BuildContext context,
    WidgetRef ref,
    ExportJobRecord record,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      color: colorScheme.errorContainer.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.borderRadiusLg,
        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: Text(
                    'Interrupted Export Detected',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Export of "${record.videoFileName}" was halted (${record.completedClips.length}/${record.totalClips} completed). Would you like to resume remaining clips?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: record.totalClips > 0
                    ? record.completedClips.length / record.totalClips
                    : null,
                minHeight: 4,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    ref
                        .read(exportJobControllerProvider.notifier)
                        .discardInterruptedJob();
                  },
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Resume Export'),
                  onPressed: () async {
                    unawaited(context.push(AppRoutes.processing));
                    await ref
                        .read(exportJobControllerProvider.notifier)
                        .resumeInterruptedJob();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveLocationCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<String> outputDirAsync,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppTokens.borderRadiusLg,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, color: colorScheme.primary, size: 20),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.dashSaveLocation,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                outputDirAsync.when(
                  loading: () => const Text('Loading...'),
                  error: (_, __) => const Text('Default Directory'),
                  data: (path) => Text(
                    path,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(outputDirectoryProvider.notifier).pickAndSetDirectory();
            },
            child: const Text(AppStrings.actionChange),
          ),
        ],
      ),
    );
  }
}
