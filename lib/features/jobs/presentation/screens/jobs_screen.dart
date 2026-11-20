import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../domain/job_queue_controller.dart';
import '../../domain/models/job_record.dart';

enum _JobFilter { all, active, completed, failed }

/// Screen presenting the unified studio job queue, live execution progress,
/// queued tasks, and historical results.
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  _JobFilter _filter = _JobFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final queueState = ref.watch(jobQueueControllerProvider);
    final queueController = ref.read(jobQueueControllerProvider.notifier);

    final filteredJobs = switch (_filter) {
      _JobFilter.all => queueState.jobs,
      _JobFilter.active =>
        queueState.jobs.where((j) => j.status.isActive).toList(),
      _JobFilter.completed =>
        queueState.jobs.where((j) => j.status == JobStatus.completed).toList(),
      _JobFilter.failed => queueState.jobs
          .where(
            (j) =>
                j.status == JobStatus.failed || j.status == JobStatus.cancelled,
          )
          .toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio Jobs & Queue'),
        actions: [
          if (queueState.completedJobs.isNotEmpty)
            IconButton(
              tooltip: 'Clear Completed Jobs',
              icon: const Icon(Icons.cleaning_services_rounded),
              onPressed: () => queueController.clearCompleted(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceLg,
              vertical: AppTokens.spaceSm,
            ),
            child: SegmentedButton<_JobFilter>(
              segments: const [
                ButtonSegment(
                  value: _JobFilter.all,
                  label: Text('All'),
                  icon: Icon(Icons.list_rounded),
                ),
                ButtonSegment(
                  value: _JobFilter.active,
                  label: Text('Active'),
                  icon: Icon(Icons.pending_actions_rounded),
                ),
                ButtonSegment(
                  value: _JobFilter.completed,
                  label: Text('Done'),
                  icon: Icon(Icons.check_circle_outline_rounded),
                ),
                ButtonSegment(
                  value: _JobFilter.failed,
                  label: Text('Failed'),
                  icon: Icon(Icons.error_outline_rounded),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (set) => setState(() => _filter = set.first),
            ),
          ),
          const Divider(height: 1),

          // Content List
          Expanded(
            child: filteredJobs.isEmpty
                ? EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No Jobs in this View',
                    message: _filter == _JobFilter.all
                        ? 'Studio export jobs will appear here as you create or edit media.'
                        : 'No jobs currently match the selected filter.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppTokens.spaceLg),
                    itemCount: filteredJobs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTokens.spaceMd),
                    itemBuilder: (context, index) {
                      final job = filteredJobs[index];
                      return _buildJobCard(
                        context,
                        job,
                        queueController,
                        colorScheme,
                        theme,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(
    BuildContext context,
    JobRecord job,
    JobQueueController controller,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final statusColor = switch (job.status) {
      JobStatus.running => colorScheme.primary,
      JobStatus.queued => colorScheme.tertiary,
      JobStatus.completed => Colors.green,
      JobStatus.failed => colorScheme.error,
      JobStatus.cancelled => colorScheme.outline,
    };

    final statusIcon = switch (job.status) {
      JobStatus.running => Icons.sync_rounded,
      JobStatus.queued => Icons.hourglass_top_rounded,
      JobStatus.completed => Icons.check_circle_rounded,
      JobStatus.failed => Icons.error_rounded,
      JobStatus.cancelled => Icons.cancel_rounded,
    };

    return SectionCard(
      title: job.title,
      icon: _getJobTypeIcon(job.type),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Text(
              job.status.name.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.currentStepMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          if (job.status == JobStatus.running ||
              job.status == JobStatus.queued) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: LinearProgressIndicator(
                value: job.status == JobStatus.running
                    ? job.overallProgress
                    : null,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(job.overallProgress * 100).toInt()}% completed',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  'Part ${job.currentPart}/${job.totalParts}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ],
          if (job.errorMessage != null) ...[
            const SizedBox(height: AppTokens.spaceSm),
            Text(
              job.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppTokens.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.formatRelativeTime(job.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
              Row(
                children: [
                  if (job.status.isActive)
                    TextButton.icon(
                      icon: const Icon(Icons.stop_rounded, size: 16),
                      label: const Text('Cancel'),
                      onPressed: () => controller.cancelJob(job.id),
                    )
                  else if (job.status == JobStatus.failed ||
                      job.status == JobStatus.cancelled)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      onPressed: () => controller.retryJob(job.id),
                    )
                  else if (job.status == JobStatus.completed)
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('View Results'),
                      onPressed: () {
                        context.push(AppRoutes.results);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    tooltip: 'Remove',
                    onPressed: () => controller.removeJob(job.id),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getJobTypeIcon(JobType type) {
    return switch (type) {
      JobType.shortsSplit => Icons.vertical_split_rounded,
      JobType.customSplit => Icons.call_split_rounded,
      JobType.editExport => Icons.movie_filter_rounded,
      JobType.convert => Icons.transform_rounded,
      JobType.audioStudio => Icons.multitrack_audio_rounded,
      JobType.screenshot => Icons.camera_alt_rounded,
      JobType.merge => Icons.join_inner_rounded,
    };
  }
}
