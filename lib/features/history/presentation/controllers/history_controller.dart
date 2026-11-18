import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/shared_prefs_history_repository.dart';
import '../../domain/models/project_record.dart';

enum HistorySortOrder {
  newest('Newest First'),
  oldest('Oldest First'),
  duration('Longest Duration'),
  clipCount('Most Clips');

  final String label;
  const HistorySortOrder(this.label);
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, List<ProjectRecord>>(
      HistoryController.new,
    );

class HistoryController extends AsyncNotifier<List<ProjectRecord>> {
  ProjectRecord? _lastDeletedProject;
  int? _lastDeletedIndex;
  String _searchQuery = '';
  HistorySortOrder _sortOrder = HistorySortOrder.newest;

  int? get lastDeletedIndex => _lastDeletedIndex;
  HistorySortOrder get sortOrder => _sortOrder;

  @override
  Future<List<ProjectRecord>> build() async {
    final repo = ref.watch(historyRepositoryProvider);
    final projects = await repo.getProjects();

    List<ProjectRecord> filtered = List<ProjectRecord>.from(projects);

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((p) => p.videoName.toLowerCase().contains(query))
          .toList();
    }

    switch (_sortOrder) {
      case HistorySortOrder.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case HistorySortOrder.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case HistorySortOrder.duration:
        filtered.sort(
          (a, b) => b.totalDurationSeconds.compareTo(a.totalDurationSeconds),
        );
        break;
      case HistorySortOrder.clipCount:
        filtered.sort(
          (a, b) => b.totalShortsCount.compareTo(a.totalShortsCount),
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
    final index = currentList.indexWhere((p) => p.id == id);
    if (index != -1) {
      _lastDeletedProject = currentList[index];
      _lastDeletedIndex = index;
    }

    final repo = ref.read(historyRepositoryProvider);
    await repo.deleteProject(id);
    ref.invalidateSelf();
  }

  Future<void> undoDelete() async {
    if (_lastDeletedProject != null) {
      final repo = ref.read(historyRepositoryProvider);
      await repo.saveProject(_lastDeletedProject!);
      _lastDeletedProject = null;
      _lastDeletedIndex = null;
      ref.invalidateSelf();
    }
  }

  Future<void> deleteMultiple(List<String> ids) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.deleteProjects(ids);
    ref.invalidateSelf();
  }

  Future<void> clearAll() async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.clearHistory();
    ref.invalidateSelf();
  }
}
