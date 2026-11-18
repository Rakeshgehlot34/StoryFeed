import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/core/errors/app_exception.dart';
import 'package:shorts_splitter/features/custom_split/domain/custom_split_calculator.dart';
import 'package:shorts_splitter/features/custom_split/domain/models/custom_split_config.dart';

void main() {
  group('CustomSplitCalculator - byDuration', () {
    test('splits video into uniform intervals without 180s restriction', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byDuration,
        targetDurationSeconds: 300.0, // 5 minutes (exceeds Shorts 180s cap)
        startSeconds: 0.0,
        endSeconds: 700.0,
        mergeShortTrailingClip: false,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'long_webinar.mp4',
        videoDurationSeconds: 700.0,
        config: config,
      );

      expect(plan.totalParts, 3);
      expect(plan.items[0].startSeconds, 0.0);
      expect(plan.items[0].endSeconds, 300.0);
      expect(plan.items[0].durationSeconds, 300.0);
      expect(plan.items[0].formattedName, 'long_webinar_part_001.mp4');

      expect(plan.items[1].startSeconds, 300.0);
      expect(plan.items[1].endSeconds, 600.0);
      expect(plan.items[1].durationSeconds, 300.0);
      expect(plan.items[1].formattedName, 'long_webinar_part_002.mp4');

      expect(plan.items[2].startSeconds, 600.0);
      expect(plan.items[2].endSeconds, 700.0);
      expect(plan.items[2].durationSeconds, 100.0);
      expect(plan.items[2].formattedName, 'long_webinar_part_003.mp4');
    });

    test('merges short trailing remainder (< 3.0s) into penultimate clip when enabled', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byDuration,
        targetDurationSeconds: 30.0,
        startSeconds: 0.0,
        endSeconds: 62.0, // 30s + 30s + 2s remainder
        mergeShortTrailingClip: true,
        trailingMergeThresholdSeconds: 3.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'lecture.mp4',
        videoDurationSeconds: 62.0,
        config: config,
      );

      // Remainder 2.0s absorbed into part 2 -> 32.0s
      expect(plan.totalParts, 2);
      expect(plan.items[0].startSeconds, 0.0);
      expect(plan.items[0].endSeconds, 30.0);
      expect(plan.items[1].startSeconds, 30.0);
      expect(plan.items[1].endSeconds, 62.0);
      expect(plan.items[1].durationSeconds, 32.0);
    });

    test(
      'keeps trailing remainder when mergeShortTrailingClip is disabled',
      () {
        const config = CustomSplitConfig(
          mode: CustomSplitMode.byDuration,
          targetDurationSeconds: 30.0,
          startSeconds: 0.0,
          endSeconds: 62.0,
          mergeShortTrailingClip: false,
        );

        final plan = CustomSplitCalculator.calculatePlan(
          originalVideoName: 'lecture.mp4',
          videoDurationSeconds: 62.0,
          config: config,
        );

        expect(plan.totalParts, 3);
        expect(plan.items[2].durationSeconds, 2.0);
      },
    );
  });

  group('CustomSplitCalculator - byParts', () {
    test('divides range into N contiguous equal parts', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byParts,
        targetPartCount: 4,
        startSeconds: 0.0,
        endSeconds: 100.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'presentation.mp4',
        videoDurationSeconds: 100.0,
        config: config,
      );

      expect(plan.totalParts, 4);
      for (int i = 0; i < 4; i++) {
        expect(plan.items[i].startSeconds, i * 25.0);
        expect(plan.items[i].endSeconds, (i + 1) * 25.0);
        expect(plan.items[i].durationSeconds, 25.0);
      }
      expect(plan.items.last.endSeconds, 100.0);
    });
  });

  group('CustomSplitCalculator - byPoints', () {
    test('creates contiguous clips matching ordered custom split points', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byPoints,
        customSplitPoints: [35.5, 10.0, 50.0], // Unsorted order
        startSeconds: 0.0,
        endSeconds: 70.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'concert.mp4',
        videoDurationSeconds: 70.0,
        config: config,
      );

      // Points sorted: [10.0, 35.5, 50.0] -> 4 clips
      expect(plan.totalParts, 4);
      expect(plan.items[0].startSeconds, 0.0);
      expect(plan.items[0].endSeconds, 10.0);

      expect(plan.items[1].startSeconds, 10.0);
      expect(plan.items[1].endSeconds, 35.5);

      expect(plan.items[2].startSeconds, 35.5);
      expect(plan.items[2].endSeconds, 50.0);

      expect(plan.items[3].startSeconds, 50.0);
      expect(plan.items[3].endSeconds, 70.0);
    });

    test('ignores split points outside the active start and end bounds', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byPoints,
        customSplitPoints: [
          5.0,
          25.0,
          95.0,
        ], // 5.0 is before start 10.0, 95.0 is after end 60.0
        startSeconds: 10.0,
        endSeconds: 60.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'match.mp4',
        videoDurationSeconds: 100.0,
        config: config,
      );

      expect(plan.totalParts, 2);
      expect(plan.items[0].startSeconds, 10.0);
      expect(plan.items[0].endSeconds, 25.0);
      expect(plan.items[1].startSeconds, 25.0);
      expect(plan.items[1].endSeconds, 60.0);
    });
  });

  group('CustomSplitCalculator - bySize', () {
    test('estimates duration based on video bitrate', () {
      const bitrate = 8000000; // 8 Mbps = 1 MB/s
      const config = CustomSplitConfig(
        mode: CustomSplitMode.bySize,
        targetSizeMb: 10.0, // 10 MB = 10s per clip
        startSeconds: 0.0,
        endSeconds: 30.0,
        mergeShortTrailingClip: false,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'gameplay.mp4',
        videoDurationSeconds: 30.0,
        config: config,
        bitrateBps: bitrate,
      );

      expect(plan.totalParts, 3);
      expect(plan.items[0].durationSeconds, closeTo(10.48, 0.5));
      expect(plan.items[1].durationSeconds, closeTo(10.48, 0.5));
      expect(plan.items[2].durationSeconds, closeTo(9.03, 0.5));
    });
  });

  group('CustomSplitCalculator - Invariants and Padding', () {
    test('guarantees boundary contiguity across all items', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byDuration,
        targetDurationSeconds: 15.0,
        startSeconds: 0.0,
        endSeconds: 70.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'stream.mp4',
        videoDurationSeconds: 70.0,
        config: config,
      );

      for (int i = 0; i < plan.items.length - 1; i++) {
        expect(
          plan.items[i].endSeconds,
          equals(plan.items[i + 1].startSeconds),
          reason: 'Item $i and ${i + 1} must be perfectly contiguous',
        );
      }
      expect(plan.items.first.startSeconds, 0.0);
      expect(plan.items.last.endSeconds, 70.0);
    });

    test('formats part numbers with at least 3 digits zero padding', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byDuration,
        targetDurationSeconds: 10.0,
        startSeconds: 0.0,
        endSeconds: 50.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'clip.mp4',
        videoDurationSeconds: 50.0,
        config: config,
      );

      expect(plan.items[0].formattedName, 'clip_part_001.mp4');
      expect(plan.items[4].formattedName, 'clip_part_005.mp4');
    });

    test('throws PlanValidationException on range < 1.0 second', () {
      const config = CustomSplitConfig(startSeconds: 10.0, endSeconds: 10.5);

      expect(
        () => CustomSplitCalculator.calculatePlan(
          originalVideoName: 'test.mp4',
          videoDurationSeconds: 60.0,
          config: config,
        ),
        throwsA(isA<PlanValidationException>()),
      );
    });
  });

  group('CustomSplitCalculator - Interactive Adjustments', () {
    test('adjustBoundary modifies adjacent clips', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byParts,
        targetPartCount: 2,
        startSeconds: 0.0,
        endSeconds: 20.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'sample.mp4',
        videoDurationSeconds: 20.0,
        config: config,
      );

      expect(plan.items[0].endSeconds, 10.0);
      expect(plan.items[1].startSeconds, 10.0);

      final adjusted = CustomSplitCalculator.adjustBoundary(plan, 1, 14.0);
      expect(adjusted.items[0].endSeconds, 14.0);
      expect(adjusted.items[0].durationSeconds, 14.0);
      expect(adjusted.items[1].startSeconds, 14.0);
      expect(adjusted.items[1].durationSeconds, 6.0);
    });

    test('mergeWithNext combines adjacent clips', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byParts,
        targetPartCount: 3,
        startSeconds: 0.0,
        endSeconds: 30.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'sample.mp4',
        videoDurationSeconds: 30.0,
        config: config,
      );

      expect(plan.totalParts, 3);
      final merged = CustomSplitCalculator.mergeWithNext(plan, 0);

      expect(merged.totalParts, 2);
      expect(merged.items[0].startSeconds, 0.0);
      expect(merged.items[0].endSeconds, 20.0);
      expect(merged.items[0].durationSeconds, 20.0);
      expect(merged.items[1].startSeconds, 20.0);
      expect(merged.items[1].endSeconds, 30.0);
    });

    test('splitClip divides clip into two parts', () {
      const config = CustomSplitConfig(
        mode: CustomSplitMode.byParts,
        targetPartCount: 1, // Will clamp to min 2
        startSeconds: 0.0,
        endSeconds: 20.0,
      );

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: 'sample.mp4',
        videoDurationSeconds: 20.0,
        config: config,
      );

      expect(plan.totalParts, 2); // 0..10 and 10..20
      final split = CustomSplitCalculator.splitClip(plan, 0, 4.0);

      expect(split.totalParts, 3);
      expect(split.items[0].startSeconds, 0.0);
      expect(split.items[0].endSeconds, 4.0);
      expect(split.items[1].startSeconds, 4.0);
      expect(split.items[1].endSeconds, 10.0);
      expect(split.items[2].startSeconds, 10.0);
      expect(split.items[2].endSeconds, 20.0);
    });
  });
}
