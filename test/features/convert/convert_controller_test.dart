import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/convert/domain/models/convert_config.dart';
import 'package:shorts_splitter/features/convert/presentation/controllers/convert_controller.dart';
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
    duration: Duration(seconds: 45),
    sizeInBytes: 25 * 1024 * 1024,
    width: 1920,
    height: 1080,
  );

  test(
    'setVideo probes metadata and calculates initial size estimate',
    () async {
      final controller = container.read(convertControllerProvider.notifier);
      await controller.setVideo(testVideo);

      final state = container.read(convertControllerProvider);
      expect(state.video, equals(testVideo));
      expect(state.metadata, isNotNull);
      expect(state.estimatedSizeBytes, greaterThan(0));
      expect(state.isLoading, isFalse);
    },
  );

  test('format and resolution updates recalculate estimated size', () async {
    final controller = container.read(convertControllerProvider.notifier);
    await controller.setVideo(testVideo);

    final initialSize =
        container.read(convertControllerProvider).estimatedSizeBytes;

    // Switch to SD 480p downscale
    controller.setResolution(ResolutionPreset.res480p);
    final sdSize = container.read(convertControllerProvider).estimatedSizeBytes;
    expect(sdSize, lessThan(initialSize));

    // Switch to Audio Only
    controller.setFormat(ConvertOutputFormat.audioOnly);
    final audioSize =
        container.read(convertControllerProvider).estimatedSizeBytes;
    expect(audioSize, lessThan(sdSize));
  });

  test('target size mode sets exact estimated size', () async {
    final controller = container.read(convertControllerProvider.notifier);
    await controller.setVideo(testVideo);

    controller.setTargetSizeMb(16.0);
    final state = container.read(convertControllerProvider);
    expect(state.config.targetSizeMb, 16.0);
    expect(state.estimatedSizeBytes, 16 * 1024 * 1024);

    controller.setTargetSizeMb(null);
    final resetState = container.read(convertControllerProvider);
    expect(resetState.config.targetSizeMb, isNull);
  });

  test('enqueueConversion adds job to JobQueueController', () async {
    final controller = container.read(convertControllerProvider.notifier);
    await controller.setVideo(testVideo);
    controller.setFormat(ConvertOutputFormat.mp4H265);

    final jobId = await controller.enqueueConversion();
    expect(jobId, startsWith('job_'));

    final queueState = container.read(jobQueueControllerProvider);
    expect(queueState.jobs.any((j) => j.id == jobId), isTrue);

    final queuedJob = queueState.jobs.firstWhere((j) => j.id == jobId);
    expect(queuedJob.type, JobType.convert);
    expect(queuedJob.payload['config'], isNotNull);
  });
}
