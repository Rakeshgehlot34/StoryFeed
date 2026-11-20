import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/app/constants.dart';
import 'package:shorts_splitter/core/database/app_database.dart';
import 'package:shorts_splitter/core/database/legacy_migration.dart';
import 'package:shorts_splitter/features/history/data/drift_project_repository.dart';

import '../../test_sqlite_helper.dart';

void main() {
  setupTestSqlite();
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftProjectRepository projectRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    projectRepo = DriftProjectRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TC-DB-MIG: Legacy SharedPreferences Migration', () {
    test('Empty legacy history generates clean completed report', () async {
      final report = await LegacyMigration.migrate(db: db);
      expect(report.totalFound, 0);
      expect(report.successfullyMigrated, 0);
      expect(report.isCompleted, isTrue);

      final projects = await projectRepo.getAllProjects();
      expect(projects, isEmpty);
    });

    test('Dry run produces accurate counts without writing to SQLite',
        () async {
      final sampleProject = {
        'id': 'legacy_1',
        'videoName': 'My Vacation.mp4',
        'baseName': 'My Vacation',
        'createdAt': DateTime.now().toIso8601String(),
        'totalDurationSeconds': 120.0,
        'totalShortsCount': 2,
        'processedShortsCount': 2,
        'canvasFormat': 'Shorts 9:16',
        'outputFilePaths': [
          '/storage/Movies/ShortsSplitter/My Vacation_part_001.mp4',
          '/storage/Movies/ShortsSplitter/My Vacation_part_002.mp4',
        ],
      };

      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyProjectsHistory: [
          jsonEncode(sampleProject),
          'corrupted_json_string{',
        ],
      });

      final report = await LegacyMigration.migrate(db: db, dryRun: true);
      expect(report.totalFound, 2);
      expect(report.successfullyMigrated, 1);
      expect(report.skippedOrCorrupted, 1);
      expect(report.isCompleted, isTrue);

      // Verify database remains empty during dry run
      final projects = await projectRepo.getAllProjects();
      expect(projects, isEmpty);
    });

    test(
        'Full migration successfully imports records, creates backup, and is idempotent',
        () async {
      final sampleProject = {
        'id': 'legacy_2',
        'videoName': 'Tutorial.mp4',
        'baseName': 'Tutorial',
        'createdAt': DateTime.now().toIso8601String(),
        'totalDurationSeconds': 180.0,
        'totalShortsCount': 3,
        'processedShortsCount': 3,
        'canvasFormat': 'Shorts 9:16',
        'outputFilePaths': [
          '/storage/Movies/ShortsSplitter/Tutorial_part_001.mp4',
          '/storage/Movies/ShortsSplitter/Tutorial_part_002.mp4',
          '/storage/Movies/ShortsSplitter/Tutorial_part_003.mp4',
        ],
      };

      final legacyList = [jsonEncode(sampleProject)];
      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyProjectsHistory: legacyList,
      });

      final report = await LegacyMigration.migrate(db: db);
      expect(report.successfullyMigrated, 1);
      expect(report.isCompleted, isTrue);

      // 1. Verify SQLite records
      final projects = await projectRepo.getAllProjects();
      expect(projects.length, 1);
      expect(projects.first.project.id, 'legacy_2');
      expect(projects.first.source.displayName, 'Tutorial.mp4');
      expect(projects.first.parts.length, 3);
      expect(projects.first.parts.first.stage, 'converted');

      // 2. Verify backup created in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(LegacyMigration.keyBackup), legacyList);

      // 3. Verify original key was NOT deleted
      expect(
        prefs.getStringList(AppConstants.prefKeyProjectsHistory),
        legacyList,
      );

      // 4. Test Idempotency: running again should do nothing
      final secondReport = await LegacyMigration.migrate(db: db);
      expect(secondReport.totalFound, 0);
      expect(secondReport.successfullyMigrated, 0);

      final projectsAfterSecond = await projectRepo.getAllProjects();
      expect(projectsAfterSecond.length, 1);
    });
  });
}
