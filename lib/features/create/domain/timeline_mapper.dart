import 'dart:ui';

/// Pure, deterministic mathematical mapper for video timeline coordinates,
/// converting integer milliseconds <-> pixel x-coordinates with strict boundary clamping.
class TimelineMapper {
  final int totalDurationMs;
  final int viewMinMs;
  final int viewMaxMs;
  final double trackLeft;
  final double trackWidth;
  final double handleWidth;
  final double handleTouchWidth;
  final int minGapMs;

  const TimelineMapper({
    required this.totalDurationMs,
    required this.viewMinMs,
    required this.viewMaxMs,
    required this.trackLeft,
    required this.trackWidth,
    this.handleWidth = 16.0,
    this.handleTouchWidth = 48.0,
    this.minGapMs = 1000,
  })  : assert(totalDurationMs >= 0, 'totalDurationMs cannot be negative'),
        assert(viewMinMs >= 0, 'viewMinMs cannot be negative'),
        assert(viewMaxMs >= viewMinMs, 'viewMaxMs must be >= viewMinMs'),
        assert(trackWidth >= 0, 'trackWidth cannot be negative');

  int get viewDurationMs => (viewMaxMs - viewMinMs).clamp(
        1,
        totalDurationMs > 0 ? totalDurationMs : 1,
      );

  double get trackRight => trackLeft + trackWidth;

  /// Converts a timestamp in milliseconds to an exact track x-coordinate.
  double timeToX(int timeMs) {
    if (viewDurationMs <= 0 || trackWidth <= 0) return trackLeft;
    final clampedTime = timeMs.clamp(viewMinMs, viewMaxMs);
    final ratio = (clampedTime - viewMinMs) / viewDurationMs;
    return trackLeft + (ratio * trackWidth);
  }

  /// Converts a pixel x-coordinate on the track to an integer timestamp in milliseconds.
  int xToTime(double x) {
    if (trackWidth <= 0) return viewMinMs;
    final clampedX = x.clamp(trackLeft, trackRight);
    final ratio = (clampedX - trackLeft) / trackWidth;
    final rawMs = viewMinMs + (ratio * viewDurationMs).round();
    return rawMs.clamp(0, totalDurationMs);
  }

  /// Clamps start time when dragging start handle so it never exceeds [currentEndMs - minGapMs].
  int clampStartMs(int candidateStartMs, int currentEndMs) {
    final maxAllowed = (currentEndMs - minGapMs).clamp(0, totalDurationMs);
    return candidateStartMs.clamp(0, maxAllowed);
  }

  /// Clamps end time when dragging end handle so it is never less than [currentStartMs + minGapMs].
  int clampEndMs(int candidateEndMs, int currentStartMs) {
    final minAllowed = (currentStartMs + minGapMs).clamp(0, totalDurationMs);
    return candidateEndMs.clamp(minAllowed, totalDurationMs);
  }

  /// Clamps the playhead position within valid playback boundaries.
  int clampPlayheadMs(
    int candidatePlayheadMs, {
    bool isPlayingSelection = false,
    int? selectionStartMs,
    int? selectionEndMs,
  }) {
    if (isPlayingSelection &&
        selectionStartMs != null &&
        selectionEndMs != null) {
      return candidatePlayheadMs.clamp(selectionStartMs, selectionEndMs);
    }
    return candidatePlayheadMs.clamp(0, totalDurationMs);
  }

  /// Tests which interactive element was touched:
  /// returns TimelineHandleType.start, TimelineHandleType.end, TimelineHandleType.playhead, or none.
  TimelineTarget hitTest({
    required double localX,
    required int startMs,
    required int endMs,
    required int playheadMs,
  }) {
    final startX = timeToX(startMs);
    final endX = timeToX(endMs);
    final playheadX = timeToX(playheadMs);

    final distStart = (localX - startX).abs();
    final distEnd = (localX - endX).abs();
    final distPlayhead = (localX - playheadX).abs();

    final hitStart = distStart <= (handleTouchWidth / 2);
    final hitEnd = distEnd <= (handleTouchWidth / 2);

    if (hitStart && hitEnd) {
      // If both handles overlap closely, choose the closer one
      return distStart <= distEnd
          ? TimelineTarget.startHandle
          : TimelineTarget.endHandle;
    }
    if (hitStart) return TimelineTarget.startHandle;
    if (hitEnd) return TimelineTarget.endHandle;

    if (distPlayhead <= 24.0) {
      return TimelineTarget.playhead;
    }

    return TimelineTarget.track;
  }

  /// Computes the active track rectangle and selection rectangle.
  Rect getTrackRect({required double top, required double height}) {
    return Rect.fromLTWH(trackLeft, top, trackWidth, height);
  }

  Rect getSelectionRect({
    required int startMs,
    required int endMs,
    required double top,
    required double height,
  }) {
    final x1 = timeToX(startMs);
    final x2 = timeToX(endMs);
    return Rect.fromLTRB(x1, top, x2, top + height);
  }
}

enum TimelineTarget { none, startHandle, endHandle, playhead, track }
