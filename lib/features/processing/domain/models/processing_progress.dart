import 'part_progress_state.dart';

enum ProcessingStatus {
  idle,
  preparing,
  processing,
  completed,
  cancelled,
  error,
}

/// Snapshot of the ongoing video split and encoding process.
class ProcessingProgress {
  final ProcessingStatus status;
  final int currentClipIndex;
  final int totalClips;
  final double currentClipProgress; // 0.0 - 1.0
  final double overallProgress; // 0.0 - 1.0
  final String currentClipName;
  final double speed;
  final double fps;
  final Duration currentTime;
  final Duration targetClipDuration;
  final String stageLabel; // Preparing, Cutting, Encoding, Saving, Verifying
  final Duration elapsed;
  final Duration? eta;
  final String? errorMessage;
  final List<String> outputPaths;
  final Map<int, PartProgressState> partProgressMap;

  const ProcessingProgress({
    this.status = ProcessingStatus.idle,
    this.currentClipIndex = 0,
    this.totalClips = 0,
    this.currentClipProgress = 0.0,
    this.overallProgress = 0.0,
    this.currentClipName = '',
    this.speed = 1.0,
    this.fps = 0.0,
    this.currentTime = Duration.zero,
    this.targetClipDuration = Duration.zero,
    this.stageLabel = 'Idle',
    this.elapsed = Duration.zero,
    this.eta,
    this.errorMessage,
    this.outputPaths = const [],
    this.partProgressMap = const {},
  });

  bool get isProcessing =>
      status == ProcessingStatus.processing ||
      status == ProcessingStatus.preparing;
  bool get isCompleted => status == ProcessingStatus.completed;
  bool get isCancelled => status == ProcessingStatus.cancelled;
  bool get hasError => status == ProcessingStatus.error;

  int get overallPercent => (overallProgress * 100).clamp(0, 100).toInt();

  ProcessingProgress copyWith({
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
  }) {
    return ProcessingProgress(
      status: status ?? this.status,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      totalClips: totalClips ?? this.totalClips,
      currentClipProgress: currentClipProgress ?? this.currentClipProgress,
      overallProgress: overallProgress ?? this.overallProgress,
      currentClipName: currentClipName ?? this.currentClipName,
      speed: speed ?? this.speed,
      fps: fps ?? this.fps,
      currentTime: currentTime ?? this.currentTime,
      targetClipDuration: targetClipDuration ?? this.targetClipDuration,
      stageLabel: stageLabel ?? this.stageLabel,
      elapsed: elapsed ?? this.elapsed,
      eta: eta ?? this.eta,
      errorMessage: errorMessage ?? this.errorMessage,
      outputPaths: outputPaths ?? this.outputPaths,
      partProgressMap: partProgressMap ?? this.partProgressMap,
    );
  }
}
