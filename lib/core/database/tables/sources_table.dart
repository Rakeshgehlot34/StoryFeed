import 'package:drift/drift.dart';

class Sources extends Table {
  @override
  String get tableName => 'sources';

  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get uriOrPath => text()();
  Int64Column get fileSizeBytes => int64()();
  RealColumn get durationSeconds => real()();
  IntColumn get width => integer()();
  IntColumn get height => integer()();
  RealColumn get fps => real()();
  IntColumn get rotationDegrees => integer().withDefault(const Constant(0))();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get fingerprint => text().unique()();
  Int64Column get createdAt => int64()();

  @override
  Set<Column> get primaryKey => {id};
}
