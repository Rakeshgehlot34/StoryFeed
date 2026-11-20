import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../player/data/player_service.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../domain/models/screenshot_config.dart';
import '../../domain/screenshot_compiler.dart';
import '../controllers/screenshot_controller.dart';
import '../widgets/screenshot_preview_dialog.dart';

class ScreenshotScreen extends ConsumerStatefulWidget {
  const ScreenshotScreen({super.key});

  @override
  ConsumerState<ScreenshotScreen> createState() => _ScreenshotScreenState();
}

class _ScreenshotScreenState extends ConsumerState<ScreenshotScreen> {
  double _scrubberPositionSeconds = 0.0;
  bool _isScrubbing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pickerVideo = ref.read(videoPickerControllerProvider).value;
      if (pickerVideo != null &&
          ref.read(screenshotControllerProvider).video == null) {
        ref.read(screenshotControllerProvider.notifier).setVideo(pickerVideo);
        ref.read(playerServiceProvider).openVideo(path: pickerVideo.path);
      }
    });
  }

  void _syncScrubberWithPlayer(PlayerService player) {
    if (!_isScrubbing && player.isInitialized) {
      final pos = player.position.inMilliseconds / 1000.0;
      if ((pos - _scrubberPositionSeconds).abs() > 0.05) {
        setState(() {
          _scrubberPositionSeconds = pos;
        });
      }
    }
  }

  void _pickVideo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(videoPickerControllerProvider.notifier)
                    .pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Browse Files'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(videoPickerControllerProvider.notifier).pickFromFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(screenshotControllerProvider);
    final controller = ref.read(screenshotControllerProvider.notifier);
    final playerService = ref.watch(playerServiceProvider);

    // Sync player position
    _syncScrubberWithPlayer(playerService);

    // Synchronize video from global picker if updated
    ref.listen(videoPickerControllerProvider, (prev, next) {
      final nextVideo = next.value;
      if (nextVideo != null && state.video?.path != nextVideo.path) {
        controller.setVideo(nextVideo);
        ref.read(playerServiceProvider).openVideo(path: nextVideo.path);
      }
    });

    final video = state.video;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenshot Capture'),
        actions: [
          if (video != null)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change Video',
              onPressed: () => _pickVideo(context),
            ),
        ],
      ),
      body: _buildBody(context, state, controller, playerService),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
    PlayerService player,
  ) {
    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: LoadingSkeleton.card(height: 200),
      );
    }

    if (state.errorMessage != null && state.video == null) {
      return ErrorState(
        message: state.errorMessage!,
        onRetry: () => _pickVideo(context),
      );
    }

    if (state.video == null) {
      return EmptyState(
        icon: Icons.camera_alt_outlined,
        title: 'No Video Selected',
        message:
            'Select a video to capture and extract high-resolution screenshots.',
        actionLabel: 'Select Video',
        onAction: () => _pickVideo(context),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Video Player & Playhead Scrubber Card
          _buildPlayerCard(context, state, controller, player),
          const SizedBox(height: AppTokens.spaceMd),

          // 2. Mode Selector Chips
          _buildModeSelector(context, state, controller),
          const SizedBox(height: AppTokens.spaceMd),

          // 3. Mode Contextual Panel
          _buildModePanel(context, state, controller, player),
          const SizedBox(height: AppTokens.spaceMd),

          // 4. Format & Quality Settings Card
          _buildFormatCard(context, state, controller),
          const SizedBox(height: AppTokens.spaceMd),

          // 5. Session Captured Frames Section
          if (state.capturedSessionFrames.isNotEmpty)
            _buildSessionGallerySection(context, state, controller),
          const SizedBox(height: AppTokens.spaceXl),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
    PlayerService player,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalDuration = state.config.videoDurationSeconds;
    final effectiveDuration = totalDuration > 0 ? totalDuration : 1.0;

    return SectionCard(
      title: 'Video Playhead Scrubber',
      child: Column(
        children: [
          // Video preview surface
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            clipBehavior: Clip.antiAlias,
            child: player.isInitialized && player.controller != null
                ? AspectRatio(
                    aspectRatio: player.controller!.value.aspectRatio > 0
                        ? player.controller!.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(player.controller!),
                  )
                : const Center(
                    child: Icon(
                      Icons.movie_outlined,
                      color: Colors.white38,
                      size: 48,
                    ),
                  ),
          ),
          const SizedBox(height: AppTokens.spaceSm),

          // Play/Pause & Position Display Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  player.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: colorScheme.primary,
                  size: 32,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (player.isPlaying) {
                    player.pause();
                  } else {
                    player.play();
                  }
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                  vertical: AppTokens.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Text(
                  '${ScreenshotCompiler.formatTimestamp(_scrubberPositionSeconds)} / ${ScreenshotCompiler.formatTimestamp(totalDuration)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Slider
          Slider(
            value: _scrubberPositionSeconds.clamp(0.0, effectiveDuration),
            min: 0.0,
            max: effectiveDuration,
            onChanged: (val) {
              setState(() {
                _isScrubbing = true;
                _scrubberPositionSeconds = val;
              });
              player.seekTo(Duration(milliseconds: (val * 1000).round()));
            },
            onChangeEnd: (val) {
              setState(() {
                _isScrubbing = false;
              });
              player.seekTo(Duration(milliseconds: (val * 1000).round()));
            },
          ),

          // Nudge bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NudgeButton(
                label: '-1s',
                onPressed: () => _nudgePosition(player, -1.0, totalDuration),
              ),
              _NudgeButton(
                label: '-0.1s',
                onPressed: () => _nudgePosition(player, -0.1, totalDuration),
              ),
              _NudgeButton(
                label: '+0.1s',
                onPressed: () => _nudgePosition(player, 0.1, totalDuration),
              ),
              _NudgeButton(
                label: '+1s',
                onPressed: () => _nudgePosition(player, 1.0, totalDuration),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _nudgePosition(PlayerService player, double delta, double maxDuration) {
    HapticFeedback.selectionClick();
    final next = (_scrubberPositionSeconds + delta).clamp(0.0, maxDuration);
    setState(() => _scrubberPositionSeconds = next);
    player.seekTo(Duration(milliseconds: (next * 1000).round()));
  }

  Widget _buildModeSelector(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
  ) {
    return SegmentedButton<ScreenshotCaptureMode>(
      segments: const [
        ButtonSegment(
          value: ScreenshotCaptureMode.single,
          icon: Icon(Icons.camera_alt_rounded),
          label: Text('Instant Snap'),
        ),
        ButtonSegment(
          value: ScreenshotCaptureMode.timestamps,
          icon: Icon(Icons.list_alt_rounded),
          label: Text('Timestamps'),
        ),
        ButtonSegment(
          value: ScreenshotCaptureMode.interval,
          icon: Icon(Icons.auto_awesome_motion_rounded),
          label: Text('Interval'),
        ),
      ],
      selected: {state.config.mode},
      onSelectionChanged: (selected) {
        HapticFeedback.selectionClick();
        controller.setMode(selected.first);
      },
    );
  }

  Widget _buildModePanel(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
    PlayerService player,
  ) {
    switch (state.config.mode) {
      case ScreenshotCaptureMode.single:
        return _buildSingleSnapPanel(context, state, controller);
      case ScreenshotCaptureMode.timestamps:
        return _buildTimestampsPanel(context, state, controller);
      case ScreenshotCaptureMode.interval:
        return _buildIntervalPanel(context, state, controller);
    }
  }

  Widget _buildSingleSnapPanel(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
  ) {
    final timeStr = ScreenshotCompiler.formatTimestamp(
      _scrubberPositionSeconds,
    );

    return SectionCard(
      title: 'Quick Playhead Capture',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Capture exact full-resolution video frame at the current playhead position without re-encoding.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppTokens.spaceMd),
          PrimaryButton(
            icon: Icons.camera_rounded,
            label: state.isCapturing
                ? 'Snapping Frame...'
                : 'Snap Frame at $timeStr',
            isLoading: state.isCapturing,
            onPressed: state.isCapturing
                ? null
                : () async {
                    await HapticFeedback.heavyImpact();
                    final item = await controller.capturePlayheadFrame(
                      _scrubberPositionSeconds,
                    );
                    if (context.mounted && item != null) {
                      await ScreenshotPreviewDialog.show(context, item);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampsPanel(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
  ) {
    final theme = Theme.of(context);
    final timestamps = state.config.customTimestamps;
    final timeStr = ScreenshotCompiler.formatTimestamp(
      _scrubberPositionSeconds,
    );

    return SectionCard(
      title: 'Target Timestamps (${timestamps.length})',
      trailing: timestamps.isNotEmpty
          ? TextButton(
              onPressed: () => controller.clearTimestamps(),
              child: const Text('Clear All'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: Text('Add Current Time ($timeStr)'),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    controller.addTimestamp(_scrubberPositionSeconds);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          if (timestamps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceMd),
              child: Text(
                'Scrub to a moment in the video and tap "Add Current Time" to create split capture targets.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            )
          else
            Wrap(
              spacing: AppTokens.spaceSm,
              runSpacing: AppTokens.spaceXs,
              children: timestamps.map((t) {
                return Chip(
                  label: Text(ScreenshotCompiler.formatTimestamp(t)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    HapticFeedback.selectionClick();
                    controller.removeTimestamp(t);
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: AppTokens.spaceMd),
          if (timestamps.isNotEmpty)
            PrimaryButton(
              icon: Icons.burst_mode_rounded,
              label: 'Batch Extract ${timestamps.length} Frames',
              onPressed: () => _dispatchBatchCapture(context, controller),
            ),
        ],
      ),
    );
  }

  Widget _buildIntervalPanel(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
  ) {
    final theme = Theme.of(context);
    final config = state.config;
    final planned = config.calculatePlannedTimestamps();
    final estimatedSize = config.estimateTotalSizeBytes();

    return SectionCard(
      title: 'Periodic Interval Extraction',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Interval Type Selector
          SegmentedButton<IntervalType>(
            segments: const [
              ButtonSegment(
                value: IntervalType.byDuration,
                label: Text('Every X Seconds'),
              ),
              ButtonSegment(
                value: IntervalType.byCount,
                label: Text('N Equal Frames'),
              ),
            ],
            selected: {config.intervalType},
            onSelectionChanged: (selected) {
              HapticFeedback.selectionClick();
              controller.setIntervalType(selected.first);
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),

          // Duration slider or Count slider
          if (config.intervalType == IntervalType.byDuration) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Step Interval:'),
                Text(
                  '${config.intervalSeconds.toStringAsFixed(1)}s',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: config.intervalSeconds.clamp(0.5, 30.0),
              min: 0.5,
              max: 30.0,
              divisions: 59,
              onChanged: (val) => controller.setIntervalSeconds(val),
            ),
            Wrap(
              spacing: AppTokens.spaceSm,
              children: [1.0, 2.0, 5.0, 10.0].map((sec) {
                return ActionChip(
                  label: Text('${sec.toInt()}s'),
                  onPressed: () => controller.setIntervalSeconds(sec),
                );
              }).toList(),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Frame Count:'),
                Text(
                  '${config.frameCount} frames',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: config.frameCount.toDouble().clamp(2.0, 50.0),
              min: 2.0,
              max: 50.0,
              divisions: 48,
              onChanged: (val) => controller.setFrameCount(val.round()),
            ),
            Wrap(
              spacing: AppTokens.spaceSm,
              children: [5, 10, 20, 50].map((count) {
                return ActionChip(
                  label: Text('$count frames'),
                  onPressed: () => controller.setFrameCount(count),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppTokens.spaceMd),

          // Metrics Preview
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceSm),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Total Frames', style: theme.textTheme.labelSmall),
                    Text(
                      '${planned.length}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Estimated Disk', style: theme.textTheme.labelSmall),
                    Text(
                      Formatters.formatFileSize(estimatedSize),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),

          PrimaryButton(
            icon: Icons.photo_library_rounded,
            label: 'Extract ${planned.length} Frames to Queue',
            onPressed: () => _dispatchBatchCapture(context, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _dispatchBatchCapture(
    BuildContext context,
    ScreenshotController controller,
  ) async {
    await HapticFeedback.mediumImpact();
    final job = await controller.dispatchBatchCapture();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Screenshot job added to queue: ${job.title}'),
          action: SnackBarAction(
            label: 'View Queue',
            onPressed: () => context.push(AppRoutes.jobs),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildFormatCard(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
  ) {
    final theme = Theme.of(context);
    final config = state.config;

    return SectionCard(
      title: 'Image Format & Quality',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ScreenshotImageFormat>(
            segments: const [
              ButtonSegment(
                value: ScreenshotImageFormat.png,
                label: Text('PNG (Lossless)'),
              ),
              ButtonSegment(
                value: ScreenshotImageFormat.jpeg,
                label: Text('JPEG (Compressed)'),
              ),
            ],
            selected: {config.format},
            onSelectionChanged: (selected) {
              HapticFeedback.selectionClick();
              controller.setFormat(selected.first);
            },
          ),
          if (config.format == ScreenshotImageFormat.jpeg) ...[
            const SizedBox(height: AppTokens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('JPEG Quality:'),
                Text(
                  '${config.jpegQuality}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: config.jpegQuality.toDouble().clamp(50.0, 100.0),
              min: 50.0,
              max: 100.0,
              divisions: 10,
              onChanged: (val) => controller.setJpegQuality(val.round()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionGallerySection(
    BuildContext context,
    ScreenshotState state,
    ScreenshotController controller,
  ) {
    final theme = Theme.of(context);
    final frames = state.capturedSessionFrames;
    final selectedCount = state.selectedFrameIds.length;

    return SectionCard(
      title: 'Session Captures (${frames.length})',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: state.isAllSelected
                ? () => controller.clearSelection()
                : () => controller.selectAll(),
            child: Text(state.isAllSelected ? 'Deselect All' : 'Select All'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action Buttons Bar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.save_alt_rounded, size: 18),
                  label: Text(
                    selectedCount > 0
                        ? 'Save Selected ($selectedCount)'
                        : 'Save All to Gallery',
                  ),
                  onPressed: state.isSaving
                      ? null
                      : () async {
                          final saved =
                              await controller.saveSelectedToGallery();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Saved $saved frames to gallery'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              IconButton.outlined(
                tooltip: 'Delete Selected',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.deleteSelected();
                },
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),

          // Horizontal Thumbnail Strip
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: frames.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppTokens.spaceSm),
              itemBuilder: (context, index) {
                final frame = frames[index];
                final isSelected = state.selectedFrameIds.contains(frame.id);
                final file = frame.tempFilePath != null
                    ? File(frame.tempFilePath!)
                    : null;
                final exists = file != null && file.existsSync();

                return GestureDetector(
                  onTap: () async {
                    await HapticFeedback.lightImpact();
                    if (context.mounted) {
                      await ScreenshotPreviewDialog.show(context, frame);
                    }
                  },
                  child: Container(
                    width: 110,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (exists)
                          Image.file(file, fit: BoxFit.cover)
                        else
                          const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white38,
                            ),
                          ),

                        // Timestamp chip at bottom
                        Positioned(
                          left: 4,
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSm / 2,
                              ),
                            ),
                            child: Text(
                              frame.formattedTime,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // Selection Checkbox top-right
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.toggleSelection(frame.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black54,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 20,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),

                        // Saved Indicator top-left
                        if (frame.isSaved)
                          const Positioned(
                            top: 4,
                            left: 4,
                            child: Icon(
                              Icons.cloud_done_rounded,
                              size: 16,
                              color: Colors.greenAccent,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _NudgeButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
