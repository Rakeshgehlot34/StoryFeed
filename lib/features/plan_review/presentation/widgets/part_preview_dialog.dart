import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/utils/formatters.dart';
import '../../../player/data/player_service.dart';
import '../../../split_config/domain/models/clip_plan.dart';
import '../../../split_config/domain/models/overlay_spec.dart';
import '../../../video_picker/domain/models/picked_video.dart';

/// Modal dialog for previewing an individual planned video clip segment with its overlay.
class PartPreviewDialog extends ConsumerStatefulWidget {
  final PickedVideo video;
  final ClipPlanItem item;
  final ClipPlan plan;

  const PartPreviewDialog({
    super.key,
    required this.video,
    required this.item,
    required this.plan,
  });

  @override
  ConsumerState<PartPreviewDialog> createState() => _PartPreviewDialogState();
}

class _PartPreviewDialogState extends ConsumerState<PartPreviewDialog> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initClipPlayback());
  }

  Future<void> _initClipPlayback() async {
    try {
      final player = ref.read(playerServiceProvider);
      final startPosition = Duration(
        milliseconds: (widget.item.startSeconds * 1000).round(),
      );

      await player.openVideo(
        path: widget.video.path,
        autoPlay: true,
        seekToPosition: startPosition,
      );

      if (mounted) {
        player.addListener(_onPlaybackUpdate);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not preview clip: $e';
        });
      }
    }
  }

  void _onPlaybackUpdate() {
    if (!mounted) return;
    final player = ref.read(playerServiceProvider);
    if (!player.isInitialized) return;

    final posMs = player.position.inMilliseconds;
    final endMs = (widget.item.endSeconds * 1000).round();
    final startMs = (widget.item.startSeconds * 1000).round();

    // Auto-loop within clip segment boundaries
    if (posMs >= endMs) {
      player.seekTo(Duration(milliseconds: startMs));
    }
    setState(() {});
  }

  @override
  void dispose() {
    final player = ref.read(playerServiceProvider);
    player.removeListener(_onPlaybackUpdate);
    player.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final player = ref.watch(playerServiceProvider);
    final controller = player.controller;

    final startMs = (widget.item.startSeconds * 1000).round();
    final endMs = (widget.item.endSeconds * 1000).round();
    final clipTotalMs = (endMs - startMs).clamp(1, 180000);
    final currentOffsetMs = (player.position.inMilliseconds - startMs).clamp(
      0,
      clipTotalMs,
    );
    final clipProgress = (currentOffsetMs / clipTotalMs).clamp(0.0, 1.0);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      title: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '${widget.item.index}',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.formattedName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.item.formattedTimeRange} (${widget.item.formattedDuration})',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // Video Preview Area
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                color: Colors.black,
                child: _isLoading
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _errorMessage != null
                        ? SizedBox(
                            height: 200,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: colorScheme.error,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          )
                        : (controller != null && player.isInitialized)
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  AspectRatio(
                                    aspectRatio:
                                        controller.value.aspectRatio > 0
                                            ? controller.value.aspectRatio
                                            : (widget.plan.canvasSpec.width /
                                                widget.plan.canvasSpec.height),
                                    child: VideoPlayer(controller),
                                  ),
                                  // Overlay Text Preview
                                  if (widget.item.resolvedMessage != null &&
                                      widget.item.resolvedMessage!
                                          .isNotEmpty) ...[
                                    _buildOverlayPreview(
                                      widget.item.resolvedMessage!,
                                      widget.plan.overlaySpec,
                                    ),
                                  ],
                                  // Play / Pause Tap Overlay
                                  GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () {
                                      if (player.isPlaying) {
                                        player.pause();
                                      } else {
                                        player.play();
                                      }
                                    },
                                    child: AnimatedOpacity(
                                      opacity: player.isPlaying ? 0.0 : 0.8,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Container(
                                        color: Colors.black38,
                                        child: Center(
                                          child: Icon(
                                            player.isPlaying
                                                ? Icons.pause_circle_filled
                                                : Icons.play_circle_filled,
                                            size: 56,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox(
                                height: 200,
                                child: Center(
                                  child: Icon(
                                    Icons.videocam_off_outlined,
                                    color: Colors.white54,
                                    size: 40,
                                  ),
                                ),
                              ),
              ),
            ),
            const SizedBox(height: 12),
            // Clip Segment Progress Bar
            LinearProgressIndicator(
              value: clipProgress,
              minHeight: 4,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Formatters.formatSeconds(currentOffsetMs / 1000.0),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  widget.item.formattedDuration,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Replay Clip'),
          onPressed: () {
            player.seekTo(
              Duration(
                milliseconds: (widget.item.startSeconds * 1000).round(),
              ),
            );
            player.play();
          },
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildOverlayPreview(String text, OverlaySpec spec) {
    Alignment alignment = Alignment.topCenter;
    if (spec.position == OverlayPosition.bottomCenter) {
      alignment = Alignment.bottomCenter;
    } else if (spec.position == OverlayPosition.center) {
      alignment = Alignment.center;
    }

    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: spec.boxColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: spec.textColor,
              fontSize: spec.fontSize.clamp(10.0, 18.0),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
