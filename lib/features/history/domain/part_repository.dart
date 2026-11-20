import '../../../core/database/app_database.dart';

abstract class PartRepository {
  Stream<List<Part>> watchPartsForProject(String projectId);
  Future<List<Part>> getPartsForProject(String projectId);
  Future<Part?> getPartByIndex(String projectId, int partIndex);
  Future<void> savePart(PartsCompanion part);
  Future<void> batchSaveParts(List<PartsCompanion> parts);
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
  });
  Future<void> markStale(String projectId);
  Future<void> verifyFilesExistence(String projectId);
}
