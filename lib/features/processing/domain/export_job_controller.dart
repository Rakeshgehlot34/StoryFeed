import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/utils/foreground_service_manager.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/source_fingerprint.dart';
import '../../history/data/drift_job_repository.dart';
import '../../history/data/drift_part_repository.dart';
import '../../history/data/drift_project_repository.dart';
import '../../history/data/drift_source_repository.dart';
import '../../history/data/shared_prefs_history_repository.dart';
import '../../history/domain/models/project_record.dart';
import '../../history/presentation/controllers/history_controller.dart';
import '../../output/data/writers/direct_directory_clip_writer.dart';
import '../../output/domain/clip_writer.dart';
import '../../output/domain/folder_layout_resolver.dart';
import '../../output/domain/models/exported_clip.dart';
import '../../output/domain/safe_clip_replacer.dart';
import '../../output/presentation/controllers/output_controller.dart';
import '../../plan_review/presentation/controllers/part_items_controller.dart';
import '../../player/data/player_service.dart';
import '../../split_config/domain/models/clip_plan.dart';
import '../../split_config/domain/models/clip_segment.dart';
import '../../split_config/domain/models/split_config.dart';
import '../../split_config/domain/models/trim_range.dart';
import '../../video_picker/domain/models/picked_video.dart';
import '../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../data/ffmpeg_video_processor.dart';
import 'models/part_progress_state.dart';
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
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  ExportJobRecord copyWith({
    List<ExportedClip>? completedClips,
    int? currentClipIndex,
    List<int>? selectedIndices,
  }) =>
      ExportJobRecord(
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
      interruptedJob:
          interruptedJob != null ? interruptedJob() : this.interruptedJob,
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

/// Per-row Riverpod selector observing only the specific part's granular progress.
/// Avoids rebuilding the entire list when a single part's progress ticks.
final partProgressProvider =
    Provider.family<PartProgressState?, int>((ref, partIndex) {
  return ref.watch(
    exportJobControllerProvider.select(
      (state) => state.progress.partProgressMap[partIndex],
    ),
  );
});

/// Domain/application layer export engine owning execution, job persistence, and recovery.
class ExportJobController extends Notifier<ExportJobState> {
  // ---------------------------------------------------------------------
  // LOGGING – job start / cancel / finish
  // ---------------------------------------------------------------------
  // Note: actual startExport method is defined later; we inject a log
  // at the beginning of that method (see later edit).
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
        final completedIndices =
            record.completedClips.map((c) => c.partIndex).toSet();
        final targetCount =
            record.selectedIndices?.length ?? record.segments.length;

        // Verify files still exist on disk via Drift PartRepository
        final partRepo = ref.read(partRepositoryProvider);
        await partRepo.verifyFilesExistence(record.id);

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

  /// Initiates a brand-new export job (Stage 1 split or single-step convert).
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
      final trimStart = config.trimRange?.startSeconds ?? 0.0;
      final trimEnd = config.trimRange?.endSeconds ?? totalSec;
      final trimDuration = (trimEnd - trimStart).clamp(0.0, totalSec);

      allSegments = ClipSegment.calculateSegments(
        totalDurationSeconds: trimDuration,
        startOffsetSeconds: trimStart,
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

    final activeBaseName = plan?.baseName ??
        (config.customBaseName?.isNotEmpty == true
            ? config.customBaseName!
            : video.baseName);

    // 1. Resolve output writer and collision-safe folder layout (R3)
    final outputRepo = ref.read(outputRepositoryProvider);
    final clipWriter = await outputRepo.resolveClipWriter();

    final resolvedTarget = await FolderLayoutResolver.resolveTarget(
      totalPartsCount: allSegments.length,
      baseName: activeBaseName,
      strategyType: clipWriter.strategyType,
      rootSaveLocation: outputDirectoryPath,
    );
    final effectiveOutputDir = resolvedTarget.destinationLocation;

    final record = ExportJobRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      inputPath: video.path,
      videoFileName: video.fileName,
      baseName: activeBaseName,
      totalDurationSeconds: video.duration.inMilliseconds / 1000.0,
      segments: allSegments,
      selectedIndices: selectedPartIndices?.toList(),
      outputDirectoryPath: effectiveOutputDir,
      completedClips: [],
      currentClipIndex: 1,
      totalClips: allSegments.length,
      createdAt: DateTime.now(),
    );

    // 2. Persist Source, Project, and Parts into Drift SQLite database (R2)
    try {
      final fingerprint = await SourceFingerprint.computeFromPath(
        path: video.path,
        fileSizeBytes: video.sizeInBytes,
        durationMs: video.duration.inMilliseconds,
      );
      final sourceRepo = ref.read(sourceRepositoryProvider);
      final source = await sourceRepo.getByFingerprint(fingerprint);
      final sourceId =
          source?.id ?? 'src_${DateTime.now().millisecondsSinceEpoch}';

      if (source == null) {
        await sourceRepo.saveSource(
          SourcesCompanion.insert(
            id: sourceId,
            displayName: video.fileName,
            uriOrPath: video.path,
            fileSizeBytes: BigInt.from(video.sizeInBytes),
            durationSeconds: video.duration.inMilliseconds / 1000.0,
            width: video.width,
            height: video.height,
            fps: video.fps,
            fingerprint: fingerprint,
            createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      }

      final isTwoStage = config.mode == SplitMode.fast;
      final settingsJson = jsonEncode({
        'targetDurationSeconds': config.targetDurationSeconds,
        'mode': config.mode.name,
        'cropToFill': config.cropToFill,
        'mergeShortTrailingClip': config.mergeShortTrailingClip,
        'customBaseName': config.customBaseName,
      });

      final projectRepo = ref.read(projectRepositoryProvider);
      await projectRepo.saveProject(
        ProjectsCompanion.insert(
          id: record.id,
          sourceId: sourceId,
          workflowType: isTwoStage ? 'two_stage' : 'single_step',
          trimStartSeconds: Value(allSegments.first.startSeconds),
          trimEndSeconds: allSegments.last.endSeconds,
          settingsJson: settingsJson,
          outputLayout:
              resolvedTarget.layout == OutputFolderLayout.multiSubfolder
                  ? 'multi_subfolder'
                  : 'single_root',
          folderUriOrPath: resolvedTarget.destinationLocation,
          totalPartsCount: allSegments.length,
          createdAt: BigInt.from(record.createdAt.millisecondsSinceEpoch),
          updatedAt: BigInt.from(record.createdAt.millisecondsSinceEpoch),
        ),
      );

      final partRepo = ref.read(partRepositoryProvider);
      final partsToInsert = allSegments.map((s) {
        return PartsCompanion.insert(
          id: '${record.id}_part_${s.index}',
          projectId: record.id,
          partIndex: s.index,
          plannedStartSeconds: s.startSeconds,
          plannedEndSeconds: s.endSeconds,
          plannedDurationSeconds: s.durationSeconds,
          stage: 'planned',
          status: 'idle',
          updatedAt: BigInt.from(record.createdAt.millisecondsSinceEpoch),
        );
      }).toList();
      await partRepo.batchSaveParts(partsToInsert);

      final jobRepo = ref.read(jobRepositoryProvider);
      await jobRepo.createJob(
        JobsCompanion.insert(
          id: record.id,
          projectId: record.id,
          jobType: isTwoStage ? 'stage1_split' : 'single_step',
          state: 'running',
          targetIndicesJson:
              jsonEncode(segmentsToProcess.map((s) => s.index).toList()),
          createdAt: BigInt.from(record.createdAt.millisecondsSinceEpoch),
          startedAt: Value(BigInt.from(DateTime.now().millisecondsSinceEpoch)),
        ),
      );
    } catch (e) {
      AppLogger.warning('Database persistence error during startNewJob: $e');
    }

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
        stageLabel: config.mode == SplitMode.fast ? 'Splitting' : 'Encoding',
      ),
    );

    unawaited(
      _runExportPipeline(
        record: record,
        segmentsToProcess: segmentsToProcess,
        config: config,
        plan: plan,
        clipWriter: clipWriter,
      ),
    );

    return true;
  }

  /// Converts a targeted selection of parts to Shorts format (Stage 2 conversion)
  /// Safely replacing the split files in-place or keeping both.
  Future<bool> startStage2Conversion({
    required String projectId,
    required List<int> selectedPartIndices,
    required SplitConfig config,
    ReplaceStrategy replaceStrategy = ReplaceStrategy.replace,
    ClipPlan? plan,
  }) async {
    if (state.isExporting) {
      AppLogger.warning('Rejecting Stage 2: an export job is already running');
      return false;
    }

    await PlayerService.instance.stopAndRelease();

    final projectRepo = ref.read(projectRepositoryProvider);
    var projectDetails = await projectRepo.getProject(projectId);
    if (projectDetails == null && state.activeRecord != null) {
      projectDetails = await projectRepo.getProject(state.activeRecord!.id);
    }

    final video = ref.read(videoPickerControllerProvider).valueOrNull;
    final sourcePath = projectDetails?.source.uriOrPath ??
        state.activeRecord?.inputPath ??
        video?.path;
    final sourceName = projectDetails?.source.displayName ??
        state.activeRecord?.baseName ??
        video?.baseName ??
        'short';

    if (sourcePath == null || sourcePath.isEmpty) {
      AppLogger.error('Source video not found for Stage 2 conversion');
      return false;
    }

    final partRepo = ref.read(partRepositoryProvider);
    var allParts = await partRepo.getPartsForProject(projectId);
    if (allParts.isEmpty && state.activeRecord != null) {
      allParts = await partRepo.getPartsForProject(state.activeRecord!.id);
    }

    final targetParts = allParts
        .where((p) => selectedPartIndices.contains(p.partIndex))
        .toList();

    if (targetParts.isEmpty) {
      AppLogger.warning('No valid parts selected for Stage 2 conversion');
      return false;
    }

    final outputRepo = ref.read(outputRepositoryProvider);
    final clipWriter = await outputRepo.resolveClipWriter();
    final processor = ref.read(videoProcessorProvider);

    final totalTarget = targetParts.length;
    await ForegroundServiceManager.startOrUpdate(
      title: 'Converting Shorts (Stage 2)',
      message: 'Converting 1 of $totalTarget...',
      progress: 0,
    );

    for (int i = 0; i < totalTarget; i++) {
      final part = targetParts[i];
      ref
          .read(partItemsControllerProvider.notifier)
          .markProcessing(part.partIndex);
      await partRepo.updatePartStageStatus(
        projectId: projectId,
        partIndex: part.partIndex,
        stage: part.stage,
        status: 'running',
      );

      final partName =
          '${sourceName}_part_${part.partIndex.toString().padLeft(3, '0')}.mp4';

      state = state.copyWith(
        progress: ProcessingProgress(
          status: ProcessingStatus.processing,
          currentClipIndex: i + 1,
          totalClips: totalTarget,
          currentClipName: partName,
          stageLabel: 'Converting',
          overallProgress: i / totalTarget,
        ),
      );

      Directory? intermediateClipDir;
      try {
        final tempDir = await getTemporaryDirectory();
        intermediateClipDir = Directory(
          p.join(
            tempDir.path,
            'stage2_temp_${part.partIndex}_${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
        await intermediateClipDir.create(recursive: true);
        final tempWriter = DirectDirectoryClipWriter(intermediateClipDir);

        final partDuration =
            (part.actualDurationSeconds ?? part.plannedDurationSeconds)
                .clamp(1.0, AppConstants.maxClipDurationSeconds.toDouble());
        final partStart = part.actualStartSeconds ?? part.plannedStartSeconds;

        // Convert individual segment with 9:16 vertical canvas and part label overlay
        final segment = ClipSegment(
          index: part.partIndex,
          startSeconds: partStart,
          durationSeconds: partDuration,
          formattedName: partName,
        );

        final String? overlayMessage = config.overlaySpec.resolveText(
          partIndex: part.partIndex,
          totalParts: totalTarget,
          baseName: sourceName,
        );

        // Always construct effectivePlan from config to honor chosen 9:16 canvas, background, and overlay
        final effectivePlan = ClipPlan(
          items: [
            ClipPlanItem(
              index: part.partIndex,
              startSeconds: partStart,
              endSeconds: partStart + partDuration,
              formattedName: partName,
              resolvedMessage: overlayMessage,
            ),
          ],
          canvasSpec: config.canvasSpec,
          backgroundSpec: config.backgroundSpec,
          overlaySpec: config.overlaySpec,
          cropToFill: config.cropToFill,
          baseName: sourceName,
          sourceDurationSeconds: partDuration,
          trimRange: TrimRange(
            startSeconds: partStart,
            endSeconds: partStart + partDuration,
          ),
          verticalPosition: config.verticalPosition,
          verticalOffsetFraction: config.verticalOffsetFraction,
        );

        final transcodeStream = processor.splitVideo(
          inputPath: sourcePath,
          segments: [segment],
          outputDirectoryPath: intermediateClipDir.path,
          mode: SplitMode.precise,
          aspectRatio: config.aspectRatio,
          baseName: sourceName,
          clipWriter: tempWriter,
          plan: effectivePlan,
        );

        String? generatedOutputPath;
        await for (final p in transcodeStream) {
          if (p.outputPaths.isNotEmpty) {
            generatedOutputPath = p.outputPaths.last;
          }
          final clipProg = p.currentClipProgress;
          final overallProg = (i + clipProg) / totalTarget;
          state = state.copyWith(
            progress: state.progress.copyWith(
              currentClipProgress: clipProg,
              overallProgress: overallProg,
            ),
          );
          final pct = (overallProg * 100).toInt();
          final clipPct = (clipProg * 100).toInt();
          await ForegroundServiceManager.startOrUpdate(
            title: 'Converting Shorts (${i + 1}/$totalTarget) • $clipPct%',
            message: 'Converting $partName ($pct% overall)',
            progress: pct,
          );
        }

        if (generatedOutputPath == null ||
            !File(generatedOutputPath).existsSync() ||
            await File(generatedOutputPath).length() == 0) {
          throw VideoProcessingException(
            'Stage 2 transcode generated no valid output for part ${part.partIndex}',
          );
        }

        // Safely replace the existing clip (R1 SafeClipReplacer)
        final safeResult = await SafeClipReplacer.replace(
          newTempClipFile: File(generatedOutputPath),
          existingPathOrUri: part.outputUriOrPath ?? '',
          targetFileName: partName,
          clipWriter: clipWriter,
          replaceStrategy: replaceStrategy,
        );

        if (safeResult.isSuccess) {
          await partRepo.updatePartStageStatus(
            projectId: projectId,
            partIndex: part.partIndex,
            stage: 'converted',
            status: 'idle',
            outputUriOrPath: safeResult.finalPathOrUri,
            fileSizeBytes: safeResult.fileSizeBytes,
          );
          ref
              .read(partItemsControllerProvider.notifier)
              .markProcessed(part.partIndex, safeResult.finalPathOrUri);
        } else {
          await partRepo.updatePartStageStatus(
            projectId: projectId,
            partIndex: part.partIndex,
            stage: part.stage,
            status: 'failed',
            errorMessage: safeResult.errorMessage,
          );
          ref.read(partItemsControllerProvider.notifier).markFailed(
                part.partIndex,
                safeResult.errorMessage ?? 'Conversion failed',
              );
        }
      } catch (e) {
        AppLogger.error(
          'Stage 2 conversion failed for part ${part.partIndex}',
          error: e,
        );
        await partRepo.updatePartStageStatus(
          projectId: projectId,
          partIndex: part.partIndex,
          stage: part.stage,
          status: 'failed',
          errorMessage: e.toString(),
        );
        ref
            .read(partItemsControllerProvider.notifier)
            .markFailed(part.partIndex, e.toString());
      } finally {
        if (intermediateClipDir != null && await intermediateClipDir.exists()) {
          try {
            await intermediateClipDir.delete(recursive: true);
          } catch (_) {}
        }
      }
    }

    await projectRepo.updateProjectTimestamp(projectId);
    ref.invalidate(historyControllerProvider);
    ref.invalidate(exportedClipsProvider);
    await ForegroundServiceManager.showCompleted(
      title: 'Stage 2 Complete',
      message: 'Converted $totalTarget Shorts successfully!',
    );
    await ForegroundServiceManager.stop();

    state = state.copyWith(
      progress: const ProcessingProgress(status: ProcessingStatus.completed),
    );

    return true;
  }

  /// Resumes an interrupted export job starting from its remaining unfinished clips.
  Future<bool> resumeInterruptedJob() async {
    final record = state.interruptedJob;
    if (record == null) return false;

    if (state.isExporting) return false;

    // Release any active players
    await PlayerService.instance.stopAndRelease();

    // Verify existing files on disk
    final partRepo = ref.read(partRepositoryProvider);
    await partRepo.verifyFilesExistence(record.id);

    final completedPartIndices =
        record.completedClips.map((c) => c.partIndex).toSet();
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
    ClipWriter? clipWriter,
  }) async {
    final processor = ref.read(videoProcessorProvider);
    final outputRepo = ref.read(outputRepositoryProvider);

    final activeClipWriter = clipWriter ?? await outputRepo.resolveClipWriter();
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
      clipWriter: activeClipWriter,
      duplicateHandling: duplicateHandling,
      plan: plan,
    );

    final completedClips = List<ExportedClip>.from(record.completedClips);
    final totalToProcess = segmentsToProcess.length;
    final isTwoStage = config.mode == SplitMode.fast;

    final jobStartTime = record.createdAt;

    _processorSubscription = stream.listen(
      (progress) async {
        final now = DateTime.now();
        final elapsed = now.difference(jobStartTime);

        // Build per-part granular progress states (R4)
        final partMap =
            Map<int, PartProgressState>.from(progress.partProgressMap);
        if (partMap.isEmpty) {
          for (int idx = 0; idx < segmentsToProcess.length; idx++) {
            final seg = segmentsToProcess[idx];
            if (idx < progress.currentClipIndex - 1) {
              partMap[seg.index] = PartProgressState(
                partIndex: seg.index,
                progress: 1.0,
                stageLabel: 'Completed',
              );
            } else if (idx == progress.currentClipIndex - 1) {
              partMap[seg.index] = PartProgressState(
                partIndex: seg.index,
                progress: progress.currentClipProgress,
                stageLabel: isTwoStage ? 'Splitting' : 'Encoding',
              );
            } else {
              partMap[seg.index] = PartProgressState(
                partIndex: seg.index,
                progress: 0.0,
                stageLabel: 'Queued',
              );
            }
          }
        }

        // Calculate accurate remaining time (ETA)
        Duration? eta;
        final elapsedMs = elapsed.inMilliseconds;
        if (elapsedMs > 1500 && progress.overallProgress < 1.0) {
          if (progress.overallProgress > 0.005) {
            final totalEstMs = elapsedMs / progress.overallProgress;
            final remainingMs = (totalEstMs - elapsedMs).round();
            if (remainingMs > 0 && remainingMs < 86400000) {
              eta = Duration(milliseconds: remainingMs);
            }
          } else if (progress.currentClipIndex == 1 &&
              progress.currentClipProgress > 0.03) {
            final estClipMs = elapsedMs / progress.currentClipProgress;
            final totalEstMs = estClipMs * totalToProcess;
            final remainingMs = (totalEstMs - elapsedMs).round();
            if (remainingMs > 0 && remainingMs < 86400000) {
              eta = Duration(milliseconds: remainingMs);
            }
          }
        }

        final adjustedProgress = progress.copyWith(
          currentClipIndex: progress.currentClipIndex,
          totalClips: totalToProcess,
          currentClipProgress: progress.currentClipProgress,
          overallProgress: progress.overallProgress,
          stageLabel: isTwoStage ? 'Splitting' : 'Encoding',
          elapsed: elapsed,
          eta: eta,
          outputPaths: [
            ...completedClips.map((c) => c.path),
            ...progress.outputPaths,
          ],
          partProgressMap: partMap,
        );

        state = state.copyWith(progress: adjustedProgress);

        final pct = (adjustedProgress.overallProgress * 100).toInt();
        final clipPct = (adjustedProgress.currentClipProgress * 100).toInt();
        final etaStr =
            eta != null ? ' • ~${Formatters.formatDuration(eta)} left' : '';
        await ForegroundServiceManager.startOrUpdate(
          title:
              'Exporting Shorts (${adjustedProgress.currentClipIndex}/$totalToProcess) • $clipPct%',
          message: '${adjustedProgress.currentClipName} ($pct% overall)$etaStr',
          progress: pct,
        );

        // When a clip finishes processing, persist the updated state checkpoint and database row
        if (progress.outputPaths.length >
            (completedClips.length - record.completedClips.length)) {
          final newPath = progress.outputPaths.last;
          final finishedSegmentIndex = progress.outputPaths.length - 1;
          if (finishedSegmentIndex >= 0 &&
              finishedSegmentIndex < segmentsToProcess.length) {
            final finishedSegment = segmentsToProcess[finishedSegmentIndex];
            final partNum = finishedSegment.index;
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

            // Update SQLite Part stage and actual cut durations (R1 & R2)
            try {
              final partRepo = ref.read(partRepositoryProvider);
              await partRepo.updatePartStageStatus(
                projectId: record.id,
                partIndex: partNum,
                stage: isTwoStage ? 'split' : 'converted',
                status: 'idle',
                outputUriOrPath: newPath,
                actualStartSeconds: finishedSegment.startSeconds,
                actualEndSeconds: finishedSegment.endSeconds,
                actualDurationSeconds: finishedSegment.durationSeconds,
                hasCapViolation: finishedSegment.durationSeconds >
                    AppConstants.maxClipDurationSeconds,
              );

              final jobRepo = ref.read(jobRepositoryProvider);
              await jobRepo.updateJobProgress(
                record.id,
                (completedClips.length / totalToProcess).clamp(0.0, 1.0),
              );
              await jobRepo.logEvent(
                jobId: record.id,
                partIndex: partNum,
                stageLabel: isTwoStage ? 'Split' : 'Converted',
                progress:
                    (completedClips.length / totalToProcess).clamp(0.0, 1.0),
                message: 'Saved $newPath',
              );
            } catch (e) {
              AppLogger.warning('Database update error on clip completion: $e');
            }

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

      // Save complete record in project history (Legacy SharedPreferences + Drift DB)
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

      final jobRepo = ref.read(jobRepositoryProvider);
      await jobRepo.markJobCompleted(record.id);

      final projectRepo = ref.read(projectRepositoryProvider);
      await projectRepo.updateProjectTimestamp(record.id);

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
    final activeId = state.activeRecord?.id;
    if (failedIndex >= 1 && failedIndex <= segmentsToProcess.length) {
      final failedSegment = segmentsToProcess[failedIndex - 1];
      ref
          .read(partItemsControllerProvider.notifier)
          .markFailed(failedSegment.index, error ?? 'Processing error');

      if (activeId != null) {
        try {
          final partRepo = ref.read(partRepositoryProvider);
          await partRepo.updatePartStageStatus(
            projectId: activeId,
            partIndex: failedSegment.index,
            stage: 'planned',
            status: 'failed',
            errorMessage: error,
          );
          final jobRepo = ref.read(jobRepositoryProvider);
          await jobRepo.markJobFailed(activeId, error ?? 'Processing error');
        } catch (_) {}
      }
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
