import '../../../../core/utils/formatters.dart';
import 'background_spec.dart';
import 'canvas_spec.dart';
import 'clip_segment.dart';
import 'overlay_spec.dart';
import 'trim_range.dart';

/// Single item in the editable pre-split plan.
class ClipPlanItem {
  final int index; // 1-based index
  final double startSeconds;
  final double endSeconds;
  final String formattedName;
  final String? customMessage;
  final String? resolvedMessage;
  final bool isMergedTrailing;

  const ClipPlanItem({
    required this.index,
    required this.startSeconds,
    required this.endSeconds,
    required this.formattedName,
    this.customMessage,
    this.resolvedMessage,
    this.isMergedTrailing = false,
  }) : assert(endSeconds > startSeconds, 'endSeconds must exceed startSeconds');

  double get durationSeconds => endSeconds - startSeconds;

  String get formattedStart => Formatters.formatPrecise(startSeconds);
  String get formattedEnd => Formatters.formatPrecise(endSeconds);
  String get formattedDuration => '${durationSeconds.toStringAsFixed(1)}s';
  String get formattedTimeRange => '$formattedStart - $formattedEnd';

  ClipSegment toClipSegment() {
    return ClipSegment(
      index: index,
      startSeconds: startSeconds,
      durationSeconds: durationSeconds,
      formattedName: formattedName,
      isMergedTrailing: isMergedTrailing,
    );
  }

  ClipPlanItem copyWith({
    int? index,
    double? startSeconds,
    double? endSeconds,
    String? formattedName,
    String? customMessage,
    String? resolvedMessage,
    bool? isMergedTrailing,
  }) {
    return ClipPlanItem(
      index: index ?? this.index,
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
      formattedName: formattedName ?? this.formattedName,
      customMessage: customMessage ?? this.customMessage,
      resolvedMessage: resolvedMessage ?? this.resolvedMessage,
      isMergedTrailing: isMergedTrailing ?? this.isMergedTrailing,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipPlanItem &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          startSeconds == other.startSeconds &&
          endSeconds == other.endSeconds &&
          formattedName == other.formattedName &&
          customMessage == other.customMessage &&
          resolvedMessage == other.resolvedMessage &&
          isMergedTrailing == other.isMergedTrailing;

  @override
  int get hashCode => Object.hash(
    index,
    startSeconds,
    endSeconds,
    formattedName,
    customMessage,
    resolvedMessage,
    isMergedTrailing,
  );
}

/// Comprehensive split plan inspected, edited, and approved by the user before processing.
class ClipPlan {
  final List<ClipPlanItem> items;
  final CanvasSpec canvasSpec;
  final BackgroundSpec backgroundSpec;
  final OverlaySpec overlaySpec;
  final bool cropToFill;
  final String baseName;
  final double sourceDurationSeconds;
  final TrimRange trimRange;

  const ClipPlan({
    required this.items,
    required this.canvasSpec,
    required this.backgroundSpec,
    required this.overlaySpec,
    required this.cropToFill,
    required this.baseName,
    required this.sourceDurationSeconds,
    required this.trimRange,
  });

  int get totalParts => items.length;

  double get totalPlannedDurationSeconds =>
      items.fold(0.0, (acc, item) => acc + item.durationSeconds);

  List<ClipSegment> get segments =>
      items.map((e) => e.toClipSegment()).toList();

  ClipPlan copyWith({
    List<ClipPlanItem>? items,
    CanvasSpec? canvasSpec,
    BackgroundSpec? backgroundSpec,
    OverlaySpec? overlaySpec,
    bool? cropToFill,
    String? baseName,
    double? sourceDurationSeconds,
    TrimRange? trimRange,
  }) {
    return ClipPlan(
      items: items ?? this.items,
      canvasSpec: canvasSpec ?? this.canvasSpec,
      backgroundSpec: backgroundSpec ?? this.backgroundSpec,
      overlaySpec: overlaySpec ?? this.overlaySpec,
      cropToFill: cropToFill ?? this.cropToFill,
      baseName: baseName ?? this.baseName,
      sourceDurationSeconds:
          sourceDurationSeconds ?? this.sourceDurationSeconds,
      trimRange: trimRange ?? this.trimRange,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipPlan &&
          runtimeType == other.runtimeType &&
          items == other.items &&
          canvasSpec == other.canvasSpec &&
          backgroundSpec == other.backgroundSpec &&
          overlaySpec == other.overlaySpec &&
          cropToFill == other.cropToFill &&
          baseName == other.baseName &&
          sourceDurationSeconds == other.sourceDurationSeconds &&
          trimRange == other.trimRange;

  @override
  int get hashCode => Object.hash(
    items,
    canvasSpec,
    backgroundSpec,
    overlaySpec,
    cropToFill,
    baseName,
    sourceDurationSeconds,
    trimRange,
  );
}
