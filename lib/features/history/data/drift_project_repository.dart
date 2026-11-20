import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/models/project_with_details.dart';
import '../domain/project_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftProjectRepository(db);
});

class DriftProjectRepository implements ProjectRepository {
  final AppDatabase _db;

  DriftProjectRepository(this._db);

  @override
  Stream<List<ProjectWithDetails>> watchAllProjects() {
    final query = _db.select(_db.projects)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);

    return query.watch().asyncMap((projectsList) async {
      final result = <ProjectWithDetails>[];
      for (final p in projectsList) {
        final source = await (_db.select(_db.sources)
              ..where((tbl) => tbl.id.equals(p.sourceId)))
            .getSingleOrNull();
        if (source == null) continue;

        final parts = await (_db.select(_db.parts)
              ..where((tbl) => tbl.projectId.equals(p.id))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.partIndex)]))
            .get();

        result.add(
          ProjectWithDetails(
            project: p,
            source: source,
            parts: parts,
          ),
        );
      }
      return result;
    });
  }

  @override
  Future<List<ProjectWithDetails>> getAllProjects() async {
    final projectsList = await (_db.select(_db.projects)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]))
        .get();

    final result = <ProjectWithDetails>[];
    for (final p in projectsList) {
      final source = await (_db.select(_db.sources)
            ..where((tbl) => tbl.id.equals(p.sourceId)))
          .getSingleOrNull();
      if (source == null) continue;

      final parts = await (_db.select(_db.parts)
            ..where((tbl) => tbl.projectId.equals(p.id))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.partIndex)]))
          .get();

      result.add(
        ProjectWithDetails(
          project: p,
          source: source,
          parts: parts,
        ),
      );
    }
    return result;
  }

  @override
  Future<ProjectWithDetails?> getProject(String id) async {
    final project = await (_db.select(_db.projects)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    if (project == null) return null;

    final source = await (_db.select(_db.sources)
          ..where((tbl) => tbl.id.equals(project.sourceId)))
        .getSingleOrNull();
    if (source == null) return null;

    final parts = await (_db.select(_db.parts)
          ..where((tbl) => tbl.projectId.equals(project.id))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.partIndex)]))
        .get();

    return ProjectWithDetails(
      project: project,
      source: source,
      parts: parts,
    );
  }

  @override
  Future<void> saveProject(ProjectsCompanion project) async {
    await _db.into(_db.projects).insertOnConflictUpdate(project);
  }

  @override
  Future<void> updateProjectTimestamp(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.projects)..where((tbl) => tbl.id.equals(id))).write(
      ProjectsCompanion(
        updatedAt: Value(BigInt.from(now)),
      ),
    );
  }

  @override
  Future<void> deleteProject(String id, {bool deleteFiles = false}) async {
    if (deleteFiles) {
      final parts = await (_db.select(_db.parts)
            ..where((tbl) => tbl.projectId.equals(id)))
          .get();
      for (final part in parts) {
        final path = part.outputUriOrPath;
        if (path != null && !path.startsWith('content://')) {
          try {
            final f = File(path);
            if (await f.exists()) {
              await f.delete();
            }
          } catch (_) {}
        }
      }
    }

    // Cascade deletes parts, jobs, events
    await (_db.delete(_db.projects)..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<void> clearAllProjects() async {
    await _db.delete(_db.projects).go();
    await _db.delete(_db.sources).go();
  }
}
