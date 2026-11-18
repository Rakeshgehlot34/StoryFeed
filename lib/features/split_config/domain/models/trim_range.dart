import '../../../../core/utils/formatters.dart';

/// Represents a contiguous time slice of a source video to be split.
class TrimRange {
  final double startSeconds;
  final double endSeconds;

  const TrimRange({required this.startSeconds, required this.endSeconds})
    : assert(startSeconds >= 0.0, 'startSeconds must be non-negative'),
      assert(
        endSeconds > startSeconds,
        'endSeconds must be strictly greater than startSeconds',
      );

  double get durationSeconds => endSeconds - startSeconds;

  String get formattedStart => Formatters.formatSeconds(startSeconds);
  String get formattedEnd => Formatters.formatSeconds(endSeconds);
  String get formattedDuration => Formatters.formatSeconds(durationSeconds);

  String get formattedSummary =>
      '$formattedStart - $formattedEnd ($formattedDuration)';

  TrimRange copyWith({double? startSeconds, double? endSeconds}) {
    return TrimRange(
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrimRange &&
          runtimeType == other.runtimeType &&
          startSeconds == other.startSeconds &&
          endSeconds == other.endSeconds;

  @override
  int get hashCode => startSeconds.hashCode ^ endSeconds.hashCode;
}
