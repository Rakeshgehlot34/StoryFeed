import 'dart:async';

import 'package:shorts_splitter/features/audio_studio/domain/models/audio_studio_project.dart';
import 'package:shorts_splitter/features/convert/domain/models/convert_config.dart';
import 'package:shorts_splitter/features/custom_split/domain/models/custom_clip_plan.dart';
import 'package:shorts_splitter/features/editor/domain/models/edit_project.dart';
import 'package:shorts_splitter/features/merge/domain/models/merge_project.dart';
import 'package:shorts_splitter/features/output/domain/clip_writer.dart';
import 'package:shorts_splitter/features/output/domain/models/storage_strategy.dart';
import 'package:shorts_splitter/features/processing/domain/models/part_progress_state.dart';
import 'package:shorts_splitter/features/processing/domain/models/processing_progress.dart';
import 'package:shorts_splitter/features/processing/domain/models/video_metadata.dart';
import 'package:shorts_splitter/features/processing/domain/video_processor.dart';
import 'package:shorts_splitter/features/screenshot/domain/models/screenshot_config.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_plan.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';
import 'package:shorts_splitter/features/split_config/domain/models/split_config.dart';

class FakeVideoProcessor implements VideoProcessor {
  bool isCancelled = false;
  bool isDisposed = false;
  Duration simulatedDuration = const Duration(seconds: 120);

  @override
  Future<VideoMetadata> getMetadata(String videoPath) async {
    return VideoMetadata(
      duration: simulatedDuration,
      sizeInBytes: 1024 * 1024 * 50,
      width: 1920,
      height: 1080,
      fps: 30.0,
      bitrate: 4000000,
      format: 'mp4',
    );
  }

  @override
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
  }) {
    final controller = StreamController<ProcessingProgress>();

    Timer.run(() async {
      final total = segments.length;
      final outputPaths = <String>[];

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.preparing,
          currentClipIndex: 0,
          totalClips: total,
          currentClipName: 'Preparing fake transcode...',
        ),
      );

      for (int i = 0; i < total; i++) {
        if (isCancelled) {
          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.cancelled,
              currentClipIndex: i + 1,
              totalClips: total,
            ),
          );
          await controller.close();
          return;
        }

        final seg = segments[i];
        final fakePath = '$outputDirectoryPath/${seg.formattedName}';
        outputPaths.add(fakePath);

        final partMap = <int, PartProgressState>{};
        for (int k = 0; k < total; k++) {
          final pIndex = segments[k].index;
          partMap[pIndex] = PartProgressState(
            partIndex: pIndex,
            progress: k <= i ? 1.0 : 0.0,
            stageLabel: k <= i ? 'Completed' : 'Queued',
          );
        }

        controller.add(
          ProcessingProgress(
            status: ProcessingStatus.processing,
            currentClipIndex: i + 1,
            totalClips: total,
            currentClipName: seg.formattedName,
            currentClipProgress: 1.0,
            overallProgress: (i + 1) / total,
            outputPaths: List.unmodifiable(outputPaths),
            partProgressMap: partMap,
          ),
        );
      }

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.completed,
          currentClipIndex: total,
          totalClips: total,
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          currentClipName: 'All clips generated',
          outputPaths: List.unmodifiable(outputPaths),
        ),
      );
      await controller.close();
    });

    return controller.stream;
  }

  @override
  Stream<ProcessingProgress> splitCustom({
    required String inputPath,
    required CustomClipPlan plan,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    final controller = StreamController<ProcessingProgress>();

    Timer.run(() async {
      final total = plan.items.length;
      final outputPaths = <String>[];

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.preparing,
          currentClipIndex: 0,
          totalClips: total,
          currentClipName: 'Preparing fake custom split...',
        ),
      );

      for (int i = 0; i < total; i++) {
        if (isCancelled) {
          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.cancelled,
              currentClipIndex: i + 1,
              totalClips: total,
              currentClipName: 'Cancelled',
              outputPaths: List.unmodifiable(outputPaths),
            ),
          );
          await controller.close();
          return;
        }

        final item = plan.items[i];
        final fakePath = '$outputDirectoryPath/${item.displayName}';
        outputPaths.add(fakePath);

        controller.add(
          ProcessingProgress(
            status: ProcessingStatus.processing,
            currentClipIndex: i + 1,
            totalClips: total,
            currentClipName: item.displayName,
            currentClipProgress: 1.0,
            overallProgress: (i + 1) / total,
            outputPaths: List.unmodifiable(outputPaths),
          ),
        );
      }

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.completed,
          currentClipIndex: total,
          totalClips: total,
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          currentClipName: 'All custom clips generated',
          outputPaths: List.unmodifiable(outputPaths),
        ),
      );
      await controller.close();
    });

    return controller.stream;
  }

  @override
  Stream<ProcessingProgress> exportEditProject({
    required String inputPath,
    required EditProject project,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    final controller = StreamController<ProcessingProgress>();

    Timer.run(() async {
      final fakePath = '$outputDirectoryPath/${project.title}.mp4';

      controller.add(
        const ProcessingProgress(
          status: ProcessingStatus.preparing,
          currentClipIndex: 0,
          totalClips: 1,
          currentClipName: 'Preparing fake edit export...',
        ),
      );

      if (isCancelled) {
        controller.add(
          const ProcessingProgress(
            status: ProcessingStatus.cancelled,
            currentClipIndex: 1,
            totalClips: 1,
            currentClipName: 'Cancelled',
          ),
        );
        await controller.close();
        return;
      }

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.processing,
          currentClipIndex: 1,
          totalClips: 1,
          currentClipName: project.title,
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          outputPaths: [fakePath],
        ),
      );

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.completed,
          currentClipIndex: 1,
          totalClips: 1,
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          currentClipName: 'Edit export complete',
          outputPaths: [fakePath],
        ),
      );
      await controller.close();
    });

    return controller.stream;
  }

  @override
  Future<String> generateEditPreview({
    required String inputPath,
    required EditProject project,
    double previewDurationSeconds = 5.0,
  }) async {
    return '/fake/cache/preview_${project.id}.mp4';
  }

  @override
  Stream<ProcessingProgress> convertVideo({
    required String inputPath,
    required ConvertConfig config,
    required double durationSeconds,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    final controller = StreamController<ProcessingProgress>();

    Timer.run(() async {
      final ext = config.effectiveExtension;
      final fakePath = '$outputDirectoryPath/converted_fake$ext';

      controller.add(
        const ProcessingProgress(
          status: ProcessingStatus.preparing,
          currentClipIndex: 0,
          totalClips: 1,
          currentClipName: 'Configuring conversion...',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      if (isCancelled) {
        controller.add(
          const ProcessingProgress(
            status: ProcessingStatus.cancelled,
            currentClipIndex: 1,
            totalClips: 1,
            currentClipName: 'Cancelled',
          ),
        );
        await controller.close();
        return;
      }

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.processing,
          currentClipIndex: 1,
          totalClips: 1,
          currentClipName: 'Converting to ${config.format.displayName}',
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          outputPaths: [fakePath],
        ),
      );

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.completed,
          currentClipIndex: 1,
          totalClips: 1,
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          currentClipName: 'Conversion complete',
          outputPaths: [fakePath],
        ),
      );
      await controller.close();
    });

    return controller.stream;
  }

  @override
  Stream<ProcessingProgress> processAudioStudio({
    required AudioStudioConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    final controller = StreamController<ProcessingProgress>();

    Timer.run(() async {
      final ext = config.effectiveExtension;
      final fakePath = '$outputDirectoryPath/audio_studio_fake$ext';

      controller.add(
        const ProcessingProgress(
          status: ProcessingStatus.preparing,
          currentClipIndex: 0,
          totalClips: 1,
          currentClipName: 'Configuring audio mix...',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      if (isCancelled) {
        controller.add(
          const ProcessingProgress(
            status: ProcessingStatus.cancelled,
            currentClipIndex: 1,
            totalClips: 1,
            currentClipName: 'Cancelled',
          ),
        );
        await controller.close();
        return;
      }

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.processing,
          currentClipIndex: 1,
          totalClips: 1,
          currentClipName: 'Mixing audio studio tracks...',
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          outputPaths: [fakePath],
        ),
      );

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.completed,
          currentClipIndex: 1,
          totalClips: 1,
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          currentClipName: 'Audio Studio export complete',
          outputPaths: [fakePath],
        ),
      );
      await controller.close();
    });

    return controller.stream;
  }

  @override
  Future<String> captureSingleFrame({
    required String inputPath,
    required double timestampSeconds,
    required ScreenshotImageFormat format,
    int jpegQuality = 90,
    String? outputFilePath,
  }) async {
    final fakePath = outputFilePath ??
        '/fake_storage/fake_screenshot_${timestampSeconds.toStringAsFixed(1)}${format.extension}';
    return fakePath;
  }

  @override
  Stream<ProcessingProgress> captureScreenshots({
    required ScreenshotConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    final controller = StreamController<ProcessingProgress>();
    final items = config.calculatePlannedItems();
    final total = items.length;

    scheduleMicrotask(() async {
      final outputPaths = <String>[];

      for (int i = 0; i < total; i++) {
        if (isCancelled) {
          controller.add(
            const ProcessingProgress(
              status: ProcessingStatus.cancelled,
              currentClipIndex: 0,
              totalClips: 0,
              currentClipName: 'Cancelled',
            ),
          );
          await controller.close();
          return;
        }

        final item = items[i];
        final fakePath = '$outputDirectoryPath/${item.outputFileName}';
        outputPaths.add(fakePath);

        controller.add(
          ProcessingProgress(
            status: ProcessingStatus.processing,
            currentClipIndex: i + 1,
            totalClips: total,
            currentClipName: item.outputFileName,
            currentClipProgress: 1.0,
            overallProgress: (i + 1) / total,
            outputPaths: List.unmodifiable(outputPaths),
          ),
        );
      }

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.completed,
          currentClipIndex: total,
          totalClips: total,
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          currentClipName: 'Screenshot extraction complete',
          outputPaths: List.unmodifiable(outputPaths),
        ),
      );
      await controller.close();
    });

    return controller.stream;
  }

  @override
  Stream<ProcessingProgress> mergeVideos({
    required MergeConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    final controller = StreamController<ProcessingProgress>();
    final fakePath = '$outputDirectoryPath/${config.effectiveBaseName}.mp4';

    scheduleMicrotask(() async {
      controller.add(
        const ProcessingProgress(
          status: ProcessingStatus.preparing,
          currentClipIndex: 0,
          totalClips: 1,
          currentClipName: 'Preparing video merge...',
        ),
      );

      if (isCancelled) {
        controller.add(
          const ProcessingProgress(
            status: ProcessingStatus.cancelled,
            currentClipIndex: 1,
            totalClips: 1,
            currentClipName: 'Cancelled',
          ),
        );
        await controller.close();
        return;
      }

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.processing,
          currentClipIndex: 1,
          totalClips: 1,
          currentClipName: config.effectiveBaseName,
          currentClipProgress: 0.5,
          overallProgress: 0.5,
          outputPaths: [fakePath],
        ),
      );

      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.completed,
          currentClipIndex: 1,
          totalClips: 1,
          currentClipProgress: 1.0,
          overallProgress: 1.0,
          currentClipName: 'Merge complete',
          outputPaths: [fakePath],
        ),
      );
      await controller.close();
    });

    return controller.stream;
  }

  @override
  Future<void> cancel() async {
    isCancelled = true;
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}
