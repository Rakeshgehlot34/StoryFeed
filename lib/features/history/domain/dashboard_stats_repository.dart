import 'models/dashboard_stats.dart';

abstract class DashboardStatsRepository {
  Stream<DashboardStats> watchStats();
  Future<DashboardStats> getStats();
}
