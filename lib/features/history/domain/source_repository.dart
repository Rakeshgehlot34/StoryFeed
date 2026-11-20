import '../../../core/database/app_database.dart';

abstract class SourceRepository {
  Future<Source?> getByFingerprint(String fingerprint);
  Future<Source?> getById(String id);
  Future<void> saveSource(SourcesCompanion source);
  Future<void> deleteSource(String id);
}
