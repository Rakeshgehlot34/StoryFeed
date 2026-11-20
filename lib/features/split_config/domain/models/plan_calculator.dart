import '../../../../app/constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import 'background_spec.dart';
import 'canvas_spec.dart';
import 'clip_plan.dart';
import 'fit_layout.dart';
import 'overlay_spec.dart';
import 'plan_validator.dart';
import 'trim_range.dart';

/// Pure mathematical and deterministic planner for video split segments.
class PlanCalculator {
  PlanCalculator._();

  /// Generates the initial auto-suggested plan based on user settings and trim range.
  static ClipPlan generateAutoPlan({
    required TrimRange trimRange,
    required int targetClipDurationSeconds,
    required bool mergeShortTrailingClip,
    required String baseName,
    required CanvasSpec canvasSpec,
    required BackgroundSpec backgroundSpec,
    required OverlaySpec overlaySpec,
    required bool cropToFill,
    required double sourceDurationSeconds,
    double trailingThresholdSeconds =
        AppConstants.trailingClipMergeThresholdSeconds,
    VerticalPosition verticalPosition = VerticalPosition.center,
    double verticalOffsetFraction = 0.0,
    SinglePartFileNameMode singlePartFileNameMode =
        SinglePartFileNameMode.keepPartSuffix,
  }) {
    PlanValidator.validateTrimRange(trimRange, sourceDurationSeconds);

    final target = targetClipDurationSeconds
        .clamp(
          AppConstants.minClipDurationSeconds,
          AppConstants.maxClipDurationSeconds,
        )
        .toDouble();

    final trimDuration = trimRange.durationSeconds;
    final trimStart = trimRange.startSeconds;
    final trimEnd = trimRange.endSeconds;

    final rawSegments = <_RawSegment>[];

    if (trimDuration <= target) {
      rawSegments.add(_RawSegment(start: trimStart, end: trimEnd));
    } else {
      final fullClipCount = (trimDuration / target).floor();
      final remainder = trimDuration - (fullClipCount * target);

      // Trailing remainder can only be merged if it doesn't violate the 180s hard cap
      final canMergeWithoutExceedingCap =
          (target + remainder) <= AppConstants.maxClipDurationSeconds;
      final shouldMerge = mergeShortTrailingClip &&
          remainder > 0.05 &&
          remainder < trailingThresholdSeconds &&
          fullClipCount >= 1 &&
          canMergeWithoutExceedingCap;

      for (int i = 0; i < fullClipCount; i++) {
        final start = trimStart + (i * target);
        final isLastFull = (i == fullClipCount - 1);

        if (isLastFull && shouldMerge) {
          rawSegments.add(
            _RawSegment(start: start, end: trimEnd, isMergedTrailing: true),
          );
        } else {
          rawSegments.add(_RawSegment(start: start, end: start + target));
        }
      }

      if (remainder > 0.05 && !shouldMerge) {
        final start = trimStart + (fullClipCount * target);
        rawSegments.add(_RawSegment(start: start, end: trimEnd));
      }
    }

    final totalParts = rawSegments.length;
    final items = <ClipPlanItem>[];

    for (int i = 0; i < totalParts; i++) {
      final raw = rawSegments[i];
      final partIndex = i + 1;
      final fileName = (totalParts == 1 &&
              singlePartFileNameMode == SinglePartFileNameMode.originalNameOnly)
          ? '$baseName.mp4'
          : Formatters.formatClipFileName(baseName, partIndex, totalParts);
      final resolvedText = overlaySpec.resolveText(
        partIndex: partIndex,
        totalParts: totalParts,
        baseName: baseName,
      );

      items.add(
        ClipPlanItem(
          index: partIndex,
          startSeconds: raw.start,
          endSeconds: raw.end,
          formattedName: fileName,
          resolvedMessage: resolvedText,
          isMergedTrailing: raw.isMergedTrailing,
        ),
      );
    }

    final plan = ClipPlan(
      items: items,
      canvasSpec: canvasSpec,
      backgroundSpec: backgroundSpec,
      overlaySpec: overlaySpec,
      cropToFill: cropToFill,
      baseName: baseName,
      sourceDurationSeconds: sourceDurationSeconds,
      trimRange: trimRange,
      verticalPosition: verticalPosition,
      verticalOffsetFraction: verticalOffsetFraction,
      singlePartFileNameMode: singlePartFileNameMode,
    );

    PlanValidator.validatePlan(plan);
    return plan;
  }

  /// Adjusts the cut boundary between item [boundaryIndex] and [boundaryIndex + 1].
  /// [boundaryIndex] is 0-based.
  static List<ClipPlanItem> adjustBoundary({
    required List<ClipPlanItem> items,
    required int boundaryIndex,
    required double newBoundaryTime,
    required String baseName,
    required OverlaySpec overlaySpec,
    SinglePartFileNameMode singlePartFileNameMode =
        SinglePartFileNameMode.keepPartSuffix,
  }) {
    if (boundaryIndex < 0 || boundaryIndex >= items.length - 1) {
      throw const PlanValidationException('Invalid boundary index.');
    }

    final prev = items[boundaryIndex];
    final next = items[boundaryIndex + 1];

    final newPrevDuration = newBoundaryTime - prev.startSeconds;
    final newNextDuration = next.endSeconds - newBoundaryTime;

    if (newPrevDuration < AppConstants.minClipDurationSeconds) {
      throw PlanValidationException(
        'Left clip duration (${newPrevDuration.toStringAsFixed(1)}s) is below 1.0 second.',
        durationSeconds: newPrevDuration,
      );
    }
    if (newPrevDuration > AppConstants.maxClipDurationSeconds) {
      throw PlanValidationException(
        'Left clip duration (${newPrevDuration.toStringAsFixed(1)}s) exceeds 180 seconds hard cap.',
        durationSeconds: newPrevDuration,
      );
    }

    if (newNextDuration < AppConstants.minClipDurationSeconds) {
      throw PlanValidationException(
        'Right clip duration (${newNextDuration.toStringAsFixed(1)}s) is below 1.0 second.',
        durationSeconds: newNextDuration,
      );
    }
    if (newNextDuration > AppConstants.maxClipDurationSeconds) {
      throw PlanValidationException(
        'Right clip duration (${newNextDuration.toStringAsFixed(1)}s) exceeds 180 seconds hard cap.',
        durationSeconds: newNextDuration,
      );
    }

    final updated = List<ClipPlanItem>.from(items);
    updated[boundaryIndex] = prev.copyWith(endSeconds: newBoundaryTime);
    updated[boundaryIndex + 1] = next.copyWith(startSeconds: newBoundaryTime);

    return _rebuildItemMetadata(
      updated,
      baseName,
      overlaySpec,
      singlePartFileNameMode,
    );
  }

  /// Merges part [index] with its successor [index + 1].
  static List<ClipPlanItem> mergeWithNext({
    required List<ClipPlanItem> items,
    required int index,
    required String baseName,
    required OverlaySpec overlaySpec,
    SinglePartFileNameMode singlePartFileNameMode =
        SinglePartFileNameMode.keepPartSuffix,
  }) {
    if (index < 0 || index >= items.length - 1) {
      throw const PlanValidationException('Cannot merge last clip with next.');
    }

    final current = items[index];
    final next = items[index + 1];
    final combinedDuration = next.endSeconds - current.startSeconds;

    if (combinedDuration > AppConstants.maxClipDurationSeconds) {
      throw PlanValidationException(
        'Merged clip duration (${combinedDuration.toStringAsFixed(1)}s) exceeds 180s YouTube Shorts hard cap.',
        durationSeconds: combinedDuration,
      );
    }

    final merged = ClipPlanItem(
      index: current.index,
      startSeconds: current.startSeconds,
      endSeconds: next.endSeconds,
      formattedName: current.formattedName,
      customMessage: current.customMessage ?? next.customMessage,
      isMergedTrailing: true,
      partLabelOverride: current.partLabelOverride,
    );

    final updated = List<ClipPlanItem>.from(items);
    updated.removeAt(index + 1);
    updated[index] = merged;

    return _rebuildItemMetadata(
      updated,
      baseName,
      overlaySpec,
      singlePartFileNameMode,
    );
  }

  /// Splits part [index] into two separate contiguous clips at [splitTime].
  static List<ClipPlanItem> splitPart({
    required List<ClipPlanItem> items,
    required int index,
    required double splitTime,
    required String baseName,
    required OverlaySpec overlaySpec,
    SinglePartFileNameMode singlePartFileNameMode =
        SinglePartFileNameMode.keepPartSuffix,
  }) {
    if (index < 0 || index >= items.length) {
      throw const PlanValidationException('Invalid clip index to split.');
    }

    final target = items[index];
    final leftDur = splitTime - target.startSeconds;
    final rightDur = target.endSeconds - splitTime;

    if (leftDur < AppConstants.minClipDurationSeconds ||
        rightDur < AppConstants.minClipDurationSeconds) {
      throw const PlanValidationException(
        'Both split parts must have at least 1.0 second duration.',
      );
    }

    final left = ClipPlanItem(
      index: target.index,
      startSeconds: target.startSeconds,
      endSeconds: splitTime,
      formattedName: target.formattedName,
      customMessage: target.customMessage,
      partLabelOverride: target.partLabelOverride,
    );

    final right = ClipPlanItem(
      index: target.index + 1,
      startSeconds: splitTime,
      endSeconds: target.endSeconds,
      formattedName: '',
    );

    final updated = List<ClipPlanItem>.from(items);
    updated.removeAt(index);
    updated.insert(index, right);
    updated.insert(index, left);

    return _rebuildItemMetadata(
      updated,
      baseName,
      overlaySpec,
      singlePartFileNameMode,
    );
  }

  /// Updates specific part custom overlay message.
  static List<ClipPlanItem> updatePartMessage({
    required List<ClipPlanItem> items,
    required int index,
    required String? customMessage,
    required String baseName,
    required OverlaySpec overlaySpec,
  }) {
    if (index < 0 || index >= items.length) {
      throw const PlanValidationException(
        'Invalid clip index for message update.',
      );
    }

    final updated = List<ClipPlanItem>.from(items);
    final target = updated[index];
    updated[index] = target.copyWith(
      customMessage: customMessage,
      resolvedMessage: overlaySpec.resolveText(
        partIndex: target.index,
        totalParts: items.length,
        baseName: baseName,
        specificPartOverride: customMessage,
        perPartOverride: target.partLabelOverride,
      ),
    );

    return updated;
  }

  /// Updates specific part label override (Use Project Default, Show, Hide).
  static List<ClipPlanItem> updatePartLabelOverride({
    required List<ClipPlanItem> items,
    required int index,
    required PartLabelOverride override,
    required String baseName,
    required OverlaySpec overlaySpec,
  }) {
    if (index < 0 || index >= items.length) {
      throw const PlanValidationException(
        'Invalid clip index for label override update.',
      );
    }

    final updated = List<ClipPlanItem>.from(items);
    final target = updated[index];
    updated[index] = target.copyWith(
      partLabelOverride: override,
      resolvedMessage: overlaySpec.resolveText(
        partIndex: target.index,
        totalParts: items.length,
        baseName: baseName,
        specificPartOverride: target.customMessage,
        perPartOverride: override,
      ),
    );

    return updated;
  }

  /// Re-generates file names and overlay messages for all items with a new base name.
  static List<ClipPlanItem> updateBaseName({
    required List<ClipPlanItem> items,
    required String newBaseName,
    required OverlaySpec overlaySpec,
    SinglePartFileNameMode singlePartFileNameMode =
        SinglePartFileNameMode.keepPartSuffix,
  }) {
    return _rebuildItemMetadata(
      items,
      newBaseName,
      overlaySpec,
      singlePartFileNameMode,
    );
  }

  /// Re-resolves messages and filenames for all items.
  static List<ClipPlanItem> _rebuildItemMetadata(
    List<ClipPlanItem> rawItems,
    String baseName,
    OverlaySpec overlaySpec,
    SinglePartFileNameMode singlePartFileNameMode,
  ) {
    final total = rawItems.length;
    final result = <ClipPlanItem>[];

    for (int i = 0; i < total; i++) {
      final partIndex = i + 1;
      final raw = rawItems[i];
      final name = (total == 1 &&
              singlePartFileNameMode == SinglePartFileNameMode.originalNameOnly)
          ? '$baseName.mp4'
          : Formatters.formatClipFileName(baseName, partIndex, total);
      final text = overlaySpec.resolveText(
        partIndex: partIndex,
        totalParts: total,
        baseName: baseName,
        specificPartOverride: raw.customMessage,
        perPartOverride: raw.partLabelOverride,
      );

      result.add(
        ClipPlanItem(
          index: partIndex,
          startSeconds: raw.startSeconds,
          endSeconds: raw.endSeconds,
          formattedName: name,
          customMessage: raw.customMessage,
          resolvedMessage: text,
          isMergedTrailing: raw.isMergedTrailing,
          partLabelOverride: raw.partLabelOverride,
        ),
      );
    }

    PlanValidator.validatePlanItems(result);
    return result;
  }
}

class _RawSegment {
  final double start;
  final double end;
  final bool isMergedTrailing;

  const _RawSegment({
    required this.start,
    required this.end,
    this.isMergedTrailing = false,
  });
}
