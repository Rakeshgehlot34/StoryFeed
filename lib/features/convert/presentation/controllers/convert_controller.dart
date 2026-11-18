import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../jobs/domain/job_queue_controller.dart';
import '../../../jobs/domain/models/job_record.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../processing/domain/export_job_controller.dart';
import '../../../processing/domain/models/video_metadata.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../domain/models/convert_config.dart';

/// State representation for Format Conversion and Compression.
class ConvertState {
  final PickedVideo? video;
  final VideoMetadata? metadata;
  final ConvertConfig config;
  final bool isLoading;
  final int estimatedSizeBytes;
  final String? errorMessage;

  const ConvertState({
    this.video,
    this.metadata,
    this.config = const ConvertConfig(),
    this.isLoading = false,
    this.estimatedSizeBytes = 0,
    this.errorMessage,
  });

  ConvertState copyWith({
    PickedVideo? video,
    bool clearVideo = false,
    VideoMetadata? metadata,
    bool clearMetadata = false,
    ConvertConfig? config,
    bool? isLoading,
    int? estimatedSizeBytes,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ConvertState(
      video: clearVideo ? null : (video ?? this.video),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      estimatedSizeBytes: estimatedSizeBytes ?? this.estimatedSizeBytes,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

final convertControllerProvider =
    NotifierProvider<ConvertController, ConvertState>(ConvertController.new);

class ConvertController extends Notifier<ConvertState> {
  @override
  ConvertState build() {
    return const ConvertState();
  }

  /// Loads a picked video, probes its metadata, and calculates initial size estimates.
  Future<void> setVideo(PickedVideo video) async {
    state = state.copyWith(
      video: video,
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final processor = ref.read(videoProcessorProvider);
      final meta = await processor.getMetadata(video.path);

      final estSize = state.config.estimateOutputSizeBytes(
        durationSeconds: meta.duration.inMilliseconds / 1000.0,
        sourceSizeBytes: meta.sizeInBytes,
        sourceWidth: meta.width,
        sourceHeight: meta.height,
      );

      state = state.copyWith(
        metadata: meta,
        isLoading: false,
        estimatedSizeBytes: estSize,
      );
    } catch (e) {
      AppLogger.warning(
        'Failed to probe video metadata in ConvertController: $e',
      );
      final fallbackMeta = VideoMetadata(
        duration: video.duration,
        sizeInBytes: video.sizeInBytes,
        width: 1920,
        height: 1080,
        fps: 30.0,
        bitrate: 4000000,
        format: 'mp4',
      );

      final estSize = state.config.estimateOutputSizeBytes(
        durationSeconds: video.duration.inMilliseconds / 1000.0,
        sourceSizeBytes: video.sizeInBytes,
        sourceWidth: 1920,
        sourceHeight: 1080,
      );

      state = state.copyWith(
        metadata: fallbackMeta,
        isLoading: false,
        estimatedSizeBytes: estSize,
      );
    }
  }

  /// Updates the conversion configuration and recalculates estimated output size.
  void updateConfig(ConvertConfig newConfig) {
    int estSize = 0;
    if (state.metadata != null) {
      estSize = newConfig.estimateOutputSizeBytes(
        durationSeconds: state.metadata!.duration.inMilliseconds / 1000.0,
        sourceSizeBytes: state.metadata!.sizeInBytes,
        sourceWidth: state.metadata!.width,
        sourceHeight: state.metadata!.height,
      );
    }

    state = state.copyWith(config: newConfig, estimatedSizeBytes: estSize);
  }

  void setFormat(ConvertOutputFormat format) {
    updateConfig(state.config.copyWith(format: format));
  }

  void setResolution(ResolutionPreset resolution) {
    updateConfig(state.config.copyWith(resolution: resolution));
  }

  void setFps(FpsPreset fps) {
    updateConfig(state.config.copyWith(fps: fps));
  }

  void setQuality(QualityPreset quality) {
    updateConfig(
      state.config.copyWith(quality: quality, clearTargetSize: true),
    );
  }

  void setTargetSizeMb(double? targetMb) {
    if (targetMb == null || targetMb <= 0) {
      updateConfig(state.config.copyWith(clearTargetSize: true));
    } else {
      updateConfig(state.config.copyWith(targetSizeMb: targetMb));
    }
  }

  void setMuteAudio(bool mute) {
    updateConfig(state.config.copyWith(muteAudio: mute));
  }

  void setAudioFormat(AudioOutputFormat audioFormat) {
    updateConfig(state.config.copyWith(audioFormat: audioFormat));
  }

  void setAudioBitrateKbps(int kbps) {
    updateConfig(state.config.copyWith(audioBitrateKbps: kbps));
  }

  void setGifConfig(GifConfig gifConfig) {
    updateConfig(state.config.copyWith(gifConfig: gifConfig));
  }

  void setCustomFileName(String? name) {
    updateConfig(state.config.copyWith(customFileName: name));
  }

  /// Enqueues the conversion job into the sequential JobQueueController.
  Future<String> enqueueConversion() async {
    final video = state.video;
    if (video == null) {
      throw const VideoProcessingException(
        'No source video selected for conversion.',
      );
    }

    final durationSec = state.metadata != null
        ? state.metadata!.duration.inMilliseconds / 1000.0
        : video.duration.inMilliseconds / 1000.0;

    final outputDir = await ref.read(outputDirectoryProvider.future);
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';

    final baseName = state.config.customFileName?.trim().isNotEmpty == true
        ? state.config.customFileName!.trim()
        : p.basenameWithoutExtension(video.path);

    final job = JobRecord(
      id: jobId,
      type: JobType.convert,
      title: 'Convert: $baseName -> ${state.config.format.shortName}',
      inputPath: video.path,
      outputDirectory: outputDir,
      totalParts: 1,
      createdAt: DateTime.now(),
      payload: {
        'config': state.config.toJson(),
        'durationSeconds': durationSec,
      },
    );

    await ref.read(jobQueueControllerProvider.notifier).enqueueJob(job);
    return jobId;
  }

  void reset() {
    state = const ConvertState();
  }
}
