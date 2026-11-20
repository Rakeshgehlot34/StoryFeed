/// Supported splitting modes for the general Custom Split tool.
enum CustomSplitMode {
  /// Split into uniform intervals of X seconds (no 180s cap).
  byDuration,

  /// Split video into N equal parts.
  byParts,

  /// User-defined explicit split points.
  byPoints,

  /// Target file size per clip (estimated based on video bitrate, requires re-encode).
  bySize,
}

extension CustomSplitModeExtension on CustomSplitMode {
  String get label => switch (this) {
        CustomSplitMode.byDuration => 'By Duration',
        CustomSplitMode.byParts => 'Equal Parts',
        CustomSplitMode.byPoints => 'Split Points',
        CustomSplitMode.bySize => 'By File Size',
      };

  String get description => switch (this) {
        CustomSplitMode.byDuration => 'Every X seconds or minutes',
        CustomSplitMode.byParts => 'Divide into N equal clips',
        CustomSplitMode.byPoints => 'Tap to split at exact moments',
        CustomSplitMode.bySize => 'Approximate MB per clip',
      };
}

/// Encoding method for clip extraction.
enum SplitMethod {
  /// Fast stream copy (-c copy). No re-encode, instantaneous, cuts snap to keyframes.
  fast,

  /// Precise re-encode. Exact cuts on millisecond boundaries, requires encoding pass.
  precise,
}

extension SplitMethodExtension on SplitMethod {
  String get label => switch (this) {
        SplitMethod.fast => 'Fast (Stream Copy)',
        SplitMethod.precise => 'Precise (Re-encode)',
      };

  String get badge => switch (this) {
        SplitMethod.fast => 'Instant • Keyframe Snap',
        SplitMethod.precise => 'Frame-Accurate • Re-encoded',
      };
}

/// Configuration payload for the Custom Split tool.
class CustomSplitConfig {
  final CustomSplitMode mode;
  final SplitMethod method;
  final double targetDurationSeconds;
  final int targetPartCount;
  final List<double> customSplitPoints;
  final double targetSizeMb;
  final double startSeconds;
  final double endSeconds;
  final bool mergeShortTrailingClip;
  final double trailingMergeThresholdSeconds;
  final String customBaseName;

  const CustomSplitConfig({
    this.mode = CustomSplitMode.byDuration,
    this.method = SplitMethod.fast,
    this.targetDurationSeconds = 60.0,
    this.targetPartCount = 2,
    this.customSplitPoints = const [],
    this.targetSizeMb = 25.0,
    this.startSeconds = 0.0,
    this.endSeconds = 0.0,
    this.mergeShortTrailingClip = true,
    this.trailingMergeThresholdSeconds = 3.0,
    this.customBaseName = '',
  });

  double get activeDuration =>
      (endSeconds > startSeconds) ? (endSeconds - startSeconds) : 0.0;

  CustomSplitConfig copyWith({
    CustomSplitMode? mode,
    SplitMethod? method,
    double? targetDurationSeconds,
    int? targetPartCount,
    List<double>? customSplitPoints,
    double? targetSizeMb,
    double? startSeconds,
    double? endSeconds,
    bool? mergeShortTrailingClip,
    double? trailingMergeThresholdSeconds,
    String? customBaseName,
  }) {
    return CustomSplitConfig(
      mode: mode ?? this.mode,
      method: method ?? this.method,
      targetDurationSeconds:
          targetDurationSeconds ?? this.targetDurationSeconds,
      targetPartCount: targetPartCount ?? this.targetPartCount,
      customSplitPoints: customSplitPoints ?? this.customSplitPoints,
      targetSizeMb: targetSizeMb ?? this.targetSizeMb,
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
      mergeShortTrailingClip:
          mergeShortTrailingClip ?? this.mergeShortTrailingClip,
      trailingMergeThresholdSeconds:
          trailingMergeThresholdSeconds ?? this.trailingMergeThresholdSeconds,
      customBaseName: customBaseName ?? this.customBaseName,
    );
  }
}
