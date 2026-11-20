import 'package:drift/drift.dart';

class Projects extends Table {
  @override
  String get tableName => 'projects';

  TextColumn get id => text()();
  TextColumn get sourceId => text().customConstraint(
        'NOT NULL REFERENCES sources(id) ON DELETE CASCADE',
      )();
  TextColumn get workflowType => text()(); // 'two_stage' or 'single_step'
  RealColumn get trimStartSeconds => real().withDefault(const Constant(0.0))();
  RealColumn get trimEndSeconds => real()();
  TextColumn get settingsJson => text()();
  TextColumn get outputLayout => text()(); // 'multi_subfolder' or 'single_root'
  TextColumn get folderUriOrPath => text()();
  IntColumn get totalPartsCount => integer()();
  Int64Column get createdAt => int64()();
  Int64Column get updatedAt => int64()();

  @override
  Set<Column> get primaryKey => {id};
}
