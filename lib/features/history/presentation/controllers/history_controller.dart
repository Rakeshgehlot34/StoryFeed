import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/legacy_migration.dart';
import '../../data/drift_project_repository.dart';
import '../../domain/models/project_with_details.dart';

enum HistorySortOrder {
  newest('Newest First'),
  oldest('Oldest First'),
  duration('Longest Duration'),
  clipCount('Most Clips');

  final String label;
  const HistorySortOrder(this.label);
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, List<ProjectWithDetails>>(
  HistoryController.new,
);

class HistoryController extends AsyncNotifier<List<ProjectWithDetails>> {
  ProjectWithDetails? _lastDeletedProject;
  int? _lastDeletedIndex;
  String _searchQuery = '';
  HistorySortOrder _sortOrder = HistorySortOrder.newest;

  int? get lastDeletedIndex => _lastDeletedIndex;
  HistorySortOrder get sortOrder => _sortOrder;

  @override
  Future<List<ProjectWithDetails>> build() async {
    // 1. Ensure any legacy data is migrated into SQLite
    final db = ref.watch(appDatabaseProvider);
    await LegacyMigration.migrate(db: db);

    // 2. Query projects from SQLite
    final repo = ref.watch(projectRepositoryProvider);
    final projects = await repo.getAllProjects();

    List<ProjectWithDetails> filtered = List<ProjectWithDetails>.from(projects);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((p) => p.source.displayName.toLowerCase().contains(query))
          .toList();
    }

    switch (_sortOrder) {
      case HistorySortOrder.newest:
        filtered.sort(
          (a, b) => b.project.createdAt.compareTo(a.project.createdAt),
        );
        break;
      case HistorySortOrder.oldest:
        filtered.sort(
          (a, b) => a.project.createdAt.compareTo(b.project.createdAt),
        );
        break;
      case HistorySortOrder.duration:
        filtered.sort(
          (a, b) =>
              b.source.durationSeconds.compareTo(a.source.durationSeconds),
        );
        break;
      case HistorySortOrder.clipCount:
        filtered.sort(
          (a, b) =>
              b.project.totalPartsCount.compareTo(a.project.totalPartsCount),
        );
        break;
    }

    return filtered;
  }

  void search(String query) {
    _searchQuery = query;
    ref.invalidateSelf();
  }

  void setSortOrder(HistorySortOrder order) {
    _sortOrder = order;
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteProject(String id) async {
    final currentList = state.valueOrNull ?? [];
    final index = currentList.indexWhere((p) => p.project.id == id);
    if (index != -1) {
      _lastDeletedProject = currentList[index];
      _lastDeletedIndex = index;
    }

    final repo = ref.read(projectRepositoryProvider);
    await repo.deleteProject(id, deleteFiles: true);
    ref.invalidateSelf();
  }

  Future<void> deleteMultiple(List<String> ids) async {
    final repo = ref.read(projectRepositoryProvider);
    for (final id in ids) {
      await repo.deleteProject(id, deleteFiles: true);
    }
    ref.invalidateSelf();
  }

  Future<void> undoDelete() async {
    if (_lastDeletedProject != null) {
      final repo = ref.read(projectRepositoryProvider);
      await repo.saveProject(
        ProjectsCompanion(
          id: Value(_lastDeletedProject!.project.id),
          sourceId: Value(_lastDeletedProject!.project.sourceId),
          workflowType: Value(_lastDeletedProject!.project.workflowType),
          trimStartSeconds:
              Value(_lastDeletedProject!.project.trimStartSeconds),
          trimEndSeconds: Value(_lastDeletedProject!.project.trimEndSeconds),
          settingsJson: Value(_lastDeletedProject!.project.settingsJson),
          outputLayout: Value(_lastDeletedProject!.project.outputLayout),
          folderUriOrPath: Value(_lastDeletedProject!.project.folderUriOrPath),
          totalPartsCount: Value(_lastDeletedProject!.project.totalPartsCount),
          createdAt: Value(_lastDeletedProject!.project.createdAt),
          updatedAt: Value(_lastDeletedProject!.project.updatedAt),
        ),
      );
      _lastDeletedProject = null;
      _lastDeletedIndex = null;
      ref.invalidateSelf();
    }
  }

  Future<void> clearAll() async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.clearAllProjects();
    ref.invalidateSelf();
  }
}
