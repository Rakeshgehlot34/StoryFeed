import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/plan_review/presentation/screens/plan_review_screen.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';
import 'package:shorts_splitter/features/video_picker/presentation/controllers/video_picker_controller.dart';

void main() {
  testWidgets(
    'PlanReviewScreen displays plan header, parts list, and create button',
    (WidgetTester tester) async {
      const testVideo = PickedVideo(
        path: '/test/video.mp4',
        fileName: 'nature_video.mp4',
        baseName: 'nature_video',
        sizeInBytes: 1024 * 1024 * 20,
        duration: Duration(seconds: 120),
        width: 1920,
        height: 1080,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoPickerControllerProvider.overrideWith(
              () => _FakeVideoPickerController(testVideo),
            ),
            outputDirectoryProvider.overrideWith(
              () => _FakeOutputDirectoryNotifier('/test/output'),
            ),
          ],
          child: const MaterialApp(home: PlanReviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Plan Review'), findsOneWidget);

      // Verify Header Card content
      expect(find.text('Total Shorts: 2'), findsOneWidget);
      expect(find.text('nature_video'), findsOneWidget);
      expect(find.text('9:16 Vertical (Shorts)'), findsOneWidget);

      // Verify Sequence items (first clip is visible)
      expect(find.text('Planned Sequence (2 clips)'), findsOneWidget);
      expect(find.textContaining('00:00.000 - 01:00.000'), findsOneWidget);

      // Scroll down to reveal second clip
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.textContaining('01:00.000 - 02:00.000'), findsOneWidget);
      expect(find.text('Part 2/2'), findsWidgets);

      // Verify Create Shorts action button
      expect(find.textContaining('Create 2 Shorts'), findsOneWidget);

      // Verify reset icon action
      final refreshBtn = find.byIcon(Icons.refresh_rounded);
      expect(refreshBtn, findsOneWidget);
      await tester.tap(refreshBtn);
      await tester.pumpAndSettle();

      expect(find.text('Reset Split Plan?'), findsOneWidget);
    },
  );
}

class _FakeVideoPickerController extends VideoPickerController {
  final PickedVideo _video;
  _FakeVideoPickerController(this._video);

  @override
  Future<PickedVideo?> build() async => _video;
}

class _FakeOutputDirectoryNotifier extends OutputDirectoryNotifier {
  final String _dir;
  _FakeOutputDirectoryNotifier(this._dir);

  @override
  Future<String> build() async => _dir;
}
