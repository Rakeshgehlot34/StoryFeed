import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../player/data/player_service.dart';
import '../../domain/models/picked_video.dart';

class VideoPreviewCard extends ConsumerStatefulWidget {
  final PickedVideo video;
  final VoidCallback onClear;

  const VideoPreviewCard({
    super.key,
    required this.video,
    required this.onClear,
  });

  @override
  ConsumerState<VideoPreviewCard> createState() => _VideoPreviewCardState();
}

class _VideoPreviewCardState extends ConsumerState<VideoPreviewCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerServiceProvider).openVideo(path: widget.video.path);
    });
  }

  @override
  void didUpdateWidget(covariant VideoPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.path != widget.video.path) {
      ref.read(playerServiceProvider).openVideo(path: widget.video.path);
    }
  }

  @override
  void dispose() {
    // Pause playback when navigating away from video picker
    PlayerService.instance.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playerService = ref.watch(playerServiceProvider);
    final controller = playerService.controller;
    final isInitialized = playerService.isInitialized;
    final isPlaying = playerService.isPlaying;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Video Player Box / Thumbnail Area
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 220,
                color: Colors.black,
                child: isInitialized && controller != null
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio > 0
                              ? controller.value.aspectRatio
                              : (16 / 9),
                          child: VideoPlayer(controller),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.movie_outlined,
                              size: 48,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loading Preview...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Play / Pause Overlay Button
              if (isInitialized && controller != null)
                IconButton.filled(
                  iconSize: 42,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  onPressed: () {
                    if (isPlaying) {
                      playerService.pause();
                    } else {
                      playerService.play();
                    }
                  },
                ),

              // Clear Button (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 18,
                  child: IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      playerService.stopAndRelease();
                      widget.onClear();
                    },
                    tooltip: 'Select different video',
                  ),
                ),
              ),

              // Progress Bar (Bottom of video preview)
              if (isInitialized && controller != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: colorScheme.primary,
                      bufferedColor: Colors.white30,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
            ],
          ),

          // File Details & Metadata Chips
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.fileName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetaChip(
                      context,
                      icon: Icons.timer_outlined,
                      label: widget.video.formattedDuration,
                    ),
                    _buildMetaChip(
                      context,
                      icon: Icons.storage_outlined,
                      label: widget.video.formattedSize,
                    ),
                    _buildMetaChip(
                      context,
                      icon: Icons.aspect_ratio_outlined,
                      label: widget.video.resolution,
                    ),
                    _buildMetaChip(
                      context,
                      icon: Icons.speed_outlined,
                      label: '${widget.video.fps.toStringAsFixed(0)} FPS',
                    ),
                    if (widget.video.isVertical)
                      _buildMetaChip(
                        context,
                        icon: Icons.stay_current_portrait_outlined,
                        label: 'Vertical',
                        highlight: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: highlight
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
