import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/screenshot/domain/models/screenshot_config.dart';
import 'package:shorts_splitter/features/screenshot/presentation/controllers/screenshot_controller.dart';
import 'package:shorts_splitter/features/screenshot/presentation/screens/screenshot_screen.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';

import '../../fakes/fake_video_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoProcessor fakeProcessor;

  const testVideo = PickedVideo(
    path: '/mock/video.mp4',
    fileName: 'video.mp4',
    baseName: 'video',
    duration: Duration(seconds: 30),
    sizeInBytes: 1024 * 1024 * 5,
    width: 1920,
    height: 1080,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
  });

  Widget createWidgetUnderTest({ScreenshotState? initialState}) {
    return ProviderScope(
      overrides: [
        videoProcessorProvider.overrideWithValue(fakeProcessor),
        if (initialState != null)
          screenshotControllerProvider.overrideWith(
            (ref) => _PreloadedScreenshotController(ref, initialState),
          ),
      ],
      child: const MaterialApp(home: ScreenshotScreen()),
    );
  }

  group('ScreenshotScreen Widget Tests', () {
    testWidgets('1. Displays EmptyState when no video is selected', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No Video Selected'), findsOneWidget);
      expect(find.text('Select Video'), findsOneWidget);
    });

    testWidgets(
      '2. Renders player scrubber, mode selector, and snap button when video is set',
      (tester) async {
        const initialConfig = ScreenshotConfig(
          videoPath: '/mock/video.mp4',
          videoTitle: 'video.mp4',
          videoDurationSeconds: 30.0,
          videoWidth: 1920,
          videoHeight: 1080,
        );

        const state = ScreenshotState(video: testVideo, config: initialConfig);

        await tester.pumpWidget(createWidgetUnderTest(initialState: state));
        await tester.pumpAndSettle();

        expect(find.text('Screenshot Capture'), findsOneWidget);
        expect(find.text('Video Playhead Scrubber'), findsOneWidget);
        expect(find.text('Instant Snap'), findsOneWidget);
        expect(find.text('Timestamps'), findsOneWidget);
        expect(find.text('Interval'), findsOneWidget);
        expect(find.byType(Slider), findsWidgets);
        expect(find.textContaining('Snap Frame at'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Switches to Interval mode and displays interval parameters',
      (tester) async {
        const initialConfig = ScreenshotConfig(
          videoPath: '/mock/video.mp4',
          videoTitle: 'video.mp4',
          videoDurationSeconds: 30.0,
          videoWidth: 1920,
          videoHeight: 1080,
          mode: ScreenshotCaptureMode.interval,
        );

        const state = ScreenshotState(video: testVideo, config: initialConfig);

        await tester.pumpWidget(createWidgetUnderTest(initialState: state));
        await tester.pumpAndSettle();

        expect(find.text('Periodic Interval Extraction'), findsOneWidget);
        expect(find.text('Every X Seconds'), findsOneWidget);
        expect(find.text('N Equal Frames'), findsOneWidget);
        expect(find.text('Total Frames'), findsOneWidget);
        expect(
          find.textContaining('Extract 7 Frames to Queue'),
          findsOneWidget,
        );
      },
    );
  });
}

class _PreloadedScreenshotController extends ScreenshotController {
  _PreloadedScreenshotController(super.ref, ScreenshotState initialState) {
    state = initialState;
  }
}
