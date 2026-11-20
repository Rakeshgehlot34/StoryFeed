import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/part_repository.dart';

final partRepositoryProvider = Provider<PartRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftPartRepository(db);
});

class DriftPartRepository implements PartRepository {
  final AppDatabase _db;

  DriftPartRepository(this._db);

  @override
  Stream<List<Part>> watchPartsForProject(String projectId) {
    final query = _db.select(_db.parts)
      ..where((tbl) => tbl.projectId.equals(projectId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.partIndex)]);
    return query.watch();
  }

  @override
  Future<List<Part>> getPartsForProject(String projectId) async {
    final query = _db.select(_db.parts)
      ..where((tbl) => tbl.projectId.equals(projectId))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.partIndex)]);
    return query.get();
  }

  @override
  Future<Part?> getPartByIndex(String projectId, int partIndex) async {
    final query = _db.select(_db.parts)
      ..where(
        (tbl) =>
            tbl.projectId.equals(projectId) & tbl.partIndex.equals(partIndex),
      );
    return query.getSingleOrNull();
  }

  @override
  Future<void> savePart(PartsCompanion part) async {
    await _db.into(_db.parts).insertOnConflictUpdate(part);
  }

  @override
  Future<void> batchSaveParts(List<PartsCompanion> parts) async {
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.parts, parts);
    });
  }

  @override
  Future<void> updatePartStageStatus({
    required String projectId,
    required int partIndex,
    required String stage,
    required String status,
    double? actualStartSeconds,
    double? actualEndSeconds,
    double? actualDurationSeconds,
    String? outputUriOrPath,
    int? fileSizeBytes,
    String? errorMessage,
    bool? hasCapViolation,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = PartsCompanion(
      stage: Value(stage),
      status: Value(status),
      actualStartSeconds: actualStartSeconds != null
          ? Value(actualStartSeconds)
          : const Value.absent(),
      actualEndSeconds: actualEndSeconds != null
          ? Value(actualEndSeconds)
          : const Value.absent(),
      actualDurationSeconds: actualDurationSeconds != null
          ? Value(actualDurationSeconds)
          : const Value.absent(),
      outputUriOrPath: outputUriOrPath != null
          ? Value(outputUriOrPath)
          : const Value.absent(),
      fileSizeBytes: fileSizeBytes != null
          ? Value(BigInt.from(fileSizeBytes))
          : const Value.absent(),
      errorMessage:
          errorMessage != null ? Value(errorMessage) : const Value.absent(),
      hasCapViolation: hasCapViolation != null
          ? Value(hasCapViolation)
          : const Value.absent(),
      updatedAt: Value(BigInt.from(now)),
    );

    await (_db.update(_db.parts)
          ..where(
            (tbl) =>
                tbl.projectId.equals(projectId) &
                tbl.partIndex.equals(partIndex),
          ))
        .write(companion);
  }

  @override
  Future<void> markStale(String projectId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.parts)
          ..where((tbl) => tbl.projectId.equals(projectId)))
        .write(
      PartsCompanion(
        isStale: const Value(true),
        updatedAt: Value(BigInt.from(now)),
      ),
    );
  }

  @override
  Future<void> verifyFilesExistence(String projectId) async {
    final parts = await getPartsForProject(projectId);
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final part in parts) {
      if (part.stage == 'split' || part.stage == 'converted') {
        final path = part.outputUriOrPath;
        var exists = false;
        if (path != null && path.isNotEmpty) {
          if (path.startsWith('content://')) {
            exists = true; // SAF URIs handled via platform check
          } else {
            exists = await File(path).exists();
          }
        }

        if (!exists && !part.isMissing) {
          await (_db.update(_db.parts)
                ..where(
                  (tbl) =>
                      tbl.projectId.equals(projectId) &
                      tbl.partIndex.equals(part.partIndex),
                ))
              .write(
            PartsCompanion(
              isMissing: const Value(true),
              updatedAt: Value(BigInt.from(now)),
            ),
          );
        }
      }
    }
  }
}
