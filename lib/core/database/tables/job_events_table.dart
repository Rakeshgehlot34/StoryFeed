import 'package:drift/drift.dart';

class JobEvents extends Table {
  @override
  String get tableName => 'job_events';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get jobId => text().customConstraint(
        'NOT NULL REFERENCES jobs(id) ON DELETE CASCADE',
      )();
  IntColumn get partIndex => integer().nullable()();
  TextColumn get stageLabel =>
      text()(); // 'Preparing', 'Cutting', 'Encoding', 'Saving', 'Verifying'
  RealColumn get progress => real()();
  TextColumn get message => text()();
  Int64Column get createdAt => int64()();
}
