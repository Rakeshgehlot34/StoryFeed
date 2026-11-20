import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/validation/validators/custom_split_validator.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../domain/models/custom_split_config.dart';
import '../controllers/custom_split_controller.dart';

class CustomSplitScreen extends ConsumerStatefulWidget {
  const CustomSplitScreen({super.key});

  @override
  ConsumerState<CustomSplitScreen> createState() => _CustomSplitScreenState();
}

class _CustomSplitScreenState extends ConsumerState<CustomSplitScreen> {
  final TextEditingController _pointInputController = TextEditingController();
  static const _customSplitValidator = CustomSplitValidator();
  String? _pointInputError;

  @override
  void dispose() {
    _pointInputController.dispose();
    super.dispose();
  }

  void _onAddPoint(
    double maxDuration,
    CustomSplitConfig config,
    CustomSplitController controller,
  ) {
    final text = _pointInputController.text.trim();
    if (text.isEmpty) {
      setState(() => _pointInputError = 'Enter a timestamp value (e.g. 15.5)');
      AppMessenger.showWarning(context, 'Enter a timestamp value');
      return;
    }
    final val = double.tryParse(text);
    if (val == null) {
      setState(() => _pointInputError = 'Invalid timestamp number');
      AppMessenger.showError(context, 'Invalid timestamp number');
      return;
    }
    final result = _customSplitValidator.validatePoint(
      pointSeconds: val,
      maxDurationSeconds: maxDuration,
      existingPoints: config.customSplitPoints,
    );
    if (!result.isValid) {
      final issue = result.firstError!;
      setState(() => _pointInputError = issue.message);
      AppMessenger.showIssue(context, issue);
      return;
    }
    setState(() => _pointInputError = null);
    controller.addSplitPoint(val);
    _pointInputController.clear();
  }

  void _onReviewCustomPlan(CustomSplitState splitState) {
    if (splitState.config.mode == CustomSplitMode.byPoints) {
      final result = _customSplitValidator.validatePlan(
        points: splitState.config.customSplitPoints,
        totalDurationSeconds: splitState.video != null
            ? splitState.video!.duration.inMilliseconds / 1000.0
            : 0.0,
      );
      if (!result.isValid) {
        final issue = result.firstError!;
        AppMessenger.showIssue(context, issue);
        return;
      }
    }
    if (splitState.plan != null && splitState.plan!.items.isNotEmpty) {
      context.push(AppRoutes.customSplitReview);
    }
  }

  @override
  Widget build(BuildContext context) {
    final splitState = ref.watch(customSplitControllerProvider);
    final controller = ref.read(customSplitControllerProvider.notifier);

    // Sync picked video if not set in splitState
    ref.listen(videoPickerControllerProvider, (prev, next) {
      final video = next.value;
      if (video != null && splitState.video == null) {
        controller.setVideo(video);
      }
    });

    final video = splitState.video;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Video Split'),
        actions: [
          if (video != null)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change Video',
              onPressed: () => _pickVideo(context),
            ),
        ],
      ),
      body: video == null
          ? EmptyState(
              icon: Icons.movie_creation_outlined,
              title: 'No Video Selected',
              message:
                  'Select a video from your device to configure custom splits without 3-minute limits.',
              actionLabel: 'Choose Video',
              onAction: () => _pickVideo(context),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVideoHeader(context, video),
                  const SizedBox(height: AppTokens.spaceMd),
                  _buildModeSelector(context, splitState.config, controller),
                  const SizedBox(height: AppTokens.spaceMd),
                  _buildModeConfig(context, splitState, controller),
                  const SizedBox(height: AppTokens.spaceMd),
                  _buildMethodSelector(context, splitState.config, controller),
                  const SizedBox(height: AppTokens.spaceMd),
                  _buildOptionsSection(context, splitState.config, controller),
                  const SizedBox(height: AppTokens.spaceLg),
                  _buildPlanSummary(context, splitState),
                  const SizedBox(height: AppTokens.spaceXl),
                  PrimaryButton(
                    label: splitState.plan != null
                        ? 'Review Plan (${splitState.plan!.totalParts} Clips)'
                        : 'Review Plan',
                    icon: Icons.playlist_play_rounded,
                    onPressed: () => _onReviewCustomPlan(splitState),
                  ),
                  const SizedBox(height: AppTokens.spaceXl),
                ],
              ),
            ),
    );
  }

  Widget _buildVideoHeader(BuildContext context, PickedVideo video) {
    final theme = Theme.of(context);
    final durationSec = video.duration.inMilliseconds / 1000.0;

    return SectionCard(
      title: 'Source Video',
      icon: Icons.video_file_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: 'Change Video',
        onPressed: () => _pickVideo(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.fileName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            'Duration: ${Formatters.formatSeconds(durationSec)} • ${video.width}x${video.height} • ${Formatters.formatFileSize(video.sizeInBytes)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(
    BuildContext context,
    CustomSplitConfig config,
    CustomSplitController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Split Strategy',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        SegmentedButton<CustomSplitMode>(
          segments: [
            ButtonSegment(
              value: CustomSplitMode.byDuration,
              label: Text(CustomSplitMode.byDuration.label),
              icon: const Icon(Icons.timer_outlined),
            ),
            ButtonSegment(
              value: CustomSplitMode.byParts,
              label: Text(CustomSplitMode.byParts.label),
              icon: const Icon(Icons.pie_chart_outline_rounded),
            ),
            ButtonSegment(
              value: CustomSplitMode.byPoints,
              label: Text(CustomSplitMode.byPoints.label),
              icon: const Icon(Icons.alt_route_rounded),
            ),
            ButtonSegment(
              value: CustomSplitMode.bySize,
              label: Text(CustomSplitMode.bySize.label),
              icon: const Icon(Icons.data_usage_rounded),
            ),
          ],
          selected: {config.mode},
          onSelectionChanged: (selected) {
            controller.setMode(selected.first);
          },
        ),
      ],
    );
  }

  Widget _buildModeConfig(
    BuildContext context,
    CustomSplitState state,
    CustomSplitController controller,
  ) {
    final config = state.config;
    final totalVideoSec = state.video != null
        ? state.video!.duration.inMilliseconds / 1000.0
        : 60.0;

    return SectionCard(
      title: config.mode.label,
      icon: Icons.tune_rounded,
      child: switch (config.mode) {
        CustomSplitMode.byDuration => _buildDurationConfig(
            context,
            config,
            controller,
            totalVideoSec,
          ),
        CustomSplitMode.byParts => _buildPartsConfig(
            context,
            config,
            controller,
            totalVideoSec,
          ),
        CustomSplitMode.byPoints => _buildPointsConfig(
            context,
            config,
            controller,
            totalVideoSec,
          ),
        CustomSplitMode.bySize => _buildSizeConfig(context, config, controller),
      },
    );
  }

  Widget _buildDurationConfig(
    BuildContext context,
    CustomSplitConfig config,
    CustomSplitController controller,
    double maxDuration,
  ) {
    final presets = [15.0, 30.0, 45.0, 60.0, 90.0, 120.0, 300.0, 600.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Duration: ${config.targetDurationSeconds.toStringAsFixed(0)}s (${Formatters.formatSeconds(config.targetDurationSeconds)})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Wrap(
          spacing: AppTokens.spaceSm,
          runSpacing: AppTokens.spaceXs,
          children: presets.map((seconds) {
            final isSelected =
                (config.targetDurationSeconds - seconds).abs() < 0.1;
            return ChoiceChip(
              label: Text(
                seconds < 60
                    ? '${seconds.toInt()}s'
                    : '${(seconds / 60).toInt()}m',
              ),
              selected: isSelected,
              onSelected: (_) => controller.setTargetDuration(seconds),
            );
          }).toList(),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Slider(
          value: config.targetDurationSeconds.clamp(1.0, maxDuration),
          min: 1.0,
          max: maxDuration > 1.0 ? maxDuration : 60.0,
          divisions: maxDuration > 10 ? maxDuration.toInt() : 10,
          label: '${config.targetDurationSeconds.toInt()}s',
          onChanged: (val) => controller.setTargetDuration(val),
        ),
      ],
    );
  }

  Widget _buildPartsConfig(
    BuildContext context,
    CustomSplitConfig config,
    CustomSplitController controller,
    double totalVideoSec,
  ) {
    final clipDuration = totalVideoSec / config.targetPartCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Divide into: ${config.targetPartCount} parts',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '~${Formatters.formatSeconds(clipDuration)} per clip',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Slider(
          value: config.targetPartCount.toDouble(),
          min: 2,
          max: 50,
          divisions: 48,
          label: '${config.targetPartCount} parts',
          onChanged: (val) => controller.setTargetPartCount(val.toInt()),
        ),
      ],
    );
  }

  Widget _buildPointsConfig(
    BuildContext context,
    CustomSplitConfig config,
    CustomSplitController controller,
    double maxDuration,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add split timestamp in seconds (e.g. 15.5):',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pointInputController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 30.0',
                  border: const OutlineInputBorder(),
                  errorText: _pointInputError,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceSm,
                    vertical: AppTokens.spaceXs,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            FilledButton.tonal(
              onPressed: () => _onAddPoint(maxDuration, config, controller),
              child: const Text('Add Point'),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        if (config.customSplitPoints.isEmpty)
          const Text(
            'No custom split points added yet. Enter a timestamp above.',
            style: TextStyle(fontStyle: FontStyle.italic),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${config.customSplitPoints.length} Split Point(s):'),
              TextButton(
                onPressed: () => controller.clearSplitPoints(),
                child: const Text('Clear All'),
              ),
            ],
          ),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: config.customSplitPoints.map((pt) {
              return Chip(
                label: Text(
                  '${pt.toStringAsFixed(1)}s (${Formatters.formatSeconds(pt)})',
                ),
                onDeleted: () => controller.removeSplitPoint(pt),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSizeConfig(
    BuildContext context,
    CustomSplitConfig config,
    CustomSplitController controller,
  ) {
    final presets = [10.0, 25.0, 50.0, 100.0, 250.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target File Size: ~${config.targetSizeMb.toStringAsFixed(0)} MB per clip',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        Wrap(
          spacing: AppTokens.spaceSm,
          children: presets.map((mb) {
            final isSelected = (config.targetSizeMb - mb).abs() < 0.1;
            return ChoiceChip(
              label: Text('${mb.toInt()} MB'),
              selected: isSelected,
              onSelected: (_) => controller.setTargetSizeMb(mb),
            );
          }).toList(),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        const InfoBanner(
          message:
              'Estimated file size requires re-encoding. Splits are calculated using video bitrate estimation.',
          type: InfoBannerType.info,
        ),
      ],
    );
  }

  Widget _buildMethodSelector(
    BuildContext context,
    CustomSplitConfig config,
    CustomSplitController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encoding Method',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        SegmentedButton<SplitMethod>(
          segments: [
            ButtonSegment(
              value: SplitMethod.fast,
              label: Text(SplitMethod.fast.label),
              icon: const Icon(Icons.flash_on_rounded),
              enabled: config.mode != CustomSplitMode.bySize,
            ),
            ButtonSegment(
              value: SplitMethod.precise,
              label: Text(SplitMethod.precise.label),
              icon: const Icon(Icons.high_quality_rounded),
            ),
          ],
          selected: {config.method},
          onSelectionChanged: (selected) {
            controller.setMethod(selected.first);
          },
        ),
        const SizedBox(height: AppTokens.spaceSm),
        if (config.method == SplitMethod.fast)
          const InfoBanner(
            message:
                'Fast mode copies streams (-c copy) with zero re-encoding. Instant export, but cuts snap to keyframes (~0.5s - 2.0s drift).',
            type: InfoBannerType.warning,
          )
        else
          const InfoBanner(
            message:
                'Precise mode re-encodes video for frame-accurate millisecond cuts.',
            type: InfoBannerType.info,
          ),
      ],
    );
  }

  Widget _buildOptionsSection(
    BuildContext context,
    CustomSplitConfig config,
    CustomSplitController controller,
  ) {
    return SectionCard(
      title: 'Options',
      icon: Icons.settings_outlined,
      child: SwitchListTile(
        title: const Text('Merge Short Trailing Clip'),
        subtitle: const Text(
          'Absorb remainder clips shorter than 3s into the previous clip',
        ),
        value: config.mergeShortTrailingClip,
        onChanged: (val) => controller.setMergeShortTrailingClip(val),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPlanSummary(BuildContext context, CustomSplitState state) {
    final plan = state.plan;
    if (plan == null) {
      if (state.errorMessage != null) {
        return InfoBanner(
          message: state.errorMessage!,
          type: InfoBannerType.error,
        );
      }
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: AppTokens.borderRadiusMd,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: colorScheme.primary,
                size: AppTokens.iconMd,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Text(
                'Plan Summary: ${plan.totalParts} Clips',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            '• Duration: ${Formatters.formatSeconds(plan.coveredDuration)} total covered\n'
            '• Method: ${plan.splitMethod.badge}\n'
            '• Est. Size: ~${Formatters.formatFileSize(plan.estimatedTotalSizeBytes)} total',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
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
}
