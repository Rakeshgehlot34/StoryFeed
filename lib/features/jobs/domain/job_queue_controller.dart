import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/utils/foreground_service_manager.dart';
import '../../audio_studio/domain/models/audio_studio_project.dart';
import '../../convert/domain/models/convert_config.dart';
import '../../custom_split/domain/models/custom_clip_plan.dart';
import '../../editor/domain/models/edit_project.dart';
import '../../merge/domain/models/merge_project.dart';
import '../../player/data/player_service.dart';
import '../../processing/domain/export_job_controller.dart';
import '../../processing/domain/models/processing_progress.dart';
import '../../screenshot/domain/models/screenshot_config.dart';
import 'models/job_record.dart';

const String _prefKeyJobQueue = 'shorts_splitter_job_queue_v2';

/// Domain state for tracking the unified job queue across all studio tools.
class JobQueueState {
  final List<JobRecord> jobs;
  final bool isProcessing;

  const JobQueueState({this.jobs = const [], this.isProcessing = false});

  JobRecord? get activeJob {
    try {
      return jobs.firstWhere((j) => j.status == JobStatus.running);
    } catch (_) {
      return null;
    }
  }

  List<JobRecord> get queuedJobs =>
      jobs.where((j) => j.status == JobStatus.queued).toList();

  List<JobRecord> get activeAndQueuedJobs =>
      jobs.where((j) => j.status.isActive).toList();

  List<JobRecord> get completedJobs =>
      jobs.where((j) => j.status == JobStatus.completed).toList();

  List<JobRecord> get failedJobs =>
      jobs.where((j) => j.status == JobStatus.failed).toList();

  JobQueueState copyWith({List<JobRecord>? jobs, bool? isProcessing}) {
    return JobQueueState(
      jobs: jobs ?? this.jobs,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

/// Global provider for the JobQueueController.
final jobQueueControllerProvider =
    NotifierProvider<JobQueueController, JobQueueState>(JobQueueController.new);

/// Central domain orchestrator managing sequential execution, checkpointing,
/// crash recovery, and notifications for all studio processing jobs.
class JobQueueController extends Notifier<JobQueueState> {
  bool _isQueueLoopRunning = false;
  StreamSubscription<ProcessingProgress>? _activeProcessorSub;

  @override
  JobQueueState build() {
    ForegroundServiceManager.initialize(
      onCancel: () async {
        final active = state.activeJob;
        if (active != null) {
          await cancelJob(active.id);
        }
      },
    );
    _loadQueueFromStorage();
    return const JobQueueState();
  }

  Future<void> _loadQueueFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyJobQueue);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List<dynamic>?) ?? [];
        final loadedJobs = list
            .map((item) => JobRecord.fromJson(item as Map<String, dynamic>))
            .map((job) {
              // If a job was left in 'running' when app died, mark as failed for safe recovery
              if (job.status == JobStatus.running) {
                return job.copyWith(
                  status: JobStatus.failed,
                  errorMessage: 'Job interrupted by process termination.',
                );
              }
              return job;
            })
            .toList();

        state = state.copyWith(jobs: loadedJobs);
        AppLogger.info('Loaded ${loadedJobs.length} jobs from queue storage');
      }
    } catch (e) {
      AppLogger.warning('Failed to load job queue from storage: $e');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = state.jobs.map((j) => j.toJson()).toList();
      await prefs.setString(_prefKeyJobQueue, jsonEncode(data));
    } catch (e) {
      AppLogger.warning('Failed to persist job queue: $e');
    }
  }

  /// Appends a new job to the queue and triggers the processing loop.
  Future<void> enqueueJob(JobRecord job) async {
    AppLogger.info('Enqueuing job: ${job.id} (${job.type.displayName})');
    final updatedList = List<JobRecord>.from(state.jobs)..add(job);
    state = state.copyWith(jobs: updatedList);
    await _persistQueue();
    unawaited(_processNextJobIfNeeded());
  }

  /// Retries a failed or cancelled job by resetting it to 'queued'.
  Future<void> retryJob(String jobId) async {
    final idx = state.jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;

    final target = state.jobs[idx];
    final reset = target.copyWith(
      status: JobStatus.queued,
      overallProgress: 0.0,
      currentStepMessage: 'Queued for retry...',
      clearErrorMessage: true,
    );

    final updated = List<JobRecord>.from(state.jobs)..[idx] = reset;
    state = state.copyWith(jobs: updated);
    await _persistQueue();
    unawaited(_processNextJobIfNeeded());
  }

  /// Cancels the specified job. If currently running, halts native FFmpeg.
  Future<void> cancelJob(String jobId) async {
    final idx = state.jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;

    final job = state.jobs[idx];
    if (job.status == JobStatus.running) {
      AppLogger.info('Halting active job $jobId');
      await _activeProcessorSub?.cancel();
      _activeProcessorSub = null;

      final processor = ref.read(videoProcessorProvider);
      await processor.cancel();
      await ForegroundServiceManager.stop();
    }

    final cancelled = job.copyWith(
      status: JobStatus.cancelled,
      currentStepMessage: 'Cancelled by user',
    );
    final updated = List<JobRecord>.from(state.jobs)..[idx] = cancelled;
    state = state.copyWith(jobs: updated);
    await _persistQueue();
    unawaited(_processNextJobIfNeeded());
  }

  /// Removes a job record from history.
  Future<void> removeJob(String jobId) async {
    final updated = state.jobs.where((j) => j.id != jobId).toList();
    state = state.copyWith(jobs: updated);
    await _persistQueue();
  }

  /// Clears all completed, failed, and cancelled jobs from the list.
  Future<void> clearCompleted() async {
    final updated = state.jobs.where((j) => j.status.isActive).toList();
    state = state.copyWith(jobs: updated);
    await _persistQueue();
  }

  /// Internal sequential queue worker.
  Future<void> _processNextJobIfNeeded() async {
    if (_isQueueLoopRunning) return;
    _isQueueLoopRunning = true;

    try {
      while (true) {
        final nextJobIdx = state.jobs.indexWhere(
          (j) => j.status == JobStatus.queued,
        );
        if (nextJobIdx == -1) break;

        final job = state.jobs[nextJobIdx];

        // Ensure audio player is released before running transcode
        await PlayerService.instance.stopAndRelease();

        final currentIdx = state.jobs.indexWhere((j) => j.id == job.id);
        if (currentIdx == -1) continue;
        final currentJob = state.jobs[currentIdx];
        if (currentJob.status != JobStatus.queued) continue;

        // Mark running
        final runningJob = currentJob.copyWith(
          status: JobStatus.running,
          currentStepMessage: 'Starting ${currentJob.type.displayName}...',
        );
        final list = List<JobRecord>.from(state.jobs)
          ..[currentIdx] = runningJob;
        state = state.copyWith(jobs: list, isProcessing: true);
        await _persistQueue();

        await ForegroundServiceManager.startOrUpdate(
          title: job.title,
          message: 'Processing...',
          progress: 0,
        );

        // Execute job
        try {
          await _executeJob(runningJob);
        } catch (e, st) {
          AppLogger.error('Job ${job.id} failed: $e', stackTrace: st);
          final failedJob = runningJob.copyWith(
            status: JobStatus.failed,
            errorMessage: e.toString(),
            currentStepMessage: 'Failed: $e',
          );
          final updated = List<JobRecord>.from(state.jobs);
          final errIdx = updated.indexWhere((j) => j.id == job.id);
          if (errIdx != -1) updated[errIdx] = failedJob;
          state = state.copyWith(jobs: updated);
          await _persistQueue();
          await ForegroundServiceManager.stop();
        }
      }
    } finally {
      _isQueueLoopRunning = false;
      state = state.copyWith(isProcessing: false);
      if (state.activeJob == null) {
        await ForegroundServiceManager.stop();
      }
    }
  }

  Future<void> _executeJob(JobRecord job) async {
    if (job.type == JobType.customSplit) {
      final rawPlan = job.payload['plan'];
      if (rawPlan is! Map<String, dynamic>) {
        throw const VideoProcessingException(
          'Job payload missing CustomClipPlan data',
        );
      }

      final plan = CustomClipPlan.fromJson(rawPlan);
      final processor = ref.read(videoProcessorProvider);

      final progressStream = processor.splitCustom(
        inputPath: job.inputPath,
        plan: plan,
        outputDirectoryPath: job.outputDirectory,
      );

      final completer = Completer<List<String>>();

      _activeProcessorSub = progressStream.listen(
        (progress) {
          if (progress.status == ProcessingStatus.cancelled) {
            if (!completer.isCompleted) {
              completer.completeError(
                const OperationCancelledException('Job cancelled'),
              );
            }
            return;
          }
          if (progress.status == ProcessingStatus.error) {
            if (!completer.isCompleted) {
              completer.completeError(
                VideoProcessingException(
                  progress.errorMessage ?? 'Custom split processing failed',
                ),
              );
            }
            return;
          }

          updateJobProgress(
            jobId: job.id,
            progress: progress.overallProgress,
            stepMessage: progress.currentClipName.isNotEmpty
                ? 'Processing ${progress.currentClipName} (${(progress.overallProgress * 100).toInt()}%)'
                : 'Processing...',
            currentPart: progress.currentClipIndex,
            totalParts: progress.totalClips,
          );

          if (progress.status == ProcessingStatus.completed) {
            if (!completer.isCompleted) {
              completer.complete(progress.outputPaths);
            }
          }
        },
        onError: (Object err, StackTrace? st) {
          if (!completer.isCompleted) completer.completeError(err, st);
        },
      );

      final finalOutputs = await completer.future;
      await _activeProcessorSub?.cancel();
      _activeProcessorSub = null;

      markJobCompleted(jobId: job.id, outputPaths: finalOutputs);
      return;
    }

    if (job.type == JobType.editExport) {
      final rawProject = job.payload['project'];
      if (rawProject is! Map<String, dynamic>) {
        throw const VideoProcessingException(
          'Job payload missing EditProject data',
        );
      }

      final project = EditProject.fromJson(rawProject);
      final processor = ref.read(videoProcessorProvider);

      final progressStream = processor.exportEditProject(
        inputPath: job.inputPath,
        project: project,
        outputDirectoryPath: job.outputDirectory,
      );

      final completer = Completer<List<String>>();

      _activeProcessorSub = progressStream.listen(
        (progress) {
          if (progress.status == ProcessingStatus.cancelled) {
            if (!completer.isCompleted) {
              completer.completeError(
                const OperationCancelledException('Job cancelled'),
              );
            }
            return;
          }
          if (progress.status == ProcessingStatus.error) {
            if (!completer.isCompleted) {
              completer.completeError(
                VideoProcessingException(
                  progress.errorMessage ?? 'Edit export processing failed',
                ),
              );
            }
            return;
          }

          updateJobProgress(
            jobId: job.id,
            progress: progress.overallProgress,
            stepMessage:
                'Exporting ${project.title} (${(progress.overallProgress * 100).toInt()}%)',
            currentPart: 1,
            totalParts: 1,
          );

          if (progress.status == ProcessingStatus.completed) {
            if (!completer.isCompleted) {
              completer.complete(progress.outputPaths);
            }
          }
        },
        onError: (Object err, StackTrace? st) {
          if (!completer.isCompleted) completer.completeError(err, st);
        },
      );

      final finalOutputs = await completer.future;
      await _activeProcessorSub?.cancel();
      _activeProcessorSub = null;

      markJobCompleted(jobId: job.id, outputPaths: finalOutputs);
      return;
    }

    if (job.type == JobType.convert) {
      final rawConfig = job.payload['config'];
      if (rawConfig is! Map<String, dynamic>) {
        throw const VideoProcessingException(
          'Job payload missing ConvertConfig data',
        );
      }

      final config = ConvertConfig.fromJson(rawConfig);
      final duration =
          (job.payload['durationSeconds'] as num?)?.toDouble() ?? 0.0;
      final processor = ref.read(videoProcessorProvider);

      final progressStream = processor.convertVideo(
        inputPath: job.inputPath,
        config: config,
        durationSeconds: duration,
        outputDirectoryPath: job.outputDirectory,
      );

      final completer = Completer<List<String>>();

      _activeProcessorSub = progressStream.listen(
        (progress) {
          if (progress.status == ProcessingStatus.cancelled) {
            if (!completer.isCompleted) {
              completer.completeError(
                const OperationCancelledException('Job cancelled'),
              );
            }
            return;
          }
          if (progress.status == ProcessingStatus.error) {
            if (!completer.isCompleted) {
              completer.completeError(
                VideoProcessingException(
                  progress.errorMessage ?? 'Conversion failed',
                ),
              );
            }
            return;
          }

          updateJobProgress(
            jobId: job.id,
            progress: progress.overallProgress,
            stepMessage:
                'Converting to ${config.format.displayName} (${(progress.overallProgress * 100).toInt()}%)',
            currentPart: 1,
            totalParts: 1,
          );

          if (progress.status == ProcessingStatus.completed) {
            if (!completer.isCompleted) {
              completer.complete(progress.outputPaths);
            }
          }
        },
        onError: (Object err, StackTrace? st) {
          if (!completer.isCompleted) completer.completeError(err, st);
        },
      );

      final finalOutputs = await completer.future;
      await _activeProcessorSub?.cancel();
      _activeProcessorSub = null;

      markJobCompleted(jobId: job.id, outputPaths: finalOutputs);
      return;
    }

    if (job.type == JobType.audioStudio) {
      final rawConfig = job.payload['config'];
      if (rawConfig is! Map<String, dynamic>) {
        throw const VideoProcessingException(
          'Job payload missing AudioStudioConfig data',
        );
      }

      final config = AudioStudioConfig.fromJson(rawConfig);
      final processor = ref.read(videoProcessorProvider);

      final progressStream = processor.processAudioStudio(
        config: config,
        outputDirectoryPath: job.outputDirectory,
      );

      final completer = Completer<List<String>>();

      _activeProcessorSub = progressStream.listen(
        (progress) {
          if (progress.status == ProcessingStatus.cancelled) {
            if (!completer.isCompleted) {
              completer.completeError(
                const OperationCancelledException('Job cancelled'),
              );
            }
            return;
          }
          if (progress.status == ProcessingStatus.error) {
            if (!completer.isCompleted) {
              completer.completeError(
                VideoProcessingException(
                  progress.errorMessage ?? 'Audio studio processing failed',
                ),
              );
            }
            return;
          }

          updateJobProgress(
            jobId: job.id,
            progress: progress.overallProgress,
            stepMessage:
                'Mixing Audio (${(progress.overallProgress * 100).toInt()}%)',
            currentPart: 1,
            totalParts: 1,
          );

          if (progress.status == ProcessingStatus.completed) {
            if (!completer.isCompleted) {
              completer.complete(progress.outputPaths);
            }
          }
        },
        onError: (Object err, StackTrace? st) {
          if (!completer.isCompleted) completer.completeError(err, st);
        },
      );

      final finalOutputs = await completer.future;
      await _activeProcessorSub?.cancel();
      _activeProcessorSub = null;

      markJobCompleted(jobId: job.id, outputPaths: finalOutputs);
      return;
    }

    if (job.type == JobType.screenshot) {
      final rawConfig = job.payload['config'];
      if (rawConfig is! Map<String, dynamic>) {
        throw const VideoProcessingException(
          'Job payload missing ScreenshotConfig data',
        );
      }

      final config = ScreenshotConfig.fromJson(rawConfig);
      final processor = ref.read(videoProcessorProvider);

      final progressStream = processor.captureScreenshots(
        config: config,
        outputDirectoryPath: job.outputDirectory,
      );

      final completer = Completer<List<String>>();

      _activeProcessorSub = progressStream.listen(
        (progress) {
          if (progress.status == ProcessingStatus.cancelled) {
            if (!completer.isCompleted) {
              completer.completeError(
                const OperationCancelledException('Job cancelled'),
              );
            }
            return;
          }
          if (progress.status == ProcessingStatus.error) {
            if (!completer.isCompleted) {
              completer.completeError(
                VideoProcessingException(
                  progress.errorMessage ?? 'Screenshot extraction failed',
                ),
              );
            }
            return;
          }

          updateJobProgress(
            jobId: job.id,
            progress: progress.overallProgress,
            stepMessage:
                'Extracting Frame ${progress.currentClipIndex} of ${progress.totalClips} (${(progress.overallProgress * 100).toInt()}%)',
            currentPart: progress.currentClipIndex,
            totalParts: progress.totalClips,
          );

          if (progress.status == ProcessingStatus.completed) {
            if (!completer.isCompleted) {
              completer.complete(progress.outputPaths);
            }
          }
        },
        onError: (Object err, StackTrace? st) {
          if (!completer.isCompleted) completer.completeError(err, st);
        },
      );

      final finalOutputs = await completer.future;
      await _activeProcessorSub?.cancel();
      _activeProcessorSub = null;

      markJobCompleted(jobId: job.id, outputPaths: finalOutputs);
      return;
    }

    if (job.type == JobType.merge) {
      final rawConfig = job.payload['config'];
      if (rawConfig is! Map<String, dynamic>) {
        throw const VideoProcessingException(
          'Job payload missing MergeConfig data',
        );
      }

      final config = MergeConfig.fromJson(rawConfig);
      final processor = ref.read(videoProcessorProvider);

      final progressStream = processor.mergeVideos(
        config: config,
        outputDirectoryPath: job.outputDirectory,
      );

      final completer = Completer<List<String>>();

      _activeProcessorSub = progressStream.listen(
        (progress) {
          if (progress.status == ProcessingStatus.cancelled) {
            if (!completer.isCompleted) {
              completer.completeError(
                const OperationCancelledException('Job cancelled'),
              );
            }
            return;
          }
          if (progress.status == ProcessingStatus.error) {
            if (!completer.isCompleted) {
              completer.completeError(
                VideoProcessingException(
                  progress.errorMessage ?? 'Video merge failed',
                ),
              );
            }
            return;
          }

          updateJobProgress(
            jobId: job.id,
            progress: progress.overallProgress,
            stepMessage:
                'Merging Videos (${(progress.overallProgress * 100).toInt()}%)',
            currentPart: 1,
            totalParts: 1,
          );

          if (progress.status == ProcessingStatus.completed) {
            if (!completer.isCompleted) {
              completer.complete(progress.outputPaths);
            }
          }
        },
        onError: (Object err, StackTrace? st) {
          if (!completer.isCompleted) completer.completeError(err, st);
        },
      );

      final finalOutputs = await completer.future;
      await _activeProcessorSub?.cancel();
      _activeProcessorSub = null;

      markJobCompleted(jobId: job.id, outputPaths: finalOutputs);
      return;
    }

    // Default simulation loop for tools in upcoming phases
    for (int pct = 10; pct <= 100; pct += 30) {
      final current = state.jobs.firstWhere(
        (j) => j.id == job.id,
        orElse: () => job,
      );
      if (current.status == JobStatus.cancelled) return;

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final checkAgain = state.jobs.firstWhere(
        (j) => j.id == job.id,
        orElse: () => job,
      );
      if (checkAgain.status == JobStatus.cancelled) return;

      updateJobProgress(
        jobId: job.id,
        progress: pct / 100.0,
        stepMessage: 'Processing ${job.type.displayName} ($pct%)...',
      );
    }

    final finalCheck = state.jobs.firstWhere(
      (j) => j.id == job.id,
      orElse: () => job,
    );
    if (finalCheck.status == JobStatus.cancelled) return;

    markJobCompleted(jobId: job.id, outputPaths: job.outputPaths);
  }

  /// Updates live progress for an actively running job.
  void updateJobProgress({
    required String jobId,
    required double progress,
    required String stepMessage,
    int? currentPart,
    int? totalParts,
  }) {
    final idx = state.jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;

    final updated = state.jobs[idx].copyWith(
      overallProgress: progress.clamp(0.0, 1.0),
      currentStepMessage: stepMessage,
      currentPart: currentPart,
      totalParts: totalParts,
    );

    final list = List<JobRecord>.from(state.jobs)..[idx] = updated;
    state = state.copyWith(jobs: list);

    final pct = (progress * 100).toInt();
    ForegroundServiceManager.startOrUpdate(
      title: updated.title,
      message: stepMessage,
      progress: pct,
    );
  }

  /// Marks a job as successfully completed.
  void markJobCompleted({
    required String jobId,
    required List<String> outputPaths,
  }) {
    final idx = state.jobs.indexWhere((j) => j.id == jobId);
    if (idx == -1) return;

    final completed = state.jobs[idx].copyWith(
      status: JobStatus.completed,
      overallProgress: 1.0,
      currentStepMessage: 'Completed successfully',
      outputPaths: outputPaths,
      completedAt: DateTime.now(),
    );

    final list = List<JobRecord>.from(state.jobs)..[idx] = completed;
    state = state.copyWith(jobs: list);
    _persistQueue();

    ForegroundServiceManager.showCompleted(
      title: 'Task Complete',
      message: '${completed.title} finished successfully.',
    );
  }
}
