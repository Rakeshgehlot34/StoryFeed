import 'package:drift/drift.dart';

class Jobs extends Table {
  @override
  String get tableName => 'jobs';

  TextColumn get id => text()();
  TextColumn get projectId => text().customConstraint(
        'NOT NULL REFERENCES projects(id) ON DELETE CASCADE',
      )();
  TextColumn get jobType =>
      text()(); // 'stage1_split', 'stage2_convert', 'single_step'
  TextColumn get state =>
      text()(); // 'queued', 'running', 'completed', 'failed', 'cancelled'
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  TextColumn get targetIndicesJson =>
      text()(); // JSON list of part indices e.g. "[1,2,3]"
  Int64Column get createdAt => int64()();
  Int64Column get startedAt => int64().nullable()();
  Int64Column get completedAt => int64().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
