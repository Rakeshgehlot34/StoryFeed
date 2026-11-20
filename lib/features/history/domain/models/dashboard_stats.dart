/// Aggregated SQL statistics for dashboard display.
class DashboardStats {
  final int totalSources;
  final int totalProjects;
  final int totalPartsSplit;
  final int totalPartsConverted;
  final double totalDurationSeconds;
  final int totalBytesWritten;
  final int totalTimeSpentSeconds;

  const DashboardStats({
    this.totalSources = 0,
    this.totalProjects = 0,
    this.totalPartsSplit = 0,
    this.totalPartsConverted = 0,
    this.totalDurationSeconds = 0.0,
    this.totalBytesWritten = 0,
    this.totalTimeSpentSeconds = 0,
  });

  static const empty = DashboardStats();
}
