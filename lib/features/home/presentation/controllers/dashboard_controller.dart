import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../history/data/shared_prefs_history_repository.dart';
import '../../../history/domain/models/project_record.dart';
import '../../../plan_review/presentation/controllers/plan_controller.dart';
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
    final historyRepo = ref.watch(historyRepositoryProvider);
    final projects = await historyRepo.getProjects();
    final plan = ref.watch(planReviewControllerProvider);

    final stats = DashboardStats.fromProjects(projects);
    final recents = projects.take(5).toList();

    return DashboardState(
      stats: stats,
      recentProjects: recents,
      hasUnfinishedPlan: plan != null && plan.items.isNotEmpty,
      unfinishedVideoName: plan?.baseName,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  void dismissTips() {
    state = state.whenData((s) => s.copyWith(isTipsDismissed: true));
  }
}
