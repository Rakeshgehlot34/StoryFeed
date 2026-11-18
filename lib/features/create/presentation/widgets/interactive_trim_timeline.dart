import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/timeline_mapper.dart';

/// Production custom-painted interactive timeline widget with dual range handles,
/// strictly clipped playhead, minimum gap enforcement, and LayoutBuilder adaptability.
class InteractiveTrimTimeline extends StatefulWidget {
  final int totalDurationMs;
  final int startMs;
  final int endMs;
  final int playheadMs;
  final bool isZoomed;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;
  final ValueChanged<int> onSeekPosition;
  final VoidCallback? onScrubbingStart;
  final VoidCallback? onScrubbingEnd;

  const InteractiveTrimTimeline({
    super.key,
    required this.totalDurationMs,
    required this.startMs,
    required this.endMs,
    required this.playheadMs,
    this.isZoomed = false,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onSeekPosition,
    this.onScrubbingStart,
    this.onScrubbingEnd,
  });

  @override
  State<InteractiveTrimTimeline> createState() =>
      _InteractiveTrimTimelineState();
}

class _InteractiveTrimTimelineState extends State<InteractiveTrimTimeline> {
  TimelineTarget _activeTarget = TimelineTarget.none;
  int _lastThrottledSeekMs = -1;
  int _lastSeekTimestamp = 0;

  static const double _timelineHeight = 56.0;
  static const double _handleWidth = 16.0;
  static const double _horizontalPadding = 12.0;

  TimelineMapper _buildMapper(BoxConstraints constraints) {
    final trackWidth = max(
      0.0,
      constraints.maxWidth - (_horizontalPadding * 2),
    );
    final total = widget.totalDurationMs > 0 ? widget.totalDurationMs : 60000;

    int viewMin = 0;
    int viewMax = total;

    if (widget.isZoomed) {
      const zoomMarginMs = 5000;
      viewMin = (widget.startMs - zoomMarginMs).clamp(0, total);
      viewMax = (widget.endMs + zoomMarginMs).clamp(viewMin + 5000, total);
    }

    return TimelineMapper(
      totalDurationMs: total,
      viewMinMs: viewMin,
      viewMaxMs: viewMax,
      trackLeft: _horizontalPadding,
      trackWidth: trackWidth,
      handleWidth: _handleWidth,
      handleTouchWidth: 48.0,
      minGapMs: 1000,
    );
  }

  void _onPointerDown(PointerDownEvent event, TimelineMapper mapper) {
    final localX = event.localPosition.dx;
    final target = mapper.hitTest(
      localX: localX,
      startMs: widget.startMs,
      endMs: widget.endMs,
      playheadMs: widget.playheadMs,
    );

    setState(() {
      _activeTarget = target;
    });

    widget.onScrubbingStart?.call();

    if (target == TimelineTarget.track || target == TimelineTarget.playhead) {
      final time = mapper.xToTime(localX);
      _throttledSeek(time);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _onPointerMove(PointerMoveEvent event, TimelineMapper mapper) {
    if (_activeTarget == TimelineTarget.none) return;

    final localX = event.localPosition.dx;

    switch (_activeTarget) {
      case TimelineTarget.startHandle:
        final rawTime = mapper.xToTime(localX);
        final clamped = mapper.clampStartMs(rawTime, widget.endMs);
        if (clamped != widget.startMs) {
          if (clamped == 0 || clamped == widget.endMs - 1000) {
            HapticFeedback.heavyImpact();
          }
          widget.onStartChanged(clamped);
        }
        break;

      case TimelineTarget.endHandle:
        final rawTime = mapper.xToTime(localX);
        final clamped = mapper.clampEndMs(rawTime, widget.startMs);
        if (clamped != widget.endMs) {
          if (clamped == widget.totalDurationMs ||
              clamped == widget.startMs + 1000) {
            HapticFeedback.heavyImpact();
          }
          widget.onEndChanged(clamped);
        }
        break;

      case TimelineTarget.playhead:
      case TimelineTarget.track:
        final time = mapper.xToTime(localX);
        _throttledSeek(time);
        break;

      case TimelineTarget.none:
        break;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activeTarget = TimelineTarget.none;
    widget.onScrubbingEnd?.call();
  }

  void _throttledSeek(int timeMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((now - _lastSeekTimestamp > 40) || _lastThrottledSeekMs != timeMs) {
      _lastSeekTimestamp = now;
      _lastThrottledSeekMs = timeMs;
      widget.onSeekPosition(timeMs);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapper = _buildMapper(constraints);

        return Listener(
          onPointerDown: (e) => _onPointerDown(e, mapper),
          onPointerMove: (e) => _onPointerMove(e, mapper),
          onPointerUp: _onPointerUp,
          onPointerCancel: (_) => _onPointerUp(const PointerUpEvent()),
          child: SizedBox(
            height: _timelineHeight + 16,
            width: double.infinity,
            child: CustomPaint(
              size: Size(constraints.maxWidth, _timelineHeight + 16),
              painter: _TrimTimelinePainter(
                mapper: mapper,
                startMs: widget.startMs,
                endMs: widget.endMs,
                playheadMs: widget.playheadMs,
                colorScheme: colorScheme,
                activeTarget: _activeTarget,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrimTimelinePainter extends CustomPainter {
  final TimelineMapper mapper;
  final int startMs;
  final int endMs;
  final int playheadMs;
  final ColorScheme colorScheme;
  final TimelineTarget activeTarget;

  _TrimTimelinePainter({
    required this.mapper,
    required this.startMs,
    required this.endMs,
    required this.playheadMs,
    required this.colorScheme,
    required this.activeTarget,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    const height = 56.0;

    final trackRect = mapper.getTrackRect(top: top, height: height);
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(AppTokens.radiusMd),
    );

    // 1. Base track background
    final basePaint = Paint()
      ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, basePaint);

    // 2. Compute handle and selection bounds
    final startX = mapper.timeToX(startMs);
    final endX = mapper.timeToX(endMs);

    // 3. Selection highlight background
    final selectedRect = Rect.fromLTRB(startX, top, endX, top + height);
    final selectPaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRect(selectedRect, selectPaint);

    // 4. Shaded unselected areas (before start and after end)
    final unselectedPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    if (startX > trackRect.left) {
      canvas.save();
      canvas.clipRRect(trackRRect);
      canvas.drawRect(
        Rect.fromLTRB(trackRect.left, top, startX, top + height),
        unselectedPaint,
      );
      canvas.restore();
    }

    if (endX < trackRect.right) {
      canvas.save();
      canvas.clipRRect(trackRRect);
      canvas.drawRect(
        Rect.fromLTRB(endX, top, trackRect.right, top + height),
        unselectedPaint,
      );
      canvas.restore();
    }

    // 5. Active selection borders (top and bottom bars)
    final borderPaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, top), Offset(endX, top), borderPaint);
    canvas.drawLine(
      Offset(startX, top + height),
      Offset(endX, top + height),
      borderPaint,
    );

    // 6. Left Trim Handle
    _paintHandle(
      canvas: canvas,
      centerX: startX,
      top: top,
      height: height,
      isLeft: true,
      isActive: activeTarget == TimelineTarget.startHandle,
    );

    // 7. Right Trim Handle
    _paintHandle(
      canvas: canvas,
      centerX: endX,
      top: top,
      height: height,
      isLeft: false,
      isActive: activeTarget == TimelineTarget.endHandle,
    );

    // 8. Playhead (strictly clipped within track rect)
    canvas.save();
    canvas.clipRRect(trackRRect);
    _paintPlayhead(canvas: canvas, top: top, height: height);
    canvas.restore();

    // 9. Outer track border
    final outlinePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(trackRRect, outlinePaint);
  }

  void _paintHandle({
    required Canvas canvas,
    required double centerX,
    required double top,
    required double height,
    required bool isLeft,
    required bool isActive,
  }) {
    final handleW = mapper.handleWidth;
    final handleRect = isLeft
        ? Rect.fromLTRB(centerX - handleW, top, centerX, top + height)
        : Rect.fromLTRB(centerX, top, centerX + handleW, top + height);

    final handleRRect = RRect.fromRectAndCorners(
      handleRect,
      topLeft: isLeft ? const Radius.circular(AppTokens.radiusSm) : Radius.zero,
      bottomLeft: isLeft
          ? const Radius.circular(AppTokens.radiusSm)
          : Radius.zero,
      topRight: !isLeft
          ? const Radius.circular(AppTokens.radiusSm)
          : Radius.zero,
      bottomRight: !isLeft
          ? const Radius.circular(AppTokens.radiusSm)
          : Radius.zero,
    );

    final fillPaint = Paint()
      ..color = isActive ? colorScheme.primary : colorScheme.primaryContainer
      ..style = PaintingStyle.fill;
    canvas.drawRRect(handleRRect, fillPaint);

    final strokePaint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(handleRRect, strokePaint);

    // Grip lines
    final gripPaint = Paint()
      ..color = isActive ? Colors.white : colorScheme.onPrimaryContainer
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final gripCenterX = isLeft
        ? centerX - (handleW / 2)
        : centerX + (handleW / 2);
    final centerY = top + (height / 2);

    canvas.drawLine(
      Offset(gripCenterX - 2, centerY - 8),
      Offset(gripCenterX - 2, centerY + 8),
      gripPaint,
    );
    canvas.drawLine(
      Offset(gripCenterX + 2, centerY - 8),
      Offset(gripCenterX + 2, centerY + 8),
      gripPaint,
    );
  }

  void _paintPlayhead({
    required Canvas canvas,
    required double top,
    required double height,
  }) {
    final playheadX = mapper.timeToX(playheadMs);

    final linePaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Vertical indicator line
    canvas.drawLine(
      Offset(playheadX, top),
      Offset(playheadX, top + height),
      linePaint,
    );

    // Top indicator cap (pill)
    final capPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;

    final capRect = Rect.fromCenter(
      center: Offset(playheadX, top + 4),
      width: 6,
      height: 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, const Radius.circular(2)),
      capPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrimTimelinePainter oldDelegate) {
    return oldDelegate.startMs != startMs ||
        oldDelegate.endMs != endMs ||
        oldDelegate.playheadMs != playheadMs ||
        oldDelegate.activeTarget != activeTarget ||
        oldDelegate.mapper.trackWidth != mapper.trackWidth ||
        oldDelegate.mapper.viewMinMs != mapper.viewMinMs ||
        oldDelegate.mapper.viewMaxMs != mapper.viewMaxMs;
  }
}
