import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../history/data/drift_dashboard_stats_repository.dart';
import '../../../history/data/drift_project_repository.dart';
import '../../../history/data/shared_prefs_history_repository.dart';
import '../../../history/domain/models/project_record.dart';
import '../../../plan_review/presentation/controllers/plan_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../domain/models/dashboard_stats.dart';

class DashboardState {
  final DashboardStats stats;
  final List<ProjectRecord> recentProjects;
  final bool hasUnfinishedPlan;
  final String? unfinishedVideoName;
  final bool isTipsDismissed;

  const DashboardState({
    this.stats = const DashboardStats(),
    this.recentProjects = const [],
    this.hasUnfinishedPlan = false,
    this.unfinishedVideoName,
    this.isTipsDismissed = false,
  });

  DashboardState copyWith({
    DashboardStats? stats,
    List<ProjectRecord>? recentProjects,
    bool? hasUnfinishedPlan,
    String? unfinishedVideoName,
    bool? isTipsDismissed,
  }) {
    return DashboardState(
      stats: stats ?? this.stats,
      recentProjects: recentProjects ?? this.recentProjects,
      hasUnfinishedPlan: hasUnfinishedPlan ?? this.hasUnfinishedPlan,
      unfinishedVideoName: unfinishedVideoName ?? this.unfinishedVideoName,
      isTipsDismissed: isTipsDismissed ?? this.isTipsDismissed,
    );
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);

class DashboardController extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() async {
    final statsRepo = ref.watch(dashboardStatsRepositoryProvider);
    final driftStats = await statsRepo.getStats();

    final projectRepo = ref.watch(projectRepositoryProvider);
    final dbProjects = await projectRepo.getAllProjects();

    final plan = ref.watch(planReviewControllerProvider);

    final DashboardStats stats;
    final List<ProjectRecord> recents;

    if (driftStats.totalProjects > 0) {
      stats = DashboardStats(
        totalVideosProcessed: driftStats.totalProjects,
        totalShortsCreated: driftStats.totalPartsConverted > 0
            ? driftStats.totalPartsConverted
            : driftStats.totalPartsSplit,
        totalDurationSeconds: driftStats.totalDurationSeconds,
        totalStorageBytes: driftStats.totalBytesWritten,
      );

      recents = dbProjects.take(5).map((p) {
        return ProjectRecord(
          id: p.project.id,
          videoName: p.source.displayName,
          baseName: p.source.displayName.replaceAll(RegExp(r'\.[^.]+$'), ''),
          totalDurationSeconds: p.source.durationSeconds,
          totalShortsCount: p.project.totalPartsCount,
          processedShortsCount:
              p.convertedCount > 0 ? p.convertedCount : p.splitCount,
          canvasFormat: 'Shorts 9:16',
          createdAt:
              DateTime.fromMillisecondsSinceEpoch(p.project.createdAt.toInt()),
          outputFilePaths: p.parts
              .map((part) => part.outputUriOrPath)
              .where((path) => path != null && path.isNotEmpty)
              .cast<String>()
              .toList(),
        );
      }).toList();
    } else {
      // Legacy fallback
      final historyRepo = ref.watch(historyRepositoryProvider);
      final legacyProjects = await historyRepo.getProjects();
      stats = DashboardStats.fromProjects(legacyProjects);
      recents = legacyProjects.take(5).toList();
    }

    return DashboardState(
      stats: stats,
      recentProjects: recents,
      hasUnfinishedPlan: plan != null && plan.items.isNotEmpty,
      unfinishedVideoName: plan?.baseName,
    );
  }

  Future<void> refresh() async {
    ref.invalidate(settingsControllerProvider);
    ref.invalidateSelf();
  }

  void dismissTips() {
    state = state.whenData((s) => s.copyWith(isTipsDismissed: true));
  }
}
