import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/jobs/domain/job_queue_controller.dart';
import 'package:shorts_splitter/features/jobs/domain/models/job_record.dart';
import 'package:shorts_splitter/features/merge/domain/models/merge_project.dart';
import 'package:shorts_splitter/features/merge/presentation/controllers/merge_controller.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';

import '../../fakes/fake_video_processor.dart';

void main() {
  late ProviderContainer container;
  late FakeVideoProcessor fakeProcessor;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
    container = ProviderContainer(
      overrides: [videoProcessorProvider.overrideWithValue(fakeProcessor)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('MergeController Tests', () {
    test('1. Adds videos, probes metadata, and creates clip items', () async {
      final controller = container.read(mergeControllerProvider.notifier);

      await controller.addVideos(['/storage/vid1.mp4', '/storage/vid2.mp4']);

      final state = container.read(mergeControllerProvider);
      expect(state.clipCount, 2);
      expect(state.config.clips[0].fileName, 'vid1.mp4');
      expect(state.config.clips[1].fileName, 'vid2.mp4');
      expect(state.canMerge, isTrue);
    });

    test('2. Removes clip by id', () async {
      final controller = container.read(mergeControllerProvider.notifier);
      await controller.addVideos(['/storage/vid1.mp4', '/storage/vid2.mp4']);

      final firstId = container
          .read(mergeControllerProvider)
          .config
          .clips[0]
          .id;
      controller.removeClip(firstId);

      final state = container.read(mergeControllerProvider);
      expect(state.clipCount, 1);
      expect(state.config.clips[0].fileName, 'vid2.mp4');
      expect(state.canMerge, isFalse);
    });

    test('3. Reorders and moves clips up/down', () async {
      final controller = container.read(mergeControllerProvider.notifier);
      await controller.addVideos([
        '/storage/vid1.mp4',
        '/storage/vid2.mp4',
        '/storage/vid3.mp4',
      ]);

      // Reorder index 0 to after index 2
      controller.reorderClips(0, 3);
      var state = container.read(mergeControllerProvider);
      expect(state.config.clips[0].fileName, 'vid2.mp4');
      expect(state.config.clips[1].fileName, 'vid3.mp4');
      expect(state.config.clips[2].fileName, 'vid1.mp4');

      // Move clip 2 up
      controller.moveClipUp(2);
      state = container.read(mergeControllerProvider);
      expect(state.config.clips[1].fileName, 'vid1.mp4');

      // Move clip 0 down
      controller.moveClipDown(0);
      state = container.read(mergeControllerProvider);
      expect(state.config.clips[1].fileName, 'vid2.mp4');
    });

    test('4. Duplicates clip and adjusts trim boundaries', () async {
      final controller = container.read(mergeControllerProvider.notifier);
      await controller.addVideos(['/storage/vid1.mp4', '/storage/vid2.mp4']);

      final firstClip = container.read(mergeControllerProvider).config.clips[0];
      controller.duplicateClip(firstClip.id);

      var state = container.read(mergeControllerProvider);
      expect(state.clipCount, 3);
      expect(state.config.clips[0].fileName, 'vid1.mp4');
      expect(state.config.clips[1].fileName, 'vid1.mp4');
      expect(state.config.clips[1].id, isNot(equals(firstClip.id)));

      // Update trim
      controller.updateClipTrim(
        id: firstClip.id,
        startTrimSeconds: 1.5,
        endTrimSeconds: 8.0,
      );
      state = container.read(mergeControllerProvider);
      expect(state.config.clips[0].startTrimSeconds, 1.5);
      expect(state.config.clips[0].endTrimSeconds, 8.0);
      expect(state.config.clips[0].effectiveDurationSeconds, 6.5);
    });

    test('5. Updates canvas, transitions, and method configurations', () {
      final controller = container.read(mergeControllerProvider.notifier);

      controller.setCanvasPreset(CanvasAspectRatioPreset.vertical9x16);
      controller.setFitMode(CanvasFitMode.fitBlur);
      controller.setTransition(MergeTransition.fade);
      controller.setTransitionDuration(1.2);
      controller.setMethod(MergeMethod.precise);
      controller.setCustomBaseName('holiday_reels');

      final state = container.read(mergeControllerProvider);
      expect(state.config.canvasPreset, CanvasAspectRatioPreset.vertical9x16);
      expect(state.config.fitMode, CanvasFitMode.fitBlur);
      expect(state.config.transition, MergeTransition.fade);
      expect(state.config.transitionDurationSeconds, 1.2);
      expect(state.config.method, MergeMethod.precise);
      expect(state.config.customBaseName, 'holiday_reels');
      expect(state.config.effectiveBaseName, 'holiday_reels');
    });

    test('6. Dispatches merge job into unified JobQueueController', () async {
      final controller = container.read(mergeControllerProvider.notifier);
      await controller.addVideos([
        '/storage/clip_a.mp4',
        '/storage/clip_b.mp4',
      ]);

      final job = await controller.dispatchMergeJob();

      expect(job.type, JobType.merge);
      expect(job.title, contains('clip_a_merged'));
      expect(job.payload['config'], isNotNull);

      final queue = container.read(jobQueueControllerProvider);
      expect(queue.jobs.any((j) => j.id == job.id), isTrue);
    });
  });
}
