import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/plan_review/presentation/screens/plan_review_screen.dart';
import 'package:shorts_splitter/features/split_config/domain/models/split_config.dart';
import 'package:shorts_splitter/features/split_config/presentation/controllers/split_config_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';
import 'package:shorts_splitter/features/video_picker/presentation/controllers/video_picker_controller.dart';

void main() {
  testWidgets(
    'PlanReviewScreen selective processing with 30 items, selection bar, and 200% text scaling',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 30 clips = 600 seconds with 20s target clip length
      const testVideo = PickedVideo(
        path: '/test/bench_10m.mp4',
        fileName: 'bench_10m.mp4',
        baseName: 'bench_10m',
        sizeInBytes: 1024 * 1024 * 50,
        duration: Duration(seconds: 600),
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
            splitConfigControllerProvider.overrideWith(
              () => _FakeSplitConfigController(
                const SplitConfig(targetDurationSeconds: 20),
              ),
            ),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              // Test 200% large accessibility font scaling
              data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: PlanReviewScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Header shows 30 clips
      expect(find.text('Planned Sequence (30 clips)'), findsOneWidget);

      // 2. Selection bar starts with all 30 selected
      expect(find.text('30 of 30 selected'), findsOneWidget);
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('Deselect'), findsOneWidget);
      expect(find.text('Invert'), findsOneWidget);

      // 3. Bottom action button reflects full plan
      expect(find.textContaining('Create 30 Shorts'), findsOneWidget);

      // 4. Tap "Deselect"
      await tester.tap(find.text('Deselect'));
      await tester.pumpAndSettle();

      expect(find.text('0 of 30 selected'), findsOneWidget);
      expect(find.text('Select parts to process'), findsOneWidget);

      // 5. Select first item by tapping its Checkbox
      final firstCheckbox = find.byType(Checkbox).first;
      await tester.tap(firstCheckbox);
      await tester.pumpAndSettle();

      expect(find.text('1 of 30 selected'), findsOneWidget);
      expect(find.textContaining('Create 1 of 30 Shorts'), findsOneWidget);

      // 6. Tap "Invert" -> 29 of 30 selected
      await tester.tap(find.text('Invert'));
      await tester.pumpAndSettle();

      expect(find.text('29 of 30 selected'), findsOneWidget);
      expect(find.textContaining('Create 29 of 30 Shorts'), findsOneWidget);

      // 7. Scroll through list smoothly
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Verify clips are rendered properly during scroll
      expect(find.textContaining('bench_10m_part_'), findsWidgets);
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

class _FakeSplitConfigController extends SplitConfigController {
  final SplitConfig _config;
  _FakeSplitConfigController(this._config);

  @override
  SplitConfig build() => _config;
}
