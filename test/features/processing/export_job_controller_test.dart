import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/output/domain/models/exported_clip.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/processing/domain/models/processing_progress.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ExportJobRecord serialization tests', () {
    test('Correctly serializes and deserializes ExportJobRecord', () {
      final segments = [
        const ClipSegment(
          index: 1,
          startSeconds: 0.0,
          durationSeconds: 15.0,
          formattedName: 'vlog_part_001.mp4',
        ),
        const ClipSegment(
          index: 2,
          startSeconds: 15.0,
          durationSeconds: 15.0,
          formattedName: 'vlog_part_002.mp4',
        ),
      ];

      final completedClips = [
        ExportedClip(
          path: '/movies/vlog_part_001.mp4',
          fileName: 'vlog_part_001.mp4',
          partIndex: 1,
          totalParts: 2,
          duration: const Duration(seconds: 15),
          sizeInBytes: 10240,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      final record = ExportJobRecord(
        id: 'job_123',
        inputPath: '/input/vlog.mp4',
        videoFileName: 'vlog.mp4',
        baseName: 'vlog',
        totalDurationSeconds: 30.0,
        segments: segments,
        outputDirectoryPath: '/movies',
        completedClips: completedClips,
        currentClipIndex: 2,
        totalClips: 2,
        createdAt: DateTime(2026, 1, 1, 12, 0),
      );

      final json = record.toJson();
      final revived = ExportJobRecord.fromJson(json);

      expect(revived.id, 'job_123');
      expect(revived.inputPath, '/input/vlog.mp4');
      expect(revived.videoFileName, 'vlog.mp4');
      expect(revived.baseName, 'vlog');
      expect(revived.totalDurationSeconds, 30.0);
      expect(revived.segments.length, 2);
      expect(revived.segments.first.formattedName, 'vlog_part_001.mp4');
      expect(revived.completedClips.length, 1);
      expect(revived.completedClips.first.fileName, 'vlog_part_001.mp4');
      expect(revived.currentClipIndex, 2);
      expect(revived.totalClips, 2);
    });

    test('ExportJobState copyWith updates progress and records cleanly', () {
      const state = ExportJobState();
      expect(state.isExporting, isFalse);
      expect(state.hasInterruptedJob, isFalse);

      final updated = state.copyWith(
        progress: const ProcessingProgress(
          status: ProcessingStatus.processing,
          overallProgress: 0.5,
          currentClipIndex: 1,
          totalClips: 2,
        ),
      );

      expect(updated.isExporting, isTrue);
      expect(updated.progress.overallProgress, 0.5);
    });
  });
}
