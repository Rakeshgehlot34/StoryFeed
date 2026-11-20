import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/plan_review/presentation/screens/plan_review_screen.dart';
import 'package:shorts_splitter/features/split_config/domain/models/overlay_spec.dart';
import 'package:shorts_splitter/features/split_config/presentation/controllers/split_config_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';
import 'package:shorts_splitter/features/video_picker/presentation/controllers/video_picker_controller.dart';

void main() {
  const testSingleVideo = PickedVideo(
    path: '/test/single_clip.mp4',
    fileName: 'my_short_clip.mp4',
    baseName: 'my_short_clip',
    sizeInBytes: 1024 * 1024 * 10,
    duration: Duration(seconds: 45),
    width: 1920,
    height: 1080,
  );

  testWidgets(
    'Single-part plan: shows 1-short banner, "Create 1 Short" button, and suppresses Part 1/1 under Auto',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoPickerControllerProvider.overrideWith(
              () => _FakeVideoPickerController(testSingleVideo),
            ),
            outputDirectoryProvider.overrideWith(
              () => _FakeOutputDirectoryNotifier('/test/output'),
            ),
          ],
          child: const MaterialApp(home: PlanReviewScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Screen Title
      expect(find.text('Plan Review'), findsOneWidget);

      // 2. Verify Single-part banner
      expect(
        find.text('Your video fits in 1 short. No splitting needed!'),
        findsOneWidget,
      );

      // 3. Verify Bottom Action Button says "Create 1 Short (45.0s)"
      expect(find.text('Create 1 Short (45.0s)'), findsOneWidget);

      // 4. Verify that "Part 1/1" is NOT present anywhere on screen
      expect(find.text('Part 1/1'), findsNothing);

      // Scroll to reveal part tile
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // 5. Verify that Part tile shows "No label (tap to add)"
      expect(find.text('No label (tap to add)'), findsOneWidget);
    },
  );

  testWidgets('Single-part plan with PartLabelMode.always: displays Part 1/1', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        videoPickerControllerProvider.overrideWith(
          () => _FakeVideoPickerController(testSingleVideo),
        ),
        outputDirectoryProvider.overrideWith(
          () => _FakeOutputDirectoryNotifier('/test/output'),
        ),
      ],
    );

    // Set partLabelMode to always
    container
        .read(splitConfigControllerProvider.notifier)
        .setPartLabelMode(PartLabelMode.always);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlanReviewScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that "Part 1/1" IS now displayed because user chose Always
    expect(find.text('Part 1/1'), findsWidgets);
  });

  testWidgets('Single-part plan supports 200% font scaling without overflow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoPickerControllerProvider.overrideWith(
            () => _FakeVideoPickerController(testSingleVideo),
          ),
          outputDirectoryProvider.overrideWith(
            () => _FakeOutputDirectoryNotifier('/test/output'),
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: PlanReviewScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Your video fits in 1 short. No splitting needed!'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
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
