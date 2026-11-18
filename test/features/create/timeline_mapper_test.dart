import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/create/domain/timeline_mapper.dart';

void main() {
  group('TimelineMapper Unit Tests', () {
    const mapper = TimelineMapper(
      totalDurationMs: 60000, // 60s
      viewMinMs: 0,
      viewMaxMs: 60000,
      trackLeft: 20.0,
      trackWidth: 300.0,
      handleWidth: 16.0,
      handleTouchWidth: 48.0,
      minGapMs: 1000,
    );

    test(
      'timeToX maps start, midpoint, and end to exact pixel coordinates',
      () {
        expect(mapper.timeToX(0), 20.0);
        expect(mapper.timeToX(30000), 170.0); // 20 + (0.5 * 300)
        expect(mapper.timeToX(60000), 320.0); // 20 + 300
      },
    );

    test('timeToX clamps out-of-range times to track boundaries', () {
      expect(mapper.timeToX(-5000), 20.0);
      expect(mapper.timeToX(999999), 320.0);
    });

    test('xToTime maps track coordinates back to milliseconds', () {
      expect(mapper.xToTime(20.0), 0);
      expect(mapper.xToTime(170.0), 30000);
      expect(mapper.xToTime(320.0), 60000);
    });

    test('xToTime clamps drag gestures outside the track rect', () {
      expect(mapper.xToTime(0.0), 0);
      expect(mapper.xToTime(500.0), 60000);
    });

    test(
      'clampStartMs prevents start handle from exceeding end handle - minGap',
      () {
        // Current end is 10000ms, minGap is 1000ms => max start is 9000ms
        expect(mapper.clampStartMs(5000, 10000), 5000);
        expect(mapper.clampStartMs(9500, 10000), 9000);
        expect(mapper.clampStartMs(15000, 10000), 9000);
        expect(mapper.clampStartMs(-500, 10000), 0);
      },
    );

    test(
      'clampEndMs prevents end handle from going below start handle + minGap',
      () {
        // Current start is 10000ms, minGap is 1000ms => min end is 11000ms
        expect(mapper.clampEndMs(20000, 10000), 20000);
        expect(mapper.clampEndMs(10500, 10000), 11000);
        expect(mapper.clampEndMs(5000, 10000), 11000);
        expect(mapper.clampEndMs(70000, 10000), 60000);
      },
    );

    test(
      'clampPlayheadMs clamps within video duration and selection bounds',
      () {
        // Normal playback: clamped [0, 60000]
        expect(mapper.clampPlayheadMs(25000), 25000);
        expect(mapper.clampPlayheadMs(-100), 0);
        expect(mapper.clampPlayheadMs(70000), 60000);

        // Play selection: clamped [10000, 30000]
        expect(
          mapper.clampPlayheadMs(
            35000,
            isPlayingSelection: true,
            selectionStartMs: 10000,
            selectionEndMs: 30000,
          ),
          30000,
        );
        expect(
          mapper.clampPlayheadMs(
            5000,
            isPlayingSelection: true,
            selectionStartMs: 10000,
            selectionEndMs: 30000,
          ),
          10000,
        );
      },
    );

    test(
      'hitTest detects start handle within 48dp touch region (24dp radius)',
      () {
        // start at 10000ms => x = 20 + (10000/60000 * 300) = 70.0
        const startMs = 10000;
        const endMs = 40000;
        const playheadMs = 25000;

        expect(
          mapper.hitTest(
            localX: 70.0,
            startMs: startMs,
            endMs: endMs,
            playheadMs: playheadMs,
          ),
          TimelineTarget.startHandle,
        );

        // Within 20dp of start handle (touch radius is 24dp)
        expect(
          mapper.hitTest(
            localX: 85.0,
            startMs: startMs,
            endMs: endMs,
            playheadMs: playheadMs,
          ),
          TimelineTarget.startHandle,
        );
      },
    );

    test('hitTest detects end handle within touch radius', () {
      // end at 40000ms => x = 20 + (40000/60000 * 300) = 220.0
      const startMs = 10000;
      const endMs = 40000;
      const playheadMs = 25000;

      expect(
        mapper.hitTest(
          localX: 220.0,
          startMs: startMs,
          endMs: endMs,
          playheadMs: playheadMs,
        ),
        TimelineTarget.endHandle,
      );
    });

    test(
      'hitTest detects track when tapped away from handles and playhead',
      () {
        const startMs = 10000; // x=70
        const endMs = 50000; // x=270
        const playheadMs = 10000;

        expect(
          mapper.hitTest(
            localX: 180.0,
            startMs: startMs,
            endMs: endMs,
            playheadMs: playheadMs,
          ),
          TimelineTarget.track,
        );
      },
    );

    test('getTrackRect returns exact coordinate bounds', () {
      final rect = mapper.getTrackRect(top: 10.0, height: 60.0);
      expect(rect, const Rect.fromLTWH(20.0, 10.0, 300.0, 60.0));
    });

    test('getSelectionRect returns correct sub-rect between handles', () {
      final sel = mapper.getSelectionRect(
        startMs: 0,
        endMs: 30000,
        top: 10.0,
        height: 60.0,
      );
      expect(sel, const Rect.fromLTRB(20.0, 10.0, 170.0, 70.0));
    });
  });
}
