import 'dart:async';

import '../../split_config/domain/models/clip_segment.dart';
import 'models/part_progress_state.dart';
import 'models/processing_progress.dart';

class ProgressTracker {
  static const int throttleIntervalMs = 250; // 4 Hz throttling

  ProcessingProgress _current = const ProcessingProgress();
  int _lastEmitTimestamp = 0;
  final StreamController<ProcessingProgress> _controller =
      StreamController<ProcessingProgress>.broadcast();

  Stream<ProcessingProgress> get stream => _controller.stream;
  ProcessingProgress get current => _current;

  void reset() {
    _current = const ProcessingProgress();
    _lastEmitTimestamp = 0;
    _controller.add(_current);
  }

  void update({
    ProcessingStatus? status,
    int? currentClipIndex,
    int? totalClips,
    double? currentClipProgress,
    double? overallProgress,
    String? currentClipName,
    double? speed,
    double? fps,
    Duration? currentTime,
    Duration? targetClipDuration,
    String? stageLabel,
    Duration? elapsed,
    Duration? eta,
    String? errorMessage,
    List<String>? outputPaths,
    Map<int, PartProgressState>? partProgressMap,
    bool force = false,
  }) {
    // Monotonic clamping for overall and clip progress
    final newOverall = overallProgress != null
        ? (overallProgress < _current.overallProgress &&
                status != ProcessingStatus.idle
            ? _current.overallProgress
            : overallProgress.clamp(0.0, 1.0))
        : _current.overallProgress;

    final newClipProgress = currentClipProgress != null
        ? currentClipProgress.clamp(0.0, 1.0)
        : _current.currentClipProgress;

    // Merge partProgressMap monotonically
    final updatedPartMap =
        Map<int, PartProgressState>.from(_current.partProgressMap);
    if (partProgressMap != null) {
      for (final entry in partProgressMap.entries) {
        final existing = updatedPartMap[entry.key];
        final newProg =
            existing != null && entry.value.progress < existing.progress
                ? existing.progress
                : entry.value.progress;
        updatedPartMap[entry.key] = entry.value.copyWith(progress: newProg);
      }
    }

    _current = _current.copyWith(
      status: status,
      currentClipIndex: currentClipIndex,
      totalClips: totalClips,
      currentClipProgress: newClipProgress,
      overallProgress: newOverall,
      currentClipName: currentClipName,
      speed: speed,
      fps: fps,
      currentTime: currentTime,
      targetClipDuration: targetClipDuration,
      stageLabel: stageLabel,
      elapsed: elapsed,
      eta: eta,
      errorMessage: errorMessage,
      outputPaths: outputPaths,
      partProgressMap: updatedPartMap,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    final isTerminal = status == ProcessingStatus.completed ||
        status == ProcessingStatus.error ||
        status == ProcessingStatus.cancelled;

    if (force ||
        isTerminal ||
        (now - _lastEmitTimestamp >= throttleIntervalMs)) {
      _lastEmitTimestamp = now;
      _controller.add(_current);
    }
  }

  /// Derives individual part progress from single-pass FFmpeg output time position.
  static Map<int, PartProgressState> deriveSinglePassParts({
    required double currentTimeSeconds,
    required List<ClipSegment> segments,
    required double speed,
    required Duration elapsed,
  }) {
    final map = <int, PartProgressState>{};

    for (final seg in segments) {
      final index = seg.index;
      final start = seg.startSeconds;
      final end = seg.endSeconds;
      final duration = seg.durationSeconds;

      if (currentTimeSeconds >= end) {
        map[index] = PartProgressState(
          partIndex: index,
          progress: 1.0,
          stageLabel: 'Completed',
          speed: speed,
          elapsed: elapsed,
        );
      } else if (currentTimeSeconds < start) {
        map[index] = PartProgressState(
          partIndex: index,
          progress: 0.0,
          stageLabel: 'Queued',
          speed: speed,
          elapsed: elapsed,
        );
      } else {
        final partProgress =
            duration > 0 ? (currentTimeSeconds - start) / duration : 0.0;
        final remainingSec = (end - currentTimeSeconds);
        final eta = speed > 0
            ? Duration(milliseconds: ((remainingSec / speed) * 1000).toInt())
            : null;

        map[index] = PartProgressState(
          partIndex: index,
          progress: partProgress.clamp(0.0, 1.0),
          stageLabel: 'Cutting',
          speed: speed,
          elapsed: elapsed,
          eta: eta,
        );
      }
    }

    return map;
  }

  void dispose() {
    _controller.close();
  }
}
