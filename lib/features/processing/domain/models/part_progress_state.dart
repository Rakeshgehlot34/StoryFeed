/// Granular progress state for an individual part clip.
class PartProgressState {
  final int partIndex;
  final double progress; // 0.0 to 1.0
  final String
      stageLabel; // Preparing, Cutting, Encoding, Saving, Verifying, Completed, Failed
  final double speed;
  final Duration elapsed;
  final Duration? eta;
  final String? errorMessage;

  const PartProgressState({
    required this.partIndex,
    this.progress = 0.0,
    this.stageLabel = 'Idle',
    this.speed = 1.0,
    this.elapsed = Duration.zero,
    this.eta,
    this.errorMessage,
  });

  int get percent => (progress * 100).clamp(0, 100).toInt();

  PartProgressState copyWith({
    double? progress,
    String? stageLabel,
    double? speed,
    Duration? elapsed,
    Duration? eta,
    String? errorMessage,
  }) =>
      PartProgressState(
        partIndex: partIndex,
        progress: progress ?? this.progress,
        stageLabel: stageLabel ?? this.stageLabel,
        speed: speed ?? this.speed,
        elapsed: elapsed ?? this.elapsed,
        eta: eta ?? this.eta,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}
