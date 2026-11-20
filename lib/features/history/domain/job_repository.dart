import '../../../core/database/app_database.dart';

abstract class JobRepository {
  Future<void> createJob(JobsCompanion job);
  Future<void> updateJobProgress(String jobId, double progress);
  Future<void> markJobCompleted(String jobId);
  Future<void> markJobFailed(String jobId, String error);
  Stream<Job?> watchActiveJob();
  Future<Job?> getActiveJob();
  Future<void> logEvent({
    required String jobId,
    int? partIndex,
    required String stageLabel,
    required double progress,
    required String message,
  });
}
