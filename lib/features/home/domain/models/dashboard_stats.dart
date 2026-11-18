import '../../../../core/utils/formatters.dart';
import '../../../history/domain/models/project_record.dart';

/// Aggregated metrics and analytics for the user's splitting activity.
class DashboardStats {
  final int totalVideosProcessed;
  final int totalShortsCreated;
  final double totalDurationSeconds;
  final int totalStorageBytes;

  const DashboardStats({
    this.totalVideosProcessed = 0,
    this.totalShortsCreated = 0,
    this.totalDurationSeconds = 0.0,
    this.totalStorageBytes = 0,
  });

  String get formattedDuration =>
      Formatters.formatSeconds(totalDurationSeconds);
  String get formattedStorage => Formatters.formatFileSize(totalStorageBytes);

  factory DashboardStats.fromProjects(List<ProjectRecord> projects) {
    final videosCount = projects.length;
    var shortsCount = 0;
    var durationSec = 0.0;
    var storageBytes = 0;

    for (final p in projects) {
      shortsCount += p.totalShortsCount;
      durationSec += p.totalDurationSeconds;
      storageBytes += p.totalDiskBytes;
    }

    return DashboardStats(
      totalVideosProcessed: videosCount,
      totalShortsCreated: shortsCount,
      totalDurationSeconds: durationSec,
      totalStorageBytes: storageBytes,
    );
  }
}
