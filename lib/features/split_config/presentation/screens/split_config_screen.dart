import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/validation/validators/background_validator.dart';
import '../../../../core/validation/validators/overlay_validator.dart';
import '../../../../core/validation/validators/split_settings_validator.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../controllers/split_config_controller.dart';
import '../widgets/background_selector.dart';
import '../widgets/canvas_selector.dart';
import '../widgets/custom_duration_input.dart';
import '../widgets/mode_selector.dart';
import '../widgets/overlay_settings_card.dart';
import '../widgets/preset_chips.dart';
import '../widgets/split_summary_card.dart';
import '../widgets/trim_range_slider.dart';

class SplitConfigScreen extends ConsumerStatefulWidget {
  const SplitConfigScreen({super.key});

  @override
  ConsumerState<SplitConfigScreen> createState() => _SplitConfigScreenState();
}

class _SplitConfigScreenState extends ConsumerState<SplitConfigScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _durationKey = GlobalKey();
  final GlobalKey _backgroundKey = GlobalKey();
  final GlobalKey _overlayKey = GlobalKey();

  String? _durationError;
  String? _backgroundError;
  String? _overlayError;
  String? _bannerError;

  static const _settingsValidator = SplitSettingsValidator();
  static const _backgroundValidator = BackgroundValidator();
  static const _overlayValidator = OverlayValidator();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onReviewPlan() {
    final splitConfig = ref.read(splitConfigControllerProvider);
    final video = ref.read(videoPickerControllerProvider).valueOrNull;

    if (video == null) {
      AppMessenger.showError(
        context,
        'Please select a video first',
        actionLabel: 'Select',
        onAction: () => context.go(AppRoutes.home),
      );
      return;
    }

    final trimDuration =
        splitConfig.trimRange?.durationSeconds ??
        (video.duration.inMilliseconds / 1000.0);

    // 1. Validate Clip Duration & Settings
    final settingsResult = _settingsValidator.validate(
      targetDurationSeconds: splitConfig.targetDurationSeconds,
      totalTrimDurationSeconds: trimDuration,
      customBaseName: splitConfig.customBaseName,
      isShortsMode: true,
    );

    // 2. Validate Background Fill
    final bgResult = _backgroundValidator.validate(splitConfig.backgroundSpec);

    // 3. Validate Text Overlay
    final overlayResult = _overlayValidator.validate(splitConfig.overlaySpec);

    setState(() {
      _durationError = settingsResult.errorForField('target_duration');
      _backgroundError = bgResult.firstError?.message;
      _overlayError = overlayResult.firstError?.message;
      _bannerError =
          settingsResult.firstError?.message ??
          bgResult.firstError?.message ??
          overlayResult.firstError?.message;
    });

    if (!settingsResult.isValid) {
      AppMessenger.showIssue(context, settingsResult.firstError!);
      _scrollToKey(_durationKey);
      return;
    }

    if (!bgResult.isValid) {
      AppMessenger.showIssue(context, bgResult.firstError!);
      _scrollToKey(_backgroundKey);
      return;
    }

    if (!overlayResult.isValid) {
      AppMessenger.showIssue(context, overlayResult.firstError!);
      _scrollToKey(_overlayKey);
      return;
    }

    // Clear any errors and proceed
    setState(() {
      _durationError = null;
      _backgroundError = null;
      _overlayError = null;
      _bannerError = null;
    });

    context.push(AppRoutes.planReview);
  }

  void _scrollToKey(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: AppTokens.durationNormal,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickedVideoAsync = ref.watch(videoPickerControllerProvider);
    final splitConfig = ref.watch(splitConfigControllerProvider);
    final splitController = ref.read(splitConfigControllerProvider.notifier);
    final outputDirAsync = ref.watch(outputDirectoryProvider);

    final video = pickedVideoAsync.valueOrNull;

    if (video == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Split Settings')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined, size: 48),
              const SizedBox(height: 16),
              const Text('No video selected.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Select a Video'),
              ),
            ],
          ),
        ),
      );
    }

    final totalSeconds = video.duration.inMilliseconds / 1000.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Split Settings')),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildVideoInfoCard(context, video),
          const SizedBox(height: 20),
          if (_bannerError != null) ...[
            InfoBanner(message: _bannerError!, type: InfoBannerType.error),
            const SizedBox(height: 16),
          ],
          _buildSectionHeader(
            context,
            title: '1. Trim Range',
            icon: Icons.content_cut_rounded,
          ),
          const SizedBox(height: 8),
          TrimRangeSlider(
            totalDurationSeconds: totalSeconds,
            currentRange: splitConfig.trimRange,
            onChanged: splitController.setTrimRange,
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: _durationKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context,
                  title: '2. Clip Duration (Max 180s)',
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(height: 8),
                PresetChips(
                  selectedDurationSeconds: splitConfig.targetDurationSeconds,
                  onSelected: (dur) {
                    setState(() => _durationError = null);
                    splitController.setTargetDuration(dur);
                  },
                ),
                const SizedBox(height: 8),
                CustomDurationInput(
                  currentDurationSeconds: splitConfig.targetDurationSeconds,
                  onChanged: (dur) {
                    setState(() => _durationError = null);
                    splitController.setTargetDuration(dur);
                  },
                ),
                if (_durationError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _durationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            context,
            title: '3. Canvas & Crop',
            icon: Icons.aspect_ratio_rounded,
          ),
          const SizedBox(height: 8),
          CanvasSelector(
            selectedCanvas: splitConfig.canvasSpec,
            cropToFill: splitConfig.cropToFill,
            onCanvasChanged: splitController.setCanvasSpec,
            onCropToFillChanged: splitController.setCropToFill,
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: _backgroundKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context,
                  title: '4. Background Fill',
                  icon: Icons.palette_outlined,
                ),
                const SizedBox(height: 8),
                BackgroundSelector(
                  selectedBackground: splitConfig.backgroundSpec,
                  onBackgroundChanged: (bg) {
                    setState(() => _backgroundError = null);
                    splitController.setBackgroundSpec(bg);
                  },
                ),
                if (_backgroundError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _backgroundError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: _overlayKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context,
                  title: '5. Part Messages & Overlay',
                  icon: Icons.subtitles_outlined,
                ),
                const SizedBox(height: 8),
                OverlaySettingsCard(
                  overlaySpec: splitConfig.overlaySpec,
                  onOverlayChanged: (ov) {
                    setState(() => _overlayError = null);
                    splitController.setOverlaySpec(ov);
                  },
                ),
                if (_overlayError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _overlayError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            context,
            title: '6. Processing Mode',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 8),
          ModeSelector(
            selectedMode: splitConfig.mode,
            isReencodeForced: splitConfig.requiresReencode,
            onModeChanged: splitController.setMode,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            context,
            title: '7. Clip Naming & Prefix',
            icon: Icons.drive_file_rename_outline,
          ),
          const SizedBox(height: 8),
          _buildNamingCard(
            context,
            splitConfig.customBaseName ?? video.baseName,
            splitController.setCustomBaseName,
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            context,
            title: '8. Output Destination',
            icon: Icons.folder_open_rounded,
          ),
          const SizedBox(height: 8),
          _buildOutputFolderCard(context, ref, outputDirAsync),
          const SizedBox(height: 20),
          SplitSummaryCard(
            totalDuration: video.duration,
            config: splitConfig,
            baseName: splitConfig.customBaseName?.isNotEmpty == true
                ? splitConfig.customBaseName!
                : video.baseName,
            onMergeToggle: splitController.setMergeShortTrailingClip,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            icon: Icons.checklist_rounded,
            label: 'Review Split Plan',
            onPressed: _onReviewPlan,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVideoInfoCard(BuildContext context, dynamic video) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.video_file_outlined, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.fileName as String,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${video.formattedDuration} • ${video.formattedSize} • ${video.resolution}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildOutputFolderCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<String> outputDirAsync,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return outputDirAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading directory: $e'),
      data: (path) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                path,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Change'),
              onPressed: () async {
                final notifier = ref.read(outputDirectoryProvider.notifier);
                await notifier.pickAndSetDirectory();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamingCard(
    BuildContext context,
    String currentBaseName,
    ValueChanged<String> onChanged,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: currentBaseName,
              decoration: const InputDecoration(
                labelText: 'File Name Starting Prefix',
                hintText: 'e.g. MyShortsSequence',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
              onChanged: (val) {
                if (val.trim().isNotEmpty) {
                  onChanged(val.trim());
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Clips will be named: ${currentBaseName}_part_001.mp4, ${currentBaseName}_part_002.mp4, etc.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
