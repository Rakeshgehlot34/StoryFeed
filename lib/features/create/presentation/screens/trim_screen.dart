import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/router.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/validation/validators/select_video_validator.dart';
import '../../../../core/validation/validators/trim_validator.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../player/data/player_service.dart';
import '../../../split_config/domain/models/trim_range.dart';
import '../../../split_config/presentation/controllers/split_config_controller.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../widgets/interactive_trim_timeline.dart';
import '../widgets/wheel_time_picker_sheet.dart';

enum _NudgeTarget { start, end }

/// Step 2 of Create Flow: Frame-accurate trimming with live VideoPlayer,
/// custom-painted interactive dual-handle timeline, strictly clipped playhead,
/// zoom mode, wheel time picker, and auto-repeating nudge controls.
class TrimScreen extends ConsumerStatefulWidget {
  const TrimScreen({super.key});

  @override
  ConsumerState<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends ConsumerState<TrimScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _errorBannerKey = GlobalKey();

  int _startMs = 0;
  int _endMs = 60000;
  int _totalMs = 60000;
  int _playheadMs = 0;
  bool _isZoomed = false;
  bool _isScrubbing = false;
  bool _isPlayingSelection = false;
  String? _inlineError;
  _NudgeTarget _nudgeTarget = _NudgeTarget.start;

  Timer? _nudgeTimer;

  static const _selectValidator = SelectVideoValidator();
  static const _trimValidator = TrimValidator();

  @override
  void initState() {
    super.initState();
    final video = ref.read(videoPickerControllerProvider).valueOrNull;
    final savedTrim = ref.read(splitConfigControllerProvider).trimRange;

    _totalMs = video?.duration.inMilliseconds ?? 60000;
    if (_totalMs <= 0) _totalMs = 60000;

    _startMs = ((savedTrim?.startSeconds ?? 0.0) * 1000).round();
    _endMs = ((savedTrim?.endSeconds ?? (_totalMs / 1000.0)) * 1000)
        .round()
        .clamp(_startMs + 1000, _totalMs);
    _playheadMs = _startMs;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (video != null) {
        PlayerService.instance.openVideo(
          path: video.path,
          autoPlay: false,
          seekToPosition: Duration(milliseconds: _startMs),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _scrollController.dispose();
    _nudgeTimer?.cancel();
    PlayerService.instance.pause();
    super.dispose();
  }

  @override
  void didPushNext() {
    unawaited(PlayerService.instance.pause());
    _isPlayingSelection = false;
  }

  @override
  void didPop() {
    unawaited(PlayerService.instance.stopAndRelease());
    _isPlayingSelection = false;
  }

  double get _startSec => _startMs / 1000.0;
  double get _endSec => _endMs / 1000.0;
  double get _totalSec => _totalMs / 1000.0;
  int get _selectedDurationMs => (_endMs - _startMs).clamp(0, _totalMs);
  double get _selectedDurationSec => _selectedDurationMs / 1000.0;
  bool get _isValidDuration => _selectedDurationMs >= 1000;

  void _onStartChanged(int newStartMs) {
    setState(() {
      _startMs = newStartMs;
      _inlineError = null;
    });
    if (_playheadMs < _startMs) {
      _onSeekPosition(_startMs);
    }
  }

  void _onEndChanged(int newEndMs) {
    setState(() {
      _endMs = newEndMs;
      _inlineError = null;
    });
    if (_playheadMs > _endMs) {
      _onSeekPosition(_endMs);
    }
  }

  void _onSeekPosition(int targetMs) {
    setState(() {
      _playheadMs = targetMs.clamp(0, _totalMs);
    });
    PlayerService.instance.seekTo(
      Duration(milliseconds: _playheadMs),
      pauseAudioDuringSeek: _isScrubbing,
    );
  }

  void _setStartToCurrent() {
    final currentMs = PlayerService.instance.position.inMilliseconds;
    if (currentMs <= _endMs - 1000) {
      HapticFeedback.mediumImpact();
      _onStartChanged(currentMs.clamp(0, _totalMs));
    } else {
      AppMessenger.showWarning(context, AppStrings.valStartBeforeEnd);
    }
  }

  void _setEndToCurrent() {
    final currentMs = PlayerService.instance.position.inMilliseconds;
    if (currentMs >= _startMs + 1000) {
      HapticFeedback.mediumImpact();
      _onEndChanged(currentMs.clamp(0, _totalMs));
    } else {
      AppMessenger.showWarning(context, AppStrings.valRangeMin1s);
    }
  }

  void _jumpToStart() {
    HapticFeedback.selectionClick();
    _onSeekPosition(_startMs);
  }

  void _jumpToEnd() {
    HapticFeedback.selectionClick();
    _onSeekPosition(_endMs);
  }

  Future<void> _playSelection() async {
    await HapticFeedback.mediumImpact();
    setState(() {
      _isPlayingSelection = true;
    });
    await PlayerService.instance.seekTo(Duration(milliseconds: _startMs));
    await PlayerService.instance.play();
  }

  void _useFullVideo() {
    HapticFeedback.selectionClick();
    setState(() {
      _startMs = 0;
      _endMs = _totalMs;
      _inlineError = null;
    });
    _jumpToStart();
  }

  Future<void> _pickStartTime() async {
    final picked = await WheelTimePickerSheet.show(
      context: context,
      title: 'Set Start Position',
      initialSeconds: _startSec,
      minSeconds: 0.0,
      maxSeconds: (_endSec - 1.0).clamp(0.0, _totalSec),
      totalDurationSeconds: _totalSec,
      onPreviewSeek: (sec) {
        PlayerService.instance.seekTo(
          Duration(milliseconds: (sec * 1000).round()),
          pauseAudioDuringSeek: true,
        );
      },
    );

    if (picked != null && mounted) {
      _onStartChanged((picked * 1000).round());
      _jumpToStart();
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await WheelTimePickerSheet.show(
      context: context,
      title: 'Set End Position',
      initialSeconds: _endSec,
      minSeconds: (_startSec + 1.0).clamp(0.0, _totalSec),
      maxSeconds: _totalSec,
      totalDurationSeconds: _totalSec,
      onPreviewSeek: (sec) {
        PlayerService.instance.seekTo(
          Duration(milliseconds: (sec * 1000).round()),
          pauseAudioDuringSeek: true,
        );
      },
    );

    if (picked != null && mounted) {
      _onEndChanged((picked * 1000).round());
      _jumpToEnd();
    }
  }

  void _applyNudge(double deltaSeconds) {
    HapticFeedback.selectionClick();
    final deltaMs = (deltaSeconds * 1000).round();
    if (_nudgeTarget == _NudgeTarget.start) {
      final candidate = (_startMs + deltaMs).clamp(0, _endMs - 1000);
      _onStartChanged(candidate);
      _jumpToStart();
    } else {
      final candidate = (_endMs + deltaMs).clamp(_startMs + 1000, _totalMs);
      _onEndChanged(candidate);
      _jumpToEnd();
    }
  }

  void _startNudgeRepeating(double deltaSeconds) {
    _applyNudge(deltaSeconds);
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(const Duration(milliseconds: 350), () {
      _nudgeTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (mounted) _applyNudge(deltaSeconds);
      });
    });
  }

  void _stopNudgeRepeating() {
    _nudgeTimer?.cancel();
    _nudgeTimer = null;
  }

  void _onContinue() {
    final video = ref.read(videoPickerControllerProvider).valueOrNull;

    // 1. Run SelectVideoValidator
    final videoValidation = _selectValidator.validate(video);
    if (!videoValidation.isValid) {
      final issue = videoValidation.firstError!;
      AppMessenger.showIssue(
        context,
        issue,
        onAction: () => context.go(AppRoutes.home),
      );
      setState(() => _inlineError = issue.message);
      _scrollToError();
      return;
    }

    // 2. Run TrimValidator
    final trimValidation = _trimValidator.validate(
      startSeconds: _startSec,
      endSeconds: _endSec,
      totalDurationSeconds: _totalSec,
    );
    if (!trimValidation.isValid) {
      final issue = trimValidation.firstError!;
      AppMessenger.showIssue(context, issue);
      setState(() => _inlineError = issue.message);
      _scrollToError();
      return;
    }

    // Valid: save and proceed
    PlayerService.instance.pause();
    ref
        .read(splitConfigControllerProvider.notifier)
        .setTrimRange(TrimRange(startSeconds: _startSec, endSeconds: _endSec));
    context.push(AppRoutes.splitConfig);
  }

  void _scrollToError() {
    if (_errorBannerKey.currentContext != null) {
      Scrollable.ensureVisible(
        _errorBannerKey.currentContext!,
        duration: AppTokens.durationNormal,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playerService = ref.watch(playerServiceProvider);
    final config = ref.watch(splitConfigControllerProvider);
    final targetClipDuration = config.targetDurationSeconds;

    // Check if player position triggers selection pause in Play Selection mode
    if (_isPlayingSelection) {
      final currentMs = playerService.position.inMilliseconds;
      if (currentMs >= _endMs) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isPlayingSelection) {
            PlayerService.instance.pause();
            PlayerService.instance.seekTo(Duration(milliseconds: _startMs));
            setState(() {
              _isPlayingSelection = false;
              _playheadMs = _startMs;
            });
          }
        });
      }
    }

    // Keep playhead synchronized with player when not scrubbing
    if (!_isScrubbing && playerService.isInitialized) {
      final posMs = playerService.position.inMilliseconds;
      if ((posMs - _playheadMs).abs() > 50) {
        _playheadMs = posMs.clamp(0, _totalMs);
      }
    }

    // Reconcile player duration if different from probed metadata
    if (playerService.isInitialized &&
        playerService.duration.inMilliseconds > 0) {
      final pDur = playerService.duration.inMilliseconds;
      if (pDur != _totalMs && pDur < _totalMs) {
        _totalMs = pDur;
        if (_endMs > _totalMs) _endMs = _totalMs;
      }
    }

    final estimatedShorts = (_selectedDurationSec / targetClipDuration).ceil();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.trimTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceLg,
            vertical: AppTokens.spaceMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Preview Player
              _buildPlayerCard(playerService, colorScheme, theme),
              const SizedBox(height: AppTokens.spaceMd),

              // 2. Playhead & Custom Interactive Timeline Card
              SectionCard(
                title: 'Timeline & Range',
                trailing: IconButton(
                  tooltip: _isZoomed
                      ? 'Zoom Out to Full View'
                      : 'Zoom In on Selection',
                  icon: Icon(
                    _isZoomed
                        ? Icons.zoom_out_map_rounded
                        : Icons.zoom_in_rounded,
                    color: colorScheme.primary,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isZoomed = !_isZoomed);
                  },
                ),
                child: Column(
                  children: [
                    InteractiveTrimTimeline(
                      totalDurationMs: _totalMs,
                      startMs: _startMs,
                      endMs: _endMs,
                      playheadMs: _playheadMs,
                      isZoomed: _isZoomed,
                      onStartChanged: _onStartChanged,
                      onEndChanged: _onEndChanged,
                      onSeekPosition: _onSeekPosition,
                      onScrubbingStart: () =>
                          setState(() => _isScrubbing = true),
                      onScrubbingEnd: () =>
                          setState(() => _isScrubbing = false),
                    ),
                    const SizedBox(height: AppTokens.spaceSm),
                    _buildQuickJumpBar(colorScheme),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.spaceMd),

              // 3. Start & End Position Badges
              _buildTimeBadgesCard(colorScheme, theme),
              const SizedBox(height: AppTokens.spaceMd),

              // 4. Fine Nudge Controls
              _buildNudgeCard(colorScheme, theme),
              const SizedBox(height: AppTokens.spaceMd),

              // 5. Output Prediction or Error Banner
              KeyedSubtree(
                key: _errorBannerKey,
                child: _inlineError != null
                    ? InfoBanner(
                        message: _inlineError!,
                        type: InfoBannerType.error,
                      )
                    : !_isValidDuration
                    ? const InfoBanner(
                        message: AppStrings.valRangeMin1s,
                        type: InfoBannerType.error,
                      )
                    : InfoBanner(
                        message:
                            'Selected range will produce ~$estimatedShorts Shorts (${targetClipDuration}s preset).',
                        type: InfoBannerType.info,
                      ),
              ),
              const SizedBox(height: AppTokens.spaceXl),

              // 6. Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _useFullVideo,
                      child: const Text('Reset to Full'),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceMd),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: 'Next: Split Settings',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _onContinue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceXl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(
    PlayerService playerService,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (playerService.controller != null && playerService.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: playerService.controller!.value.aspectRatio,
                child: VideoPlayer(playerService.controller!),
              ),
            )
          else
            Center(
              child: LoadingSkeleton(
                width: 120,
                height: 40,
                borderRadius: AppTokens.borderRadiusSm,
              ),
            ),

          // Tap overlay to play/pause
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              if (playerService.isPlaying) {
                playerService.pause();
                _isPlayingSelection = false;
              } else {
                playerService.play();
              }
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: playerService.isPlaying ? 0.0 : 0.85,
                  duration: AppTokens.durationNormal,
                  child: Container(
                    padding: const EdgeInsets.all(AppTokens.spaceMd),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      playerService.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Time Overlay at bottom
          Positioned(
            left: AppTokens.spaceMd,
            bottom: AppTokens.spaceSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Text(
                Formatters.formatPrecise(
                  playerService.position.inMilliseconds / 1000.0,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            right: AppTokens.spaceMd,
            bottom: AppTokens.spaceSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: Text(
                Formatters.formatPrecise(_totalSec),
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickJumpBar(ColorScheme colorScheme) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Start (0:00)'),
          onPressed: _jumpToStart,
        ),
        ActionChip(
          avatar: Icon(
            _isPlayingSelection
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            size: 16,
          ),
          label: Text(_isPlayingSelection ? 'Pause' : 'Play Trim'),
          onPressed: _isPlayingSelection
              ? () {
                  PlayerService.instance.pause();
                  setState(() => _isPlayingSelection = false);
                }
              : _playSelection,
        ),
        ActionChip(
          avatar: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('End'),
          onPressed: _jumpToEnd,
        ),
      ],
    );
  }

  Widget _buildTimeBadgesCard(ColorScheme colorScheme, ThemeData theme) {
    return SectionCard(
      title: 'Trim Positions',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickStartTime,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppTokens.spaceMd),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _nudgeTarget == _NudgeTarget.start
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: _nudgeTarget == _NudgeTarget.start ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('START', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatPrecise(_startSec),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: InkWell(
                  onTap: _pickEndTime,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppTokens.spaceMd),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _nudgeTarget == _NudgeTarget.end
                            ? colorScheme.primary
                            : colorScheme.outlineVariant,
                        width: _nudgeTarget == _NudgeTarget.end ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('END', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(
                          Formatters.formatPrecise(_endSec),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.first_page_rounded, size: 16),
                  label: const Text('Set Start Here'),
                  onPressed: _setStartToCurrent,
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.last_page_rounded, size: 16),
                  label: const Text('Set End Here'),
                  onPressed: _setEndToCurrent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeCard(ColorScheme colorScheme, ThemeData theme) {
    return SectionCard(
      title: 'Fine Nudge Controls',
      child: Column(
        children: [
          SegmentedButton<_NudgeTarget>(
            segments: const [
              ButtonSegment(
                value: _NudgeTarget.start,
                label: Text('Adjust Start Marker'),
                icon: Icon(Icons.start_rounded),
              ),
              ButtonSegment(
                value: _NudgeTarget.end,
                label: Text('Adjust End Marker'),
                icon: Icon(Icons.pin_end_rounded),
              ),
            ],
            selected: {_nudgeTarget},
            onSelectionChanged: (set) {
              HapticFeedback.selectionClick();
              setState(() => _nudgeTarget = set.first);
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildNudgeButton('-1s', -1.0, colorScheme),
                _buildNudgeButton('-0.1s', -0.1, colorScheme),
                _buildNudgeButton('-1f', -0.033, colorScheme),
                const SizedBox(width: AppTokens.spaceSm),
                _buildNudgeButton('+1f', 0.033, colorScheme),
                _buildNudgeButton('+0.1s', 0.1, colorScheme),
                _buildNudgeButton('+1s', 1.0, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNudgeButton(
    String label,
    double delta,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTapDown: (_) => _startNudgeRepeating(delta),
        onTapUp: (_) => _stopNudgeRepeating(),
        onTapCancel: _stopNudgeRepeating,
        child: FilledButton.tonal(
          onPressed: () {},
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(48, 36),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
