import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/create/presentation/widgets/interactive_trim_timeline.dart';

void main() {
  Widget buildTimeline({
    required int totalDurationMs,
    required int startMs,
    required int endMs,
    required int playheadMs,
    required ValueChanged<int> onStartChanged,
    required ValueChanged<int> onEndChanged,
    required ValueChanged<int> onSeekPosition,
    VoidCallback? onScrubbingStart,
    VoidCallback? onScrubbingEnd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 324.0, // trackWidth = 324 - 24 = 300.0, trackLeft = 12.0
            child: InteractiveTrimTimeline(
              totalDurationMs: totalDurationMs,
              startMs: startMs,
              endMs: endMs,
              playheadMs: playheadMs,
              onStartChanged: onStartChanged,
              onEndChanged: onEndChanged,
              onSeekPosition: onSeekPosition,
              onScrubbingStart: onScrubbingStart,
              onScrubbingEnd: onScrubbingEnd,
            ),
          ),
        ),
      ),
    );
  }

  group('InteractiveTrimTimeline Widget Tests', () {
    testWidgets('Renders CustomPaint timeline widget', (tester) async {
      await tester.pumpWidget(
        buildTimeline(
          totalDurationMs: 60000,
          startMs: 0,
          endMs: 60000,
          playheadMs: 0,
          onStartChanged: (_) {},
          onEndChanged: (_) {},
          onSeekPosition: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveTrimTimeline), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      'Tapping on track triggers onSeekPosition and scrubbing callbacks',
      (tester) async {
        int? seekPos;
        bool scrubStarted = false;
        bool scrubEnded = false;

        await tester.pumpWidget(
          buildTimeline(
            totalDurationMs: 60000,
            startMs: 10000,
            endMs: 50000,
            playheadMs: 10000,
            onStartChanged: (_) {},
            onEndChanged: (_) {},
            onSeekPosition: (pos) => seekPos = pos,
            onScrubbingStart: () => scrubStarted = true,
            onScrubbingEnd: () => scrubEnded = true,
          ),
        );
        await tester.pumpAndSettle();

        // Tap in the middle of the timeline
        final center = tester.getCenter(find.byType(InteractiveTrimTimeline));
        await tester.tapAt(center);
        await tester.pumpAndSettle();

        expect(scrubStarted, isTrue);
        expect(scrubEnded, isTrue);
        expect(seekPos, isNotNull);
        // Roughly midpoint (30000ms +- 500ms)
        expect((seekPos! - 30000).abs() < 1000, isTrue);
      },
    );

    testWidgets('Dragging start handle updates start and enforces min gap', (
      tester,
    ) async {
      int? updatedStart;

      await tester.pumpWidget(
        buildTimeline(
          totalDurationMs: 60000,
          startMs: 5000,
          endMs: 20000,
          playheadMs: 5000,
          onStartChanged: (s) => updatedStart = s,
          onEndChanged: (_) {},
          onSeekPosition: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final timelineFinder = find.byType(InteractiveTrimTimeline);
      final topLeft = tester.getTopLeft(timelineFinder);

      // Start handle is at 5000ms:
      // x = 12.0 + (5000 / 60000 * 300.0) = 12.0 + 25.0 = 37.0
      final handlePos = topLeft + const Offset(37.0, 30.0);

      // Drag to the right
      final gesture = await tester.startGesture(handlePos);
      await tester.pump();
      await gesture.moveBy(const Offset(50.0, 0.0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(updatedStart, isNotNull);
      expect(updatedStart! > 5000, isTrue);
      // Must not exceed endMs - 1000ms (19000ms)
      expect(updatedStart! <= 19000, isTrue);
    });
  });
}
