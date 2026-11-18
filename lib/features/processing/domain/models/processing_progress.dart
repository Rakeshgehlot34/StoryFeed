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
  final String? errorMessage;
  final List<String> outputPaths;

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
    this.errorMessage,
    this.outputPaths = const [],
  });

  bool get isProcessing =>
      status == ProcessingStatus.processing ||
      status == ProcessingStatus.preparing;
  bool get isCompleted => status == ProcessingStatus.completed;
  bool get isCancelled => status == ProcessingStatus.cancelled;
  bool get hasError => status == ProcessingStatus.error;

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
    String? errorMessage,
    List<String>? outputPaths,
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
      errorMessage: errorMessage ?? this.errorMessage,
      outputPaths: outputPaths ?? this.outputPaths,
    );
  }
}
