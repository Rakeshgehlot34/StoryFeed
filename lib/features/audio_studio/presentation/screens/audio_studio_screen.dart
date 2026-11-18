import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/validation/validators/audio_validator.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../convert/domain/models/convert_config.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../domain/models/audio_studio_project.dart';
import '../controllers/audio_studio_controller.dart';

/// Screen empowering users to mute, balance, mix background music, record voice-overs,
/// enable audio ducking, and export enhanced video or standalone audio tracks.
class AudioStudioScreen extends ConsumerStatefulWidget {
  const AudioStudioScreen({super.key});

  @override
  ConsumerState<AudioStudioScreen> createState() => _AudioStudioScreenState();
}

class _AudioStudioScreenState extends ConsumerState<AudioStudioScreen> {
  @override
  Widget build(BuildContext context) {
    final studioState = ref.watch(audioStudioControllerProvider);
    final controller = ref.read(audioStudioControllerProvider.notifier);

    // Sync global picked video if available
    ref.listen(videoPickerControllerProvider, (prev, next) {
      final video = next.value;
      if (video != null && studioState.video == null) {
        controller.setVideo(video);
      }
    });

    final video = studioState.video;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Studio'),
        actions: [
          if (video != null)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change Video',
              onPressed: () => _pickVideo(context),
            ),
        ],
      ),
      body: _buildBody(context, studioState, controller),
      bottomNavigationBar: video != null && !studioState.isLoading
          ? _buildBottomBar(context, studioState, controller)
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    AudioStudioState state,
    AudioStudioController controller,
  ) {
    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: LoadingSkeleton.card(height: 180),
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
        icon: Icons.graphic_eq_rounded,
        title: 'No Video Selected',
        message: 'Select a video to adjust audio volume, replace audio, record microphone voice-overs, and mix background tracks.',
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
          _buildMultiTrackVisualizer(context, state),
          const SizedBox(height: AppTokens.spaceMd),
          _buildOriginalTrackCard(context, state.config, controller),
          const SizedBox(height: AppTokens.spaceMd),
          _buildMusicTrackCard(context, state.config, controller),
          const SizedBox(height: AppTokens.spaceMd),
          _buildVoiceoverTrackCard(context, state, controller),
          const SizedBox(height: AppTokens.spaceMd),
          _buildDuckingCard(context, state.config, controller),
          const SizedBox(height: AppTokens.spaceMd),
          _buildExportModeCard(context, state.config, controller),
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

  Widget _buildMultiTrackVisualizer(
    BuildContext context,
    AudioStudioState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final config = state.config;
    final totalDur = config.videoDurationSeconds > 0
        ? config.videoDurationSeconds
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: AppTokens.borderRadiusMd,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.stacked_line_chart_rounded,
                color: colorScheme.primary,
                size: AppTokens.iconSm,
              ),
              const SizedBox(width: AppTokens.spaceXs),
              Text(
                'Timeline Mixer',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                Formatters.formatSeconds(totalDur),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          // Original track line
          _buildTrackBar(
            label: 'Original',
            color: config.isOriginalMuted ? Colors.grey : Colors.blue,
            startFraction: 0.0,
            widthFraction: 1.0,
            volume: config.isOriginalMuted ? 0.0 : config.originalVolume,
          ),
          const SizedBox(height: AppTokens.spaceXs),
          // Music track line
          if (config.musicTrack != null)
            _buildTrackBar(
              label: 'Music',
              color: Colors.green,
              startFraction: 0.0,
              widthFraction: 1.0,
              volume: config.musicTrack!.volume,
            ),
          if (config.voiceoverTrack != null) ...[
            const SizedBox(height: AppTokens.spaceXs),
            _buildTrackBar(
              label: 'Voice',
              color: Colors.purple,
              startFraction:
                  (config.voiceoverTrack!.startTimeSeconds / totalDur).clamp(
                    0.0,
                    1.0,
                  ),
              widthFraction: (config.voiceoverTrack!.durationSeconds / totalDur)
                  .clamp(0.05, 1.0),
              volume: config.voiceoverTrack!.volume,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackBar({
    required String label,
    required Color color,
    required double startFraction,
    required double widthFraction,
    required double volume,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final leftOffset = totalW * startFraction;
              final barW = (totalW * widthFraction).clamp(
                4.0,
                totalW - leftOffset,
              );

              return Container(
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: leftOffset,
                      width: barW,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: (volume * 0.5 + 0.3).clamp(0.2, 1.0),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(width: AppTokens.spaceSm),
        SizedBox(
          width: 38,
          child: Text(
            '${(volume * 100).toInt()}%',
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalTrackCard(
    BuildContext context,
    AudioStudioConfig config,
    AudioStudioController controller,
  ) {
    return SectionCard(
      title: 'Original Audio Track',
      icon: Icons.mic_none_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Mute Original Audio'),
            subtitle: const Text('Completely silences audio from source video'),
            value: config.isOriginalMuted,
            onChanged: (_) => controller.toggleOriginalMute(),
            contentPadding: EdgeInsets.zero,
          ),
          if (!config.isOriginalMuted) ...[
            const SizedBox(height: AppTokens.spaceXs),
            Row(
              children: [
                const Icon(Icons.volume_down_outlined, size: AppTokens.iconSm),
                Expanded(
                  child: Slider(
                    value: config.originalVolume,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    label: '${(config.originalVolume * 100).toInt()}%',
                    onChanged: (val) => controller.setOriginalVolume(val),
                  ),
                ),
                Text(
                  '${(config.originalVolume * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMusicTrackCard(
    BuildContext context,
    AudioStudioConfig config,
    AudioStudioController controller,
  ) {
    final music = config.musicTrack;

    return SectionCard(
      title: 'Background Music',
      icon: Icons.music_note_outlined,
      child: music == null
          ? SecondaryButton(
              label: 'Add Music Track (MP3, WAV, AAC)',
              icon: Icons.library_music_outlined,
              onPressed: () => _pickMusicFile(controller),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.audiotrack, color: Colors.green),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: Text(
                        music.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Remove Music',
                      onPressed: () => controller.removeMusicTrack(),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.volume_down_outlined,
                      size: AppTokens.iconSm,
                    ),
                    Expanded(
                      child: Slider(
                        value: music.volume,
                        min: 0.0,
                        max: 2.0,
                        divisions: 20,
                        label: '${(music.volume * 100).toInt()}%',
                        onChanged: (val) => controller.setMusicVolume(val),
                      ),
                    ),
                    Text(
                      '${(music.volume * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Loop Music Track'),
                  subtitle: const Text('Repeats track if shorter than video'),
                  value: music.loop,
                  onChanged: (val) => controller.setMusicLoop(val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
    );
  }

  Widget _buildVoiceoverTrackCard(
    BuildContext context,
    AudioStudioState state,
    AudioStudioController controller,
  ) {
    final vo = state.config.voiceoverTrack;

    return SectionCard(
      title: 'Voice-over Track',
      icon: Icons.record_voice_over_outlined,
      child: vo == null
          ? Column(
              children: [
                if (state.isRecording) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.red,
                        size: AppTokens.iconMd,
                      ),
                      const SizedBox(width: AppTokens.spaceSm),
                      Text(
                        'Recording... ${state.recordingElapsedSeconds}s',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                  PrimaryButton(
                    label: 'Stop & Keep Voice-over',
                    icon: Icons.stop_rounded,
                    onPressed: () => controller.stopVoiceoverRecording(),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Record Mic',
                          icon: Icons.mic_rounded,
                          onPressed: () => controller.startVoiceoverRecording(),
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceSm),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Import File',
                          icon: Icons.folder_open_outlined,
                          onPressed: () => _pickVoiceoverFile(controller),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.purple),
                    const SizedBox(width: AppTokens.spaceSm),
                    Expanded(
                      child: Text(
                        vo.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Remove Voice-over',
                      onPressed: () => controller.removeVoiceoverTrack(),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.volume_down_outlined,
                      size: AppTokens.iconSm,
                    ),
                    Expanded(
                      child: Slider(
                        value: vo.volume,
                        min: 0.0,
                        max: 2.0,
                        divisions: 20,
                        label: '${(vo.volume * 100).toInt()}%',
                        onChanged: (val) => controller.setVoiceoverVolume(val),
                      ),
                    ),
                    Text(
                      '${(vo.volume * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  'Timeline Start: ${vo.startTimeSeconds.toStringAsFixed(1)}s',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: vo.startTimeSeconds.clamp(
                    0.0,
                    state.config.videoDurationSeconds,
                  ),
                  min: 0.0,
                  max: state.config.videoDurationSeconds,
                  divisions: (state.config.videoDurationSeconds * 2)
                      .toInt()
                      .clamp(1, 200),
                  label: '${vo.startTimeSeconds.toStringAsFixed(1)}s',
                  onChanged: (val) => controller.setVoiceoverStartTime(val),
                ),
              ],
            ),
    );
  }

  Widget _buildDuckingCard(
    BuildContext context,
    AudioStudioConfig config,
    AudioStudioController controller,
  ) {
    return SectionCard(
      title: 'Smart Audio Ducking',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Auto-Duck Music'),
            subtitle: const Text(
              'Automatically attenuates background music when speech or voice-over is detected',
            ),
            value: config.enableDucking,
            onChanged: (val) => controller.toggleDucking(val),
            contentPadding: EdgeInsets.zero,
          ),
          if (config.enableDucking)
            const InfoBanner(
              message: 'Audio ducking utilizes hardware sidechain compression for studio-grade broadcast ducking.',
              type: InfoBannerType.info,
            ),
        ],
      ),
    );
  }

  Widget _buildExportModeCard(
    BuildContext context,
    AudioStudioConfig config,
    AudioStudioController controller,
  ) {
    return SectionCard(
      title: 'Export Target',
      icon: Icons.output_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<AudioStudioExportMode>(
            segments: const [
              ButtonSegment<AudioStudioExportMode>(
                value: AudioStudioExportMode.videoWithAudio,
                label: Text('Full Video'),
                icon: Icon(Icons.videocam_outlined),
              ),
              ButtonSegment<AudioStudioExportMode>(
                value: AudioStudioExportMode.extractedAudio,
                label: Text('Audio Only'),
                icon: Icon(Icons.audiotrack_outlined),
              ),
            ],
            selected: {config.exportMode},
            onSelectionChanged: (set) => controller.setExportMode(set.first),
          ),
          if (config.exportMode == AudioStudioExportMode.extractedAudio) ...[
            const SizedBox(height: AppTokens.spaceMd),
            const Text(
              'Audio Codec & Container',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Wrap(
              spacing: AppTokens.spaceSm,
              children: AudioOutputFormat.values.map((fmt) {
                return ChoiceChip(
                  label: Text(fmt.displayName),
                  selected: config.audioFormat == fmt,
                  onSelected: (_) => controller.setAudioFormat(fmt),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    AudioStudioState state,
    AudioStudioController controller,
  ) {
    final isAudioOnly =
        state.config.exportMode == AudioStudioExportMode.extractedAudio;
    final label = isAudioOnly ? 'Extract Audio Track' : 'Export Studio Video';

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
            // Validate audio track configuration
            final validation = const AudioValidator().validate(
              isOriginalAudioEnabled: !state.config.isOriginalMuted,
              musicFilePath: state.config.musicTrack?.sourcePath,
              voiceoverFilePath: state.config.voiceoverTrack?.sourcePath,
              requiresAudioTrack: true,
            );
            if (!validation.isValid) {
              AppMessenger.showIssue(context, validation.firstError!);
              return;
            }

            try {
              final jobId = await controller.enqueueAudioStudioJob();
              if (context.mounted) {
                AppMessenger.showSuccess(
                  context,
                  'Audio Studio Job #$jobId queued.',
                  actionLabel: 'View Queue',
                  onAction: () => context.push(AppRoutes.jobs),
                );
                await context.push(AppRoutes.jobs);
              }
            } catch (e) {
              if (context.mounted) {
                AppMessenger.showError(context, 'Failed to enqueue job: $e');
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _pickMusicFile(AudioStudioController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final trackName = p.basename(filePath);
        controller.setMusicTrack(
          AudioTrack(
            type: AudioTrackType.music,
            sourcePath: filePath,
            title: trackName,
            volume: 0.6,
            loop: true,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _pickVoiceoverFile(AudioStudioController controller) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final trackName = p.basename(filePath);
        controller.setVoiceoverTrack(
          AudioTrack(
            type: AudioTrackType.voiceover,
            sourcePath: filePath,
            title: trackName,
            volume: 1.0,
            startTimeSeconds: 0.0,
          ),
        );
      }
    } catch (_) {}
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
