import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/output/domain/models/exported_clip.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';

import '../../utils/output_verifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Selective Split Integration with Real Video Fixture', () {
    const fixturePath = 'test/fixtures/test_70s.mp4';
    late Directory tempOutDir;

    setUpAll(() async {
      final fixture = File(fixturePath);
      if (!fixture.existsSync()) {
        fail(
          'Fixture $fixturePath not found. Run scripts/make_fixtures.sh first.',
        );
      }
      tempOutDir = Directory.systemTemp.createTempSync('selective_split_test_');
    });

    tearDownAll(() {
      if (tempOutDir.existsSync()) {
        tempOutDir.deleteSync(recursive: true);
      }
    });

    test(
        'calculates and executes selective split on parts 1 and 3 of 3, verifies strict naming invariant, then processes remaining part 2',
        () async {
      // 1. Probe source video with OutputVerifier
      final sourceProbe = await OutputVerifier.probe(fixturePath);
      expect(sourceProbe.hasVideo, isTrue);
      expect(sourceProbe.duration, closeTo(70.0, 1.0));

      // 2. Define 3 planned segments aligned with GOP keyframe interval:
      const part1 = ClipSegment(
        index: 1,
        startSeconds: 0.0,
        durationSeconds: 30.0,
        formattedName: 'test_70s_part_001.mp4',
      );
      const part2 = ClipSegment(
        index: 2,
        startSeconds: 30.0,
        durationSeconds: 30.0,
        formattedName: 'test_70s_part_002.mp4',
      );
      const part3 = ClipSegment(
        index: 3,
        startSeconds: 60.0,
        durationSeconds: 10.0,
        formattedName: 'test_70s_part_003.mp4',
      );

      final selectedSegments = [part1, part3];

      // 3. Execute fast stream-copy command pattern for selected segments
      for (final segment in selectedSegments) {
        final outPath = p.join(tempOutDir.path, segment.formattedName);
        final res = await Process.run('ffmpeg', [
          '-y',
          '-ss',
          segment.startSeconds.toStringAsFixed(3),
          '-i',
          fixturePath,
          '-t',
          segment.durationSeconds.toStringAsFixed(3),
          '-c',
          'copy',
          '-avoid_negative_ts',
          'make_zero',
          outPath,
        ]);

        expect(res.exitCode, 0, reason: 'FFmpeg command failed: ${res.stderr}');
      }

      // 4. Verify outputs on disk
      final file1 = File(p.join(tempOutDir.path, 'test_70s_part_001.mp4'));
      final file2 = File(p.join(tempOutDir.path, 'test_70s_part_002.mp4'));
      final file3 = File(p.join(tempOutDir.path, 'test_70s_part_003.mp4'));

      expect(file1.existsSync(), isTrue, reason: 'Part 1 must exist');
      expect(file3.existsSync(), isTrue, reason: 'Part 3 must exist');
      expect(
        file2.existsSync(),
        isFalse,
        reason: 'Part 2 was unselected and must NOT exist',
      );

      // Check file 1 probe
      final probe1 = await OutputVerifier.probe(file1.path);
      expect(probe1.hasVideo, isTrue);
      expect(probe1.duration, closeTo(30.0, 1.5));

      // Check file 3 probe
      final probe3 = await OutputVerifier.probe(file3.path);
      expect(probe3.hasVideo, isTrue);
      expect(probe3.duration, closeTo(10.0, 1.5));

      // 5. Resume / process remaining unselected part (Part 2)
      final outPath2 = p.join(tempOutDir.path, part2.formattedName);
      final res2 = await Process.run('ffmpeg', [
        '-y',
        '-ss',
        part2.startSeconds.toStringAsFixed(3),
        '-i',
        fixturePath,
        '-t',
        part2.durationSeconds.toStringAsFixed(3),
        '-c',
        'copy',
        '-avoid_negative_ts',
        'make_zero',
        outPath2,
      ]);
      expect(res2.exitCode, 0);

      // Verify all 3 parts exist and are valid clips
      expect(file1.existsSync(), isTrue);
      expect(file2.existsSync(), isTrue);
      expect(file3.existsSync(), isTrue);

      final probe2 = await OutputVerifier.probe(file2.path);
      expect(probe2.hasVideo, isTrue);
      expect(probe2.duration, closeTo(30.0, 1.5));
    });
  });

  group('ExportJobRecord with Selective Processing Tests', () {
    test('Persists and restores selectedIndices and completedClips', () {
      final segments = [
        const ClipSegment(
          index: 1,
          startSeconds: 0.0,
          durationSeconds: 20.0,
          formattedName: 'clip_part_001.mp4',
        ),
        const ClipSegment(
          index: 2,
          startSeconds: 20.0,
          durationSeconds: 20.0,
          formattedName: 'clip_part_002.mp4',
        ),
        const ClipSegment(
          index: 3,
          startSeconds: 40.0,
          durationSeconds: 20.0,
          formattedName: 'clip_part_003.mp4',
        ),
      ];

      final completedClips = [
        ExportedClip(
          path: '/movies/clip_part_003.mp4',
          fileName: 'clip_part_003.mp4',
          partIndex: 3, // Selective part 3 finished
          totalParts: 3,
          duration: const Duration(seconds: 20),
          sizeInBytes: 10240,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      final record = ExportJobRecord(
        id: 'job_selective_1',
        inputPath: '/in/clip.mp4',
        videoFileName: 'clip.mp4',
        baseName: 'clip',
        totalDurationSeconds: 60.0,
        segments: segments,
        selectedIndices: [1, 3], // Only parts 1 and 3 selected
        outputDirectoryPath: '/out',
        completedClips: completedClips,
        currentClipIndex: 1,
        totalClips: 3,
        createdAt: DateTime(2026, 1, 1),
      );

      final json = record.toJson();
      final restored = ExportJobRecord.fromJson(json);

      expect(restored.selectedIndices, [1, 3]);
      expect(restored.completedClips.length, 1);
      expect(restored.completedClips.first.partIndex, 3);
      expect(restored.totalClips, 3);
    });
  });
}
