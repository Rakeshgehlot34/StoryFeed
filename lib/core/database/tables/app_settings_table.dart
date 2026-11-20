import 'package:drift/drift.dart';

class AppSettings extends Table {
  @override
  String get tableName => 'app_settings_kv';

  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  Int64Column get updatedAt => int64()();

  @override
  Set<Column> get primaryKey => {key};
}
