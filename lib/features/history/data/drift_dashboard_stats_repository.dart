import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/dashboard_stats_repository.dart';
import '../domain/models/dashboard_stats.dart';

final dashboardStatsRepositoryProvider =
    Provider<DashboardStatsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftDashboardStatsRepository(db);
});

class DriftDashboardStatsRepository implements DashboardStatsRepository {
  final AppDatabase _db;

  DriftDashboardStatsRepository(this._db);

  @override
  Stream<DashboardStats> watchStats() {
    // Watch parts table as driving stream for reactive updates
    return _db.select(_db.parts).watch().asyncMap((_) => getStats());
  }

  @override
  Future<DashboardStats> getStats() async {
    final sources = await _db.select(_db.sources).get();
    final projects = await _db.select(_db.projects).get();
    final parts = await _db.select(_db.parts).get();

    var splitCount = 0;
    var convertedCount = 0;
    var totalBytes = 0;

    for (final p in parts) {
      if (p.stage == 'split' || p.stage == 'converted') {
        splitCount++;
      }
      if (p.stage == 'converted') {
        convertedCount++;
      }
      totalBytes += p.fileSizeBytes.toInt();
    }

    var totalDuration = 0.0;
    for (final s in sources) {
      totalDuration += s.durationSeconds;
    }

    return DashboardStats(
      totalSources: sources.length,
      totalProjects: projects.length,
      totalPartsSplit: splitCount,
      totalPartsConverted: convertedCount,
      totalDurationSeconds: totalDuration,
      totalBytesWritten: totalBytes,
      totalTimeSpentSeconds: 0,
    );
  }
}
