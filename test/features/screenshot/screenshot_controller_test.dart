import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/jobs/domain/job_queue_controller.dart';
import 'package:shorts_splitter/features/jobs/domain/models/job_record.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/screenshot/domain/models/screenshot_config.dart';
import 'package:shorts_splitter/features/screenshot/presentation/controllers/screenshot_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';

import '../../fakes/fake_video_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeVideoProcessor fakeProcessor;

  const testVideo = PickedVideo(
    path: '/mock/video.mp4',
    fileName: 'video.mp4',
    baseName: 'video',
    duration: Duration(seconds: 45),
    sizeInBytes: 1024 * 1024 * 10,
    width: 1920,
    height: 1080,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
    fakeProcessor.simulatedDuration = const Duration(seconds: 45);
    container = ProviderContainer(
      overrides: [videoProcessorProvider.overrideWithValue(fakeProcessor)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ScreenshotController Tests', () {
    test('1. Sets video and extracts metadata into config', () async {
      final controller = container.read(screenshotControllerProvider.notifier);

      await controller.setVideo(testVideo);

      final state = container.read(screenshotControllerProvider);
      expect(state.video, testVideo);
      expect(state.config.videoPath, testVideo.path);
      expect(state.config.videoDurationSeconds, 45.0);
      expect(state.config.videoWidth, 1920);
      expect(state.config.videoHeight, 1080);
      expect(state.isLoading, isFalse);
    });

    test('2. Updates capture mode, format, quality, and intervals', () async {
      final controller = container.read(screenshotControllerProvider.notifier);
      await controller.setVideo(testVideo);

      controller.setMode(ScreenshotCaptureMode.interval);
      controller.setFormat(ScreenshotImageFormat.jpeg);
      controller.setJpegQuality(80);
      controller.setIntervalSeconds(2.5);

      final state = container.read(screenshotControllerProvider);
      expect(state.config.mode, ScreenshotCaptureMode.interval);
      expect(state.config.format, ScreenshotImageFormat.jpeg);
      expect(state.config.jpegQuality, 80);
      expect(state.config.intervalSeconds, 2.5);
    });

    test('3. Manages timestamp list additions and deletions', () async {
      final controller = container.read(screenshotControllerProvider.notifier);
      await controller.setVideo(testVideo);

      controller.addTimestamp(10.5);
      controller.addTimestamp(25.0);
      controller.addTimestamp(5.2);
      // Duplicate within threshold should be ignored
      controller.addTimestamp(10.52);

      var state = container.read(screenshotControllerProvider);
      expect(state.config.customTimestamps, [5.2, 10.5, 25.0]);

      controller.removeTimestamp(10.5);
      state = container.read(screenshotControllerProvider);
      expect(state.config.customTimestamps, [5.2, 25.0]);

      controller.clearTimestamps();
      state = container.read(screenshotControllerProvider);
      expect(state.config.customTimestamps, isEmpty);
    });

    test('4. Captures playhead frame and adds to session gallery', () async {
      final controller = container.read(screenshotControllerProvider.notifier);
      await controller.setVideo(testVideo);

      final item = await controller.capturePlayheadFrame(12.5);

      expect(item, isNotNull);
      final state = container.read(screenshotControllerProvider);
      expect(state.capturedSessionFrames.length, 1);
      expect(state.capturedSessionFrames.first.timestampSeconds, 12.5);
      expect(state.activePreviewItem?.timestampSeconds, 12.5);
      expect(state.isCapturing, isFalse);
    });

    test('5. Manages frame selection and batch deletion', () async {
      final controller = container.read(screenshotControllerProvider.notifier);
      await controller.setVideo(testVideo);

      final item1 = await controller.capturePlayheadFrame(5.0);
      await controller.capturePlayheadFrame(15.0);

      expect(
        container
            .read(screenshotControllerProvider)
            .capturedSessionFrames
            .length,
        2,
      );

      controller.toggleSelection(item1!.id);
      expect(container.read(screenshotControllerProvider).selectedFrameIds, {
        item1.id,
      });

      controller.selectAll();
      expect(
        container.read(screenshotControllerProvider).isAllSelected,
        isTrue,
      );

      controller.deleteSelected();
      expect(
        container.read(screenshotControllerProvider).capturedSessionFrames,
        isEmpty,
      );
    });

    test('6. Enqueues batch capture job into JobQueueController', () async {
      final controller = container.read(screenshotControllerProvider.notifier);
      await controller.setVideo(testVideo);
      controller.setMode(ScreenshotCaptureMode.interval);
      controller.setIntervalSeconds(15.0);

      final job = await controller.dispatchBatchCapture();

      expect(job.type, JobType.screenshot);
      expect(job.totalParts, 4); // 0, 15, 30, 45
      final queueState = container.read(jobQueueControllerProvider);
      expect(queueState.jobs.any((j) => j.id == job.id), isTrue);
    });
  });
}
