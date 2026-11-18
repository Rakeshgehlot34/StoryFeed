import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../jobs/domain/job_queue_controller.dart';
import '../../../jobs/domain/models/job_record.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../processing/domain/export_job_controller.dart';
import '../../domain/models/merge_project.dart';

/// State representation for the Video Merge feature.
class MergeState {
  final MergeConfig config;
  final bool isLoading;
  final bool isAnalyzing;
  final String? errorMessage;
  final String? activePreviewClipId;

  const MergeState({
    this.config = const MergeConfig(),
    this.isLoading = false,
    this.isAnalyzing = false,
    this.errorMessage,
    this.activePreviewClipId,
  });

  bool get canMerge => config.canMerge;
  int get clipCount => config.clips.length;
  double get totalDurationSeconds => config.calculateTotalDurationSeconds();
  int get estimatedSizeBytes => config.estimateOutputSizeBytes();

  MergeState copyWith({
    MergeConfig? config,
    bool? isLoading,
    bool? isAnalyzing,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? activePreviewClipId,
    bool clearPreviewClipId = false,
  }) {
    return MergeState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      activePreviewClipId: clearPreviewClipId
          ? null
          : (activePreviewClipId ?? this.activePreviewClipId),
    );
  }
}

final mergeControllerProvider = NotifierProvider<MergeController, MergeState>(
  MergeController.new,
);

class MergeController extends Notifier<MergeState> {
  @override
  MergeState build() {
    return const MergeState();
  }

  /// Appends multiple video files to the merge sequence, probing their metadata.
  Future<void> addVideos(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    state = state.copyWith(isAnalyzing: true, clearErrorMessage: true);
    final processor = ref.read(videoProcessorProvider);
    final newClips = <MergeClipItem>[];

    try {
      for (final path in filePaths) {
        try {
          final meta = await processor.getMetadata(path);
          final fileName = path.contains('/')
              ? path.substring(path.lastIndexOf('/') + 1)
              : path;

          final clip = MergeClipItem(
            id: 'clip_${DateTime.now().microsecondsSinceEpoch}_${newClips.length}',
            videoPath: path,
            fileName: fileName,
            durationSeconds: meta.duration.inMilliseconds / 1000.0,
            width: meta.width > 0 ? meta.width : 1920,
            height: meta.height > 0 ? meta.height : 1080,
            fps: meta.fps > 0 ? meta.fps : 30.0,
            hasAudio: meta.hasAudio,
            startTrimSeconds: 0.0,
            endTrimSeconds: null,
          );
          newClips.add(clip);
        } catch (e) {
          AppLogger.warning('Failed to probe metadata for $path: $e');
        }
      }

      final updatedClips = [...state.config.clips, ...newClips];
      state = state.copyWith(
        isAnalyzing: false,
        config: state.config.copyWith(clips: updatedClips),
      );
    } catch (e) {
      state = state.copyWith(
        isAnalyzing: false,
        errorMessage: 'Failed to analyze videos: $e',
      );
    }
  }

  /// Removes a clip from the merge sequence by id.
  void removeClip(String id) {
    final updated = state.config.clips.where((c) => c.id != id).toList();
    state = state.copyWith(config: state.config.copyWith(clips: updated));
  }

  /// Reorders the clips list based on standard drag-and-drop index shifts.
  void reorderClips(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= state.config.clips.length) return;
    int target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    if (target < 0 || target >= state.config.clips.length) return;

    final updated = List<MergeClipItem>.from(state.config.clips);
    final item = updated.removeAt(oldIndex);
    updated.insert(target, item);

    state = state.copyWith(config: state.config.copyWith(clips: updated));
  }

  /// Moves a clip up one position.
  void moveClipUp(int index) {
    if (index <= 0 || index >= state.config.clips.length) return;
    reorderClips(index, index - 1);
  }

  /// Moves a clip down one position.
  void moveClipDown(int index) {
    if (index < 0 || index >= state.config.clips.length - 1) return;
    reorderClips(index, index + 2);
  }

  /// Duplicates a clip and inserts it immediately after the original.
  void duplicateClip(String id) {
    final idx = state.config.clips.indexWhere((c) => c.id == id);
    if (idx == -1) return;

    final original = state.config.clips[idx];
    final copy = original.copyWith(
      id: 'clip_${DateTime.now().microsecondsSinceEpoch}',
    );

    final updated = List<MergeClipItem>.from(state.config.clips);
    updated.insert(idx + 1, copy);

    state = state.copyWith(config: state.config.copyWith(clips: updated));
  }

  /// Updates trim points for an individual clip.
  void updateClipTrim({
    required String id,
    double? startTrimSeconds,
    double? endTrimSeconds,
  }) {
    final updated = state.config.clips.map((c) {
      if (c.id == id) {
        return c.copyWith(
          startTrimSeconds: startTrimSeconds ?? c.startTrimSeconds,
          endTrimSeconds: endTrimSeconds ?? c.endTrimSeconds,
        );
      }
      return c;
    }).toList();

    state = state.copyWith(config: state.config.copyWith(clips: updated));
  }

  void setCanvasPreset(CanvasAspectRatioPreset preset) {
    state = state.copyWith(config: state.config.copyWith(canvasPreset: preset));
  }

  void setCustomDimensions(int width, int height) {
    state = state.copyWith(
      config: state.config.copyWith(customWidth: width, customHeight: height),
    );
  }

  void setFitMode(CanvasFitMode mode) {
    state = state.copyWith(config: state.config.copyWith(fitMode: mode));
  }

  void setTransition(MergeTransition transition) {
    state = state.copyWith(
      config: state.config.copyWith(transition: transition),
    );
  }

  void setTransitionDuration(double durationSeconds) {
    final clamped = durationSeconds.clamp(0.2, 3.0);
    state = state.copyWith(
      config: state.config.copyWith(transitionDurationSeconds: clamped),
    );
  }

  void setMethod(MergeMethod method) {
    state = state.copyWith(config: state.config.copyWith(method: method));
  }

  void setCustomBaseName(String name) {
    state = state.copyWith(config: state.config.copyWith(customBaseName: name));
  }

  void setActivePreviewClip(String? id) {
    state = state.copyWith(
      activePreviewClipId: id,
      clearPreviewClipId: id == null,
    );
  }

  void clearAll() {
    state = const MergeState();
  }

  /// Dispatches the configured merge project to the unified [JobQueueController].
  Future<JobRecord> dispatchMergeJob() async {
    if (!state.canMerge) {
      throw const VideoProcessingException(
        'At least two clips are required to merge videos.',
      );
    }

    final outDir = ref.read(outputDirectoryProvider).value ?? '';
    final config = state.config;
    final jobId = 'job_merge_${DateTime.now().millisecondsSinceEpoch}';

    final job = JobRecord(
      id: jobId,
      type: JobType.merge,
      title: 'Merge ${config.clips.length} Clips: ${config.effectiveBaseName}',
      inputPath: config.clips.first.videoPath,
      outputDirectory: outDir,
      totalParts: 1,
      createdAt: DateTime.now(),
      payload: {'config': config.toJson()},
    );

    await ref.read(jobQueueControllerProvider.notifier).enqueueJob(job);
    return job;
  }
}
