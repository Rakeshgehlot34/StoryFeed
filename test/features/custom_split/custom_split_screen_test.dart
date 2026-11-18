import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/custom_split/presentation/controllers/custom_split_controller.dart';
import 'package:shorts_splitter/features/custom_split/presentation/screens/custom_split_plan_review_screen.dart';
import 'package:shorts_splitter/features/custom_split/presentation/screens/custom_split_screen.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';

import '../../fakes/fake_video_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoProcessor fakeProcessor;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
  });

  const testVideo = PickedVideo(
    path: '/data/user/0/com.shortssplitter/cache/test_video.mp4',
    fileName: 'test_video.mp4',
    baseName: 'test_video',
    duration: Duration(seconds: 120),
    sizeInBytes: 25 * 1024 * 1024,
    width: 1920,
    height: 1080,
  );

  testWidgets('CustomSplitScreen shows EmptyState when no video is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [videoProcessorProvider.overrideWithValue(fakeProcessor)],
        child: const MaterialApp(home: CustomSplitScreen()),
      ),
    );

    expect(find.text('No Video Selected'), findsOneWidget);
    expect(find.text('Choose Video'), findsOneWidget);
  });

  testWidgets(
    'CustomSplitScreen renders mode selectors and plan summary when video is loaded',
    (tester) async {
      final container = ProviderContainer(
        overrides: [videoProcessorProvider.overrideWithValue(fakeProcessor)],
      );
      addTearDown(container.dispose);

      container
          .read(customSplitControllerProvider.notifier)
          .setVideo(testVideo);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: CustomSplitScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Source Video'), findsOneWidget);
      expect(find.text('test_video.mp4'), findsOneWidget);
      expect(find.text('Split Strategy'), findsOneWidget);
      expect(find.text('By Duration'), findsNWidgets(2));
      expect(find.text('Equal Parts'), findsOneWidget);
      expect(find.text('Split Points'), findsOneWidget);
      expect(find.text('By File Size'), findsOneWidget);
      expect(find.text('Review Plan (2 Clips)'), findsOneWidget);
    },
  );

  testWidgets('CustomSplitPlanReviewScreen renders list of planned clips', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [videoProcessorProvider.overrideWithValue(fakeProcessor)],
    );
    addTearDown(container.dispose);

    container.read(customSplitControllerProvider.notifier).setVideo(testVideo);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CustomSplitPlanReviewScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Review Split Plan'), findsOneWidget);
    expect(find.text('Split Overview'), findsOneWidget);
    expect(find.text('Planned Clips (2)'), findsOneWidget);
    expect(find.text('test_video_part_001.mp4'), findsOneWidget);
    expect(find.text('test_video_part_002.mp4'), findsOneWidget);
    expect(find.text('Start Split (2 Clips)'), findsOneWidget);
  });
}
