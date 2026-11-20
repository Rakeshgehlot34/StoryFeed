import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/core/utils/formatters.dart';
import 'package:shorts_splitter/features/plan_review/domain/models/clip_processing_state.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_plan.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';

void main() {
  group('ClipProcessingStatus and PartItem Domain Tests', () {
    test('PartItem getters and lifecycle status checks', () {
      const segment = ClipSegment(
        index: 3,
        startSeconds: 40.0,
        durationSeconds: 20.0,
        formattedName: 'my_video_part_003.mp4',
      );

      const item = PartItem(
        segment: segment,
        isSelected: true,
        status: ClipProcessingStatus.notProcessed,
      );

      expect(item.index, 3);
      expect(item.startSeconds, 40.0);
      expect(item.endSeconds, 60.0);
      expect(item.durationSeconds, 20.0);
      expect(item.formattedName, 'my_video_part_003.mp4');
      expect(item.isNotProcessed, isTrue);
      expect(item.isProcessed, isFalse);

      final processing = item.copyWith(status: ClipProcessingStatus.processing);
      expect(processing.isProcessing, isTrue);

      final processed = processing.copyWith(
        status: ClipProcessingStatus.processed,
        outputPath: '/storage/my_video_part_003.mp4',
      );
      expect(processed.isProcessed, isTrue);
      expect(processed.outputPath, '/storage/my_video_part_003.mp4');

      final failed = item.copyWith(
        status: ClipProcessingStatus.failed,
        failureReason: 'FFmpeg exit code 1',
      );
      expect(failed.isFailed, isTrue);
      expect(failed.failureReason, 'FFmpeg exit code 1');

      final stale = item.copyWith(status: ClipProcessingStatus.stale);
      expect(stale.isStale, isTrue);

      final missing = item.copyWith(status: ClipProcessingStatus.missing);
      expect(missing.isMissing, isTrue);
    });

    test('PartItem JSON serialization and deserialization', () {
      const segment = ClipSegment(
        index: 5,
        startSeconds: 80.0,
        durationSeconds: 20.0,
        formattedName: 'vid_part_005.mp4',
      );

      const item = PartItem(
        segment: segment,
        isSelected: false,
        status: ClipProcessingStatus.processed,
        outputPath: '/out/vid_part_005.mp4',
      );

      final json = item.toJson();
      final restored = PartItem.fromJson(json);

      expect(restored.index, 5);
      expect(restored.isSelected, isFalse);
      expect(restored.status, ClipProcessingStatus.processed);
      expect(restored.outputPath, '/out/vid_part_005.mp4');
    });
  });

  group('PartSelectionHelpers Tests', () {
    late List<PartItem> testItems;

    setUp(() {
      testItems = List.generate(10, (i) {
        final index = i + 1;
        return PartItem(
          segment: ClipSegment(
            index: index,
            startSeconds: i * 20.0,
            durationSeconds: 20.0,
            formattedName: 'test_part_${index.toString().padLeft(3, '0')}.mp4',
          ),
          isSelected: true,
          status: ClipProcessingStatus.notProcessed,
        );
      });
    });

    test('selectAll and selectNone toggle all items cleanly', () {
      final none = PartSelectionHelpers.selectNone(testItems);
      expect(none.every((item) => !item.isSelected), isTrue);

      final all = PartSelectionHelpers.selectAll(none);
      expect(all.every((item) => item.isSelected), isTrue);
    });

    test('invertSelection flips selection state', () {
      // Unselect parts 2 and 4
      var modified = PartSelectionHelpers.toggleSelection(testItems, 2);
      modified = PartSelectionHelpers.toggleSelection(modified, 4);

      expect(modified[1].isSelected, isFalse);
      expect(modified[3].isSelected, isFalse);
      expect(modified[0].isSelected, isTrue);

      final inverted = PartSelectionHelpers.invertSelection(modified);
      expect(inverted[1].isSelected, isTrue);
      expect(inverted[3].isSelected, isTrue);
      expect(inverted[0].isSelected, isFalse);
    });

    test('selectRange selects only clips within 1-based bounds', () {
      final range = PartSelectionHelpers.selectRange(testItems, 3, 6);
      for (final item in range) {
        if (item.index >= 3 && item.index <= 6) {
          expect(item.isSelected, isTrue);
        } else {
          expect(item.isSelected, isFalse);
        }
      }
    });

    test('selectNotConverted selects only unprocessed/raw parts', () {
      var modified = PartSelectionHelpers.updateStatus(
        testItems,
        1,
        ClipProcessingStatus.processed,
      );
      modified = PartSelectionHelpers.updateStatus(
        modified,
        3,
        ClipProcessingStatus.processed,
      );

      final notConverted = PartSelectionHelpers.selectNotConverted(modified);
      expect(notConverted[0].isSelected, isFalse);
      expect(notConverted[1].isSelected, isTrue);
      expect(notConverted[2].isSelected, isFalse);
      expect(notConverted[3].isSelected, isTrue);
    });

    test('selectFailed selects only failed parts', () {
      final modified = PartSelectionHelpers.updateStatus(
        testItems,
        5,
        ClipProcessingStatus.failed,
        failureReason: 'FFmpeg transcode error',
      );

      final failed = PartSelectionHelpers.selectFailed(modified);
      for (final item in failed) {
        if (item.index == 5) {
          expect(item.isSelected, isTrue);
        } else {
          expect(item.isSelected, isFalse);
        }
      }
    });

    test('selectNextN selects exactly the next N unfinished parts', () {
      var modified = PartSelectionHelpers.updateStatus(
        testItems,
        1,
        ClipProcessingStatus.processed,
      );
      modified = PartSelectionHelpers.updateStatus(
        modified,
        2,
        ClipProcessingStatus.processed,
      );

      final next3 = PartSelectionHelpers.selectNextN(modified, 3);
      // Items 1 and 2 are processed, so items 3, 4, 5 are selected
      expect(next3[0].isSelected, isFalse);
      expect(next3[1].isSelected, isFalse);
      expect(next3[2].isSelected, isTrue);
      expect(next3[3].isSelected, isTrue);
      expect(next3[4].isSelected, isTrue);
      expect(next3[5].isSelected, isFalse);
    });

    test('updateStatus updates specific item and preserves others', () {
      final updated = PartSelectionHelpers.updateStatus(
        testItems,
        3,
        ClipProcessingStatus.processed,
        outputPath: '/path/part_003.mp4',
      );

      expect(updated[2].status, ClipProcessingStatus.processed);
      expect(updated[2].outputPath, '/path/part_003.mp4');
      expect(updated[0].status, ClipProcessingStatus.notProcessed);
      expect(updated[1].status, ClipProcessingStatus.notProcessed);
    });

    test(
      'detectStale invalidates only items whose boundary or message changed',
      () {
        // Mark parts 1, 2, 3 as processed
        var processedItems = List<PartItem>.from(testItems);
        processedItems = PartSelectionHelpers.updateStatus(
          processedItems,
          1,
          ClipProcessingStatus.processed,
          outputPath: '/out/part_001.mp4',
        );
        processedItems = PartSelectionHelpers.updateStatus(
          processedItems,
          2,
          ClipProcessingStatus.processed,
          outputPath: '/out/part_002.mp4',
        );
        processedItems = PartSelectionHelpers.updateStatus(
          processedItems,
          3,
          ClipProcessingStatus.processed,
          outputPath: '/out/part_003.mp4',
        );

        // Now simulate a plan update:
        // Part 1: unchanged
        // Part 2: boundary changed from 20.0-40.0 to 20.0-45.0
        // Part 3: boundary changed from 40.0-60.0 to 45.0-60.0
        // Part 4: unchanged (was notProcessed)
        final newPlanItems = [
          const ClipPlanItem(
            index: 1,
            startSeconds: 0.0,
            endSeconds: 20.0,
            formattedName: 'test_part_001.mp4',
          ),
          const ClipPlanItem(
            index: 2,
            startSeconds: 20.0,
            endSeconds: 45.0, // Modified boundary!
            formattedName: 'test_part_002.mp4',
          ),
          const ClipPlanItem(
            index: 3,
            startSeconds: 45.0, // Modified boundary!
            endSeconds: 60.0,
            formattedName: 'test_part_003.mp4',
          ),
          const ClipPlanItem(
            index: 4,
            startSeconds: 60.0,
            endSeconds: 80.0,
            formattedName: 'test_part_004.mp4',
          ),
        ];

        final staled = PartSelectionHelpers.detectStale(
          previousItems: processedItems,
          newPlanItems: newPlanItems,
        );

        // Part 1 was unchanged -> stays processed
        expect(staled[0].status, ClipProcessingStatus.processed);
        expect(staled[0].outputPath, '/out/part_001.mp4');

        // Part 2 changed boundary -> marked stale
        expect(staled[1].status, ClipProcessingStatus.stale);

        // Part 3 changed boundary -> marked stale
        expect(staled[2].status, ClipProcessingStatus.stale);

        // Part 4 was notProcessed -> remains notProcessed
        expect(staled[3].status, ClipProcessingStatus.notProcessed);
      },
    );

    test(
      'verifyDiskFiles transitions deleted files to missing status',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'disk_verify_test',
        );
        final realFile = File('${tempDir.path}/real_part.mp4');
        await realFile.writeAsString('test');

        final items = [
          PartItem(
            segment: testItems[0].segment,
            status: ClipProcessingStatus.processed,
            outputPath: realFile.path,
          ),
          PartItem(
            segment: testItems[1].segment,
            status: ClipProcessingStatus.processed,
            outputPath: '${tempDir.path}/non_existent_part.mp4',
          ),
        ];

        final verified = await PartSelectionHelpers.verifyDiskFiles(items);
        expect(verified[0].status, ClipProcessingStatus.processed);
        expect(verified[1].status, ClipProcessingStatus.missing);

        await tempDir.delete(recursive: true);
      },
    );
  });

  group('Naming Invariant Tests for Selective Processing', () {
    test('Clip filenames strictly use planIndex regardless of selection', () {
      const baseName = 'summer_vlog';
      const totalClipsInPlan = 30;

      // Suppose user selects parts 3, 7, and 12 out of 30
      final selectedIndices = [3, 7, 12];

      final fileNames = selectedIndices.map((idx) {
        return Formatters.formatClipFileName(baseName, idx, totalClipsInPlan);
      }).toList();

      expect(fileNames[0], 'summer_vlog_part_003.mp4');
      expect(fileNames[1], 'summer_vlog_part_007.mp4');
      expect(fileNames[2], 'summer_vlog_part_012.mp4');

      // Invariant: they must NEVER be renumbered to part_001, part_002, part_003!
      expect(fileNames[0], isNot('summer_vlog_part_001.mp4'));
      expect(fileNames[1], isNot('summer_vlog_part_002.mp4'));
      expect(fileNames[2], isNot('summer_vlog_part_003.mp4'));
    });
  });
}
