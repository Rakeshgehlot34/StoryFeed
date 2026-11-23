import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../app/constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/performance/perf_trace.dart';
import '../../../../core/utils/storage_bridge.dart';
import '../../audio_studio/domain/audio_studio_compiler.dart';
import '../../audio_studio/domain/models/audio_studio_project.dart';
import '../../convert/domain/convert_filter_compiler.dart';
import '../../convert/domain/models/convert_config.dart';
import '../../custom_split/domain/models/custom_clip_plan.dart';
import '../../custom_split/domain/models/custom_split_config.dart';
import '../../editor/domain/editor_filter_compiler.dart';
import '../../editor/domain/models/edit_project.dart';
import '../../merge/domain/merge_filter_compiler.dart';
import '../../merge/domain/models/merge_project.dart';
import '../../output/data/clip_writer_factory.dart';
import '../../output/domain/clip_writer.dart';
import '../../output/domain/models/storage_strategy.dart';
import '../../screenshot/domain/models/screenshot_config.dart';
import '../../screenshot/domain/screenshot_compiler.dart';
import '../../split_config/domain/models/canvas_spec.dart';
import '../../split_config/domain/models/clip_plan.dart';
import '../../split_config/domain/models/clip_segment.dart';
import '../../split_config/domain/models/overlay_spec.dart' as split_overlay;
import '../../split_config/domain/models/split_config.dart';
import '../domain/filter_graph_builder.dart';
import '../domain/models/processing_progress.dart';
import '../domain/models/video_metadata.dart';
import '../domain/video_processor.dart';
import 'overlay_renderer.dart';

/// Production FFmpeg implementation wrapping ffmpeg_kit_flutter_new.
class FFmpegVideoProcessor implements VideoProcessor {
  bool _isCancelled = false;
  int? _activeSessionId;
  final Set<String> _trackedTempFiles = <String>{};

  // Caching to eliminate duplicate streaming of 1GB+ files and repeated probing
  static final Map<String, VideoMetadata> _metadataCache = {};
  static final Map<String, String> _resolvedUriCache = {};

  @override
  Future<VideoMetadata> getMetadata(String videoPath) async {
    // Return cached metadata if file is still accessible
    if (_metadataCache.containsKey(videoPath)) {
      if (videoPath.startsWith('content://') || File(videoPath).existsSync()) {
        return _metadataCache[videoPath]!;
      }
    }

    String resolvedPath = videoPath;
    String? tempStreamedFile;

    try {
      if (videoPath.startsWith('content://')) {
        if (_resolvedUriCache.containsKey(videoPath)) {
          final cachedTemp = _resolvedUriCache[videoPath]!;
          if (File(cachedTemp).existsSync() &&
              File(cachedTemp).lengthSync() > 0) {
            resolvedPath = cachedTemp;
          }
        }
        if (resolvedPath == videoPath) {
          final tempDir = await getTemporaryDirectory();
          tempStreamedFile = p.join(
            tempDir.path,
            'probe_stream_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          resolvedPath = await StorageBridge.copyContentUriToTempFile(
            contentUri: videoPath,
            tempDestPath: tempStreamedFile,
          );
          _resolvedUriCache[videoPath] = resolvedPath;
        }
      }

      final file = File(resolvedPath);
      if (!await file.exists()) {
        throw StorageAccessException(
          'Video file does not exist',
          path: resolvedPath,
        );
      }

      final fileSize = await file.length();
      AppLogger.info('Extracting metadata with FFprobe for: $resolvedPath');

      final session = await FFprobeKit.getMediaInformation(resolvedPath);
      final mediaInfo = session.getMediaInformation();

      if (mediaInfo == null) {
        final logs = await session.getAllLogsAsString();
        throw UnsupportedVideoFormatException(
          'Could not read media information from video file.',
          logs,
        );
      }

      final rawDuration = mediaInfo.getDuration();
      double durationSeconds = double.tryParse(rawDuration ?? '0') ?? 0.0;

      int width = 0;
      int height = 0;
      double fps = 30.0;
      final int bitrate = int.tryParse(mediaInfo.getBitrate() ?? '0') ?? 0;
      bool hasAudio = false;
      int rotation = 0;
      double sar = 1.0;

      final streams = mediaInfo.getStreams();
      for (final stream in streams) {
        if (stream.getType() == 'audio') {
          hasAudio = true;
        }
        if (stream.getType() == 'video' && width == 0) {
          width = stream.getWidth() ?? 0;
          height = stream.getHeight() ?? 0;

          final streamDurStr = stream.getStringProperty('duration');
          if (streamDurStr != null) {
            final sDur = double.tryParse(streamDurStr) ?? 0.0;
            if (sDur > 0.0 &&
                (durationSeconds <= 0.0 || sDur < durationSeconds)) {
              durationSeconds = sDur;
            }
          }

          final rFrameRate = stream.getRealFrameRate();
          if (rFrameRate != null && rFrameRate.contains('/')) {
            final parts = rFrameRate.split('/');
            final num = double.tryParse(parts[0]) ?? 30.0;
            final den = double.tryParse(parts[1]) ?? 1.0;
            if (den > 0) fps = num / den;
          } else if (rFrameRate != null) {
            fps = double.tryParse(rFrameRate) ?? 30.0;
          }

          final allProps = stream.getAllProperties();
          if (allProps != null) {
            final tags = allProps['tags'];
            if (tags is Map) {
              final rotateStr = tags['rotate']?.toString();
              if (rotateStr != null) {
                rotation = int.tryParse(rotateStr) ?? 0;
              }
            }
            final sideDataList = allProps['side_data_list'];
            if (sideDataList is List) {
              for (final sd in sideDataList) {
                if (sd is Map && sd['rotation'] != null) {
                  rotation =
                      int.tryParse(sd['rotation'].toString()) ?? rotation;
                }
              }
            }
            final sarStr = stream.getSampleAspectRatio() ??
                allProps['sample_aspect_ratio']?.toString();
            if (sarStr != null && sarStr.contains(':')) {
              final parts = sarStr.split(':');
              final num = double.tryParse(parts[0]) ?? 1.0;
              final den = double.tryParse(parts[1]) ?? 1.0;
              if (den > 0) sar = num / den;
            }
          }
        }
      }

      final duration = Duration(milliseconds: (durationSeconds * 1000).round());
      final metadata = VideoMetadata(
        duration: duration,
        sizeInBytes: fileSize,
        width: width,
        height: height,
        fps: fps,
        bitrate: bitrate,
        format: mediaInfo.getFormat() ?? 'mp4',
        hasAudio: hasAudio,
        rotation: rotation,
        sar: sar,
      );
      _metadataCache[videoPath] = metadata;
      return metadata;
    } finally {
      if (tempStreamedFile != null &&
          !_resolvedUriCache.containsValue(tempStreamedFile)) {
        _safeDelete(tempStreamedFile);
      }
    }
  }

  static bool _areSegmentsContiguous(List<ClipSegment> segs) {
    if (segs.isEmpty) return false;
    for (int i = 0; i < segs.length - 1; i++) {
      if ((segs[i].endSeconds - segs[i + 1].startSeconds).abs() > 0.05) {
        return false;
      }
    }
    return true;
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
    late StreamController<ProcessingProgress> controller;
    _isCancelled = false;

    controller = StreamController<ProcessingProgress>(
      onListen: () async {
        final totalClips = segments.length;
        final outputPaths = <String>[];
        String resolvedInputPath = inputPath;
        String? tempStreamedInput;

        try {
          // Pre-flight check: free space
          final freeBytes = await StorageBridge.getFreeDiskSpace();
          const minRequiredBytes = 250 * 1024 * 1024;
          if (freeBytes < minRequiredBytes) {
            throw const StorageAccessException(
              'Insufficient storage space. At least 250MB free space required.',
              path: 'device_storage',
            );
          }

          // Handle content:// URI streaming with cache reuse
          if (inputPath.startsWith('content://')) {
            if (_resolvedUriCache.containsKey(inputPath)) {
              final cachedPath = _resolvedUriCache[inputPath]!;
              if (File(cachedPath).existsSync() &&
                  File(cachedPath).lengthSync() > 0) {
                resolvedInputPath = cachedPath;
              }
            }
            if (resolvedInputPath == inputPath) {
              final tempDir = await getTemporaryDirectory();
              tempStreamedInput = p.join(
                tempDir.path,
                'source_stream_${DateTime.now().millisecondsSinceEpoch}.mp4',
              );
              _trackedTempFiles.add(tempStreamedInput);
              resolvedInputPath = await StorageBridge.copyContentUriToTempFile(
                contentUri: inputPath,
                tempDestPath: tempStreamedInput,
              );
              _resolvedUriCache[inputPath] = resolvedInputPath;
            }
          }

          final activeWriter = clipWriter ??
              await ClipWriterFactory.resolveWriter(
                preferredSafUri: outputDirectoryPath.startsWith('content://')
                    ? outputDirectoryPath
                    : null,
                subfolderName: baseName,
                customRelativePath: outputDirectoryPath.startsWith('Movies/')
                    ? outputDirectoryPath
                    : 'Movies/StoryFeed/$baseName',
              );

          final tempCacheDir = await getTemporaryDirectory();
          final sourceMeta = await getMetadata(resolvedInputPath);

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.preparing,
              currentClipIndex: 0,
              totalClips: totalClips,
              currentClipName: 'Preparing split...',
            ),
          );

          // High-Performance Single-Pass Stream Copy Optimization
          final canUseSinglePass = mode == SplitMode.fast &&
              aspectRatio == AspectRatioOption.original &&
              totalClips > 1 &&
              segments.first.startSeconds < 0.05 &&
              _areSegmentsContiguous(segments) &&
              segments.every(
                (s) =>
                    (s.durationSeconds - segments.first.durationSeconds).abs() <
                    0.001,
              );

          if (canUseSinglePass) {
            AppLogger.info(
              'Fast mode: executing single-pass segment muxer for $totalClips clips',
            );
            final segTime = segments.first.durationSeconds.toStringAsFixed(3);
            final firstStart = segments.first.startSeconds.toStringAsFixed(3);
            final totalSelectedDuration = segments.fold<double>(
              0.0,
              (sum, s) => sum + s.durationSeconds,
            );
            final segPrefix = 'seg_${DateTime.now().millisecondsSinceEpoch}';
            final segPattern = p.join(
              tempCacheDir.path,
              '${segPrefix}_%03d.mp4',
            );

            final singlePassArgs = [
              '-y',
              '-ss',
              firstStart,
              '-i',
              resolvedInputPath,
              '-t',
              totalSelectedDuration.toStringAsFixed(3),
              '-c',
              'copy',
              '-map',
              '0:v?',
              '-map',
              '0:a?',
              '-f',
              'segment',
              '-segment_time',
              segTime,
              '-reset_timestamps',
              '1',
              segPattern,
            ];

            final singlePassSuccess = await _executeSession(
              singlePassArgs,
              totalSelectedDuration,
              (prog) {
                if (!_isCancelled && !controller.isClosed) {
                  controller.add(
                    ProcessingProgress(
                      status: ProcessingStatus.processing,
                      currentClipIndex: (prog * totalClips).ceil().clamp(
                            1,
                            totalClips,
                          ),
                      totalClips: totalClips,
                      currentClipName: 'Single-pass splitting...',
                      currentClipProgress: prog,
                      overallProgress: prog,
                      outputPaths: List.unmodifiable(outputPaths),
                    ),
                  );
                }
              },
              timeout: const Duration(seconds: 60),
            );

            if (singlePassSuccess) {
              for (int i = 0; i < totalClips; i++) {
                final genPath = p.join(
                  tempCacheDir.path,
                  '${segPrefix}_${i.toString().padLeft(3, '0')}.mp4',
                );
                final genFile = File(genPath);
                if (await genFile.exists() && await genFile.length() > 0) {
                  final segment = segments[i];

                  String effectiveGenPath = genPath;
                  // Strictly enforce Domain Invariant #1 (Hard 180s Cap)
                  try {
                    final probeSession =
                        await FFprobeKit.getMediaInformation(genPath);
                    final mediaInfo = probeSession.getMediaInformation();
                    final dur =
                        double.tryParse(mediaInfo?.getDuration() ?? '') ??
                            segment.durationSeconds;
                    if (dur > AppConstants.maxClipDurationSeconds) {
                      AppLogger.warning(
                        'Single-pass segment ${segment.formattedName} exceeded 180s ($dur s). Clamping to 180.0s.',
                      );
                      final clampedPath = p.join(
                        tempCacheDir.path,
                        'clamped_seg_${i}_${DateTime.now().millisecondsSinceEpoch}.mp4',
                      );
                      _trackedTempFiles.add(clampedPath);
                      final clampSuccess = await _executeSession(
                        [
                          '-y',
                          '-i',
                          genPath,
                          '-t',
                          AppConstants.maxClipDurationSeconds
                              .toStringAsFixed(3),
                          '-c:v',
                          'libx264',
                          '-preset',
                          'ultrafast',
                          '-c:a',
                          'copy',
                          '-movflags',
                          '+faststart',
                          clampedPath,
                        ],
                        AppConstants.maxClipDurationSeconds.toDouble(),
                        (_) {},
                      );
                      if (clampSuccess &&
                          await File(clampedPath).exists() &&
                          await File(clampedPath).length() > 0) {
                        _safeDelete(genPath);
                        effectiveGenPath = clampedPath;
                      }
                    }
                  } catch (e) {
                    AppLogger.warning('Segment duration check error: $e');
                  }

                  final destUri = await activeWriter.writeClip(
                    sourceTempFile: File(effectiveGenPath),
                    fileName: segment.formattedName,
                    duplicateHandling: duplicateHandling,
                  );
                  outputPaths.add(destUri);
                  _safeDelete(effectiveGenPath);
                  controller.add(
                    ProcessingProgress(
                      status: ProcessingStatus.processing,
                      currentClipIndex: i + 1,
                      totalClips: totalClips,
                      currentClipName: segment.formattedName,
                      currentClipProgress: 1.0,
                      overallProgress: (i + 1) / totalClips,
                      outputPaths: List.unmodifiable(outputPaths),
                    ),
                  );
                }
              }

              if (outputPaths.length == totalClips) {
                AppLogger.info(
                  'Single-pass segment muxing completed for all $totalClips clips',
                );
                controller.add(
                  ProcessingProgress(
                    status: ProcessingStatus.completed,
                    currentClipIndex: totalClips,
                    totalClips: totalClips,
                    currentClipProgress: 1.0,
                    overallProgress: 1.0,
                    currentClipName: 'All clips generated successfully',
                    outputPaths: List.unmodifiable(outputPaths),
                  ),
                );
                await controller.close();
                return;
              }
            }
            AppLogger.warning(
              'Single-pass segment muxing incomplete; falling back to per-clip loop',
            );
          }

          for (int i = 0; i < totalClips; i++) {
            if (_isCancelled) {
              _emitCancelled(controller, i + 1, totalClips, outputPaths);
              return;
            }

            final segment = segments[i];

            // Hard 180s cap assertion and runtime check
            if (segment.durationSeconds > AppConstants.maxClipDurationSeconds) {
              throw PlanValidationException(
                'Clip ${segment.formattedName} duration (${segment.durationSeconds.toStringAsFixed(1)}s) exceeds 180 seconds hard cap.',
                durationSeconds: segment.durationSeconds,
              );
            }
            assert(
              segment.durationSeconds <= AppConstants.maxClipDurationSeconds,
              'Clip duration cannot exceed 180s',
            );

            final clipName = segment.formattedName;
            final tempClipPath = p.join(
              tempCacheDir.path,
              'temp_${segment.index}_${DateTime.now().millisecondsSinceEpoch}.mp4',
            );
            _trackedTempFiles.add(tempClipPath);

            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.processing,
                currentClipIndex: i + 1,
                totalClips: totalClips,
                currentClipName: clipName,
                currentClipProgress: 0.0,
                overallProgress: i / totalClips,
                stageLabel: mode == SplitMode.fast
                    ? 'Splitting clip ${i + 1} of $totalClips...'
                    : 'Cropping & converting to 9:16 (${i + 1}/$totalClips)...',
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );

            // Render text overlay to PNG if resolved message exists
            String? tempOverlayPng;
            final planItem = plan?.items.cast<ClipPlanItem?>().firstWhere(
                  (item) => item?.index == segment.index,
                  orElse: () => null,
                );

            if (planItem?.resolvedMessage != null &&
                planItem!.resolvedMessage!.isNotEmpty &&
                plan != null) {
              tempOverlayPng = p.join(
                tempCacheDir.path,
                'overlay_${segment.index}_${DateTime.now().millisecondsSinceEpoch}.png',
              );
              _trackedTempFiles.add(tempOverlayPng);

              await OverlayRenderer.renderToPngFile(
                text: planItem.resolvedMessage!,
                width: plan.canvasSpec.width,
                height: plan.canvasSpec.height,
                overlaySpec: plan.overlaySpec,
                outputPath: tempOverlayPng,
              );
            }

            try {
              await _transcodeClipWithFallback(
                inputPath: resolvedInputPath,
                segment: segment,
                tempOutputPath: tempClipPath,
                mode: mode,
                aspectRatio: aspectRatio,
                plan: plan,
                sourceMeta: sourceMeta,
                overlayPngPath: tempOverlayPng,
                totalDuration: segment.durationSeconds,
                onProgress: (clipProgress) {
                  if (!_isCancelled && !controller.isClosed) {
                    final percent = (clipProgress * 100).toInt();
                    controller.add(
                      ProcessingProgress(
                        status: ProcessingStatus.processing,
                        currentClipIndex: i + 1,
                        totalClips: totalClips,
                        currentClipName: clipName,
                        currentClipProgress: clipProgress,
                        overallProgress: (i + clipProgress) / totalClips,
                        stageLabel: mode == SplitMode.fast
                            ? 'Splitting frames ($percent%)...'
                            : 'Cropping & converting frames ($percent%)...',
                        outputPaths: List.unmodifiable(outputPaths),
                      ),
                    );
                  }
                },
              );
            } catch (e) {
              final errStr = e.toString().toLowerCase();
              if (outputPaths.isNotEmpty &&
                  (errStr.contains('ended prematurely') ||
                      errStr.contains('empty or missing') ||
                      errStr.contains('no valid frames') ||
                      errStr.contains('eof'))) {
                AppLogger.warning(
                  'Premature EOF encountered at clip $clipName: $e. Gracefully concluding export with ${outputPaths.length} valid clips.',
                );
                controller.add(
                  ProcessingProgress(
                    status: ProcessingStatus.completed,
                    currentClipIndex: outputPaths.length,
                    totalClips: totalClips,
                    currentClipProgress: 1.0,
                    overallProgress: 1.0,
                    currentClipName:
                        'Reached end of source video ($clipName reached EOF)',
                    stageLabel: 'Complete',
                    outputPaths: List.unmodifiable(outputPaths),
                  ),
                );
                await controller.close();
                return;
              }
              rethrow;
            } finally {
              if (tempOverlayPng != null) {
                _safeDelete(tempOverlayPng);
              }
            }

            if (_isCancelled) {
              _emitCancelled(controller, i + 1, totalClips, outputPaths);
              return;
            }

            // Emit "Verifying..." at 100% clip progress
            if (!controller.isClosed) {
              controller.add(
                ProcessingProgress(
                  status: ProcessingStatus.processing,
                  currentClipIndex: i + 1,
                  totalClips: totalClips,
                  currentClipName: clipName,
                  currentClipProgress: 1.0,
                  overallProgress: (i + 0.94) / totalClips,
                  stageLabel: 'Verifying clip duration...',
                  outputPaths: List.unmodifiable(outputPaths),
                ),
              );
            }

            String finalTempClipPath = tempClipPath;

            // Probe actual duration to strictly enforce Domain Invariant #1 (Hard 180s Cap)
            try {
              final probeSession =
                  await FFprobeKit.getMediaInformation(tempClipPath);
              final mediaInfo = probeSession.getMediaInformation();
              final rawDuration = mediaInfo?.getDuration();
              final probedDuration =
                  double.tryParse(rawDuration ?? '') ?? segment.durationSeconds;

              // In precise mode, the clip was already encoded with -t duration.
              // Container audio packet boundaries may cause probed duration to be e.g. 180.03s,
              // which is completely normal container padding. Only clamp if in fast stream copy
              // mode (which snaps to keyframes up to e.g. 187s) or if precise mode significantly
              // exceeded the cap (> 180.5s).
              final clampThreshold = mode == SplitMode.precise
                  ? AppConstants.maxClipDurationSeconds + 0.5
                  : AppConstants.maxClipDurationSeconds.toDouble();

              if (probedDuration > clampThreshold) {
                AppLogger.warning(
                  'Clip $clipName duration (${probedDuration.toStringAsFixed(2)}s) exceeded ${clampThreshold}s. Clamping precisely to 180.0s.',
                );
                if (!controller.isClosed) {
                  controller.add(
                    ProcessingProgress(
                      status: ProcessingStatus.processing,
                      currentClipIndex: i + 1,
                      totalClips: totalClips,
                      currentClipName: clipName,
                      currentClipProgress: 1.0,
                      overallProgress: (i + 0.96) / totalClips,
                      stageLabel: 'Trimming to 180s Shorts limit...',
                      outputPaths: List.unmodifiable(outputPaths),
                    ),
                  );
                }

                final clampedTempPath = p.join(
                  tempCacheDir.path,
                  'clamped_${segment.index}_${DateTime.now().millisecondsSinceEpoch}.mp4',
                );
                _trackedTempFiles.add(clampedTempPath);

                final clampArgs = [
                  '-y',
                  '-i',
                  tempClipPath,
                  '-t',
                  AppConstants.maxClipDurationSeconds.toStringAsFixed(3),
                  '-c:v',
                  'libx264',
                  '-preset',
                  'ultrafast',
                  '-c:a',
                  'copy',
                  '-movflags',
                  '+faststart',
                  clampedTempPath,
                ];

                final clampSuccess = await _executeSession(
                  clampArgs,
                  AppConstants.maxClipDurationSeconds.toDouble(),
                  (clampProg) {
                    if (!_isCancelled && !controller.isClosed) {
                      final clampPct = (clampProg * 100).toInt();
                      controller.add(
                        ProcessingProgress(
                          status: ProcessingStatus.processing,
                          currentClipIndex: i + 1,
                          totalClips: totalClips,
                          currentClipName: clipName,
                          currentClipProgress: 1.0,
                          overallProgress: (i + 0.96) / totalClips,
                          stageLabel: 'Trimming to 180s ($clampPct%)...',
                          outputPaths: List.unmodifiable(outputPaths),
                        ),
                      );
                    }
                  },
                );

                if (clampSuccess &&
                    await File(clampedTempPath).exists() &&
                    await File(clampedTempPath).length() > 0) {
                  _safeDelete(tempClipPath);
                  finalTempClipPath = clampedTempPath;
                }
              }
            } catch (e) {
              AppLogger.warning(
                'Duration verification warning for $clipName: $e',
              );
            }

            final tempFile = File(finalTempClipPath);
            if (!await tempFile.exists() || await tempFile.length() == 0) {
              if (outputPaths.isNotEmpty) {
                AppLogger.warning(
                  'Encoded clip $clipName is empty or missing (likely source EOF). Gracefully concluding export with ${outputPaths.length} valid clips.',
                );
                controller.add(
                  ProcessingProgress(
                    status: ProcessingStatus.completed,
                    currentClipIndex: outputPaths.length,
                    totalClips: totalClips,
                    currentClipProgress: 1.0,
                    overallProgress: 1.0,
                    currentClipName:
                        'Reached end of source video ($clipName reached EOF)',
                    stageLabel: 'Complete',
                    outputPaths: List.unmodifiable(outputPaths),
                  ),
                );
                await controller.close();
                return;
              }
              throw VideoProcessingException(
                'Encoded clip $clipName is empty or missing.',
              );
            }

            // Emit "Saving clip to storage..." so user knows file transfer is in progress
            if (!controller.isClosed) {
              controller.add(
                ProcessingProgress(
                  status: ProcessingStatus.processing,
                  currentClipIndex: i + 1,
                  totalClips: totalClips,
                  currentClipName: clipName,
                  currentClipProgress: 1.0,
                  overallProgress: (i + 0.98) / totalClips,
                  stageLabel: 'Saving clip to storage folder...',
                  outputPaths: List.unmodifiable(outputPaths),
                ),
              );
            }

            final finalDestinationUri = await activeWriter.writeClip(
              sourceTempFile: tempFile,
              fileName: clipName,
              duplicateHandling: duplicateHandling,
            );

            outputPaths.add(finalDestinationUri);
            _safeDelete(finalTempClipPath);

            // Emit "Saved to storage!"
            if (!controller.isClosed) {
              controller.add(
                ProcessingProgress(
                  status: ProcessingStatus.processing,
                  currentClipIndex: i + 1,
                  totalClips: totalClips,
                  currentClipName: clipName,
                  currentClipProgress: 1.0,
                  overallProgress: (i + 1.0) / totalClips,
                  stageLabel: 'Saved to storage folder!',
                  outputPaths: List.unmodifiable(outputPaths),
                ),
              );
            }
          }

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.completed,
              currentClipIndex: totalClips,
              totalClips: totalClips,
              currentClipProgress: 1.0,
              overallProgress: 1.0,
              currentClipName: 'All clips generated successfully',
              stageLabel: 'Complete',
              outputPaths: List.unmodifiable(outputPaths),
            ),
          );
          await controller.close();
        } catch (e, st) {
          if (_isCancelled) {
            _emitCancelled(controller, 0, totalClips, outputPaths);
          } else {
            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.error,
                currentClipIndex: outputPaths.length + 1,
                totalClips: totalClips,
                errorMessage: e.toString(),
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );
            controller.addError(e, st);
            await controller.close();
          }
        } finally {
          if (tempStreamedInput != null) {
            _safeDelete(tempStreamedInput);
          }
          _cleanupAllTempFiles();
        }
      },
      onCancel: () async {
        await cancel();
      },
    );

    return controller.stream;
  }

  Future<void> _transcodeClipWithFallback({
    required String inputPath,
    required ClipSegment segment,
    required String tempOutputPath,
    required SplitMode mode,
    required AspectRatioOption aspectRatio,
    required ClipPlan? plan,
    required VideoMetadata sourceMeta,
    required String? overlayPngPath,
    required double totalDuration,
    required void Function(double) onProgress,
  }) async {
    final is4k = plan?.canvasSpec.resolution == CanvasResolution.ultraHd4k ||
        (plan != null &&
            (plan.canvasSpec.width > 1920 || plan.canvasSpec.height > 1920));

    // 1. Android Hardware MediaCodec Acceleration (when not stream copy, not software fallback, and not 4K)
    // Note: Android MediaCodec hardware encoders commonly fail on vertical 4K (2160x3840) because
    // mobile hardware encoders limit frame height to 2160. 4K routes directly to libx264 software encoder.
    if (Platform.isAndroid && mode == SplitMode.precise && !is4k) {
      try {
        final hwArgs = _buildHardwareArguments(
          inputPath: inputPath,
          segment: segment,
          outputPath: tempOutputPath,
          aspectRatio: aspectRatio,
          plan: plan,
          sourceMeta: sourceMeta,
          overlayPngPath: overlayPngPath,
        );
        final hwSuccess = await _executeSession(
          hwArgs,
          totalDuration,
          onProgress,
        );
        if (hwSuccess) {
          final tempFile = File(tempOutputPath);
          if (tempFile.existsSync() && tempFile.lengthSync() > 1024) {
            PerfTrace.instance.recordEncoder('h264_mediacodec');
            return;
          }
          AppLogger.warning(
            'Hardware encoder produced an empty or truncated file. Retrying with software encoder...',
          );
        }
      } catch (e) {
        AppLogger.warning('h264_mediacodec hardware encoding unavailable: $e');
      }
    }

    if (_isCancelled) return;

    // 2. Primary / Fast Software Transcode (libx264 ultrafast)
    final primaryArgs = _buildFFmpegArguments(
      inputPath: inputPath,
      segment: segment,
      outputPath: tempOutputPath,
      mode: mode,
      aspectRatio: aspectRatio,
      plan: plan,
      sourceMeta: sourceMeta,
      overlayPngPath: overlayPngPath,
      isSoftwareFallback: false,
    );

    final success = await _executeSession(
      primaryArgs,
      totalDuration,
      onProgress,
    );
    if (success) {
      final tempFile = File(tempOutputPath);
      if (tempFile.existsSync() && tempFile.lengthSync() > 1024) {
        PerfTrace.instance.recordEncoder(
          mode == SplitMode.fast ? 'copy' : 'libx264-ultrafast',
        );
        return;
      }
      AppLogger.warning(
        'Primary software encoder produced an empty or truncated file. Retrying with baseline fallback...',
      );
    }

    if (_isCancelled) return;

    // 3. Robust Software Baseline Compatibility Fallback (for low-end chipsets / API 28)
    AppLogger.warning(
      'Primary transcode failed on ${segment.formattedName}. Retrying with software H.264 baseline fallback...',
    );
    final fallbackArgs = _buildFFmpegArguments(
      inputPath: inputPath,
      segment: segment,
      outputPath: tempOutputPath,
      mode: SplitMode.precise,
      aspectRatio: aspectRatio,
      plan: plan,
      sourceMeta: sourceMeta,
      overlayPngPath: overlayPngPath,
      isSoftwareFallback: true,
    );

    final fallbackSuccess = await _executeSession(
      fallbackArgs,
      totalDuration,
      onProgress,
    );
    if (fallbackSuccess) {
      PerfTrace.instance.recordEncoder('libx264-baseline');
      return;
    }

    throw VideoProcessingException(
      'FFmpeg failed to transcode clip: ${segment.formattedName}',
    );
  }

  Future<bool> _executeSession(
    List<String> args,
    double totalDuration,
    void Function(double) onProgress, {
    Duration? timeout,
  }) async {
    final completer = Completer<bool>();
    final timeoutDuration = timeout ??
        Duration(seconds: (totalDuration * 3 + 30).clamp(30.0, 300.0).toInt());

    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (completedSession) async {
        final code = await completedSession.getReturnCode();
        if (!completer.isCompleted) {
          completer.complete(ReturnCode.isSuccess(code));
        }
      },
      null,
      (statistics) {
        if (totalDuration > 0) {
          final timeMs = statistics.getTime();
          final progress = (timeMs / (totalDuration * 1000.0)).clamp(0.0, 1.0);
          onProgress(progress);
        }
      },
    );

    _activeSessionId = session.getSessionId();

    Timer? watchdog;
    watchdog = Timer(timeoutDuration, () async {
      if (!completer.isCompleted) {
        AppLogger.error(
          'FFmpeg session timed out after ${timeoutDuration.inSeconds}s (duration: ${totalDuration}s). Aborting hung session $_activeSessionId...',
        );
        try {
          await FFmpegKit.cancel(_activeSessionId);
        } catch (_) {}
        completer.complete(false);
      }
    });

    try {
      final success = await completer.future;
      return success;
    } finally {
      watchdog.cancel();
      _activeSessionId = null;
    }
  }

  List<String> _buildHardwareArguments({
    required String inputPath,
    required ClipSegment segment,
    required String outputPath,
    required AspectRatioOption aspectRatio,
    required ClipPlan? plan,
    required VideoMetadata sourceMeta,
    required String? overlayPngPath,
  }) {
    final startStr = segment.startSeconds.toStringAsFixed(3);
    final durationStr = segment.durationSeconds.toStringAsFixed(3);

    final args = <String>[
      '-y',
      '-ss',
      startStr,
      '-i',
      inputPath,
      '-t',
      durationStr,
    ];

    if (plan != null) {
      final filterResult = FilterGraphBuilder.build(
        sourceWidth: sourceMeta.width,
        sourceHeight: sourceMeta.height,
        canvasSpec: plan.canvasSpec,
        backgroundSpec: plan.backgroundSpec,
        cropToFill: plan.cropToFill,
        rotationDegrees: sourceMeta.rotation,
        sar: sourceMeta.sar,
        verticalPosition: plan.verticalPosition,
        verticalOffsetFraction: plan.verticalOffsetFraction,
        overlayPngPath: overlayPngPath,
        displayWholeClip: plan.overlaySpec.displayWholeClip,
        displayDurationSeconds: plan.overlaySpec.displayDurationSeconds,
      );

      args.addAll(filterResult.additionalInputArgs);

      if (filterResult.filterComplex != null) {
        args.addAll(['-filter_complex', filterResult.filterComplex!]);
        args.addAll(['-map', filterResult.outputVideoMap]);
      } else if (filterResult.simpleFilter != null) {
        args.addAll(['-vf', filterResult.simpleFilter!]);
        args.addAll(['-map', filterResult.outputVideoMap]);
      } else {
        args.addAll(['-map', '0:v']);
      }
    } else {
      switch (aspectRatio) {
        case AspectRatioOption.cropVertical:
          args.addAll([
            '-vf',
            "crop='if(gte(a,9/16),ih*9/16,iw)':'if(gte(a,9/16),ih,iw*16/9)':'(iw-ow)/2':'(ih-oh)/2',scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1",
            '-map',
            '0:v',
          ]);
          break;
        case AspectRatioOption.blurVertical:
          args.addAll([
            '-filter_complex',
            '[0:v]scale=108:192:force_original_aspect_ratio=increase,crop=108:192,boxblur=5:1,scale=1080:1920:flags=bicubic[bg];[0:v]scale=1080:1920:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[outv]',
            '-map',
            '[outv]',
          ]);
          break;
        case AspectRatioOption.original:
          args.addAll([
            '-vf',
            'scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1',
            '-map',
            '0:v',
          ]);
          break;
      }
    }

    final cpuThreads = Platform.numberOfProcessors.clamp(2, 8).toString();
    args.addAll(['-threads', cpuThreads]);
    args.addAll(['-map', '0:a:0?']);
    args.addAll([
      '-c:v',
      'h264_mediacodec',
      '-b:v',
      '3500k',
      '-maxrate',
      '5000k',
      '-bufsize',
      '8000k',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-ac',
      '2',
      '-ar',
      '48000',
      '-movflags',
      '+faststart',
      outputPath,
    ]);

    return args;
  }

  List<String> _buildFFmpegArguments({
    required String inputPath,
    required ClipSegment segment,
    required String outputPath,
    required SplitMode mode,
    required AspectRatioOption aspectRatio,
    required ClipPlan? plan,
    required VideoMetadata sourceMeta,
    required String? overlayPngPath,
    required bool isSoftwareFallback,
  }) {
    final startStr = segment.startSeconds.toStringAsFixed(3);
    final durationStr = segment.durationSeconds.toStringAsFixed(3);

    // Fast mode: stream copy without re-encoding.
    // ONLY valid when no canvas/filter plan is active — a plan means 9:16 scaling
    // or background fill is required, which stream-copy physically cannot do.
    final canUseFastCopy = mode == SplitMode.fast && plan == null;

    if (canUseFastCopy) {
      return [
        '-y',
        '-ss',
        startStr,
        '-i',
        inputPath,
        '-t',
        durationStr,
        '-c',
        'copy',
        '-map',
        '0:v:0?',
        '-map',
        '0:a:0?',
        '-avoid_negative_ts',
        'make_zero',
        outputPath,
      ];
    }

    final args = <String>[
      '-y',
      '-ss',
      startStr,
      '-i',
      inputPath,
      '-t',
      durationStr,
    ];

    if (plan != null) {
      final filterResult = FilterGraphBuilder.build(
        sourceWidth: sourceMeta.width,
        sourceHeight: sourceMeta.height,
        canvasSpec: plan.canvasSpec,
        backgroundSpec: plan.backgroundSpec,
        cropToFill: plan.cropToFill,
        rotationDegrees: sourceMeta.rotation,
        sar: sourceMeta.sar,
        verticalPosition: plan.verticalPosition,
        verticalOffsetFraction: plan.verticalOffsetFraction,
        overlayPngPath: overlayPngPath,
        displayWholeClip: plan.overlaySpec.displayWholeClip,
        displayDurationSeconds: plan.overlaySpec.displayDurationSeconds,
      );

      args.addAll(filterResult.additionalInputArgs);

      if (filterResult.filterComplex != null) {
        args.addAll(['-filter_complex', filterResult.filterComplex!]);
        args.addAll(['-map', filterResult.outputVideoMap]);
      } else if (filterResult.simpleFilter != null) {
        args.addAll(['-vf', filterResult.simpleFilter!]);
        args.addAll(['-map', filterResult.outputVideoMap]);
      } else {
        args.addAll(['-map', '0:v']);
      }
    } else {
      // Legacy fallback
      switch (aspectRatio) {
        case AspectRatioOption.cropVertical:
          args.addAll([
            '-vf',
            "crop='if(gte(a,9/16),ih*9/16,iw)':'if(gte(a,9/16),ih,iw*16/9)':'(iw-ow)/2':'(ih-oh)/2',scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,setsar=1",
            '-map',
            '0:v',
          ]);
          break;
        case AspectRatioOption.blurVertical:
          args.addAll([
            '-filter_complex',
            '[0:v]scale=108:192:force_original_aspect_ratio=increase,crop=108:192,boxblur=5:1,scale=1080:1920:flags=bicubic[bg];[0:v]scale=1080:1920:force_original_aspect_ratio=decrease[fg];[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1[outv]',
            '-map',
            '[outv]',
          ]);
          break;
        case AspectRatioOption.original:
          args.addAll([
            '-vf',
            'scale=trunc(iw/2)*2:trunc(ih/2)*2,setsar=1',
            '-map',
            '0:v',
          ]);
          break;
      }
    }

    // Map single primary audio track gracefully (-map 0:a:0? so videos without audio don't fail and multi-track audio doesn't break mobile apps)
    args.addAll(['-map', '0:a:0?']);

    final cpuThreads = Platform.numberOfProcessors.clamp(2, 8).toString();

    if (isSoftwareFallback) {
      args.addAll([
        '-threads',
        cpuThreads,
        '-c:v',
        'libx264',
        '-profile:v',
        'baseline',
        '-level',
        '3.1',
        '-preset',
        'ultrafast',
        '-g',
        '48',
        '-keyint_min',
        '24',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-ac',
        '2',
        '-ar',
        '48000',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outputPath,
      ]);
    } else {
      final is4k = plan?.canvasSpec.resolution == CanvasResolution.ultraHd4k ||
          (plan != null &&
              (plan.canvasSpec.width > 1920 || plan.canvasSpec.height > 1920));
      final h264Level = is4k ? '5.1' : '4.1';
      final crfVal = is4k ? '18' : '22';
      final audioBitrate = is4k ? '320k' : '192k';

      args.addAll([
        '-threads',
        cpuThreads,
        '-c:v',
        'libx264',
        '-profile:v',
        'high',
        '-level',
        h264Level,
        '-preset',
        'veryfast',
        '-crf',
        crfVal,
        '-g',
        '48',
        '-keyint_min',
        '24',
        '-c:a',
        'aac',
        '-b:a',
        audioBitrate,
        '-ac',
        '2',
        '-ar',
        '48000',
        '-pix_fmt',
        'yuv420p',
        '-movflags',
        '+faststart',
        outputPath,
      ]);
    }

    return args;
  }

  @override
  Stream<ProcessingProgress> splitCustom({
    required String inputPath,
    required CustomClipPlan plan,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    late StreamController<ProcessingProgress> controller;
    _isCancelled = false;

    controller = StreamController<ProcessingProgress>(
      onListen: () async {
        final totalClips = plan.items.length;
        final outputPaths = <String>[];
        String resolvedInputPath = inputPath;
        String? tempStreamedInput;

        try {
          final freeBytes = await StorageBridge.getFreeDiskSpace();
          const minRequiredBytes = 250 * 1024 * 1024;
          if (freeBytes < minRequiredBytes) {
            throw const StorageAccessException(
              'Insufficient storage space. At least 250MB free space required.',
              path: 'device_storage',
            );
          }

          if (inputPath.startsWith('content://')) {
            final tempDir = await getTemporaryDirectory();
            tempStreamedInput = p.join(
              tempDir.path,
              'source_custom_split_${DateTime.now().millisecondsSinceEpoch}.mp4',
            );
            _trackedTempFiles.add(tempStreamedInput);
            resolvedInputPath = await StorageBridge.copyContentUriToTempFile(
              contentUri: inputPath,
              tempDestPath: tempStreamedInput,
            );
          }

          final activeWriter = clipWriter ??
              await ClipWriterFactory.resolveWriter(
                preferredSafUri: outputDirectoryPath.startsWith('content://')
                    ? outputDirectoryPath
                    : null,
              );

          final tempCacheDir = await getTemporaryDirectory();

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.preparing,
              currentClipIndex: 0,
              totalClips: totalClips,
              currentClipName: 'Initializing custom split...',
            ),
          );

          for (int i = 0; i < totalClips; i++) {
            if (_isCancelled) {
              _emitCancelled(controller, i + 1, totalClips, outputPaths);
              return;
            }

            final item = plan.items[i];
            final clipName = item.displayName;
            final tempClipPath = p.join(
              tempCacheDir.path,
              'custom_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.mp4',
            );
            _trackedTempFiles.add(tempClipPath);

            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.processing,
                currentClipIndex: i + 1,
                totalClips: totalClips,
                currentClipName: clipName,
                currentClipProgress: 0.0,
                overallProgress: i / totalClips,
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );

            final args = <String>[
              '-y',
              '-ss',
              item.startSeconds.toStringAsFixed(3),
              '-i',
              resolvedInputPath,
              '-t',
              item.durationSeconds.toStringAsFixed(3),
            ];

            if (plan.splitMethod == SplitMethod.fast) {
              args.addAll(['-c', 'copy', '-avoid_negative_ts', 'make_zero']);
            } else {
              args.addAll([
                '-c:v',
                'libx264',
                '-preset',
                'ultrafast',
                '-crf',
                '23',
                '-c:a',
                'aac',
                '-b:a',
                '128k',
                '-pix_fmt',
                'yuv420p',
                '-movflags',
                '+faststart',
              ]);
            }
            args.add(tempClipPath);

            final success = await _executeSession(args, item.durationSeconds, (
              clipProg,
            ) {
              if (!_isCancelled && !controller.isClosed) {
                controller.add(
                  ProcessingProgress(
                    status: ProcessingStatus.processing,
                    currentClipIndex: i + 1,
                    totalClips: totalClips,
                    currentClipName: clipName,
                    currentClipProgress: clipProg,
                    overallProgress: (i + clipProg) / totalClips,
                    outputPaths: List.unmodifiable(outputPaths),
                  ),
                );
              }
            });

            if (_isCancelled) {
              _emitCancelled(controller, i + 1, totalClips, outputPaths);
              return;
            }

            if (!success) {
              throw VideoProcessingException(
                'FFmpeg failed to split clip: $clipName',
              );
            }

            final tempFile = File(tempClipPath);
            if (!await tempFile.exists() || await tempFile.length() == 0) {
              throw VideoProcessingException(
                'Split clip $clipName is empty or missing.',
              );
            }

            final finalUri = await activeWriter.writeClip(
              sourceTempFile: tempFile,
              fileName: clipName,
              duplicateHandling: duplicateHandling,
            );

            outputPaths.add(finalUri);
            _safeDelete(tempClipPath);
          }

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.completed,
              currentClipIndex: totalClips,
              totalClips: totalClips,
              currentClipProgress: 1.0,
              overallProgress: 1.0,
              currentClipName: 'All custom clips generated successfully',
              outputPaths: List.unmodifiable(outputPaths),
            ),
          );
          await controller.close();
        } catch (e, st) {
          if (_isCancelled) {
            _emitCancelled(controller, 0, totalClips, outputPaths);
          } else {
            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.error,
                currentClipIndex: outputPaths.length + 1,
                totalClips: totalClips,
                errorMessage: e.toString(),
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );
            controller.addError(e, st);
            await controller.close();
          }
        } finally {
          if (tempStreamedInput != null) _safeDelete(tempStreamedInput);
          _cleanupAllTempFiles();
        }
      },
      onCancel: () async {
        await cancel();
      },
    );

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
    late StreamController<ProcessingProgress> controller;
    _isCancelled = false;

    controller = StreamController<ProcessingProgress>(
      onListen: () async {
        final outputPaths = <String>[];
        String resolvedInputPath = inputPath;
        String? tempStreamedInput;
        String? tempOverlayPng;

        try {
          final freeBytes = await StorageBridge.getFreeDiskSpace();
          const minRequiredBytes = 250 * 1024 * 1024;
          if (freeBytes < minRequiredBytes) {
            throw const StorageAccessException(
              'Insufficient storage space. At least 250MB free space required.',
              path: 'device_storage',
            );
          }

          if (inputPath.startsWith('content://')) {
            final tempDir = await getTemporaryDirectory();
            tempStreamedInput = p.join(
              tempDir.path,
              'source_editor_${DateTime.now().millisecondsSinceEpoch}.mp4',
            );
            _trackedTempFiles.add(tempStreamedInput);
            resolvedInputPath = await StorageBridge.copyContentUriToTempFile(
              contentUri: inputPath,
              tempDestPath: tempStreamedInput,
            );
          }

          final activeWriter = clipWriter ??
              await ClipWriterFactory.resolveWriter(
                preferredSafUri: outputDirectoryPath.startsWith('content://')
                    ? outputDirectoryPath
                    : null,
              );

          final tempCacheDir = await getTemporaryDirectory();
          final tempExportPath = p.join(
            tempCacheDir.path,
            'editor_export_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          _trackedTempFiles.add(tempExportPath);

          controller.add(
            const ProcessingProgress(
              status: ProcessingStatus.preparing,
              currentClipIndex: 0,
              totalClips: 1,
              currentClipName: 'Compiling studio edit...',
            ),
          );

          if (project.textOverlay != null &&
              project.textOverlay!.text.trim().isNotEmpty) {
            final (cw, ch) = project.canvas.aspectRatio.dimensions;
            final overlayW = cw > 0 ? cw : project.sourceWidth;
            final overlayH = ch > 0 ? ch : project.sourceHeight;

            tempOverlayPng = p.join(
              tempCacheDir.path,
              'edit_overlay_${DateTime.now().millisecondsSinceEpoch}.png',
            );
            _trackedTempFiles.add(tempOverlayPng);

            await OverlayRenderer.renderToPngFile(
              text: project.textOverlay!.text,
              width: overlayW,
              height: overlayH,
              overlaySpec: split_overlay.OverlaySpec(
                fontSize: project.textOverlay!.fontSize.toDouble(),
                textColorValue: project.textOverlay!.fontColorHex,
                boxColorValue:
                    project.textOverlay!.backgroundColorHex ?? 0x80000000,
              ),
              outputPath: tempOverlayPng,
            );
          }

          final primaryCmd = EditorFilterCompiler.compileExport(
            project: project,
            resolvedInputPath: resolvedInputPath,
            outputPath: tempExportPath,
            renderedTextPngPath: tempOverlayPng,
            isSoftwareFallback: false,
          );

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.processing,
              currentClipIndex: 1,
              totalClips: 1,
              currentClipName: project.title,
              currentClipProgress: 0.0,
              overallProgress: 0.0,
            ),
          );

          var success = await _executeSession(
            primaryCmd.arguments,
            project.outputDuration,
            (progress) {
              if (!_isCancelled && !controller.isClosed) {
                controller.add(
                  ProcessingProgress(
                    status: ProcessingStatus.processing,
                    currentClipIndex: 1,
                    totalClips: 1,
                    currentClipName: project.title,
                    currentClipProgress: progress,
                    overallProgress: progress,
                  ),
                );
              }
            },
          );

          if (!success && !_isCancelled) {
            AppLogger.warning(
              'Primary edit export failed. Retrying with software fallback...',
            );
            final fallbackCmd = EditorFilterCompiler.compileExport(
              project: project,
              resolvedInputPath: resolvedInputPath,
              outputPath: tempExportPath,
              renderedTextPngPath: tempOverlayPng,
              isSoftwareFallback: true,
            );

            success = await _executeSession(
              fallbackCmd.arguments,
              project.outputDuration,
              (progress) {
                if (!_isCancelled && !controller.isClosed) {
                  controller.add(
                    ProcessingProgress(
                      status: ProcessingStatus.processing,
                      currentClipIndex: 1,
                      totalClips: 1,
                      currentClipName: project.title,
                      currentClipProgress: progress,
                      overallProgress: progress,
                    ),
                  );
                }
              },
            );
          }

          if (_isCancelled) {
            _emitCancelled(controller, 1, 1, outputPaths);
            return;
          }

          if (!success) {
            throw VideoProcessingException(
              'FFmpeg failed to export edit project: ${project.title}',
            );
          }

          final tempFile = File(tempExportPath);
          if (!await tempFile.exists() || await tempFile.length() == 0) {
            throw const VideoProcessingException(
              'Exported video is empty or missing.',
            );
          }

          final outputFileName = '${project.title}.mp4';
          final finalUri = await activeWriter.writeClip(
            sourceTempFile: tempFile,
            fileName: outputFileName,
            duplicateHandling: duplicateHandling,
          );

          outputPaths.add(finalUri);
          _safeDelete(tempExportPath);

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.completed,
              currentClipIndex: 1,
              totalClips: 1,
              currentClipProgress: 1.0,
              overallProgress: 1.0,
              currentClipName: 'Edit export complete',
              outputPaths: List.unmodifiable(outputPaths),
            ),
          );
          await controller.close();
        } catch (e, st) {
          if (_isCancelled) {
            _emitCancelled(controller, 0, 1, outputPaths);
          } else {
            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.error,
                currentClipIndex: 1,
                totalClips: 1,
                errorMessage: e.toString(),
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );
            controller.addError(e, st);
            await controller.close();
          }
        } finally {
          if (tempStreamedInput != null) _safeDelete(tempStreamedInput);
          if (tempOverlayPng != null) _safeDelete(tempOverlayPng);
          _cleanupAllTempFiles();
        }
      },
      onCancel: () async {
        await cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<String> generateEditPreview({
    required String inputPath,
    required EditProject project,
    double previewDurationSeconds = 5.0,
  }) async {
    final tempCacheDir = await getTemporaryDirectory();
    final previewPath = p.join(
      tempCacheDir.path,
      'preview_${project.id}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
    _trackedTempFiles.add(previewPath);

    String resolvedInputPath = inputPath;
    String? tempStreamedInput;

    try {
      if (inputPath.startsWith('content://')) {
        tempStreamedInput = p.join(
          tempCacheDir.path,
          'preview_source_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        _trackedTempFiles.add(tempStreamedInput);
        resolvedInputPath = await StorageBridge.copyContentUriToTempFile(
          contentUri: inputPath,
          tempDestPath: tempStreamedInput,
        );
      }

      final cmdArgs = EditorFilterCompiler.compilePreview(
        project: project,
        resolvedInputPath: resolvedInputPath,
        previewOutputPath: previewPath,
        previewDurationSeconds: previewDurationSeconds,
      );

      final success = await _executeSession(
        cmdArgs,
        previewDurationSeconds,
        (_) {},
      );

      if (!success) {
        throw const VideoProcessingException(
          'Failed to generate quick preview.',
        );
      }

      return previewPath;
    } finally {
      if (tempStreamedInput != null) _safeDelete(tempStreamedInput);
    }
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
    late StreamController<ProcessingProgress> controller;
    _isCancelled = false;

    controller = StreamController<ProcessingProgress>(
      onListen: () async {
        final outputPaths = <String>[];
        String resolvedInputPath = inputPath;
        String? tempStreamedInput;

        try {
          final freeBytes = await StorageBridge.getFreeDiskSpace();
          const minRequiredBytes = 150 * 1024 * 1024;
          if (freeBytes < minRequiredBytes) {
            throw const StorageAccessException(
              'Insufficient storage space. At least 150MB free space required.',
              path: 'device_storage',
            );
          }

          if (inputPath.startsWith('content://')) {
            final tempDir = await getTemporaryDirectory();
            tempStreamedInput = p.join(
              tempDir.path,
              'source_convert_${DateTime.now().millisecondsSinceEpoch}.mp4',
            );
            _trackedTempFiles.add(tempStreamedInput);
            resolvedInputPath = await StorageBridge.copyContentUriToTempFile(
              contentUri: inputPath,
              tempDestPath: tempStreamedInput,
            );
          }

          final activeWriter = clipWriter ??
              await ClipWriterFactory.resolveWriter(
                preferredSafUri: outputDirectoryPath.startsWith('content://')
                    ? outputDirectoryPath
                    : null,
              );

          final ext = config.effectiveExtension;
          final tempCacheDir = await getTemporaryDirectory();
          final tempExportPath = p.join(
            tempCacheDir.path,
            'convert_${DateTime.now().millisecondsSinceEpoch}$ext',
          );
          _trackedTempFiles.add(tempExportPath);

          controller.add(
            const ProcessingProgress(
              status: ProcessingStatus.preparing,
              currentClipIndex: 0,
              totalClips: 1,
              currentClipName: 'Configuring conversion...',
            ),
          );

          const compiler = ConvertFilterCompiler();
          final cmdArgs = compiler.compile(
            inputPath: resolvedInputPath,
            outputPath: tempExportPath,
            config: config,
            durationSeconds: durationSeconds,
          );

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.processing,
              currentClipIndex: 1,
              totalClips: 1,
              currentClipName: 'Converting to ${config.format.displayName}',
              currentClipProgress: 0.0,
              overallProgress: 0.0,
            ),
          );

          final success = await _executeSession(cmdArgs, durationSeconds, (
            progress,
          ) {
            if (!_isCancelled && !controller.isClosed) {
              controller.add(
                ProcessingProgress(
                  status: ProcessingStatus.processing,
                  currentClipIndex: 1,
                  totalClips: 1,
                  currentClipName: 'Converting to ${config.format.displayName}',
                  currentClipProgress: progress,
                  overallProgress: progress,
                ),
              );
            }
          });

          if (_isCancelled) {
            _emitCancelled(controller, 1, 1, outputPaths);
            return;
          }

          if (!success) {
            throw VideoProcessingException(
              'FFmpeg conversion failed for format: ${config.format.displayName}',
            );
          }

          final tempFile = File(tempExportPath);
          if (!await tempFile.exists() || await tempFile.length() == 0) {
            throw const VideoProcessingException(
              'Converted output file is empty or missing.',
            );
          }

          final baseName = config.customFileName?.trim().isNotEmpty == true
              ? config.customFileName!.trim()
              : p.basenameWithoutExtension(inputPath);
          final outputFileName = '$baseName$ext';

          final finalUri = await activeWriter.writeClip(
            sourceTempFile: tempFile,
            fileName: outputFileName,
            duplicateHandling: duplicateHandling,
          );

          outputPaths.add(finalUri);
          _safeDelete(tempExportPath);

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.completed,
              currentClipIndex: 1,
              totalClips: 1,
              currentClipProgress: 1.0,
              overallProgress: 1.0,
              currentClipName: 'Conversion completed successfully',
              outputPaths: List.unmodifiable(outputPaths),
            ),
          );
          await controller.close();
        } catch (e, st) {
          if (_isCancelled) {
            _emitCancelled(controller, 0, 1, outputPaths);
          } else {
            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.error,
                currentClipIndex: 1,
                totalClips: 1,
                errorMessage: e.toString(),
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );
            controller.addError(e, st);
            await controller.close();
          }
        } finally {
          if (tempStreamedInput != null) _safeDelete(tempStreamedInput);
          _cleanupAllTempFiles();
        }
      },
      onCancel: () async {
        await cancel();
      },
    );

    return controller.stream;
  }

  @override
  Stream<ProcessingProgress> processAudioStudio({
    required AudioStudioConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    late StreamController<ProcessingProgress> controller;
    _isCancelled = false;

    controller = StreamController<ProcessingProgress>(
      onListen: () async {
        final outputPaths = <String>[];
        String resolvedInputPath = config.videoPath;
        String? tempStreamedInput;
        String? tempStreamedMusic;
        String? tempStreamedVo;

        try {
          final freeBytes = await StorageBridge.getFreeDiskSpace();
          const minRequiredBytes = 150 * 1024 * 1024;
          if (freeBytes < minRequiredBytes) {
            throw const StorageAccessException(
              'Insufficient storage space. At least 150MB free space required.',
              path: 'device_storage',
            );
          }

          final tempDir = await getTemporaryDirectory();

          if (config.videoPath.startsWith('content://')) {
            tempStreamedInput = p.join(
              tempDir.path,
              'source_audio_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
            );
            _trackedTempFiles.add(tempStreamedInput);
            resolvedInputPath = await StorageBridge.copyContentUriToTempFile(
              contentUri: config.videoPath,
              tempDestPath: tempStreamedInput,
            );
          }

          String? resolvedMusicPath = config.musicTrack?.sourcePath;
          if (resolvedMusicPath != null &&
              resolvedMusicPath.startsWith('content://')) {
            tempStreamedMusic = p.join(
              tempDir.path,
              'music_${DateTime.now().millisecondsSinceEpoch}.mp3',
            );
            _trackedTempFiles.add(tempStreamedMusic);
            resolvedMusicPath = await StorageBridge.copyContentUriToTempFile(
              contentUri: resolvedMusicPath,
              tempDestPath: tempStreamedMusic,
            );
          }

          String? resolvedVoPath = config.voiceoverTrack?.sourcePath;
          if (resolvedVoPath != null &&
              resolvedVoPath.startsWith('content://')) {
            tempStreamedVo = p.join(
              tempDir.path,
              'vo_${DateTime.now().millisecondsSinceEpoch}.m4a',
            );
            _trackedTempFiles.add(tempStreamedVo);
            resolvedVoPath = await StorageBridge.copyContentUriToTempFile(
              contentUri: resolvedVoPath,
              tempDestPath: tempStreamedVo,
            );
          }

          final resolvedConfig = config.copyWith(
            videoPath: resolvedInputPath,
            musicTrack: config.musicTrack?.copyWith(
              sourcePath: resolvedMusicPath,
            ),
            voiceoverTrack: config.voiceoverTrack?.copyWith(
              sourcePath: resolvedVoPath,
            ),
          );

          final activeWriter = clipWriter ??
              await ClipWriterFactory.resolveWriter(
                preferredSafUri: outputDirectoryPath.startsWith('content://')
                    ? outputDirectoryPath
                    : null,
              );

          final ext = resolvedConfig.effectiveExtension;
          final tempExportPath = p.join(
            tempDir.path,
            'audio_studio_${DateTime.now().millisecondsSinceEpoch}$ext',
          );
          _trackedTempFiles.add(tempExportPath);

          controller.add(
            const ProcessingProgress(
              status: ProcessingStatus.preparing,
              currentClipIndex: 0,
              totalClips: 1,
              currentClipName: 'Configuring audio mix...',
            ),
          );

          bool hasSourceAudio = true;
          try {
            final meta = await getMetadata(resolvedInputPath);
            hasSourceAudio = meta.duration > Duration.zero;
          } catch (_) {
            hasSourceAudio = true;
          }

          const compiler = AudioStudioCompiler();
          final cmdArgs = compiler.compile(
            config: resolvedConfig,
            outputPath: tempExportPath,
            hasSourceAudio: hasSourceAudio,
          );

          controller.add(
            const ProcessingProgress(
              status: ProcessingStatus.processing,
              currentClipIndex: 1,
              totalClips: 1,
              currentClipName: 'Mixing audio studio tracks...',
              currentClipProgress: 0.0,
              overallProgress: 0.0,
            ),
          );

          final success = await _executeSession(
            cmdArgs,
            resolvedConfig.videoDurationSeconds,
            (progress) {
              if (!_isCancelled && !controller.isClosed) {
                controller.add(
                  ProcessingProgress(
                    status: ProcessingStatus.processing,
                    currentClipIndex: 1,
                    totalClips: 1,
                    currentClipName: 'Mixing audio studio tracks...',
                    currentClipProgress: progress,
                    overallProgress: progress,
                  ),
                );
              }
            },
          );

          if (_isCancelled) {
            _emitCancelled(controller, 1, 1, outputPaths);
            return;
          }

          if (!success) {
            throw const VideoProcessingException(
              'FFmpeg audio studio processing failed.',
            );
          }

          final tempFile = File(tempExportPath);
          if (!await tempFile.exists() || await tempFile.length() == 0) {
            throw const VideoProcessingException(
              'Audio studio output file is empty or missing.',
            );
          }

          final baseName =
              resolvedConfig.customFileName?.trim().isNotEmpty == true
                  ? resolvedConfig.customFileName!.trim()
                  : '${p.basenameWithoutExtension(resolvedInputPath)}_audio';
          final outputFileName = '$baseName$ext';

          final finalUri = await activeWriter.writeClip(
            sourceTempFile: tempFile,
            fileName: outputFileName,
            duplicateHandling: duplicateHandling,
          );

          outputPaths.add(finalUri);
          _safeDelete(tempExportPath);

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.completed,
              currentClipIndex: 1,
              totalClips: 1,
              currentClipProgress: 1.0,
              overallProgress: 1.0,
              currentClipName: 'Audio Studio export complete',
              outputPaths: List.unmodifiable(outputPaths),
            ),
          );
          await controller.close();
        } catch (e, st) {
          if (_isCancelled) {
            _emitCancelled(controller, 0, 1, outputPaths);
          } else {
            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.error,
                currentClipIndex: 1,
                totalClips: 1,
                errorMessage: e.toString(),
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );
            controller.addError(e, st);
            await controller.close();
          }
        } finally {
          if (tempStreamedInput != null) _safeDelete(tempStreamedInput);
          if (tempStreamedMusic != null) _safeDelete(tempStreamedMusic);
          if (tempStreamedVo != null) _safeDelete(tempStreamedVo);
          _cleanupAllTempFiles();
        }
      },
      onCancel: () async {
        await cancel();
      },
    );

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
    _isCancelled = false;
    final tempDir = await getTemporaryDirectory();
    final ext = format.extension;
    final outputPath = outputFilePath ??
        p.join(
          tempDir.path,
          'screenshot_${DateTime.now().millisecondsSinceEpoch}_${(timestampSeconds * 1000).round()}$ext',
        );

    final args = ScreenshotCompiler.buildCaptureArgs(
      inputPath: inputPath,
      timestampSeconds: timestampSeconds,
      outputPath: outputPath,
      format: format,
      jpegQuality: jpegQuality,
    );

    AppLogger.info(
      'FFmpeg captureSingleFrame command: ffmpeg ${args.join(' ')}',
    );
    final session = await FFmpegKit.executeWithArguments(args);
    _activeSessionId = session.getSessionId();
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      final outputFile = File(outputPath);
      if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
        throw const VideoProcessingException(
          'Screenshot output file was empty',
        );
      }
      _trackedTempFiles.add(outputPath);
      return outputPath;
    } else {
      final logs = await session.getAllLogsAsString();
      throw VideoProcessingException('Screenshot capture failed: $logs');
    }
  }

  @override
  Stream<ProcessingProgress> captureScreenshots({
    required ScreenshotConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    late StreamController<ProcessingProgress> controller;
    _isCancelled = false;

    controller = StreamController<ProcessingProgress>(
      onListen: () async {
        final outputPaths = <String>[];
        final plannedItems = config.calculatePlannedItems();
        final totalFrames = plannedItems.length;

        if (totalFrames == 0) {
          controller.add(
            const ProcessingProgress(
              status: ProcessingStatus.completed,
              currentClipIndex: 0,
              totalClips: 0,
              currentClipName: 'No frames selected',
              outputPaths: [],
            ),
          );
          await controller.close();
          return;
        }

        try {
          final effectiveWriter = clipWriter ??
              await ClipWriterFactory.resolveWriter(
                preferredSafUri: outputDirectoryPath,
              );

          final tempDir = await getTemporaryDirectory();

          for (int i = 0; i < totalFrames; i++) {
            if (_isCancelled) {
              _emitCancelled(controller, i, totalFrames, outputPaths);
              return;
            }

            final item = plannedItems[i];
            final tempOutput = p.join(
              tempDir.path,
              'temp_${DateTime.now().millisecondsSinceEpoch}_${item.outputFileName}',
            );
            _trackedTempFiles.add(tempOutput);

            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.processing,
                currentClipIndex: i + 1,
                totalClips: totalFrames,
                currentClipName: item.outputFileName,
                currentClipProgress: 0.1,
                overallProgress: i / totalFrames,
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );

            final args = ScreenshotCompiler.buildCaptureArgs(
              inputPath: config.videoPath,
              timestampSeconds: item.timestampSeconds,
              outputPath: tempOutput,
              format: config.format,
              jpegQuality: config.jpegQuality,
            );

            final session = await FFmpegKit.executeWithArguments(args);
            _activeSessionId = session.getSessionId();
            final returnCode = await session.getReturnCode();

            if (!ReturnCode.isSuccess(returnCode)) {
              final logs = await session.getAllLogsAsString();
              throw VideoProcessingException(
                'Frame extraction failed for ${item.outputFileName}: $logs',
              );
            }

            final tempFile = File(tempOutput);
            if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
              throw VideoProcessingException(
                'Extracted frame ${item.outputFileName} was missing or empty',
              );
            }

            final finalUri = await effectiveWriter.writeClip(
              sourceTempFile: tempFile,
              fileName: item.outputFileName,
              duplicateHandling: duplicateHandling,
            );

            outputPaths.add(finalUri);
            _safeDelete(tempOutput);

            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.processing,
                currentClipIndex: i + 1,
                totalClips: totalFrames,
                currentClipName: item.outputFileName,
                currentClipProgress: 1.0,
                overallProgress: (i + 1) / totalFrames,
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );
          }

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.completed,
              currentClipIndex: totalFrames,
              totalClips: totalFrames,
              currentClipProgress: 1.0,
              overallProgress: 1.0,
              currentClipName:
                  'All $totalFrames screenshots saved successfully',
              outputPaths: List.unmodifiable(outputPaths),
            ),
          );
          await controller.close();
        } catch (e, st) {
          if (_isCancelled) {
            _emitCancelled(controller, 0, totalFrames, outputPaths);
          } else {
            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.error,
                currentClipIndex: outputPaths.length + 1,
                totalClips: totalFrames,
                errorMessage: e.toString(),
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );
            controller.addError(e, st);
            await controller.close();
          }
        } finally {
          _cleanupAllTempFiles();
        }
      },
      onCancel: () async {
        await cancel();
      },
    );

    return controller.stream;
  }

  @override
  Stream<ProcessingProgress> mergeVideos({
    required MergeConfig config,
    required String outputDirectoryPath,
    ClipWriter? clipWriter,
    DuplicateHandling duplicateHandling = DuplicateHandling.overwrite,
  }) {
    late StreamController<ProcessingProgress> controller;
    _isCancelled = false;

    controller = StreamController<ProcessingProgress>(
      onListen: () async {
        final outputPaths = <String>[];
        final tempStreamedFiles = <String>[];
        String? tempConcatListFile;

        try {
          final freeBytes = await StorageBridge.getFreeDiskSpace();
          const minRequiredBytes = 200 * 1024 * 1024;
          if (freeBytes < minRequiredBytes) {
            throw const StorageAccessException(
              'Insufficient storage space. At least 200MB free space required for video merge.',
              path: 'device_storage',
            );
          }

          if (config.clips.length < 2) {
            throw const VideoProcessingException(
              'At least two video clips are required for merging.',
            );
          }

          final tempDir = await getTemporaryDirectory();

          // 1. Resolve content:// URIs for each clip
          final resolvedClips = <MergeClipItem>[];
          for (int i = 0; i < config.clips.length; i++) {
            final clip = config.clips[i];
            String path = clip.videoPath;
            if (path.startsWith('content://')) {
              final streamedPath = p.join(
                tempDir.path,
                'merge_input_${i}_${DateTime.now().millisecondsSinceEpoch}.mp4',
              );
              _trackedTempFiles.add(streamedPath);
              tempStreamedFiles.add(streamedPath);
              path = await StorageBridge.copyContentUriToTempFile(
                contentUri: path,
                tempDestPath: streamedPath,
              );
            }
            resolvedClips.add(clip.copyWith(videoPath: path));
          }

          final resolvedConfig = config.copyWith(clips: resolvedClips);

          final activeWriter = clipWriter ??
              await ClipWriterFactory.resolveWriter(
                preferredSafUri: outputDirectoryPath.startsWith('content://')
                    ? outputDirectoryPath
                    : null,
              );

          final tempExportPath = p.join(
            tempDir.path,
            'merge_output_${DateTime.now().millisecondsSinceEpoch}.mp4',
          );
          _trackedTempFiles.add(tempExportPath);

          controller.add(
            const ProcessingProgress(
              status: ProcessingStatus.preparing,
              currentClipIndex: 0,
              totalClips: 1,
              currentClipName: 'Configuring video merge...',
            ),
          );

          final method = resolvedConfig.effectiveMethod;
          List<String> cmdArgs;

          if (method == MergeMethod.fast) {
            tempConcatListFile = p.join(
              tempDir.path,
              'concat_list_${DateTime.now().millisecondsSinceEpoch}.txt',
            );
            _trackedTempFiles.add(tempConcatListFile);

            final listContent = MergeFilterCompiler.generateConcatListContent(
              resolvedClips.map((c) => c.videoPath).toList(),
            );
            await File(tempConcatListFile).writeAsString(listContent);

            cmdArgs = MergeFilterCompiler.buildFastConcatArgs(
              listFilePath: tempConcatListFile,
              outputPath: tempExportPath,
            );
          } else {
            cmdArgs = MergeFilterCompiler.buildComplexMergeArgs(
              config: resolvedConfig,
              outputPath: tempExportPath,
            );
          }

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.processing,
              currentClipIndex: 1,
              totalClips: 1,
              currentClipName: resolvedConfig.effectiveBaseName,
              currentClipProgress: 0.0,
              overallProgress: 0.0,
            ),
          );

          final totalDuration = resolvedConfig.calculateTotalDurationSeconds();

          final success = await _executeSession(cmdArgs, totalDuration, (
            progress,
          ) {
            if (!_isCancelled && !controller.isClosed) {
              controller.add(
                ProcessingProgress(
                  status: ProcessingStatus.processing,
                  currentClipIndex: 1,
                  totalClips: 1,
                  currentClipName: resolvedConfig.effectiveBaseName,
                  currentClipProgress: progress,
                  overallProgress: progress,
                ),
              );
            }
          });

          if (_isCancelled) {
            _emitCancelled(controller, 1, 1, outputPaths);
            return;
          }

          if (!success) {
            throw const VideoProcessingException(
              'FFmpeg video merge processing failed.',
            );
          }

          final tempFile = File(tempExportPath);
          if (!await tempFile.exists() || await tempFile.length() == 0) {
            throw const VideoProcessingException(
              'Merged video output file is empty or missing.',
            );
          }

          final outputFileName = '${resolvedConfig.effectiveBaseName}.mp4';
          final savedUri = await activeWriter.writeClip(
            sourceTempFile: tempFile,
            fileName: outputFileName,
            duplicateHandling: duplicateHandling,
          );

          outputPaths.add(savedUri);

          controller.add(
            ProcessingProgress(
              status: ProcessingStatus.completed,
              currentClipIndex: 1,
              totalClips: 1,
              currentClipProgress: 1.0,
              overallProgress: 1.0,
              currentClipName: 'Video merge complete',
              outputPaths: List.unmodifiable(outputPaths),
            ),
          );
          await controller.close();
        } catch (e, st) {
          AppLogger.error(
            'Failed to merge videos: $e',
            error: e,
            stackTrace: st,
          );
          if (!_isCancelled && !controller.isClosed) {
            controller.add(
              ProcessingProgress(
                status: ProcessingStatus.error,
                currentClipIndex: 1,
                totalClips: 1,
                errorMessage: e.toString(),
                outputPaths: List.unmodifiable(outputPaths),
              ),
            );
            controller.addError(e, st);
            await controller.close();
          }
        } finally {
          _cleanupAllTempFiles();
        }
      },
      onCancel: () async {
        await cancel();
      },
    );

    return controller.stream;
  }

  void _emitCancelled(
    StreamController<ProcessingProgress> controller,
    int index,
    int total,
    List<String> paths,
  ) {
    if (!controller.isClosed) {
      controller.add(
        ProcessingProgress(
          status: ProcessingStatus.cancelled,
          currentClipIndex: index,
          totalClips: total,
          outputPaths: List.unmodifiable(paths),
        ),
      );
      controller.close();
    }
  }

  void _safeDelete(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        f.deleteSync();
      }
      _trackedTempFiles.remove(path);
    } catch (_) {}
  }

  void _cleanupAllTempFiles() {
    for (final path in _trackedTempFiles.toList()) {
      _safeDelete(path);
    }
    _trackedTempFiles.clear();
  }

  @override
  Future<void> cancel() async {
    _isCancelled = true;
    AppLogger.info('Cancelling active FFmpeg session...');
    try {
      if (_activeSessionId != null) {
        await FFmpegKit.cancel(_activeSessionId);
      } else {
        await FFmpegKit.cancel();
      }
    } catch (e) {
      AppLogger.warning('Error while cancelling FFmpeg session: $e');
    } finally {
      _cleanupAllTempFiles();
    }
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}
