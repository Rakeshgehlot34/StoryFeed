import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/custom_split/domain/models/custom_split_config.dart';
import 'package:shorts_splitter/features/custom_split/presentation/controllers/custom_split_controller.dart';
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
    path: '/data/user/0/com.shortssplitter/cache/test_video.mp4',
    fileName: 'test_video.mp4',
    baseName: 'test_video',
    duration: Duration(seconds: 120),
    sizeInBytes: 25 * 1024 * 1024,
    width: 1920,
    height: 1080,
  );

  test('setVideo calculates initial plan and sets trim bounds', () {
    final controller = container.read(customSplitControllerProvider.notifier);
    controller.setVideo(testVideo);

    final state = container.read(customSplitControllerProvider);
    expect(state.video, equals(testVideo));
    expect(state.config.endSeconds, 120.0);
    expect(state.plan, isNotNull);
    expect(state.plan!.totalParts, 2); // 120s / 60s default = 2
  });

  test('setMode updates configuration and recalculates plan', () {
    final controller = container.read(customSplitControllerProvider.notifier);
    controller.setVideo(testVideo);

    controller.setMode(CustomSplitMode.byParts);
    controller.setTargetPartCount(4);

    final state = container.read(customSplitControllerProvider);
    expect(state.config.mode, CustomSplitMode.byParts);
    expect(state.plan!.totalParts, 4);
    expect(state.plan!.items[0].durationSeconds, 30.0);
  });

  test(
    'addSplitPoint adds sorted timestamps and recalculates byPoints plan',
    () {
      final controller = container.read(customSplitControllerProvider.notifier);
      controller.setVideo(testVideo);

      controller.setMode(CustomSplitMode.byPoints);
      controller.addSplitPoint(30.0);
      controller.addSplitPoint(90.0);

      final state = container.read(customSplitControllerProvider);
      expect(state.config.customSplitPoints, [30.0, 90.0]);
      expect(state.plan!.totalParts, 3); // [0..30], [30..90], [90..120]
    },
  );

  test('enqueueSplitJob enqueues JobRecord into JobQueueController', () async {
    final controller = container.read(customSplitControllerProvider.notifier);
    controller.setVideo(testVideo);

    final jobId = await controller.enqueueSplitJob();
    expect(jobId, startsWith('job_'));

    final queueState = container.read(jobQueueControllerProvider);
    expect(
      queueState.jobs.any(
        (j) => j.id == jobId && j.type == JobType.customSplit,
      ),
      isTrue,
    );
  });
}
