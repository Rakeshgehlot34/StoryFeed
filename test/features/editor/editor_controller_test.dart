import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/editor/domain/models/edit_project.dart';
import 'package:shorts_splitter/features/editor/presentation/controllers/editor_controller.dart';
import 'package:shorts_splitter/features/jobs/domain/job_queue_controller.dart';
import 'package:shorts_splitter/features/jobs/domain/models/job_record.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';

import '../../fakes/fake_video_processor.dart';

class _FakeOutputDirectoryNotifier extends OutputDirectoryNotifier {
  @override
  Future<String> build() async => '/fake/output/directory';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeVideoProcessor fakeProcessor;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
    container = ProviderContainer(
      overrides: [
        videoProcessorProvider.overrideWithValue(fakeProcessor),
        outputDirectoryProvider.overrideWith(_FakeOutputDirectoryNotifier.new),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  const testVideo = PickedVideo(
    path: '/cache/sample_video.mp4',
    fileName: 'sample_video.mp4',
    baseName: 'sample_video',
    duration: Duration(seconds: 40),
    sizeInBytes: 15 * 1024 * 1024,
    width: 1920,
    height: 1080,
  );

  test('loadVideo creates initial EditProject with full video duration', () {
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadVideo(testVideo);

    final state = container.read(editorControllerProvider);
    expect(state.video, equals(testVideo));
    expect(state.project, isNotNull);
    expect(state.project!.sourceDurationSeconds, 40.0);
    expect(state.project!.trim.endSeconds, 40.0);
  });

  test('tool controls update EditProject state', () {
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadVideo(testVideo);

    controller.setTrim(5.0, 25.0);
    controller.setRotation(90);
    controller.toggleHFlip();
    controller.setSpeed(1.5, true);
    controller.setCanvas(aspectRatio: TargetAspectRatio.vertical916);
    controller.setColorFilter(preset: ColorFilterPreset.cinematic);
    controller.setFade(fadeIn: 1.0, fadeOut: 1.0, fadeAudio: true);

    final project = container.read(editorControllerProvider).project!;
    expect(project.trim.startSeconds, 5.0);
    expect(project.trim.endSeconds, 25.0);
    expect(project.transform.rotationDegrees, 90);
    expect(project.transform.hflip, isTrue);
    expect(project.speed.speed, 1.5);
    expect(project.canvas.aspectRatio, TargetAspectRatio.vertical916);
    expect(project.color.preset, ColorFilterPreset.cinematic);
    expect(project.fade.fadeInSeconds, 1.0);
  });

  test(
    'generatePreview invokes generateEditPreview and sets previewPath',
    () async {
      final controller = container.read(editorControllerProvider.notifier);
      controller.loadVideo(testVideo);

      final path = await controller.generatePreview();
      expect(path, isNotNull);
      expect(path, contains('preview_'));

      final state = container.read(editorControllerProvider);
      expect(state.previewPath, equals(path));
      expect(state.isPreviewLoading, isFalse);
    },
  );

  test('enqueueExport enqueues JobRecord into JobQueueController', () async {
    final controller = container.read(editorControllerProvider.notifier);
    controller.loadVideo(testVideo);

    final jobId = await controller.enqueueExport();
    expect(jobId, startsWith('job_'));

    final queueState = container.read(jobQueueControllerProvider);
    expect(
      queueState.jobs.any((j) => j.id == jobId && j.type == JobType.editExport),
      isTrue,
    );
  });
}
