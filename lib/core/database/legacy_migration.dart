import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/constants.dart';
import '../../core/logger/app_logger.dart';
import '../../features/history/domain/models/project_record.dart';
import 'app_database.dart';

class MigrationReport {
  final int totalFound;
  final int successfullyMigrated;
  final int skippedOrCorrupted;
  final bool isCompleted;
  final String? errorMessage;

  const MigrationReport({
    required this.totalFound,
    required this.successfullyMigrated,
    required this.skippedOrCorrupted,
    required this.isCompleted,
    this.errorMessage,
  });
}

class LegacyMigration {
  static const String keyMigratedFlag = 'history_migrated_v1';
  static const String keyBackup = 'pref_history_projects_backup_v1';

  /// Performs a one-time, non-destructive migration from SharedPreferences to SQLite.
  static Future<MigrationReport> migrate({
    required AppDatabase db,
    bool dryRun = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check if already migrated
    final setting = await (db.select(db.appSettings)
          ..where((tbl) => tbl.key.equals(keyMigratedFlag)))
        .getSingleOrNull();

    if (setting != null && setting.valueJson == 'true') {
      return const MigrationReport(
        totalFound: 0,
        successfullyMigrated: 0,
        skippedOrCorrupted: 0,
        isCompleted: true,
      );
    }

    // 2. Fetch raw list from SharedPreferences
    final rawList =
        prefs.getStringList(AppConstants.prefKeyProjectsHistory) ?? [];
    if (rawList.isEmpty) {
      if (!dryRun) {
        await _markMigrated(db);
      }
      return const MigrationReport(
        totalFound: 0,
        successfullyMigrated: 0,
        skippedOrCorrupted: 0,
        isCompleted: true,
      );
    }

    // 3. Create safety backup in SharedPreferences
    if (!dryRun) {
      await prefs.setStringList(keyBackup, rawList);
    }

    var validRecords = 0;
    var corruptedRecords = 0;

    final parsedProjects = <ProjectRecord>[];
    for (final raw in rawList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        parsedProjects.add(ProjectRecord.fromJson(map));
        validRecords++;
      } catch (_) {
        corruptedRecords++;
      }
    }

    if (dryRun) {
      return MigrationReport(
        totalFound: rawList.length,
        successfullyMigrated: validRecords,
        skippedOrCorrupted: corruptedRecords,
        isCompleted: true,
      );
    }

    // 4. Execute atomic transaction in SQLite
    try {
      await db.transaction(() async {
        for (final p in parsedProjects) {
          final sourceId = 'src_${p.id}';
          final now = p.createdAt.millisecondsSinceEpoch;

          // Insert synthetic source
          await db.into(db.sources).insertOnConflictUpdate(
                SourcesCompanion(
                  id: Value(sourceId),
                  displayName: Value(p.videoName),
                  uriOrPath: Value(
                    p.outputFilePaths.isNotEmpty ? p.outputFilePaths.first : '',
                  ),
                  fileSizeBytes: Value(BigInt.from(p.totalDiskBytes)),
                  durationSeconds: Value(p.totalDurationSeconds),
                  width: const Value(1080),
                  height: const Value(1920),
                  fps: const Value(30.0),
                  thumbnailPath: Value(p.thumbnailPath),
                  fingerprint: Value('legacy_${p.id}'),
                  createdAt: Value(BigInt.from(now)),
                ),
              );

          // Insert project
          final isSingle = p.totalShortsCount <= 1;
          await db.into(db.projects).insertOnConflictUpdate(
                ProjectsCompanion(
                  id: Value(p.id),
                  sourceId: Value(sourceId),
                  workflowType: const Value('single_step'),
                  trimStartSeconds: const Value(0.0),
                  trimEndSeconds: Value(p.totalDurationSeconds),
                  settingsJson: Value(jsonEncode(p.toJson())),
                  outputLayout:
                      Value(isSingle ? 'single_root' : 'multi_subfolder'),
                  folderUriOrPath: const Value(''),
                  totalPartsCount: Value(p.totalShortsCount),
                  createdAt: Value(BigInt.from(now)),
                  updatedAt: Value(BigInt.from(now)),
                ),
              );

          // Insert parts
          final partDuration = p.totalShortsCount > 0
              ? p.totalDurationSeconds / p.totalShortsCount
              : p.totalDurationSeconds;

          final count = p.outputFilePaths.isNotEmpty
              ? p.outputFilePaths.length
              : p.totalShortsCount;

          for (var i = 0; i < count; i++) {
            final partIndex = i + 1;
            final startSec = i * partDuration;
            final endSec = (i + 1) * partDuration;
            final path =
                i < p.outputFilePaths.length ? p.outputFilePaths[i] : null;

            await db.into(db.parts).insertOnConflictUpdate(
                  PartsCompanion(
                    id: Value('part_${p.id}_$partIndex'),
                    projectId: Value(p.id),
                    partIndex: Value(partIndex),
                    plannedStartSeconds: Value(startSec),
                    plannedEndSeconds: Value(endSec),
                    plannedDurationSeconds: Value(partDuration),
                    actualStartSeconds: Value(startSec),
                    actualEndSeconds: Value(endSec),
                    actualDurationSeconds: Value(partDuration),
                    stage: const Value('converted'),
                    status: const Value('idle'),
                    outputUriOrPath: Value(path),
                    updatedAt: Value(BigInt.from(now)),
                  ),
                );
          }
        }

        // Mark migrated
        await _markMigrated(db);
      });

      AppLogger.info(
        'Successfully migrated $validRecords legacy projects to SQLite',
      );

      return MigrationReport(
        totalFound: rawList.length,
        successfullyMigrated: validRecords,
        skippedOrCorrupted: corruptedRecords,
        isCompleted: true,
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to migrate legacy projects',
        error: e,
        stackTrace: st,
      );
      return MigrationReport(
        totalFound: rawList.length,
        successfullyMigrated: 0,
        skippedOrCorrupted: corruptedRecords,
        isCompleted: false,
        errorMessage: e.toString(),
      );
    }
  }

  static Future<void> _markMigrated(AppDatabase db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value(keyMigratedFlag),
            valueJson: const Value('true'),
            updatedAt: Value(BigInt.from(now)),
          ),
        );
  }
}
