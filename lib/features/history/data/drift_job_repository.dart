import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftJobRepository(db);
});

class DriftJobRepository implements JobRepository {
  final AppDatabase _db;

  DriftJobRepository(this._db);

  @override
  Future<void> createJob(JobsCompanion job) async {
    await _db.into(_db.jobs).insertOnConflictUpdate(job);
  }

  @override
  Future<void> updateJobProgress(String jobId, double progress) async {
    await (_db.update(_db.jobs)..where((tbl) => tbl.id.equals(jobId))).write(
      JobsCompanion(
        progress: Value(progress),
      ),
    );
  }

  @override
  Future<void> markJobCompleted(String jobId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.jobs)..where((tbl) => tbl.id.equals(jobId))).write(
      JobsCompanion(
        state: const Value('completed'),
        progress: const Value(1.0),
        completedAt: Value(BigInt.from(now)),
      ),
    );
  }

  @override
  Future<void> markJobFailed(String jobId, String error) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.jobs)..where((tbl) => tbl.id.equals(jobId))).write(
      JobsCompanion(
        state: const Value('failed'),
        errorMessage: Value(error),
        completedAt: Value(BigInt.from(now)),
      ),
    );
  }

  @override
  Stream<Job?> watchActiveJob() {
    final query = _db.select(_db.jobs)
      ..where((tbl) => tbl.state.equals('running') | tbl.state.equals('queued'))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  @override
  Future<Job?> getActiveJob() async {
    final query = _db.select(_db.jobs)
      ..where((tbl) => tbl.state.equals('running') | tbl.state.equals('queued'))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  @override
  Future<void> logEvent({
    required String jobId,
    int? partIndex,
    required String stageLabel,
    required double progress,
    required String message,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.jobEvents).insert(
          JobEventsCompanion(
            jobId: Value(jobId),
            partIndex:
                partIndex != null ? Value(partIndex) : const Value.absent(),
            stageLabel: Value(stageLabel),
            progress: Value(progress),
            message: Value(message),
            createdAt: Value(BigInt.from(now)),
          ),
        );
  }
}
