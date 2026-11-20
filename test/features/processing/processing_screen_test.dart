import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/processing/domain/models/processing_progress.dart';
import 'package:shorts_splitter/features/processing/presentation/controllers/processing_controller.dart';
import 'package:shorts_splitter/features/processing/presentation/screens/processing_screen.dart';

class _FakeProcessingController extends ProcessingController {
  final ProcessingProgress initialProgress;
  _FakeProcessingController(this.initialProgress);

  @override
  ProcessingProgress build() => initialProgress;
}

void main() {
  testWidgets(
    'ProcessingScreen renders overall progress, current clip percentage badge, and valid ETA',
    (tester) async {
      const progress = ProcessingProgress(
        status: ProcessingStatus.processing,
        currentClipIndex: 3,
        totalClips: 20,
        currentClipProgress: 0.45,
        overallProgress: 0.15,
        currentClipName: 'long_vlog_part_003.mp4',
        elapsed: Duration(seconds: 45),
        eta: Duration(minutes: 2, seconds: 15),
        fps: 42.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            processingControllerProvider.overrideWith(
              () => _FakeProcessingController(progress),
            ),
          ],
          child: const MaterialApp(
            home: ProcessingScreen(),
          ),
        ),
      );

      await tester.pump();

      // Verify overall clip progress
      expect(
        find.text('Clip 3 of 20'),
        findsNWidgets(2),
      ); // ProgressRing and Card header

      // Verify current clip percentage badge (45%)
      expect(find.text('45%'), findsOneWidget);

      // Verify current clip filename
      expect(find.text('long_vlog_part_003.mp4'), findsOneWidget);

      // Verify elapsed time (45s -> 00:45)
      expect(find.text('00:45'), findsOneWidget);

      // Verify remaining time (2m 15s -> ~02:15)
      expect(find.text('~02:15'), findsOneWidget);

      // Verify speed stat
      expect(find.text('42 FPS'), findsOneWidget);
    },
  );

  testWidgets(
    'ProcessingScreen calculates remaining time correctly without getting stuck on Estimating',
    (tester) async {
      // 20-clip export at clip 1 with 20% clip progress (1% overall) and 4s elapsed
      const progress = ProcessingProgress(
        status: ProcessingStatus.processing,
        currentClipIndex: 1,
        totalClips: 20,
        currentClipProgress: 0.20,
        overallProgress: 0.01,
        currentClipName: 'long_vlog_part_001.mp4',
        elapsed: Duration(seconds: 4),
        eta: Duration(seconds: 76),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            processingControllerProvider.overrideWith(
              () => _FakeProcessingController(progress),
            ),
          ],
          child: const MaterialApp(
            home: ProcessingScreen(),
          ),
        ),
      );

      await tester.pump();

      // Should show 20% for clip 1
      expect(find.text('20%'), findsOneWidget);

      // Should display remaining time (~01:16)
      expect(find.text('~01:16'), findsOneWidget);
    },
  );
}
