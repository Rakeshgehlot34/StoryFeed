import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/core/errors/app_exception.dart';
import 'package:shorts_splitter/features/split_config/domain/models/background_spec.dart';
import 'package:shorts_splitter/features/split_config/domain/models/canvas_spec.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_plan.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';
import 'package:shorts_splitter/features/split_config/domain/models/overlay_spec.dart';
import 'package:shorts_splitter/features/split_config/domain/models/plan_calculator.dart';
import 'package:shorts_splitter/features/split_config/domain/models/plan_validator.dart';
import 'package:shorts_splitter/features/split_config/domain/models/trim_range.dart';

void main() {
  group('PlanCalculator & PlanValidator Tests', () {
    const baseName = 'my_video';
    const canvas = CanvasSpec(format: CanvasFormat.shorts916);
    const bg = SolidColorBackgroundSpec();
    const overlay = OverlaySpec(autoLabel: true, template: 'Part {n}/{total}');

    test(
      'Trim inside video generates contiguous slices starting at trim start',
      () {
        final plan = PlanCalculator.generateAutoPlan(
          trimRange: const TrimRange(startSeconds: 15.0, endSeconds: 135.0),
          targetClipDurationSeconds: 60,
          mergeShortTrailingClip: true,
          baseName: baseName,
          canvasSpec: canvas,
          backgroundSpec: bg,
          overlaySpec: overlay,
          cropToFill: false,
          sourceDurationSeconds: 200.0,
        );

        expect(plan.totalParts, equals(2));
        expect(plan.items[0].startSeconds, equals(15.0));
        expect(plan.items[0].endSeconds, equals(75.0));
        expect(plan.items[0].durationSeconds, equals(60.0));
        expect(plan.items[0].formattedName, equals('my_video_part_001.mp4'));

        expect(plan.items[1].startSeconds, equals(75.0));
        expect(plan.items[1].endSeconds, equals(135.0));
        expect(plan.items[1].durationSeconds, equals(60.0));
        expect(plan.items[1].formattedName, equals('my_video_part_002.mp4'));
      },
    );

    test('Trim duration shorter than target clip generates single clip', () {
      final plan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 45.0),
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: true,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 100.0,
      );

      expect(plan.totalParts, equals(1));
      expect(plan.items[0].durationSeconds, equals(45.0));
      expect(plan.items[0].formattedName, equals('my_video_part_001.mp4'));
      // Under default PartLabelMode.auto, a single clip suppresses auto label
      expect(plan.items[0].resolvedMessage, isNull);

      // When PartLabelMode.always is explicitly set, it resolves 'Part 1/1'
      final planAlways = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 45.0),
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: true,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay.copyWith(partLabelMode: PartLabelMode.always),
        cropToFill: false,
        sourceDurationSeconds: 100.0,
      );
      expect(planAlways.items[0].resolvedMessage, equals('Part 1/1'));
    });

    test('Exact multiple duration produces equal-sized parts', () {
      final plan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 180.0),
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: true,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 180.0,
      );

      expect(plan.totalParts, equals(3));
      for (int i = 0; i < 3; i++) {
        expect(plan.items[i].durationSeconds, equals(60.0));
        expect(plan.items[i].startSeconds, equals(i * 60.0));
        expect(plan.items[i].endSeconds, equals((i + 1) * 60.0));
      }
    });

    test('1-second remainder merged into previous clip when merge enabled', () {
      final plan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 61.0),
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: true,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 61.0,
      );

      expect(plan.totalParts, equals(1));
      expect(plan.items[0].durationSeconds, equals(61.0));
      expect(plan.items[0].isMergedTrailing, isTrue);
    });

    test('1-second remainder kept independent when merge disabled', () {
      final plan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 61.0),
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: false,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 61.0,
      );

      expect(plan.totalParts, equals(2));
      expect(plan.items[0].durationSeconds, equals(60.0));
      expect(plan.items[1].durationSeconds, equals(1.0));
    });

    test(
      'Boundary adjustment preserves contiguity and updates both neighbors',
      () {
        final plan = PlanCalculator.generateAutoPlan(
          trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 120.0),
          targetClipDurationSeconds: 60,
          mergeShortTrailingClip: true,
          baseName: baseName,
          canvasSpec: canvas,
          backgroundSpec: bg,
          overlaySpec: overlay,
          cropToFill: false,
          sourceDurationSeconds: 120.0,
        );

        // Initial: [0-60], [60-120]
        // Move boundary to 40.0s
        final updatedItems = PlanCalculator.adjustBoundary(
          items: plan.items,
          boundaryIndex: 0,
          newBoundaryTime: 40.0,
          baseName: baseName,
          overlaySpec: overlay,
        );

        expect(updatedItems[0].endSeconds, equals(40.0));
        expect(updatedItems[0].durationSeconds, equals(40.0));
        expect(updatedItems[1].startSeconds, equals(40.0));
        expect(updatedItems[1].durationSeconds, equals(80.0));
        expect(
          updatedItems[0].endSeconds,
          equals(updatedItems[1].startSeconds),
        );
      },
    );

    test('Boundary adjustment rejects values violating 180s cap or 1s min', () {
      final plan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 200.0),
        targetClipDurationSeconds: 100,
        mergeShortTrailingClip: true,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 200.0,
      );

      // Trying to move boundary to 195s makes right part 5s, but left part 195s (>180s)
      expect(
        () => PlanCalculator.adjustBoundary(
          items: plan.items,
          boundaryIndex: 0,
          newBoundaryTime: 195.0,
          baseName: baseName,
          overlaySpec: overlay,
        ),
        throwsA(isA<PlanValidationException>()),
      );

      // Trying to move boundary to 0.5s makes left part < 1s
      expect(
        () => PlanCalculator.adjustBoundary(
          items: plan.items,
          boundaryIndex: 0,
          newBoundaryTime: 0.5,
          baseName: baseName,
          overlaySpec: overlay,
        ),
        throwsA(isA<PlanValidationException>()),
      );
    });

    test('Merging parts unites ranges and blocks merges exceeding 180s', () {
      final plan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 90.0),
        targetClipDurationSeconds: 30,
        mergeShortTrailingClip: true,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 90.0,
      );

      expect(plan.totalParts, equals(3));

      // Merge part 1 ([0-30]) and part 2 ([30-60])
      final merged = PlanCalculator.mergeWithNext(
        items: plan.items,
        index: 0,
        baseName: baseName,
        overlaySpec: overlay,
      );

      expect(merged.length, equals(2));
      expect(merged[0].startSeconds, equals(0.0));
      expect(merged[0].endSeconds, equals(60.0));
      expect(merged[0].durationSeconds, equals(60.0));
      expect(merged[1].startSeconds, equals(60.0));
      expect(merged[1].endSeconds, equals(90.0));

      // Now create parts that would exceed 180s if merged: [0-100], [100-200]
      final largePlan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 200.0),
        targetClipDurationSeconds: 100,
        mergeShortTrailingClip: true,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 200.0,
      );

      expect(
        () => PlanCalculator.mergeWithNext(
          items: largePlan.items,
          index: 0,
          baseName: baseName,
          overlaySpec: overlay,
        ),
        throwsA(isA<PlanValidationException>()),
      );
    });

    test('Splitting a part into two preserves contiguous boundaries', () {
      final plan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 60.0),
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: true,
        baseName: baseName,
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 60.0,
      );

      final splitItems = PlanCalculator.splitPart(
        items: plan.items,
        index: 0,
        splitTime: 25.0,
        baseName: baseName,
        overlaySpec: overlay,
      );

      expect(splitItems.length, equals(2));
      expect(splitItems[0].startSeconds, equals(0.0));
      expect(splitItems[0].endSeconds, equals(25.0));
      expect(splitItems[0].durationSeconds, equals(25.0));
      expect(splitItems[1].startSeconds, equals(25.0));
      expect(splitItems[1].endSeconds, equals(60.0));
      expect(splitItems[1].durationSeconds, equals(35.0));
      expect(splitItems[0].formattedName, equals('my_video_part_001.mp4'));
      expect(splitItems[1].formattedName, equals('my_video_part_002.mp4'));
    });

    test('PlanValidator enforces hard 180s cap and contiguity', () {
      // Over 180s
      const invalidItem = ClipPlanItem(
        index: 1,
        startSeconds: 0.0,
        endSeconds: 185.0,
        formattedName: 'my_video_part_001.mp4',
      );
      expect(
        () => PlanValidator.validatePlanItems([invalidItem]),
        throwsA(isA<PlanValidationException>()),
      );

      // Under 1.0s
      const shortItem = ClipPlanItem(
        index: 1,
        startSeconds: 0.0,
        endSeconds: 0.8,
        formattedName: 'my_video_part_001.mp4',
      );
      expect(
        () => PlanValidator.validatePlanItems([shortItem]),
        throwsA(isA<PlanValidationException>()),
      );

      // Gap in contiguity
      const gapItem1 = ClipPlanItem(
        index: 1,
        startSeconds: 0.0,
        endSeconds: 30.0,
        formattedName: 'my_video_part_001.mp4',
      );
      const gapItem2 = ClipPlanItem(
        index: 2,
        startSeconds: 32.0, // gap of 2 seconds
        endSeconds: 60.0,
        formattedName: 'my_video_part_002.mp4',
      );
      expect(
        () => PlanValidator.validatePlanItems([gapItem1, gapItem2]),
        throwsA(isA<PlanValidationException>()),
      );
    });

    test('updateBaseName renames all items and updates formatted names', () {
      final plan = PlanCalculator.generateAutoPlan(
        trimRange: const TrimRange(startSeconds: 0.0, endSeconds: 120.0),
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: true,
        baseName: 'original_raw_name',
        canvasSpec: canvas,
        backgroundSpec: bg,
        overlaySpec: overlay,
        cropToFill: false,
        sourceDurationSeconds: 120.0,
      );

      expect(
        plan.items[0].formattedName,
        equals('original_raw_name_part_001.mp4'),
      );
      expect(
        plan.items[1].formattedName,
        equals('original_raw_name_part_002.mp4'),
      );

      final updatedItems = PlanCalculator.updateBaseName(
        items: plan.items,
        newBaseName: 'TokyoTrip',
        overlaySpec: overlay,
      );

      expect(updatedItems.length, equals(2));
      expect(updatedItems[0].formattedName, equals('TokyoTrip_part_001.mp4'));
      expect(updatedItems[1].formattedName, equals('TokyoTrip_part_002.mp4'));
    });

    test(
      '2-hour video trimmed from 00:01:20 (80s) to 00:11:20 (680s) with 30s target generates exactly 20 clips with exact matching timestamps and no extra clips',
      () {
        const twoHoursSeconds = 7200.0;
        const trimStart = 80.0; // 00:01:20.000
        const trimEnd = 680.0; // 00:11:20.000 (10 minutes total trim)
        const targetDuration = 30;

        final plan = PlanCalculator.generateAutoPlan(
          trimRange:
              const TrimRange(startSeconds: trimStart, endSeconds: trimEnd),
          targetClipDurationSeconds: targetDuration,
          mergeShortTrailingClip: true,
          baseName: 'long_vlog',
          canvasSpec: canvas,
          backgroundSpec: bg,
          overlaySpec: overlay,
          cropToFill: false,
          sourceDurationSeconds: twoHoursSeconds,
        );

        expect(plan.totalParts, equals(20));
        expect(plan.totalPlannedDurationSeconds, equals(600.0));

        // Verify Clip 1 starts at 00:01:20 (80.0s)
        expect(plan.items.first.index, equals(1));
        expect(plan.items.first.startSeconds, equals(80.0));
        expect(plan.items.first.endSeconds, equals(110.0));
        expect(plan.items.first.durationSeconds, equals(30.0));
        expect(
          plan.items.first.formattedName,
          equals('long_vlog_part_001.mp4'),
        );

        // Verify Clip 20 ends at 00:11:20 (680.0s)
        expect(plan.items.last.index, equals(20));
        expect(plan.items.last.startSeconds, equals(650.0));
        expect(plan.items.last.endSeconds, equals(680.0));
        expect(plan.items.last.durationSeconds, equals(30.0));
        expect(
          plan.items.last.formattedName,
          equals('long_vlog_part_020.mp4'),
        );

        // Verify contiguous boundaries across all 20 clips
        for (int i = 0; i < plan.items.length - 1; i++) {
          expect(
            plan.items[i].endSeconds,
            equals(plan.items[i + 1].startSeconds),
          );
        }

        // Also verify ClipSegment.calculateSegments with startOffsetSeconds matches
        final segments = ClipSegment.calculateSegments(
          totalDurationSeconds: trimEnd - trimStart,
          startOffsetSeconds: trimStart,
          targetClipDurationSeconds: targetDuration,
          mergeShortTrailingClip: true,
          baseName: 'long_vlog',
        );

        expect(segments.length, equals(20));
        expect(segments.first.startSeconds, equals(80.0));
        expect(
          segments.first.formattedTimeRange,
          equals('01:20 - 01:50 (00:30)'),
        );
        expect(segments.last.endSeconds, equals(680.0));
        expect(
          segments.last.formattedTimeRange,
          equals('10:50 - 11:20 (00:30)'),
        );
      },
    );
  });
}
