import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../jobs/domain/job_queue_controller.dart';
import '../../../jobs/domain/models/job_record.dart';
import '../../../output/data/clip_writer_factory.dart';
import '../../../output/domain/models/storage_strategy.dart';
import '../../../processing/domain/export_job_controller.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../domain/models/screenshot_config.dart';

/// State of the Screenshot Studio tool.
class ScreenshotState {
  final PickedVideo? video;
  final ScreenshotConfig config;
  final bool isLoading;
  final bool isCapturing;
  final bool isSaving;
  final String? errorMessage;
  final List<ScreenshotItem> capturedSessionFrames;
  final Set<String> selectedFrameIds;
  final ScreenshotItem? activePreviewItem;

  const ScreenshotState({
    this.video,
    required this.config,
    this.isLoading = false,
    this.isCapturing = false,
    this.isSaving = false,
    this.errorMessage,
    this.capturedSessionFrames = const [],
    this.selectedFrameIds = const {},
    this.activePreviewItem,
  });

  bool get isAllSelected =>
      capturedSessionFrames.isNotEmpty &&
      selectedFrameIds.length == capturedSessionFrames.length;

  ScreenshotState copyWith({
    PickedVideo? video,
    ScreenshotConfig? config,
    bool? isLoading,
    bool? isCapturing,
    bool? isSaving,
    String? errorMessage,
    List<ScreenshotItem>? capturedSessionFrames,
    Set<String>? selectedFrameIds,
    ScreenshotItem? activePreviewItem,
    bool clearActivePreview = false,
  }) {
    return ScreenshotState(
      video: video ?? this.video,
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      isCapturing: isCapturing ?? this.isCapturing,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      capturedSessionFrames:
          capturedSessionFrames ?? this.capturedSessionFrames,
      selectedFrameIds: selectedFrameIds ?? this.selectedFrameIds,
      activePreviewItem: clearActivePreview
          ? null
          : (activePreviewItem ?? this.activePreviewItem),
    );
  }
}

final screenshotControllerProvider =
    StateNotifierProvider<ScreenshotController, ScreenshotState>((ref) {
      return ScreenshotController(ref);
    });

class ScreenshotController extends StateNotifier<ScreenshotState> {
  final Ref ref;

  ScreenshotController(this.ref)
    : super(
        const ScreenshotState(
          config: ScreenshotConfig(
            videoPath: '',
            videoTitle: '',
            videoDurationSeconds: 0.0,
          ),
        ),
      );

  /// Initializes the controller with a newly selected video.
  Future<void> setVideo(PickedVideo video) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final processor = ref.read(videoProcessorProvider);
      final metadata = await processor.getMetadata(video.path);

      final durationSec = metadata.duration.inMilliseconds / 1000.0;

      final config = ScreenshotConfig(
        videoPath: video.path,
        videoTitle: video.fileName,
        videoDurationSeconds: durationSec,
        videoWidth: metadata.width,
        videoHeight: metadata.height,
        endSeconds: durationSec,
      );

      state = state.copyWith(video: video, config: config, isLoading: false);
    } catch (e) {
      AppLogger.warning('Failed to probe video metadata: $e');
      final durationSec = video.duration.inMilliseconds / 1000.0;

      final config = ScreenshotConfig(
        videoPath: video.path,
        videoTitle: video.fileName,
        videoDurationSeconds: durationSec,
        videoWidth: video.width,
        videoHeight: video.height,
        endSeconds: durationSec,
      );

      state = state.copyWith(video: video, config: config, isLoading: false);
    }
  }

  void setMode(ScreenshotCaptureMode mode) {
    state = state.copyWith(config: state.config.copyWith(mode: mode));
  }

  void setFormat(ScreenshotImageFormat format) {
    state = state.copyWith(config: state.config.copyWith(format: format));
  }

  void setJpegQuality(int quality) {
    state = state.copyWith(
      config: state.config.copyWith(jpegQuality: quality.clamp(50, 100)),
    );
  }

  void setIntervalType(IntervalType type) {
    state = state.copyWith(config: state.config.copyWith(intervalType: type));
  }

  void setIntervalSeconds(double seconds) {
    state = state.copyWith(
      config: state.config.copyWith(intervalSeconds: seconds),
    );
  }

  void setFrameCount(int count) {
    state = state.copyWith(
      config: state.config.copyWith(frameCount: count.clamp(2, 500)),
    );
  }

  void setTrimRange(double start, double end) {
    state = state.copyWith(
      config: state.config.copyWith(
        startSeconds: start.clamp(0.0, state.config.videoDurationSeconds),
        endSeconds: end.clamp(start, state.config.videoDurationSeconds),
      ),
    );
  }

  void setBaseName(String name) {
    state = state.copyWith(
      config: state.config.copyWith(customBaseName: name.trim()),
    );
  }

  void addTimestamp(double timestamp) {
    final clamped = timestamp.clamp(0.0, state.config.videoDurationSeconds);
    final currentList = List<double>.from(state.config.customTimestamps);
    if (!currentList.any((t) => (t - clamped).abs() < 0.05)) {
      currentList.add(double.parse(clamped.toStringAsFixed(3)));
      currentList.sort();
      state = state.copyWith(
        config: state.config.copyWith(customTimestamps: currentList),
      );
    }
  }

  void removeTimestamp(double timestamp) {
    final currentList = List<double>.from(state.config.customTimestamps)
      ..removeWhere((t) => (t - timestamp).abs() < 0.05);
    state = state.copyWith(
      config: state.config.copyWith(customTimestamps: currentList),
    );
  }

  void clearTimestamps() {
    state = state.copyWith(
      config: state.config.copyWith(customTimestamps: const []),
    );
  }

  /// Captures an instant frame at [positionSeconds] and adds it to the session.
  Future<ScreenshotItem?> capturePlayheadFrame(double positionSeconds) async {
    final video = state.video;
    if (video == null) return null;

    state = state.copyWith(isCapturing: true, errorMessage: null);

    try {
      final processor = ref.read(videoProcessorProvider);
      final clampedPos = positionSeconds.clamp(
        0.0,
        state.config.videoDurationSeconds,
      );

      final tempPath = await processor.captureSingleFrame(
        inputPath: video.path,
        timestampSeconds: clampedPos,
        format: state.config.format,
        jpegQuality: state.config.jpegQuality,
      );

      final totalMs = (clampedPos * 1000).round();
      final ext = state.config.format.extension;
      final m = totalMs ~/ 60000;
      final s = (totalMs % 60000) ~/ 1000;
      final ms = totalMs % 1000;
      final timeStr =
          '${m.toString().padLeft(2, '0')}m${s.toString().padLeft(2, '0')}s${ms.toString().padLeft(3, '0')}ms';
      final fileName =
          '${state.config.effectiveBaseName}_frame_${state.capturedSessionFrames.length + 1}_$timeStr$ext';

      int? fileSize;
      try {
        final f = File(tempPath);
        if (f.existsSync()) {
          fileSize = f.lengthSync();
        }
      } catch (_) {}

      final item = ScreenshotItem(
        id: 'session_${DateTime.now().microsecondsSinceEpoch}_${state.capturedSessionFrames.length}',
        timestampSeconds: clampedPos,
        outputFileName: fileName,
        tempFilePath: tempPath,
        width: state.config.videoWidth,
        height: state.config.videoHeight,
        fileSizeBytes: fileSize,
      );

      final updatedSession = [item, ...state.capturedSessionFrames];
      state = state.copyWith(
        isCapturing: false,
        capturedSessionFrames: updatedSession,
        activePreviewItem: item,
      );

      return item;
    } catch (e) {
      AppLogger.error('Failed to capture playhead frame: $e');
      state = state.copyWith(
        isCapturing: false,
        errorMessage: 'Capture failed: $e',
      );
      return null;
    }
  }

  /// Saves a specific captured item to the user's destination gallery storage.
  Future<String?> saveItemToGallery(ScreenshotItem item) async {
    if (item.tempFilePath == null) return null;
    final file = File(item.tempFilePath!);
    if (!file.existsSync()) return null;

    state = state.copyWith(isSaving: true);

    try {
      final writer = await ClipWriterFactory.resolveWriter();
      final destinationUri = await writer.writeClip(
        sourceTempFile: file,
        fileName: item.outputFileName,
        duplicateHandling: DuplicateHandling.overwrite,
      );

      final updatedFrames = state.capturedSessionFrames.map((f) {
        if (f.id == item.id) {
          return f.copyWith(savedPath: destinationUri);
        }
        return f;
      }).toList();

      final updatedPreview = state.activePreviewItem?.id == item.id
          ? state.activePreviewItem!.copyWith(savedPath: destinationUri)
          : state.activePreviewItem;

      state = state.copyWith(
        isSaving: false,
        capturedSessionFrames: updatedFrames,
        activePreviewItem: updatedPreview,
      );

      return destinationUri;
    } catch (e) {
      AppLogger.error('Failed to save screenshot to gallery: $e');
      state = state.copyWith(isSaving: false, errorMessage: 'Save failed: $e');
      return null;
    }
  }

  /// Saves all selected frames (or all session frames if none explicitly selected) to gallery.
  Future<int> saveSelectedToGallery() async {
    final targets = state.selectedFrameIds.isEmpty
        ? state.capturedSessionFrames.where((f) => !f.isSaved).toList()
        : state.capturedSessionFrames
              .where((f) => state.selectedFrameIds.contains(f.id) && !f.isSaved)
              .toList();

    if (targets.isEmpty) return 0;

    state = state.copyWith(isSaving: true);
    int savedCount = 0;

    try {
      final writer = await ClipWriterFactory.resolveWriter();

      final updatedFrames = List<ScreenshotItem>.from(
        state.capturedSessionFrames,
      );

      for (final target in targets) {
        if (target.tempFilePath == null) continue;
        final file = File(target.tempFilePath!);
        if (!file.existsSync()) continue;

        try {
          final uri = await writer.writeClip(
            sourceTempFile: file,
            fileName: target.outputFileName,
            duplicateHandling: DuplicateHandling.overwrite,
          );

          final idx = updatedFrames.indexWhere((f) => f.id == target.id);
          if (idx != -1) {
            updatedFrames[idx] = updatedFrames[idx].copyWith(savedPath: uri);
            savedCount++;
          }
        } catch (_) {}
      }

      state = state.copyWith(
        isSaving: false,
        capturedSessionFrames: updatedFrames,
      );
      return savedCount;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Batch save failed: $e',
      );
      return savedCount;
    }
  }

  void toggleSelection(String id) {
    final current = Set<String>.from(state.selectedFrameIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedFrameIds: current);
  }

  void selectAll() {
    final allIds = state.capturedSessionFrames.map((f) => f.id).toSet();
    state = state.copyWith(selectedFrameIds: allIds);
  }

  void clearSelection() {
    state = state.copyWith(selectedFrameIds: const {});
  }

  void deleteItem(String id) {
    final item = state.capturedSessionFrames.firstWhere(
      (f) => f.id == id,
      orElse: () =>
          const ScreenshotItem(id: '', timestampSeconds: 0, outputFileName: ''),
    );

    if (item.tempFilePath != null) {
      try {
        final f = File(item.tempFilePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    final updated = state.capturedSessionFrames
        .where((f) => f.id != id)
        .toList();
    final updatedSelection = Set<String>.from(state.selectedFrameIds)
      ..remove(id);

    state = state.copyWith(
      capturedSessionFrames: updated,
      selectedFrameIds: updatedSelection,
      clearActivePreview: state.activePreviewItem?.id == id,
    );
  }

  void deleteSelected() {
    final idsToDelete = state.selectedFrameIds.isNotEmpty
        ? state.selectedFrameIds
        : state.capturedSessionFrames.map((f) => f.id).toSet();

    for (final frame in state.capturedSessionFrames) {
      if (idsToDelete.contains(frame.id) && frame.tempFilePath != null) {
        try {
          final f = File(frame.tempFilePath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }

    final updated = state.capturedSessionFrames
        .where((f) => !idsToDelete.contains(f.id))
        .toList();

    state = state.copyWith(
      capturedSessionFrames: updated,
      selectedFrameIds: const {},
      clearActivePreview: true,
    );
  }

  void setActivePreview(ScreenshotItem? item) {
    state = state.copyWith(
      activePreviewItem: item,
      clearActivePreview: item == null,
    );
  }

  /// Dispatches the planned batch capture into the unified [JobQueueController].
  Future<JobRecord> dispatchBatchCapture() async {
    final config = state.config;
    final totalPlanned = config.calculatePlannedTimestamps().length;
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';

    final job = JobRecord(
      id: jobId,
      type: JobType.screenshot,
      title: 'Extract $totalPlanned Frames (${config.format.displayName})',
      inputPath: config.videoPath,
      outputDirectory: '',
      totalParts: totalPlanned,
      createdAt: DateTime.now(),
      payload: {'config': config.toJson(), 'totalFrames': totalPlanned},
    );

    await ref.read(jobQueueControllerProvider.notifier).enqueueJob(job);
    return job;
  }
}
