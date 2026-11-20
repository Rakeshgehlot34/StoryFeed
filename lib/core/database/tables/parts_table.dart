import 'package:drift/drift.dart';

class Parts extends Table {
  @override
  String get tableName => 'parts';

  TextColumn get id => text()();
  TextColumn get projectId => text().customConstraint(
        'NOT NULL REFERENCES projects(id) ON DELETE CASCADE',
      )();
  IntColumn get partIndex => integer()(); // 1-based index
  RealColumn get plannedStartSeconds => real()();
  RealColumn get plannedEndSeconds => real()();
  RealColumn get plannedDurationSeconds => real()();
  RealColumn get actualStartSeconds => real().nullable()();
  RealColumn get actualEndSeconds => real().nullable()();
  RealColumn get actualDurationSeconds => real().nullable()();
  TextColumn get stage => text()(); // 'planned', 'split', 'converted'
  TextColumn get status => text()(); // 'idle', 'queued', 'running', 'failed'
  BoolColumn get isStale => boolean().withDefault(const Constant(false))();
  BoolColumn get isMissing => boolean().withDefault(const Constant(false))();
  BoolColumn get hasCapViolation =>
      boolean().withDefault(const Constant(false))();
  TextColumn get customMessage => text().nullable()();
  TextColumn get outputUriOrPath => text().nullable()();
  Int64Column get fileSizeBytes => int64().clientDefault(() => BigInt.zero)();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get timingsJson => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  Int64Column get updatedAt => int64()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, partIndex},
      ];
}
