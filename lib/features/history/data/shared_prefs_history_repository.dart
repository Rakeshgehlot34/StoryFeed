import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/constants.dart';
import '../domain/history_repository.dart';
import '../domain/models/project_record.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return SharedPrefsHistoryRepository();
});

/// SharedPreferences implementation of HistoryRepository.
///
/// NOTE: SharedPreferences is used here because project records store only lightweight metadata
/// (filenames, dates, clip counts, and output paths) for personal video exports. This avoids adding
/// heavyweight SQLite/Isar database dependencies while providing instant zero-migration reads/writes.
class SharedPrefsHistoryRepository implements HistoryRepository {
  @override
  Future<List<ProjectRecord>> getProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList =
        prefs.getStringList(AppConstants.prefKeyProjectsHistory) ?? [];

    final projects = <ProjectRecord>[];
    for (final item in rawList) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        projects.add(ProjectRecord.fromJson(map));
      } catch (_) {
        // Skip corrupted entries gracefully
      }
    }

    // Sort newest first
    projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return projects;
  }

  @override
  Future<void> saveProject(ProjectRecord project) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getProjects();

    // Replace if existing, or prepend
    current.removeWhere((p) => p.id == project.id);
    current.insert(0, project);

    final rawList = current.map((p) => p.toJsonString()).toList();
    await prefs.setStringList(AppConstants.prefKeyProjectsHistory, rawList);
  }

  @override
  Future<void> deleteProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getProjects();
    current.removeWhere((p) => p.id == id);
    final rawList = current.map((p) => p.toJsonString()).toList();
    await prefs.setStringList(AppConstants.prefKeyProjectsHistory, rawList);
  }

  @override
  Future<void> deleteProjects(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getProjects();
    final idSet = ids.toSet();
    current.removeWhere((p) => idSet.contains(p.id));
    final rawList = current.map((p) => p.toJsonString()).toList();
    await prefs.setStringList(AppConstants.prefKeyProjectsHistory, rawList);
  }

  @override
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefKeyProjectsHistory);
  }
}
