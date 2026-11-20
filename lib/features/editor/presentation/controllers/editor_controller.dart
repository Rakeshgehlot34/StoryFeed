import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../jobs/domain/job_queue_controller.dart';
import '../../../jobs/domain/models/job_record.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../processing/domain/export_job_controller.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../domain/models/edit_project.dart';

class EditorState {
  final PickedVideo? video;
  final EditProject? project;
  final String? previewPath;
  final bool isPreviewLoading;
  final int
      activeToolIndex; // 0: Trim, 1: Canvas, 2: Speed, 3: Color, 4: Overlay, 5: Effects
  final String? errorMessage;

  const EditorState({
    this.video,
    this.project,
    this.previewPath,
    this.isPreviewLoading = false,
    this.activeToolIndex = 0,
    this.errorMessage,
  });

  EditorState copyWith({
    PickedVideo? video,
    bool clearVideo = false,
    EditProject? project,
    bool clearProject = false,
    String? previewPath,
    bool clearPreviewPath = false,
    bool? isPreviewLoading,
    int? activeToolIndex,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return EditorState(
      video: clearVideo ? null : (video ?? this.video),
      project: clearProject ? null : (project ?? this.project),
      previewPath: clearPreviewPath ? null : (previewPath ?? this.previewPath),
      isPreviewLoading: isPreviewLoading ?? this.isPreviewLoading,
      activeToolIndex: activeToolIndex ?? this.activeToolIndex,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);

class EditorController extends Notifier<EditorState> {
  @override
  EditorState build() {
    return const EditorState();
  }

  void loadVideo(PickedVideo video) {
    final durationSec = video.duration.inMilliseconds / 1000.0;
    final project = EditProject(
      id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
      title: '${video.baseName}_edited',
      sourceVideoPath: video.path,
      sourceVideoName: video.fileName,
      sourceDurationSeconds: durationSec,
      sourceWidth: video.width,
      sourceHeight: video.height,
      trim: TrimConfig(startSeconds: 0.0, endSeconds: durationSec),
    );

    state = state.copyWith(
      video: video,
      project: project,
      clearPreviewPath: true,
      clearErrorMessage: true,
    );
  }

  void setActiveTool(int index) {
    state = state.copyWith(activeToolIndex: index);
  }

  void setTrim(double start, double end) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      trim: curr.trim.copyWith(startSeconds: start, endSeconds: end),
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setRotation(int degrees) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      transform: curr.transform.copyWith(rotationDegrees: degrees % 360),
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void toggleHFlip() {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      transform: curr.transform.copyWith(hflip: !curr.transform.hflip),
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void toggleVFlip() {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      transform: curr.transform.copyWith(vflip: !curr.transform.vflip),
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setCanvas({
    TargetAspectRatio? aspectRatio,
    CanvasFitMode? fitMode,
    int? backgroundColorHex,
  }) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      canvas: curr.canvas.copyWith(
        aspectRatio: aspectRatio,
        fitMode: fitMode,
        backgroundColorHex: backgroundColorHex,
      ),
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setSpeed(double speed, bool preservePitch) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      speed: curr.speed.copyWith(speed: speed, preservePitch: preservePitch),
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setColorFilter({
    double? brightness,
    double? contrast,
    double? saturation,
    ColorFilterPreset? preset,
  }) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      color: curr.color.copyWith(
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
        preset: preset,
      ),
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setWatermark(WatermarkSpec? watermark) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      watermark: watermark,
      clearWatermark: watermark == null,
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setTextOverlay(TextOverlaySpec? textOverlay) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      textOverlay: textOverlay,
      clearTextOverlay: textOverlay == null,
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setFade({double? fadeIn, double? fadeOut, bool? fadeAudio}) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(
      fade: curr.fade.copyWith(
        fadeInSeconds: fadeIn,
        fadeOutSeconds: fadeOut,
        fadeAudio: fadeAudio,
      ),
    );
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setReverse(bool reverse) {
    final curr = state.project;
    if (curr == null) return;

    if (reverse && !curr.isReverseAllowed) {
      state = state.copyWith(
        errorMessage:
            'Reverse playback requires clip duration <= 15s. Trim the video first.',
      );
      return;
    }

    final updated = curr.copyWith(reverse: reverse);
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  void setTitle(String title) {
    final curr = state.project;
    if (curr == null) return;
    final updated = curr.copyWith(title: title);
    state = state.copyWith(project: updated, clearErrorMessage: true);
  }

  /// Generates a fast 5-second preview of the edited video.
  Future<String?> generatePreview() async {
    final project = state.project;
    if (project == null) return null;

    state = state.copyWith(isPreviewLoading: true, clearErrorMessage: true);
    try {
      final processor = ref.read(videoProcessorProvider);
      final previewPath = await processor.generateEditPreview(
        inputPath: project.sourceVideoPath,
        project: project,
        previewDurationSeconds: 5.0,
      );

      state = state.copyWith(previewPath: previewPath, isPreviewLoading: false);
      return previewPath;
    } catch (e) {
      AppLogger.warning('Quick preview generation failed: $e');
      state = state.copyWith(
        isPreviewLoading: false,
        errorMessage: e is AppException ? e.message : e.toString(),
      );
      return null;
    }
  }

  /// Enqueues the 1-pass edit export job into the sequential JobQueueController.
  Future<String> enqueueExport() async {
    final project = state.project;
    if (project == null) {
      throw const VideoProcessingException('No active edit project to export.');
    }

    project.validate();
    final outputDir = await ref.read(outputDirectoryProvider.future);

    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    final job = JobRecord(
      id: jobId,
      type: JobType.editExport,
      title: 'Studio Edit: ${project.title}',
      inputPath: project.sourceVideoPath,
      outputDirectory: outputDir,
      totalParts: 1,
      createdAt: DateTime.now(),
      payload: {'project': project.toJson()},
    );

    await ref.read(jobQueueControllerProvider.notifier).enqueueJob(job);
    return jobId;
  }

  void reset() {
    state = const EditorState();
  }
}
