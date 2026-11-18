import 'dart:io';

import '../../../split_config/domain/models/clip_plan.dart';
import '../../../split_config/domain/models/clip_segment.dart';

/// Processing lifecycle states for an individual clip segment in a plan.
enum ClipProcessingStatus {
  /// Clip has not yet been submitted or processed.
  notProcessed,

  /// Clip is currently being transcoded or exported.
  processing,

  /// Clip has been successfully exported to storage.
  processed,

  /// Transcoding or writing for this clip encountered an error.
  failed,

  /// Clip was previously processed, but its boundary or overlay was modified.
  stale,

  /// Clip was marked as processed, but its file was moved or deleted from disk.
  missing,
}

/// Rich domain model representing an individual planned part, its selection
/// state, and its processing lifecycle status.
class PartItem {
  final ClipSegment segment;
  final ClipPlanItem? planItem;
  final bool isSelected;
  final ClipProcessingStatus status;
  final String? outputPath;
  final String? failureReason;

  const PartItem({
    required this.segment,
    this.planItem,
    this.isSelected = true,
    this.status = ClipProcessingStatus.notProcessed,
    this.outputPath,
    this.failureReason,
  });

  /// 1-based index in the split plan (e.g., 1, 2, ..., N).
  int get index => segment.index;

  double get startSeconds => segment.startSeconds;
  double get endSeconds => segment.endSeconds;
  double get durationSeconds => segment.durationSeconds;
  String get formattedName => segment.formattedName;
  String get formattedTimeRange => segment.formattedTimeRange;
  String get formattedDuration => segment.formattedDuration;
  String? get resolvedMessage => planItem?.resolvedMessage;
  String? get customMessage => planItem?.customMessage;

  bool get isProcessed => status == ClipProcessingStatus.processed;
  bool get isProcessing => status == ClipProcessingStatus.processing;
  bool get isFailed => status == ClipProcessingStatus.failed;
  bool get isStale => status == ClipProcessingStatus.stale;
  bool get isMissing => status == ClipProcessingStatus.missing;
  bool get isNotProcessed => status == ClipProcessingStatus.notProcessed;

  PartItem copyWith({
    ClipSegment? segment,
    ClipPlanItem? planItem,
    bool? isSelected,
    ClipProcessingStatus? status,
    String? outputPath,
    String? failureReason,
  }) {
    return PartItem(
      segment: segment ?? this.segment,
      planItem: planItem ?? this.planItem,
      isSelected: isSelected ?? this.isSelected,
      status: status ?? this.status,
      outputPath: outputPath ?? this.outputPath,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  Map<String, dynamic> toJson() => {
    'segment': segment.toJson(),
    'isSelected': isSelected,
    'status': status.name,
    'outputPath': outputPath,
    'failureReason': failureReason,
  };

  factory PartItem.fromJson(Map<String, dynamic> json) => PartItem(
    segment: ClipSegment.fromJson(json['segment'] as Map<String, dynamic>),
    isSelected: json['isSelected'] as bool? ?? true,
    status: ClipProcessingStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => ClipProcessingStatus.notProcessed,
    ),
    outputPath: json['outputPath'] as String?,
    failureReason: json['failureReason'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartItem &&
          runtimeType == other.runtimeType &&
          segment.index == other.segment.index &&
          isSelected == other.isSelected &&
          status == other.status &&
          outputPath == other.outputPath &&
          failureReason == other.failureReason;

  @override
  int get hashCode =>
      Object.hash(segment.index, isSelected, status, outputPath, failureReason);
}

/// Pure algorithmic helper functions for managing part selections and state transitions.
class PartSelectionHelpers {
  const PartSelectionHelpers._();

  /// Selects all items in the list.
  static List<PartItem> selectAll(List<PartItem> items) =>
      items.map((i) => i.copyWith(isSelected: true)).toList();

  /// Deselects all items in the list.
  static List<PartItem> selectNone(List<PartItem> items) =>
      items.map((i) => i.copyWith(isSelected: false)).toList();

  /// Inverts the selection state of every item.
  static List<PartItem> invertSelection(List<PartItem> items) =>
      items.map((i) => i.copyWith(isSelected: !i.isSelected)).toList();

  /// Selects only the items whose 1-based index falls within [startPartIndex] and [endPartIndex].
  static List<PartItem> selectRange(
    List<PartItem> items,
    int startPartIndex,
    int endPartIndex,
  ) {
    final low = startPartIndex < endPartIndex ? startPartIndex : endPartIndex;
    final high = startPartIndex < endPartIndex ? endPartIndex : startPartIndex;
    return items.map((i) {
      final inRange = i.index >= low && i.index <= high;
      return i.copyWith(isSelected: inRange);
    }).toList();
  }

  /// Toggles the selection state of the item with 1-based index [partIndex].
  static List<PartItem> toggleSelection(List<PartItem> items, int partIndex) {
    return items.map((i) {
      if (i.index == partIndex) {
        return i.copyWith(isSelected: !i.isSelected);
      }
      return i;
    }).toList();
  }

  /// Updates the status of the item with 1-based index [partIndex].
  static List<PartItem> updateStatus(
    List<PartItem> items,
    int partIndex,
    ClipProcessingStatus newStatus, {
    String? outputPath,
    String? failureReason,
  }) {
    return items.map((i) {
      if (i.index == partIndex) {
        return i.copyWith(
          status: newStatus,
          outputPath: outputPath ?? i.outputPath,
          failureReason: failureReason ?? i.failureReason,
        );
      }
      return i;
    }).toList();
  }

  /// Compares [previousItems] against updated [newPlanItems].
  ///
  /// Invariant:
  /// - Unchanged processed items retain their [ClipProcessingStatus.processed] status.
  /// - Processed items whose boundary or resolved message changed are marked [ClipProcessingStatus.stale].
  /// - New items start as [ClipProcessingStatus.notProcessed].
  /// - User selection is preserved for matching items.
  static List<PartItem> detectStale({
    required List<PartItem> previousItems,
    required List<ClipPlanItem> newPlanItems,
  }) {
    final prevMap = {for (final item in previousItems) item.index: item};

    return newPlanItems.map((newPlan) {
      final prev = prevMap[newPlan.index];
      if (prev == null) {
        return PartItem(
          segment: newPlan.toClipSegment(),
          planItem: newPlan,
          isSelected: true,
          status: ClipProcessingStatus.notProcessed,
        );
      }

      if (prev.status == ClipProcessingStatus.processed) {
        final boundaryChanged =
            (prev.startSeconds - newPlan.startSeconds).abs() > 0.05 ||
            (prev.durationSeconds - newPlan.durationSeconds).abs() > 0.05;
        final messageChanged = prev.resolvedMessage != newPlan.resolvedMessage;

        if (boundaryChanged || messageChanged) {
          return prev.copyWith(
            segment: newPlan.toClipSegment(),
            planItem: newPlan,
            status: ClipProcessingStatus.stale,
          );
        }
      }

      return prev.copyWith(segment: newPlan.toClipSegment(), planItem: newPlan);
    }).toList();
  }

  /// Verifies all processed files on disk. If an output file no longer exists,
  /// its status is transitioned to [ClipProcessingStatus.missing].
  static Future<List<PartItem>> verifyDiskFiles(List<PartItem> items) async {
    final verified = <PartItem>[];
    for (final item in items) {
      if (item.status == ClipProcessingStatus.processed &&
          item.outputPath != null) {
        final path = item.outputPath!;
        if (path.startsWith('content://')) {
          verified.add(item);
        } else {
          final exists = await File(path).exists();
          if (!exists) {
            verified.add(item.copyWith(status: ClipProcessingStatus.missing));
          } else {
            verified.add(item);
          }
        }
      } else {
        verified.add(item);
      }
    }
    return verified;
  }
}
