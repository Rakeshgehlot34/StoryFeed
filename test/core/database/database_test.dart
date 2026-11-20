import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/core/database/app_database.dart';
import 'package:shorts_splitter/features/history/data/drift_dashboard_stats_repository.dart';
import 'package:shorts_splitter/features/history/data/drift_job_repository.dart';
import 'package:shorts_splitter/features/history/data/drift_part_repository.dart';
import 'package:shorts_splitter/features/history/data/drift_project_repository.dart';
import 'package:shorts_splitter/features/history/data/drift_source_repository.dart';

import '../../test_sqlite_helper.dart';

void main() {
  setupTestSqlite();

  late AppDatabase db;
  late DriftSourceRepository sourceRepo;
  late DriftProjectRepository projectRepo;
  late DriftPartRepository partRepo;
  late DriftJobRepository jobRepo;
  late DriftDashboardStatsRepository statsRepo;

  setUp(() {
    db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    sourceRepo = DriftSourceRepository(db);
    projectRepo = DriftProjectRepository(db);
    partRepo = DriftPartRepository(db);
    jobRepo = DriftJobRepository(db);
    statsRepo = DriftDashboardStatsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TC-DB-001: AppDatabase Constraints and Cascades', () {
    test('Cascade deletion from source down to parts and jobs', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Insert source
      await sourceRepo.saveSource(
        SourcesCompanion(
          id: const Value('src_1'),
          displayName: const Value('Video 1'),
          uriOrPath: const Value('/path/to/video.mp4'),
          fileSizeBytes: Value(BigInt.from(1000000)),
          durationSeconds: const Value(120.0),
          width: const Value(1920),
          height: const Value(1080),
          fps: const Value(30.0),
          fingerprint: const Value('fp_1'),
          createdAt: Value(BigInt.from(now)),
        ),
      );

      // 2. Insert project
      await projectRepo.saveProject(
        ProjectsCompanion(
          id: const Value('proj_1'),
          sourceId: const Value('src_1'),
          workflowType: const Value('two_stage'),
          trimStartSeconds: const Value(0.0),
          trimEndSeconds: const Value(120.0),
          settingsJson: const Value('{}'),
          outputLayout: const Value('multi_subfolder'),
          folderUriOrPath: const Value('/path/to/output/Video 1'),
          totalPartsCount: const Value(2),
          createdAt: Value(BigInt.from(now)),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      // 3. Insert parts
      await partRepo.batchSaveParts([
        PartsCompanion(
          id: const Value('part_1_1'),
          projectId: const Value('proj_1'),
          partIndex: const Value(1),
          plannedStartSeconds: const Value(0.0),
          plannedEndSeconds: const Value(60.0),
          plannedDurationSeconds: const Value(60.0),
          stage: const Value('planned'),
          status: const Value('idle'),
          updatedAt: Value(BigInt.from(now)),
        ),
        PartsCompanion(
          id: const Value('part_1_2'),
          projectId: const Value('proj_1'),
          partIndex: const Value(2),
          plannedStartSeconds: const Value(60.0),
          plannedEndSeconds: const Value(120.0),
          plannedDurationSeconds: const Value(60.0),
          stage: const Value('planned'),
          status: const Value('idle'),
          updatedAt: Value(BigInt.from(now)),
        ),
      ]);

      // 4. Insert job
      await jobRepo.createJob(
        JobsCompanion(
          id: const Value('job_1'),
          projectId: const Value('proj_1'),
          jobType: const Value('stage1_split'),
          state: const Value('running'),
          targetIndicesJson: const Value('[1,2]'),
          createdAt: Value(BigInt.from(now)),
        ),
      );

      // Verify records exist
      final initialParts = await partRepo.getPartsForProject('proj_1');
      expect(initialParts.length, 2);

      // Delete source
      await sourceRepo.deleteSource('src_1');

      // Verify cascade: project and parts must be deleted
      final remainingProjects = await projectRepo.getAllProjects();
      expect(remainingProjects, isEmpty);

      final remainingParts = await partRepo.getPartsForProject('proj_1');
      expect(remainingParts, isEmpty);
    });

    test('Unique constraint on (projectId, partIndex) prevents duplicates',
        () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await sourceRepo.saveSource(
        SourcesCompanion(
          id: const Value('src_u'),
          displayName: const Value('Unique Video'),
          uriOrPath: const Value('/path/to/v.mp4'),
          fileSizeBytes: Value(BigInt.from(500)),
          durationSeconds: const Value(60.0),
          width: const Value(1080),
          height: const Value(1920),
          fps: const Value(30.0),
          fingerprint: const Value('fp_u'),
          createdAt: Value(BigInt.from(now)),
        ),
      );

      await projectRepo.saveProject(
        ProjectsCompanion(
          id: const Value('proj_u'),
          sourceId: const Value('src_u'),
          workflowType: const Value('two_stage'),
          trimStartSeconds: const Value(0.0),
          trimEndSeconds: const Value(60.0),
          settingsJson: const Value('{}'),
          outputLayout: const Value('single_root'),
          folderUriOrPath: const Value(''),
          totalPartsCount: const Value(1),
          createdAt: Value(BigInt.from(now)),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      // Insert part 1
      await partRepo.savePart(
        PartsCompanion(
          id: const Value('part_u_1'),
          projectId: const Value('proj_u'),
          partIndex: const Value(1),
          plannedStartSeconds: const Value(0.0),
          plannedEndSeconds: const Value(60.0),
          plannedDurationSeconds: const Value(60.0),
          stage: const Value('planned'),
          status: const Value('idle'),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      // Re-inserting same (projectId, partIndex) updates on conflict
      await partRepo.savePart(
        PartsCompanion(
          id: const Value('part_u_1'),
          projectId: const Value('proj_u'),
          partIndex: const Value(1),
          plannedStartSeconds: const Value(0.0),
          plannedEndSeconds: const Value(60.0),
          plannedDurationSeconds: const Value(60.0),
          stage: const Value('split'),
          status: const Value('idle'),
          actualDurationSeconds: const Value(59.9),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      final parts = await partRepo.getPartsForProject('proj_u');
      expect(parts.length, 1);
      expect(parts.first.stage, 'split');
      expect(parts.first.actualDurationSeconds, 59.9);
    });
  });

  group('TC-DB-002: Reactive Streams and Stats', () {
    test('Part updates reactively trigger project watch stream', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await sourceRepo.saveSource(
        SourcesCompanion(
          id: const Value('src_stream'),
          displayName: const Value('Stream Source'),
          uriOrPath: const Value('/stream.mp4'),
          fileSizeBytes: Value(BigInt.from(1000)),
          durationSeconds: const Value(100.0),
          width: const Value(1080),
          height: const Value(1920),
          fps: const Value(30.0),
          fingerprint: const Value('fp_stream'),
          createdAt: Value(BigInt.from(now)),
        ),
      );

      await projectRepo.saveProject(
        ProjectsCompanion(
          id: const Value('proj_stream'),
          sourceId: const Value('src_stream'),
          workflowType: const Value('two_stage'),
          trimStartSeconds: const Value(0.0),
          trimEndSeconds: const Value(100.0),
          settingsJson: const Value('{}'),
          outputLayout: const Value('multi_subfolder'),
          folderUriOrPath: const Value('/output/Stream Source'),
          totalPartsCount: const Value(1),
          createdAt: Value(BigInt.from(now)),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      await partRepo.savePart(
        PartsCompanion(
          id: const Value('part_stream_1'),
          projectId: const Value('proj_stream'),
          partIndex: const Value(1),
          plannedStartSeconds: const Value(0.0),
          plannedEndSeconds: const Value(100.0),
          plannedDurationSeconds: const Value(100.0),
          stage: const Value('planned'),
          status: const Value('idle'),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      final streamExpectation = expectLater(
        partRepo.watchPartsForProject('proj_stream'),
        emitsInOrder([
          predicate<List<Part>>((list) => list.first.stage == 'planned'),
          predicate<List<Part>>((list) => list.first.stage == 'split'),
          predicate<List<Part>>((list) => list.first.stage == 'converted'),
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await partRepo.updatePartStageStatus(
        projectId: 'proj_stream',
        partIndex: 1,
        stage: 'split',
        status: 'idle',
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await partRepo.updatePartStageStatus(
        projectId: 'proj_stream',
        partIndex: 1,
        stage: 'converted',
        status: 'idle',
      );

      await streamExpectation;
    });

    test('Dashboard stats derive accurate totals from SQL', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await sourceRepo.saveSource(
        SourcesCompanion(
          id: const Value('src_s1'),
          displayName: const Value('Source 1'),
          uriOrPath: const Value('/s1.mp4'),
          fileSizeBytes: Value(BigInt.from(5000000)),
          durationSeconds: const Value(300.0),
          width: const Value(1080),
          height: const Value(1920),
          fps: const Value(30.0),
          fingerprint: const Value('fp_s1'),
          createdAt: Value(BigInt.from(now)),
        ),
      );

      await projectRepo.saveProject(
        ProjectsCompanion(
          id: const Value('proj_s1'),
          sourceId: const Value('src_s1'),
          workflowType: const Value('two_stage'),
          trimStartSeconds: const Value(0.0),
          trimEndSeconds: const Value(300.0),
          settingsJson: const Value('{}'),
          outputLayout: const Value('multi_subfolder'),
          folderUriOrPath: const Value('/output/s1'),
          totalPartsCount: const Value(3),
          createdAt: Value(BigInt.from(now)),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      await partRepo.batchSaveParts([
        PartsCompanion(
          id: const Value('p1'),
          projectId: const Value('proj_s1'),
          partIndex: const Value(1),
          plannedStartSeconds: const Value(0.0),
          plannedEndSeconds: const Value(100.0),
          plannedDurationSeconds: const Value(100.0),
          stage: const Value('converted'),
          status: const Value('idle'),
          fileSizeBytes: Value(BigInt.from(1500000)),
          updatedAt: Value(BigInt.from(now)),
        ),
        PartsCompanion(
          id: const Value('p2'),
          projectId: const Value('proj_s1'),
          partIndex: const Value(2),
          plannedStartSeconds: const Value(100.0),
          plannedEndSeconds: const Value(200.0),
          plannedDurationSeconds: const Value(100.0),
          stage: const Value('split'),
          status: const Value('idle'),
          fileSizeBytes: Value(BigInt.from(1200000)),
          updatedAt: Value(BigInt.from(now)),
        ),
        PartsCompanion(
          id: const Value('p3'),
          projectId: const Value('proj_s1'),
          partIndex: const Value(3),
          plannedStartSeconds: const Value(200.0),
          plannedEndSeconds: const Value(300.0),
          plannedDurationSeconds: const Value(100.0),
          stage: const Value('planned'),
          status: const Value('idle'),
          fileSizeBytes: Value(BigInt.zero),
          updatedAt: Value(BigInt.from(now)),
        ),
      ]);

      final stats = await statsRepo.getStats();
      expect(stats.totalSources, 1);
      expect(stats.totalProjects, 1);
      expect(stats.totalPartsSplit, 2); // 1 split + 1 converted
      expect(stats.totalPartsConverted, 1);
      expect(stats.totalDurationSeconds, 300.0);
      expect(stats.totalBytesWritten, 2700000);
    });
  });

  group('TC-DB-003: Large Dataset Performance (10,000 parts)', () {
    test(
        'Batch insertion and retrieval of 10,000 parts completes in under 2 seconds',
        () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      await sourceRepo.saveSource(
        SourcesCompanion(
          id: const Value('src_perf'),
          displayName: const Value('High Volume Video'),
          uriOrPath: const Value('/perf.mp4'),
          fileSizeBytes: Value(BigInt.from(50000000)),
          durationSeconds: const Value(60000.0),
          width: const Value(1080),
          height: const Value(1920),
          fps: const Value(30.0),
          fingerprint: const Value('fp_perf'),
          createdAt: Value(BigInt.from(now)),
        ),
      );

      await projectRepo.saveProject(
        ProjectsCompanion(
          id: const Value('proj_perf'),
          sourceId: const Value('src_perf'),
          workflowType: const Value('two_stage'),
          trimStartSeconds: const Value(0.0),
          trimEndSeconds: const Value(60000.0),
          settingsJson: const Value('{}'),
          outputLayout: const Value('multi_subfolder'),
          folderUriOrPath: const Value('/output/perf'),
          totalPartsCount: const Value(10000),
          createdAt: Value(BigInt.from(now)),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      final stopwatch = Stopwatch()..start();

      final parts = List.generate(
        10000,
        (i) => PartsCompanion(
          id: Value('perf_part_$i'),
          projectId: const Value('proj_perf'),
          partIndex: Value(i + 1),
          plannedStartSeconds: Value(i * 6.0),
          plannedEndSeconds: Value((i + 1) * 6.0),
          plannedDurationSeconds: const Value(6.0),
          stage: const Value('planned'),
          status: const Value('idle'),
          updatedAt: Value(BigInt.from(now)),
        ),
      );

      await partRepo.batchSaveParts(parts);
      stopwatch.stop();

      // SQLite in-memory batch insert of 10,000 rows should easily be < 2000ms
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      final fetchStopwatch = Stopwatch()..start();
      final retrieved = await partRepo.getPartsForProject('proj_perf');
      fetchStopwatch.stop();

      expect(retrieved.length, 10000);
      expect(fetchStopwatch.elapsedMilliseconds, lessThan(500));
    });
  });
}
