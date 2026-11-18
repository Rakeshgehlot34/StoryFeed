import '../../audio_studio/domain/models/audio_studio_project.dart';
import '../../convert/domain/models/convert_config.dart';
import '../../custom_split/domain/models/custom_clip_plan.dart';
import '../../editor/domain/models/edit_project.dart';
import '../../merge/domain/models/merge_project.dart';
import '../../output/domain/clip_writer.dart';
import '../../output/domain/models/storage_strategy.dart';
import '../../screenshot/domain/models/screenshot_config.dart';
import '../../split_config/domain/models/clip_plan.dart';
import '../../split_config/domain/models/clip_segment.dart';
import '../../split_config/domain/models/split_config.dart';
import 'models/processing_progress.dart';
import 'models/video_metadata.dart';

/// Abstract video processing engine interface.
/// Encapsulates all FFmpeg/transcoding operations behind swappable contracts.
abstract class VideoProcessor {
  /// Extracts technical metadata (duration, width, height, bitrate) from a video file.
  Future<VideoMetadata> getMetadata(String videoPath);

  /// Splits an input video file into a list of contiguous [ClipSegment]s,
  /// streaming progress updates for both individual clips and overall batch.
  Stream<ProcessingProgress> splitVideo({
    required String inputPath,
    required List<ClipSegment> segments,
    required String outputDirectoryPath,
    required SplitMode mode,
    required AspectRatioOption aspectRatio,
    required String baseName,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
    ClipPlan? plan,
  });

  /// Splits an input video file into custom contiguous slices without duration caps,
  /// supporting fast stream-copy or precise re-encoding.
  Stream<ProcessingProgress> splitCustom({
    required String inputPath,
    required CustomClipPlan plan,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  });

  /// Exports an [EditProject] through a single-pass FFmpeg filter graph pipeline,
  /// streaming progress updates.
  Stream<ProcessingProgress> exportEditProject({
    required String inputPath,
    required EditProject project,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  });

  /// Generates a fast 5-second preview of an [EditProject] for instant playback.
  Future<String> generateEditPreview({
    required String inputPath,
    required EditProject project,
    double previewDurationSeconds = 5.0,
  });

  /// Converts a video to a target format, resolution, fps, or size constraint,
  /// streaming progress updates.
  Stream<ProcessingProgress> convertVideo({
    required String inputPath,
    required ConvertConfig config,
    required double durationSeconds,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  });

  /// Processes and mixes multi-track audio inside an [AudioStudioConfig],
  /// streaming progress updates.
  Stream<ProcessingProgress> processAudioStudio({
    required AudioStudioConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  });

  /// Extracts a single frame at [timestampSeconds] to a temporary or specified output file.
  Future<String> captureSingleFrame({
    required String inputPath,
    required double timestampSeconds,
    required ScreenshotImageFormat format,
    int jpegQuality = 90,
    String? outputFilePath,
  });

  /// Extracts multiple frames according to [config] in batch, streaming progress.
  Stream<ProcessingProgress> captureScreenshots({
    required ScreenshotConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  });

  /// Merges multiple videos according to [config], streaming progress updates.
  Stream<ProcessingProgress> mergeVideos({
    required MergeConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  });

  /// Aborts an active split/encode job and cleans up partial files.
  Future<void> cancel();

  /// Releases resources held by the processor engine.
  Future<void> dispose();
}
