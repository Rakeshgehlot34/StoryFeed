import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../output/domain/models/exported_clip.dart';
import '../../data/player_service.dart';

/// Full-screen capable video player for previewing exported shorts sequence using PlayerService.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final List<ExportedClip> clips;
  final int initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.clips,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late int _currentIndex;
  bool _showControls = true;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.clips.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPlayerForCurrentClip();
    });
  }

  Future<void> _initPlayerForCurrentClip() async {
    if (widget.clips.isEmpty) return;

    final clip = widget.clips[_currentIndex];
    final playerService = ref.read(playerServiceProvider);
    await playerService.openVideo(path: clip.path, autoPlay: true);
    await playerService.setPlaybackSpeed(_playbackSpeed);

    if (mounted) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && ref.read(playerServiceProvider).isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    ref.read(playerServiceProvider).setPlaybackSpeed(speed);
  }

  void _nextClip() {
    if (_currentIndex < widget.clips.length - 1) {
      setState(() => _currentIndex++);
      _initPlayerForCurrentClip();
    }
  }

  void _prevClip() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _initPlayerForCurrentClip();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    PlayerService.instance.stopAndRelease();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clips.isNotEmpty ? widget.clips[_currentIndex] : null;
    final playerService = ref.watch(playerServiceProvider);
    final controller = playerService.controller;

    return PopScope(
      onPopInvokedWithResult: (_, __) {
        playerService.pause();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: GestureDetector(
            onTap: _toggleControls,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildVideoSurface(controller, playerService.isInitialized),
                if (_showControls && clip != null) ...[
                  _buildTopBar(clip),
                  _buildCenterPlayPause(playerService),
                  _buildBottomControls(clip, playerService),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSurface(
    VideoPlayerController? controller,
    bool isInitialized,
  ) {
    if (controller == null || !isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : (9 / 16),
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildTopBar(ExportedClip clip) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXs,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Short ${_currentIndex + 1} of ${widget.clips.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    clip.fileName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<double>(
              icon: const Icon(Icons.speed_rounded, color: Colors.white),
              tooltip: 'Playback Speed',
              onSelected: _changeSpeed,
              itemBuilder: (_) => [0.5, 1.0, 1.25, 1.5, 2.0].map((s) {
                return PopupMenuItem(
                  value: s,
                  child: Text('${s}x${s == _playbackSpeed ? ' ✓' : ''}'),
                );
              }).toList(),
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: () {
                Share.shareXFiles([XFile(clip.path)], text: clip.fileName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPlayPause(PlayerService playerService) {
    final isPlaying = playerService.isPlaying;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 44,
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
            onPressed: _currentIndex > 0 ? _prevClip : null,
          ),
          const SizedBox(width: AppTokens.spaceLg),
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.black45,
            child: IconButton(
              iconSize: 40,
              icon: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                if (isPlaying) {
                  playerService.pause();
                } else {
                  playerService.play();
                  _startHideTimer();
                }
              },
            ),
          ),
          const SizedBox(width: AppTokens.spaceLg),
          IconButton(
            iconSize: 44,
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            onPressed: _currentIndex < widget.clips.length - 1
                ? _nextClip
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ExportedClip clip, PlayerService playerService) {
    final position = playerService.position;
    final duration = playerService.duration;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: position.inMilliseconds.toDouble().clamp(
                0.0,
                duration.inMilliseconds.toDouble() > 0
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
              ),
              min: 0.0,
              max: duration.inMilliseconds > 0
                  ? duration.inMilliseconds.toDouble()
                  : 1.0,
              onChanged: (val) {
                playerService.seekTo(Duration(milliseconds: val.round()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.formatDuration(position),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    Formatters.formatDuration(duration),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
