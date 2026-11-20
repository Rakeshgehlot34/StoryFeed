import '../../../../core/utils/formatters.dart';

/// Represents a single contiguous slice of the source video.
class ClipSegment {
  final int index; // 1-based index
  final double startSeconds;
  final double durationSeconds;
  final String formattedName;
  final bool isMergedTrailing;

  const ClipSegment({
    required this.index,
    required this.startSeconds,
    required this.durationSeconds,
    required this.formattedName,
    this.isMergedTrailing = false,
  });

  double get endSeconds => startSeconds + durationSeconds;

  String get formattedStart => Formatters.formatSeconds(startSeconds);
  String get formattedEnd => Formatters.formatSeconds(endSeconds);
  String get formattedDuration => Formatters.formatSeconds(durationSeconds);
  String get formattedTimeRange =>
      '$formattedStart - $formattedEnd ($formattedDuration)';

  /// Pure algorithmic generator for contiguous video slices.
  /// Guarantees:
  /// - Contiguous slices with zero gaps or overlaps.
  /// - Perfect sequence naming (`_part_001.mp4`, `_part_002.mp4` etc).
  /// - Respects `mergeShortTrailingClip` (< 3.0s threshold merged into previous clip).
  static List<ClipSegment> calculateSegments({
    required double totalDurationSeconds,
    required int targetClipDurationSeconds,
    required bool mergeShortTrailingClip,
    required String baseName,
    double startOffsetSeconds = 0.0,
    double trailingThresholdSeconds = 3.0,
  }) {
    if (totalDurationSeconds <= 0) return const [];

    final target = targetClipDurationSeconds.toDouble();

    // If source video is shorter than or equal to target, single clip
    if (totalDurationSeconds <= target) {
      final name = Formatters.formatClipFileName(baseName, 1, 1);
      return [
        ClipSegment(
          index: 1,
          startSeconds: startOffsetSeconds,
          durationSeconds: totalDurationSeconds,
          formattedName: name,
        ),
      ];
    }

    final fullClipCount = (totalDurationSeconds / target).floor();
    final remainder = totalDurationSeconds - (fullClipCount * target);

    final shouldMerge = mergeShortTrailingClip &&
        remainder > 0.05 &&
        remainder < trailingThresholdSeconds &&
        fullClipCount >= 1;

    final totalClips = shouldMerge
        ? fullClipCount
        : (remainder > 0.05 ? fullClipCount + 1 : fullClipCount);

    final segments = <ClipSegment>[];

    for (int i = 0; i < fullClipCount; i++) {
      final start = startOffsetSeconds + (i * target);
      final isLastFullClip = (i == fullClipCount - 1);

      if (isLastFullClip && shouldMerge) {
        final duration = target + remainder;
        segments.add(
          ClipSegment(
            index: i + 1,
            startSeconds: start,
            durationSeconds: duration,
            formattedName: Formatters.formatClipFileName(
              baseName,
              i + 1,
              totalClips,
            ),
            isMergedTrailing: true,
          ),
        );
      } else {
        segments.add(
          ClipSegment(
            index: i + 1,
            startSeconds: start,
            durationSeconds: target,
            formattedName: Formatters.formatClipFileName(
              baseName,
              i + 1,
              totalClips,
            ),
          ),
        );
      }
    }

    // Add remainder clip if not merged
    if (remainder > 0.05 && !shouldMerge) {
      final start = startOffsetSeconds + (fullClipCount * target);
      segments.add(
        ClipSegment(
          index: fullClipCount + 1,
          startSeconds: start,
          durationSeconds: remainder,
          formattedName: Formatters.formatClipFileName(
            baseName,
            fullClipCount + 1,
            totalClips,
          ),
        ),
      );
    }

    return segments;
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'startSeconds': startSeconds,
        'durationSeconds': durationSeconds,
        'formattedName': formattedName,
        'isMergedTrailing': isMergedTrailing,
      };

  factory ClipSegment.fromJson(Map<String, dynamic> json) => ClipSegment(
        index: json['index'] as int,
        startSeconds: (json['startSeconds'] as num).toDouble(),
        durationSeconds: (json['durationSeconds'] as num).toDouble(),
        formattedName: json['formattedName'] as String,
        isMergedTrailing: json['isMergedTrailing'] as bool? ?? false,
      );
}
