import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/constants/app_strings.dart';
import '../../app/theme/app_tokens.dart';
import '../../features/jobs/domain/job_queue_controller.dart';
import '../../features/processing/domain/models/processing_progress.dart';
import '../../features/processing/presentation/controllers/processing_controller.dart';

/// Adaptive scaffold providing NavigationBar on compact mobile and NavigationRail on wide screens.
class AppScaffold extends ConsumerWidget {
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int>? onDestinationSelected;

  const AppScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    this.onDestinationSelected,
  });

  void _handleDestinationSelected(BuildContext context, int index) {
    if (onDestinationSelected != null) {
      onDestinationSelected!(index);
      return;
    }
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.create);
        break;
      case 2:
        context.go(AppRoutes.jobs);
        break;
      case 3:
        context.go(AppRoutes.history);
        break;
      case 4:
        context.go(AppRoutes.settings);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppTokens.breakpointCompact;
    final progress = ref.watch(processingControllerProvider);
    final queueState = ref.watch(jobQueueControllerProvider);
    final isBusy = progress.isProcessing || queueState.isProcessing;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (idx) =>
                  _handleDestinationSelected(context, idx),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTokens.spaceMd,
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(
                    Icons.content_cut_rounded,
                    color: Colors.white,
                    size: AppTokens.iconMd,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: Text(AppStrings.navHome),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.add_circle_outline_rounded),
                  selectedIcon: Icon(Icons.add_circle_rounded),
                  label: Text(AppStrings.navCreate),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment_rounded),
                  label: Text(AppStrings.navJobs),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_rounded),
                  selectedIcon: Icon(Icons.history_toggle_off_rounded),
                  label: Text(AppStrings.navHistory),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text(AppStrings.navSettings),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: body),
                  if (isBusy)
                    _buildMiniProgressBanner(context, progress, queueState),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(child: body),
          if (isBusy) _buildMiniProgressBanner(context, progress, queueState),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (idx) =>
            _handleDestinationSelected(context, idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: AppStrings.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: AppStrings.navCreate,
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: AppStrings.navJobs,
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_toggle_off_rounded),
            label: AppStrings.navHistory,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: AppStrings.navSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProgressBanner(
    BuildContext context,
    ProcessingProgress progress,
    JobQueueState queueState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String bannerText;
    final double indicatorProgress;

    if (queueState.activeJob != null) {
      final active = queueState.activeJob!;
      final pct = (active.progress * 100).toInt();
      bannerText = '${active.title} ($pct%)';
      indicatorProgress = active.progress;
    } else {
      final pct = (progress.overallProgress * 100).toInt();
      bannerText =
          'Exporting Clip ${progress.currentClipIndex}/${progress.totalClips} ($pct%)';
      indicatorProgress = progress.overallProgress;
    }

    return Material(
      color: colorScheme.primaryContainer,
      elevation: 3,
      child: InkWell(
        onTap: () => context.push(AppRoutes.jobs),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  value: indicatorProgress > 0 ? indicatorProgress : null,
                  strokeWidth: 2,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  bannerText,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'View',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
