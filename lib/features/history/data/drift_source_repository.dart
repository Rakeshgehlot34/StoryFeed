import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/source_repository.dart';

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftSourceRepository(db);
});

class DriftSourceRepository implements SourceRepository {
  final AppDatabase _db;

  DriftSourceRepository(this._db);

  @override
  Future<Source?> getByFingerprint(String fingerprint) async {
    final query = _db.select(_db.sources)
      ..where((tbl) => tbl.fingerprint.equals(fingerprint));
    return query.getSingleOrNull();
  }

  @override
  Future<Source?> getById(String id) async {
    final query = _db.select(_db.sources)..where((tbl) => tbl.id.equals(id));
    return query.getSingleOrNull();
  }

  @override
  Future<void> saveSource(SourcesCompanion source) async {
    await _db.into(_db.sources).insertOnConflictUpdate(source);
  }

  @override
  Future<void> deleteSource(String id) async {
    await (_db.delete(_db.sources)..where((tbl) => tbl.id.equals(id))).go();
  }
}
