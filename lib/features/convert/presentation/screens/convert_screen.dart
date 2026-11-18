import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../domain/models/convert_config.dart';
import '../controllers/convert_controller.dart';

/// Screen allowing users to convert video containers, codecs, compress to target size,
/// create animated GIFs with palettegen, or extract high-fidelity audio streams.
class ConvertScreen extends ConsumerStatefulWidget {
  const ConvertScreen({super.key});

  @override
  ConsumerState<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends ConsumerState<ConvertScreen> {
  final TextEditingController _fileNameController = TextEditingController();

  @override
  void dispose() {
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final convertState = ref.watch(convertControllerProvider);
    final controller = ref.read(convertControllerProvider.notifier);

    // Synchronize video from global video picker if available
    ref.listen(videoPickerControllerProvider, (prev, next) {
      final video = next.value;
      if (video != null && convertState.video == null) {
        controller.setVideo(video);
      }
    });

    final video = convertState.video;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Convert & Compress'),
        actions: [
          if (video != null)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change Video',
              onPressed: () => _pickVideo(context),
            ),
        ],
      ),
      body: _buildBody(context, convertState, controller),
      bottomNavigationBar: video != null && !convertState.isLoading
          ? _buildBottomBar(context, convertState, controller)
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    ConvertState state,
    ConvertController controller,
  ) {
    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: LoadingSkeleton.card(height: 160),
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
        icon: Icons.transform_rounded,
        title: 'No Video Selected',
        message: 'Select a video to convert formats (MP4, WebM, MKV, GIF), compress for Discord/WhatsApp, or extract audio tracks.',
        actionLabel: 'Choose Video',
        onAction: () => _pickVideo(context),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVideoSummary(context, state.video!),
          const SizedBox(height: AppTokens.spaceMd),
          _buildFormatSelector(context, state.config, controller),
          const SizedBox(height: AppTokens.spaceMd),
          if (state.config.format.isVideo) ...[
            _buildVideoOptions(context, state.config, controller),
            const SizedBox(height: AppTokens.spaceMd),
            _buildCompressionSection(context, state.config, controller),
            const SizedBox(height: AppTokens.spaceMd),
            _buildAudioToggle(context, state.config, controller),
          ] else if (state.config.format == ConvertOutputFormat.gif) ...[
            _buildGifSection(context, state.config, controller),
          ] else if (state.config.format == ConvertOutputFormat.audioOnly) ...[
            _buildAudioExtractionSection(context, state.config, controller),
          ],
          const SizedBox(height: AppTokens.spaceMd),
          _buildEstimateSection(context, state),
          const SizedBox(height: AppTokens.spaceLg),
        ],
      ),
    );
  }

  Widget _buildVideoSummary(BuildContext context, PickedVideo video) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: AppTokens.borderRadiusMd,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.spaceSm),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: AppTokens.borderRadiusSm,
            ),
            child: Icon(
              Icons.video_file_outlined,
              color: colorScheme.onPrimaryContainer,
              size: AppTokens.iconLg,
            ),
          ),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
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
                  '${Formatters.formatDuration(video.duration)} • ${Formatters.formatFileSize(video.sizeInBytes)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
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

  Widget _buildFormatSelector(
    BuildContext context,
    ConvertConfig config,
    ConvertController controller,
  ) {
    return SectionCard(
      title: 'Target Format',
      icon: Icons.category_outlined,
      child: Wrap(
        spacing: AppTokens.spaceSm,
        runSpacing: AppTokens.spaceXs,
        children: ConvertOutputFormat.values.map((fmt) {
          final isSelected = config.format == fmt;
          return ChoiceChip(
            label: Text(fmt.displayName),
            selected: isSelected,
            onSelected: (_) => controller.setFormat(fmt),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVideoOptions(
    BuildContext context,
    ConvertConfig config,
    ConvertController controller,
  ) {
    return SectionCard(
      title: 'Resolution & Frame Rate',
      icon: Icons.aspect_ratio_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resolution',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Wrap(
            spacing: AppTokens.spaceSm,
            runSpacing: AppTokens.spaceXs,
            children: ResolutionPreset.values.map((res) {
              return ChoiceChip(
                label: Text(res.displayName),
                selected: config.resolution == res,
                onSelected: (_) => controller.setResolution(res),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          const Text(
            'Frame Rate',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Wrap(
            spacing: AppTokens.spaceSm,
            runSpacing: AppTokens.spaceXs,
            children: FpsPreset.values.map((fps) {
              return ChoiceChip(
                label: Text(fps.displayName),
                selected: config.fps == fps,
                onSelected: (_) => controller.setFps(fps),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompressionSection(
    BuildContext context,
    ConvertConfig config,
    ConvertController controller,
  ) {
    final isTargetSizeMode = config.targetSizeMb != null;

    return SectionCard(
      title: 'Compression Strategy',
      icon: Icons.compress_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Quality Preset'),
                icon: Icon(Icons.tune_outlined),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Target MB Limit'),
                icon: Icon(Icons.data_usage_outlined),
              ),
            ],
            selected: {isTargetSizeMode},
            onSelectionChanged: (set) {
              if (set.first) {
                controller.setTargetSizeMb(
                  25.0,
                ); // Default 25MB for Discord/Email
              } else {
                controller.setTargetSizeMb(null);
              }
            },
          ),
          const SizedBox(height: AppTokens.spaceMd),
          if (!isTargetSizeMode) ...[
            Wrap(
              spacing: AppTokens.spaceSm,
              runSpacing: AppTokens.spaceXs,
              children: QualityPreset.values.map((q) {
                return ChoiceChip(
                  label: Text(q.displayName),
                  selected: config.quality == q,
                  onSelected: (_) => controller.setQuality(q),
                );
              }).toList(),
            ),
          ] else ...[
            Text(
              'Target File Size: ~${config.targetSizeMb!.toStringAsFixed(0)} MB',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Wrap(
              spacing: AppTokens.spaceSm,
              children: [8.0, 16.0, 25.0, 50.0, 100.0].map((mb) {
                final isSelected = (config.targetSizeMb! - mb).abs() < 0.1;
                return ChoiceChip(
                  label: Text(
                    mb == 16.0
                        ? '16 MB (WhatsApp)'
                        : mb == 25.0
                        ? '25 MB (Discord)'
                        : '${mb.toInt()} MB',
                  ),
                  selected: isSelected,
                  onSelected: (_) => controller.setTargetSizeMb(mb),
                );
              }).toList(),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Slider(
              value: config.targetSizeMb!.clamp(5.0, 200.0),
              min: 5.0,
              max: 200.0,
              divisions: 39,
              label: '${config.targetSizeMb!.toStringAsFixed(0)} MB',
              onChanged: (val) => controller.setTargetSizeMb(val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioToggle(
    BuildContext context,
    ConvertConfig config,
    ConvertController controller,
  ) {
    return SectionCard(
      title: 'Audio Settings',
      icon: Icons.volume_up_outlined,
      child: SwitchListTile(
        title: const Text('Mute Audio Track'),
        subtitle: const Text(
          'Removes audio completely to maximize compression',
        ),
        value: config.muteAudio,
        onChanged: (val) => controller.setMuteAudio(val),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildGifSection(
    BuildContext context,
    ConvertConfig config,
    ConvertController controller,
  ) {
    final gifCfg = config.gifConfig;

    return SectionCard(
      title: 'GIF Settings',
      icon: Icons.gif_box_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InfoBanner(
            message: 'Animated GIFs generate a dynamic 256-color palette (palettegen) for vivid colors and zero banding.',
            type: InfoBannerType.info,
          ),
          const SizedBox(height: AppTokens.spaceMd),
          const Text(
            'Max Width',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: [320, 480, 640].map((w) {
              return ChoiceChip(
                label: Text('${w}px'),
                selected: gifCfg.maxWidth == w,
                onSelected: (_) =>
                    controller.setGifConfig(gifCfg.copyWith(maxWidth: w)),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          const Text(
            'Framerate',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: [10, 15, 20, 24].map((fps) {
              return ChoiceChip(
                label: Text('$fps FPS'),
                selected: gifCfg.fps == fps,
                onSelected: (_) =>
                    controller.setGifConfig(gifCfg.copyWith(fps: fps)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioExtractionSection(
    BuildContext context,
    ConvertConfig config,
    ConvertController controller,
  ) {
    return SectionCard(
      title: 'Audio Extraction Settings',
      icon: Icons.audiotrack_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Audio Format',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Wrap(
            spacing: AppTokens.spaceSm,
            runSpacing: AppTokens.spaceXs,
            children: AudioOutputFormat.values.map((fmt) {
              return ChoiceChip(
                label: Text(fmt.displayName),
                selected: config.audioFormat == fmt,
                onSelected: (_) => controller.setAudioFormat(fmt),
              );
            }).toList(),
          ),
          if (config.audioFormat != AudioOutputFormat.wav) ...[
            const SizedBox(height: AppTokens.spaceMd),
            const Text(
              'Bitrate',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Wrap(
              spacing: AppTokens.spaceSm,
              children: [128, 192, 256, 320].map((kbps) {
                return ChoiceChip(
                  label: Text('$kbps kbps'),
                  selected: config.audioBitrateKbps == kbps,
                  onSelected: (_) => controller.setAudioBitrateKbps(kbps),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstimateSection(BuildContext context, ConvertState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final originalBytes = state.video?.sizeInBytes ?? 0;
    final estBytes = state.estimatedSizeBytes;

    double diffPct = 0.0;
    if (originalBytes > 0 && estBytes > 0) {
      diffPct = ((estBytes - originalBytes) / originalBytes) * 100.0;
    }

    final isSavings = diffPct < 0;

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
                Icons.analytics_outlined,
                color: colorScheme.primary,
                size: AppTokens.iconMd,
              ),
              const SizedBox(width: AppTokens.spaceSm),
              Text(
                'Output Estimate',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Size:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                Formatters.formatFileSize(estBytes),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          if (originalBytes > 0 && estBytes > 0) ...[
            const SizedBox(height: AppTokens.spaceXs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Change vs Source:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${isSavings ? '' : '+'}${diffPct.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSavings ? Colors.green : colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    ConvertState state,
    ConvertController controller,
  ) {
    final format = state.config.format;
    final label = switch (format) {
      ConvertOutputFormat.gif => 'Create Animated GIF',
      ConvertOutputFormat.audioOnly => 'Extract Audio Track',
      _ => 'Convert Video',
    };

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: PrimaryButton(
          label: label,
          icon: Icons.check_circle_outline,
          onPressed: () async {
            try {
              final jobId = await controller.enqueueConversion();
              if (context.mounted) {
                AppMessenger.showSuccess(
                  context,
                  'Job #$jobId queued in background studio.',
                  actionLabel: 'View Queue',
                  onAction: () => context.push(AppRoutes.jobs),
                );
                await context.push(AppRoutes.jobs);
              }
            } catch (e) {
              if (context.mounted) {
                AppMessenger.showError(
                  context,
                  'Failed to enqueue conversion: $e',
                );
              }
            }
          },
        ),
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
