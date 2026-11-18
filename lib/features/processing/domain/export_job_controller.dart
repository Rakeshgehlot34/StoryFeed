import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/utils/foreground_service_manager.dart';
import '../../history/data/shared_prefs_history_repository.dart';
import '../../history/domain/models/project_record.dart';
import '../../history/presentation/controllers/history_controller.dart';
import '../../output/domain/models/exported_clip.dart';
import '../../output/presentation/controllers/output_controller.dart';
import '../../plan_review/presentation/controllers/part_items_controller.dart';
import '../../player/data/player_service.dart';
import '../../split_config/domain/models/clip_plan.dart';
import '../../split_config/domain/models/clip_segment.dart';
import '../../split_config/domain/models/split_config.dart';
import '../../video_picker/domain/models/picked_video.dart';
import '../data/ffmpeg_video_processor.dart';
import 'models/processing_progress.dart';
import 'video_processor.dart';

const String _prefKeyActiveJob = 'shorts_splitter_active_export_job_v1';

/// Persistent data record representation of an export job.
class ExportJobRecord {
  final String id;
  final String inputPath;
  final String videoFileName;
  final String baseName;
  final double totalDurationSeconds;
  final List<ClipSegment> segments;
  final List<int>? selectedIndices;
  final String outputDirectoryPath;
  final List<ExportedClip> completedClips;
  final int currentClipIndex;
  final int totalClips;
  final DateTime createdAt;

  const ExportJobRecord({
    required this.id,
    required this.inputPath,
    required this.videoFileName,
    required this.baseName,
    required this.totalDurationSeconds,
    required this.segments,
    this.selectedIndices,
    required this.outputDirectoryPath,
    required this.completedClips,
    required this.currentClipIndex,
    required this.totalClips,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'inputPath': inputPath,
    'videoFileName': videoFileName,
    'baseName': baseName,
    'totalDurationSeconds': totalDurationSeconds,
    'segments': segments.map((s) => s.toJson()).toList(),
    'selectedIndices': selectedIndices,
    'outputDirectoryPath': outputDirectoryPath,
    'completedClips': completedClips.map((c) => c.toJson()).toList(),
    'currentClipIndex': currentClipIndex,
    'totalClips': totalClips,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ExportJobRecord.fromJson(Map<String, dynamic> json) =>
      ExportJobRecord(
        id: json['id'] as String,
        inputPath: json['inputPath'] as String,
        videoFileName: json['videoFileName'] as String,
        baseName: json['baseName'] as String,
        totalDurationSeconds: (json['totalDurationSeconds'] as num).toDouble(),
        segments: (json['segments'] as List<dynamic>)
            .map((e) => ClipSegment.fromJson(e as Map<String, dynamic>))
            .toList(),
        selectedIndices: (json['selectedIndices'] as List<dynamic>?)
            ?.map((e) => (e as num).toInt())
            .toList(),
        outputDirectoryPath: json['outputDirectoryPath'] as String,
        completedClips: (json['completedClips'] as List<dynamic>)
            .map((e) => ExportedClip.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentClipIndex: json['currentClipIndex'] as int,
        totalClips: json['totalClips'] as int,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  ExportJobRecord copyWith({
    List<ExportedClip>? completedClips,
    int? currentClipIndex,
    List<int>? selectedIndices,
  }) => ExportJobRecord(
    id: id,
    inputPath: inputPath,
    videoFileName: videoFileName,
    baseName: baseName,
    totalDurationSeconds: totalDurationSeconds,
    segments: segments,
    selectedIndices: selectedIndices ?? this.selectedIndices,
    outputDirectoryPath: outputDirectoryPath,
    completedClips: completedClips ?? this.completedClips,
    currentClipIndex: currentClipIndex ?? this.currentClipIndex,
    totalClips: totalClips,
    createdAt: createdAt,
  );
}

/// Immutable state snapshot of the active export job controller.
class ExportJobState {
  final ProcessingProgress progress;
  final ExportJobRecord? activeRecord;
  final ExportJobRecord? interruptedJob;

  const ExportJobState({
    this.progress = const ProcessingProgress(),
    this.activeRecord,
    this.interruptedJob,
  });

  bool get isExporting => progress.isProcessing;
  bool get hasInterruptedJob => interruptedJob != null;
  bool get isCompleted => progress.status == ProcessingStatus.completed;
  bool get hasError => progress.status == ProcessingStatus.error;

  ExportJobState copyWith({
    ProcessingProgress? progress,
    ExportJobRecord? Function()? activeRecord,
    ExportJobRecord? Function()? interruptedJob,
  }) {
    return ExportJobState(
      progress: progress ?? this.progress,
      activeRecord: activeRecord != null ? activeRecord() : this.activeRecord,
      interruptedJob: interruptedJob != null
          ? interruptedJob()
          : this.interruptedJob,
    );
  }
}

final videoProcessorProvider = Provider<VideoProcessor>((ref) {
  final processor = FFmpegVideoProcessor();
  ref.onDispose(() => processor.dispose());
  return processor;
});

/// Global provider for the ExportJobController. Kept alive across screens and app restarts.
final exportJobControllerProvider =
    NotifierProvider<ExportJobController, ExportJobState>(
      ExportJobController.new,
    );

/// Domain/application layer export engine owning execution, job persistence, and recovery.
class ExportJobController extends Notifier<ExportJobState> {
  StreamSubscription<ProcessingProgress>? _processorSubscription;

  @override
  ExportJobState build() {
    ForegroundServiceManager.initialize(onCancel: cancelActiveJob);
    _checkInterruptedJobOnLaunch();
    return const ExportJobState();
  }

  Future<void> _checkInterruptedJobOnLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyActiveJob);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final record = ExportJobRecord.fromJson(decoded);
        final completedIndices = record.completedClips
            .map((c) => c.partIndex)
            .toSet();
        final targetCount =
            record.selectedIndices?.length ?? record.segments.length;
        if (completedIndices.length < targetCount) {
          AppLogger.info(
            'Detected interrupted export job: ${record.id} with ${completedIndices.length}/$targetCount completed',
          );
          state = state.copyWith(interruptedJob: () => record);
        } else {
          await prefs.remove(_prefKeyActiveJob);
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to load interrupted job record: $e');
    }
  }

  /// Initiates a brand-new export job, optionally selecting a subset of clips to process.
  Future<bool> startNewJob({
    required PickedVideo video,
    required SplitConfig config,
    required String outputDirectoryPath,
    ClipPlan? plan,
    Set<int>? selectedPartIndices,
  }) async {
    if (state.isExporting) {
      AppLogger.warning(
        'Rejecting startNewJob: an export job is already running',
      );
      return false;
    }

    // Release any active video playback so decoding does not compete with encoding
    await PlayerService.instance.stopAndRelease();

    final List<ClipSegment> allSegments;
    if (plan != null) {
      allSegments = plan.segments;
    } else {
      final totalSec = video.duration.inMilliseconds / 1000.0;
      final baseName = config.customBaseName?.isNotEmpty == true
          ? config.customBaseName!
          : video.baseName;
      allSegments = ClipSegment.calculateSegments(
        totalDurationSeconds: totalSec,
        targetClipDurationSeconds: config.targetDurationSeconds,
        mergeShortTrailingClip: config.mergeShortTrailingClip,
        baseName: baseName,
      );
    }

    if (allSegments.isEmpty) {
      state = state.copyWith(
        progress: const ProcessingProgress(
          status: ProcessingStatus.error,
          errorMessage: 'Cannot export: No segments generated.',
        ),
      );
      return false;
    }

    final segmentsToProcess =
        (selectedPartIndices != null && selectedPartIndices.isNotEmpty)
        ? allSegments
              .where((s) => selectedPartIndices.contains(s.index))
              .toList()
        : allSegments;

    if (segmentsToProcess.isEmpty) {
      state = state.copyWith(
        progress: const ProcessingProgress(
          status: ProcessingStatus.error,
          errorMessage: 'Cannot export: No segments selected.',
        ),
      );
      return false;
    }

    final activeBaseName =
        plan?.baseName ??
        (config.customBaseName?.isNotEmpty == true
            ? config.customBaseName!
            : video.baseName);

    final record = ExportJobRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      inputPath: video.path,
      videoFileName: video.fileName,
      baseName: activeBaseName,
      totalDurationSeconds: video.duration.inMilliseconds / 1000.0,
      segments: allSegments,
      selectedIndices: selectedPartIndices?.toList(),
      outputDirectoryPath: outputDirectoryPath,
      completedClips: [],
      currentClipIndex: 1,
      totalClips: allSegments.length,
      createdAt: DateTime.now(),
    );

    await _persistJobRecord(record);

    // Mark all selected parts as processing in the UI
    for (final seg in segmentsToProcess) {
      ref.read(partItemsControllerProvider.notifier).markProcessing(seg.index);
    }

    state = state.copyWith(
      activeRecord: () => record,
      interruptedJob: () => null,
      progress: ProcessingProgress(
        status: ProcessingStatus.preparing,
        currentClipIndex: 1,
        totalClips: segmentsToProcess.length,
        currentClipName: segmentsToProcess.first.formattedName,
      ),
    );

    return _runExportPipeline(
      record: record,
      segmentsToProcess: segmentsToProcess,
      config: config,
      plan: plan,
    );
  }

  /// Resumes an interrupted export job starting from its remaining unfinished clips.
  Future<bool> resumeInterruptedJob() async {
    final record = state.interruptedJob;
    if (record == null) return false;

    if (state.isExporting) return false;

    // Release any active players
    await PlayerService.instance.stopAndRelease();

    final completedPartIndices = record.completedClips
        .map((c) => c.partIndex)
        .toSet();
    final targetIndices = record.selectedIndices != null
        ? record.selectedIndices!.toSet()
        : record.segments.map((s) => s.index).toSet();

    final remainingSegments = record.segments
        .where(
          (s) =>
              targetIndices.contains(s.index) &&
              !completedPartIndices.contains(s.index),
        )
        .toList();

    if (remainingSegments.isEmpty) {
      await discardInterruptedJob();
      return true;
    }

    AppLogger.info(
      'Resuming export job ${record.id} for ${remainingSegments.length} unfinished clips',
    );

    for (final seg in remainingSegments) {
      ref.read(partItemsControllerProvider.notifier).markProcessing(seg.index);
    }

    state = state.copyWith(
      activeRecord: () => record,
      interruptedJob: () => null,
      progress: ProcessingProgress(
        status: ProcessingStatus.preparing,
        currentClipIndex: record.completedClips.length + 1,
        totalClips: record.totalClips,
        currentClipName: remainingSegments.first.formattedName,
        outputPaths: record.completedClips.map((c) => c.path).toList(),
      ),
    );

    const config = SplitConfig();
    return _runExportPipeline(
      record: record,
      segmentsToProcess: remainingSegments,
      config: config,
      plan: null,
    );
  }

  /// Discards any detected interrupted job and purges its stored record.
  Future<void> discardInterruptedJob() async {
    state = state.copyWith(interruptedJob: () => null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyActiveJob);
    } catch (_) {}
  }

  Future<bool> _runExportPipeline({
    required ExportJobRecord record,
    required List<ClipSegment> segmentsToProcess,
    required SplitConfig config,
    required ClipPlan? plan,
  }) async {
    final processor = ref.read(videoProcessorProvider);
    final outputRepo = ref.read(outputRepositoryProvider);

    final clipWriter = await outputRepo.resolveClipWriter();
    final duplicateHandling = await outputRepo.getDuplicateHandling();

    await ForegroundServiceManager.startOrUpdate(
      title: 'Exporting YouTube Shorts',
      message: 'Processing clip 1 of ${segmentsToProcess.length}...',
      progress: 0,
    );

    final completer = Completer<bool>();
    await _processorSubscription?.cancel();

    final stream = processor.splitVideo(
      inputPath: record.inputPath,
      segments: segmentsToProcess,
      outputDirectoryPath: record.outputDirectoryPath,
      mode: config.mode,
      aspectRatio: config.aspectRatio,
      baseName: record.baseName,
      clipWriter: clipWriter,
      duplicateHandling: duplicateHandling,
      plan: plan,
    );

    final completedClips = List<ExportedClip>.from(record.completedClips);
    final totalToProcess = segmentsToProcess.length;

    _processorSubscription = stream.listen(
      (progress) async {
        final adjustedProgress = progress.copyWith(
          currentClipIndex: progress.currentClipIndex,
          totalClips: totalToProcess,
          overallProgress: progress.overallProgress,
          outputPaths: [
            ...completedClips.map((c) => c.path),
            ...progress.outputPaths,
          ],
        );

        state = state.copyWith(progress: adjustedProgress);

        final pct = (adjustedProgress.overallProgress * 100).toInt();
        await ForegroundServiceManager.startOrUpdate(
          title:
              'Exporting Shorts (${adjustedProgress.currentClipIndex}/$totalToProcess)',
          message: 'Exporting ${adjustedProgress.currentClipName} ($pct%)',
          progress: pct,
        );

        // When a clip finishes processing, persist the updated state checkpoint
        if (progress.outputPaths.length >
            (completedClips.length - record.completedClips.length)) {
          final newPath = progress.outputPaths.last;
          final finishedSegmentIndex = progress.outputPaths.length - 1;
          if (finishedSegmentIndex >= 0 &&
              finishedSegmentIndex < segmentsToProcess.length) {
            final finishedSegment = segmentsToProcess[finishedSegmentIndex];
            final partNum =
                finishedSegment.index; // Invariant: strict plan index!
            final exportedClip = ExportedClip(
              path: newPath,
              fileName: p.basename(newPath),
              partIndex: partNum,
              totalParts: record.totalClips,
              duration: Duration(
                milliseconds: (finishedSegment.durationSeconds * 1000).toInt(),
              ),
              sizeInBytes: 0,
              createdAt: DateTime.now(),
            );
            completedClips.add(exportedClip);

            ref
                .read(partItemsControllerProvider.notifier)
                .markProcessed(partNum, newPath);

            final updatedRecord = record.copyWith(
              completedClips: completedClips,
              currentClipIndex: completedClips.length + 1,
            );
            await _persistJobRecord(updatedRecord);
          }
        }

        if (adjustedProgress.status == ProcessingStatus.completed) {
          await _onJobSucceeded(record, completedClips);
          if (!completer.isCompleted) completer.complete(true);
        } else if (adjustedProgress.status == ProcessingStatus.error) {
          await _onJobFailed(
            adjustedProgress.errorMessage,
            segmentsToProcess,
            progress.currentClipIndex,
          );
          if (!completer.isCompleted) completer.complete(false);
        }
      },
      onError: (Object err) async {
        await _onJobFailed(err.toString(), segmentsToProcess, 1);
        if (!completer.isCompleted) completer.complete(false);
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  Future<void> _onJobSucceeded(
    ExportJobRecord record,
    List<ExportedClip> completedClips,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyActiveJob);

      // Save complete record in project history
      final historyRecord = ProjectRecord(
        id: record.id,
        videoName: record.videoFileName,
        baseName: record.baseName,
        createdAt: DateTime.now(),
        totalDurationSeconds: record.totalDurationSeconds,
        totalShortsCount: record.totalClips,
        processedShortsCount: completedClips.length,
        canvasFormat: 'Shorts 9:16',
        outputFilePaths: completedClips.map((c) => c.path).toList(),
      );
      final historyRepo = ref.read(historyRepositoryProvider);
      await historyRepo.saveProject(historyRecord);
      ref.invalidate(historyControllerProvider);

      await ForegroundServiceManager.showCompleted(
        title: 'Export Complete',
        message:
            '${completedClips.length} YouTube Shorts saved successfully! Tap to view.',
      );
    } catch (e) {
      AppLogger.warning('Error completing export job: $e');
    } finally {
      await ForegroundServiceManager.stop();
      state = state.copyWith(activeRecord: () => null);
    }
  }

  Future<void> _onJobFailed(
    String? error,
    List<ClipSegment> segmentsToProcess,
    int failedIndex,
  ) async {
    AppLogger.error('Export job failed: $error');
    if (failedIndex >= 1 && failedIndex <= segmentsToProcess.length) {
      final failedSegment = segmentsToProcess[failedIndex - 1];
      ref
          .read(partItemsControllerProvider.notifier)
          .markFailed(failedSegment.index, error ?? 'Processing error');
    }
    try {
      final processor = ref.read(videoProcessorProvider);
      await processor.cancel();
    } catch (_) {}
    await ForegroundServiceManager.stop();
  }

  /// Cancels the currently running export job, cleans partial files, and dismisses notifications.
  Future<void> cancelActiveJob() async {
    AppLogger.info('Cancelling active export job');
    await _processorSubscription?.cancel();
    _processorSubscription = null;

    final processor = ref.read(videoProcessorProvider);
    await processor.cancel();

    await ForegroundServiceManager.stop();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyActiveJob);
    } catch (_) {}

    ref
        .read(partItemsControllerProvider.notifier)
        .resetProcessingToNotProcessed();

    state = state.copyWith(
      activeRecord: () => null,
      progress: const ProcessingProgress(status: ProcessingStatus.cancelled),
    );
  }

  Future<void> _persistJobRecord(ExportJobRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyActiveJob, jsonEncode(record.toJson()));
    } catch (e) {
      AppLogger.warning('Failed to persist active export job record: $e');
    }
  }
}
