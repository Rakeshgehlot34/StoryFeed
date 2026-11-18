import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/jobs/domain/job_queue_controller.dart';
import 'package:shorts_splitter/features/jobs/domain/models/job_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('JobQueueController Tests', () {
    test('1. starts with empty queue and isProcessing = false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(jobQueueControllerProvider);
      expect(state.jobs, isEmpty);
      expect(state.isProcessing, isFalse);
      expect(state.activeJob, isNull);
    });

    test(
      '2. enqueues jobs and executes sequentially without concurrency',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(jobQueueControllerProvider.notifier);

        final job1 = JobRecord(
          id: 'job_1',
          type: JobType.shortsSplit,
          title: 'Shorts 1',
          inputPath: '/in/1.mp4',
          outputDirectory: '/out',
          createdAt: DateTime.now(),
        );

        final job2 = JobRecord(
          id: 'job_2',
          type: JobType.convert,
          title: 'Convert 2',
          inputPath: '/in/2.mp4',
          outputDirectory: '/out',
          createdAt: DateTime.now(),
        );

        await controller.enqueueJob(job1);
        await controller.enqueueJob(job2);

        final state = container.read(jobQueueControllerProvider);
        expect(state.jobs.length, equals(2));
        // At most one job should ever be in running state
        final runningJobs = state.jobs
            .where((j) => j.status == JobStatus.running)
            .toList();
        expect(runningJobs.length, lessThanOrEqualTo(1));
      },
    );

    test('3. cancels active or queued job properly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(jobQueueControllerProvider.notifier);

      final job = JobRecord(
        id: 'job_cancel_test',
        type: JobType.customSplit,
        title: 'Custom Split',
        inputPath: '/in/test.mp4',
        outputDirectory: '/out',
        createdAt: DateTime.now(),
      );

      await controller.enqueueJob(job);
      await controller.cancelJob('job_cancel_test');

      final state = container.read(jobQueueControllerProvider);
      final cancelled = state.jobs.firstWhere((j) => j.id == 'job_cancel_test');
      expect(cancelled.status, equals(JobStatus.cancelled));
    });

    test('4. retries a failed or cancelled job', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(jobQueueControllerProvider.notifier);

      final job = JobRecord(
        id: 'job_retry_test',
        type: JobType.screenshot,
        title: 'Screenshot Grab',
        inputPath: '/in/shot.mp4',
        outputDirectory: '/out',
        status: JobStatus.failed,
        errorMessage: 'Network timeout simulated',
        createdAt: DateTime.now(),
      );

      await controller.enqueueJob(job);
      await controller.retryJob('job_retry_test');

      final state = container.read(jobQueueControllerProvider);
      final retried = state.jobs.firstWhere((j) => j.id == 'job_retry_test');
      expect(retried.status.isActive, isTrue);
      expect(retried.errorMessage, isNull);
    });

    test('5. removes job from queue history', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(jobQueueControllerProvider.notifier);

      final job = JobRecord(
        id: 'job_remove_test',
        type: JobType.merge,
        title: 'Merge Clips',
        inputPath: '/in/m.mp4',
        outputDirectory: '/out',
        createdAt: DateTime.now(),
      );

      await controller.enqueueJob(job);
      expect(container.read(jobQueueControllerProvider).jobs.length, equals(1));

      await controller.removeJob('job_remove_test');
      expect(container.read(jobQueueControllerProvider).jobs, isEmpty);
    });
  });
}
