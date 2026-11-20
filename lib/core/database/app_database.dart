import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables/app_settings_table.dart';
import 'tables/job_events_table.dart';
import 'tables/jobs_table.dart';
import 'tables/parts_table.dart';
import 'tables/projects_table.dart';
import 'tables/sources_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Sources,
    Projects,
    Parts,
    Jobs,
    JobEvents,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sources_fingerprint ON sources(fingerprint);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_projects_source_id ON projects(source_id);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_projects_updated_at ON projects(updated_at DESC);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_parts_project_index ON parts(project_id, part_index);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_parts_stage_status ON parts(stage, status);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_jobs_project_state ON jobs(project_id, state);',
          );
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_job_events_job_created ON job_events(job_id, created_at);',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'shorts_splitter_v1');
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
