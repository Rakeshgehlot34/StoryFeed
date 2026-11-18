import 'dart:math' as math;

import '../../../core/errors/app_exception.dart';
import 'models/custom_clip_plan.dart';
import 'models/custom_split_config.dart';

/// Pure mathematical calculation engine for the Custom Split tool.
/// Computes contiguous clip intervals across all 4 modes (duration, parts, points, size).
class CustomSplitCalculator {
  /// Computes a [CustomClipPlan] based on video parameters and [CustomSplitConfig].
  static CustomClipPlan calculatePlan({
    required String originalVideoName,
    required double videoDurationSeconds,
    required CustomSplitConfig config,
    int bitrateBps = 0,
  }) {
    if (videoDurationSeconds <= 0.0) {
      throw const PlanValidationException(
        'Source video duration must be greater than zero.',
      );
    }

    final double effectiveStart = config.startSeconds.clamp(
      0.0,
      videoDurationSeconds,
    );
    double effectiveEnd = config.endSeconds;
    if (effectiveEnd <= effectiveStart || effectiveEnd > videoDurationSeconds) {
      effectiveEnd = videoDurationSeconds;
    }

    final double activeRange = effectiveEnd - effectiveStart;
    if (activeRange < 1.0) {
      throw const PlanValidationException(
        'Selected split range must be at least 1.0 second.',
      );
    }

    // Default effective bitrate if probe did not report or 0
    final effectiveBitrate = bitrateBps > 0
        ? bitrateBps
        : (5 * 1000 * 1000); // 5 Mbps default

    final List<_Interval> rawIntervals = switch (config.mode) {
      CustomSplitMode.byDuration => _calculateByDuration(
        start: effectiveStart,
        end: effectiveEnd,
        clipDuration: config.targetDurationSeconds,
        mergeTrailing: config.mergeShortTrailingClip,
        mergeThreshold: config.trailingMergeThresholdSeconds,
      ),
      CustomSplitMode.byParts => _calculateByParts(
        start: effectiveStart,
        end: effectiveEnd,
        parts: config.targetPartCount,
      ),
      CustomSplitMode.byPoints => _calculateByPoints(
        start: effectiveStart,
        end: effectiveEnd,
        points: config.customSplitPoints,
      ),
      CustomSplitMode.bySize => _calculateBySize(
        start: effectiveStart,
        end: effectiveEnd,
        sizeMb: config.targetSizeMb,
        bitrateBps: effectiveBitrate,
        mergeTrailing: config.mergeShortTrailingClip,
        mergeThreshold: config.trailingMergeThresholdSeconds,
      ),
    };

    if (rawIntervals.isEmpty) {
      throw const PlanValidationException(
        'No split clips could be generated from configuration.',
      );
    }

    final totalClips = rawIntervals.length;
    final padWidth = _calculatePadWidth(totalClips);

    final cleanBase = config.customBaseName.trim().isNotEmpty
        ? _sanitizeBaseName(config.customBaseName.trim())
        : _deriveBaseName(originalVideoName);

    final items = <CustomClipItem>[];
    int totalEstimatedBytes = 0;

    for (int i = 0; i < totalClips; i++) {
      final interval = rawIntervals[i];
      final partIndex = i + 1;
      final partSuffix = partIndex.toString().padLeft(padWidth, '0');
      final fileName = '${cleanBase}_part_$partSuffix.mp4';
      final duration = interval.end - interval.start;
      final estimatedBytes = ((duration * effectiveBitrate) / 8).round();
      totalEstimatedBytes += estimatedBytes;

      items.add(
        CustomClipItem(
          index: partIndex,
          formattedName: fileName,
          startSeconds: interval.start,
          endSeconds: interval.end,
          durationSeconds: duration,
          estimatedSizeBytes: estimatedBytes,
          isKeyframeAccurate: config.method == SplitMethod.precise,
        ),
      );
    }

    return CustomClipPlan(
      originalVideoName: originalVideoName,
      baseName: cleanBase,
      totalDurationSeconds: videoDurationSeconds,
      splitMode: config.mode,
      splitMethod: config.method,
      items: items,
      estimatedTotalSizeBytes: totalEstimatedBytes,
    );
  }

  static List<_Interval> _calculateByDuration({
    required double start,
    required double end,
    required double clipDuration,
    required bool mergeTrailing,
    required double mergeThreshold,
  }) {
    final step = clipDuration.clamp(1.0, 86400.0);
    final intervals = <_Interval>[];

    double current = start;
    while (current < end) {
      final next = math.min(current + step, end);
      intervals.add(_Interval(current, next));
      current = next;
    }

    // Trailing remainder merge
    if (mergeTrailing && intervals.length > 1) {
      final lastInterval = intervals.last;
      final lastDuration = lastInterval.end - lastInterval.start;
      if (lastDuration > 0.05 && lastDuration < mergeThreshold) {
        final penultimate = intervals[intervals.length - 2];
        intervals[intervals.length - 2] = _Interval(
          penultimate.start,
          lastInterval.end,
        );
        intervals.removeLast();
      }
    }

    return intervals;
  }

  static List<_Interval> _calculateByParts({
    required double start,
    required double end,
    required int parts,
  }) {
    final count = parts.clamp(2, 50);
    final totalRange = end - start;
    final step = totalRange / count;
    final intervals = <_Interval>[];

    for (int i = 0; i < count; i++) {
      final s = start + (i * step);
      final e = (i == count - 1) ? end : (start + ((i + 1) * step));
      intervals.add(_Interval(s, e));
    }

    return intervals;
  }

  static List<_Interval> _calculateByPoints({
    required double start,
    required double end,
    required List<double> points,
  }) {
    // Filter points strictly between start and end
    final validPoints =
        points.where((p) => p > start + 0.1 && p < end - 0.1).toSet().toList()
          ..sort();

    final boundaries = [start, ...validPoints, end];
    final intervals = <_Interval>[];

    for (int i = 0; i < boundaries.length - 1; i++) {
      final s = boundaries[i];
      final e = boundaries[i + 1];
      if (e - s >= 0.1) {
        intervals.add(_Interval(s, e));
      }
    }

    return intervals;
  }

  static List<_Interval> _calculateBySize({
    required double start,
    required double end,
    required double sizeMb,
    required int bitrateBps,
    required bool mergeTrailing,
    required double mergeThreshold,
  }) {
    final targetMb = sizeMb.clamp(1.0, 10000.0);
    final targetBytes = targetMb * 1024 * 1024;
    final durationSeconds = (targetBytes * 8) / bitrateBps;
    final clampedDuration = durationSeconds.clamp(1.0, 86400.0);

    return _calculateByDuration(
      start: start,
      end: end,
      clipDuration: clampedDuration,
      mergeTrailing: mergeTrailing,
      mergeThreshold: mergeThreshold,
    );
  }

  /// Adjusts the cut boundary between two adjacent clips.
  static CustomClipPlan adjustBoundary(
    CustomClipPlan plan,
    int clipIndex,
    double newBoundary,
  ) {
    if (clipIndex < 1 || clipIndex >= plan.items.length) {
      throw const PlanValidationException(
        'Invalid clip index for boundary adjustment.',
      );
    }

    final prev = plan.items[clipIndex - 1];
    final curr = plan.items[clipIndex];

    if (newBoundary <= prev.startSeconds + 0.5 ||
        newBoundary >= curr.endSeconds - 0.5) {
      throw const PlanValidationException(
        'Adjusted boundary must leave at least 0.5 seconds in both adjacent clips.',
      );
    }

    final updatedItems = List<CustomClipItem>.from(plan.items);
    final prevDuration = newBoundary - prev.startSeconds;
    final currDuration = curr.endSeconds - newBoundary;

    final bitrate =
        (plan.totalDurationSeconds > 0 && plan.estimatedTotalSizeBytes > 0)
        ? ((plan.estimatedTotalSizeBytes * 8) / plan.totalDurationSeconds)
              .round()
        : (5 * 1000 * 1000);

    updatedItems[clipIndex - 1] = prev.copyWith(
      endSeconds: newBoundary,
      durationSeconds: prevDuration,
      estimatedSizeBytes: ((prevDuration * bitrate) / 8).round(),
    );

    updatedItems[clipIndex] = curr.copyWith(
      startSeconds: newBoundary,
      durationSeconds: currDuration,
      estimatedSizeBytes: ((currDuration * bitrate) / 8).round(),
    );

    return plan.copyWith(items: updatedItems);
  }

  /// Merges clip at [index] with its succeeding clip [index + 1].
  static CustomClipPlan mergeWithNext(CustomClipPlan plan, int index) {
    if (index < 0 || index >= plan.items.length - 1) {
      throw const PlanValidationException(
        'Cannot merge: clip is the last item.',
      );
    }

    final first = plan.items[index];
    final second = plan.items[index + 1];

    final mergedDuration = second.endSeconds - first.startSeconds;
    final padWidth = _calculatePadWidth(plan.items.length - 1);

    final newItems = <CustomClipItem>[];
    int newIdx = 1;

    for (int i = 0; i < plan.items.length; i++) {
      if (i == index) {
        final partSuffix = newIdx.toString().padLeft(padWidth, '0');
        newItems.add(
          CustomClipItem(
            index: newIdx,
            formattedName: '${plan.baseName}_part_$partSuffix.mp4',
            startSeconds: first.startSeconds,
            endSeconds: second.endSeconds,
            durationSeconds: mergedDuration,
            estimatedSizeBytes:
                first.estimatedSizeBytes + second.estimatedSizeBytes,
            isKeyframeAccurate: plan.splitMethod == SplitMethod.precise,
          ),
        );
        newIdx++;
        i++; // skip second
      } else {
        final partSuffix = newIdx.toString().padLeft(padWidth, '0');
        newItems.add(
          plan.items[i].copyWith(
            index: newIdx,
            formattedName: '${plan.baseName}_part_$partSuffix.mp4',
          ),
        );
        newIdx++;
      }
    }

    return plan.copyWith(items: newItems);
  }

  /// Splits clip at [index] into two parts at [splitPoint].
  static CustomClipPlan splitClip(
    CustomClipPlan plan,
    int index,
    double splitPoint,
  ) {
    if (index < 0 || index >= plan.items.length) {
      throw const PlanValidationException('Invalid clip index for split.');
    }

    final target = plan.items[index];
    if (splitPoint <= target.startSeconds + 0.5 ||
        splitPoint >= target.endSeconds - 0.5) {
      throw const PlanValidationException(
        'Split point must be at least 0.5s from the clip start and end boundaries.',
      );
    }

    final totalNewClips = plan.items.length + 1;
    final padWidth = _calculatePadWidth(totalNewClips);
    final bitrate =
        (plan.totalDurationSeconds > 0 && plan.estimatedTotalSizeBytes > 0)
        ? ((plan.estimatedTotalSizeBytes * 8) / plan.totalDurationSeconds)
              .round()
        : (5 * 1000 * 1000);

    final newItems = <CustomClipItem>[];
    int newIdx = 1;

    for (int i = 0; i < plan.items.length; i++) {
      if (i == index) {
        // First half
        final dur1 = splitPoint - target.startSeconds;
        final suffix1 = newIdx.toString().padLeft(padWidth, '0');
        newItems.add(
          CustomClipItem(
            index: newIdx,
            formattedName: '${plan.baseName}_part_$suffix1.mp4',
            startSeconds: target.startSeconds,
            endSeconds: splitPoint,
            durationSeconds: dur1,
            estimatedSizeBytes: ((dur1 * bitrate) / 8).round(),
            isKeyframeAccurate: plan.splitMethod == SplitMethod.precise,
          ),
        );
        newIdx++;

        // Second half
        final dur2 = target.endSeconds - splitPoint;
        final suffix2 = newIdx.toString().padLeft(padWidth, '0');
        newItems.add(
          CustomClipItem(
            index: newIdx,
            formattedName: '${plan.baseName}_part_$suffix2.mp4',
            startSeconds: splitPoint,
            endSeconds: target.endSeconds,
            durationSeconds: dur2,
            estimatedSizeBytes: ((dur2 * bitrate) / 8).round(),
            isKeyframeAccurate: plan.splitMethod == SplitMethod.precise,
          ),
        );
        newIdx++;
      } else {
        final suffix = newIdx.toString().padLeft(padWidth, '0');
        newItems.add(
          plan.items[i].copyWith(
            index: newIdx,
            formattedName: '${plan.baseName}_part_$suffix.mp4',
          ),
        );
        newIdx++;
      }
    }

    return plan.copyWith(items: newItems);
  }

  static int _calculatePadWidth(int totalClips) {
    if (totalClips <= 0) return 3;
    final digits = (math.log(totalClips) / math.ln10).floor() + 1;
    return math.max(3, digits);
  }

  static String _deriveBaseName(String sourceName) {
    var name = sourceName;
    final dotIdx = name.lastIndexOf('.');
    if (dotIdx > 0) {
      name = name.substring(0, dotIdx);
    }
    return _sanitizeBaseName(name);
  }

  static String _sanitizeBaseName(String name) {
    return name
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}

class _Interval {
  final double start;
  final double end;
  const _Interval(this.start, this.end);
}
