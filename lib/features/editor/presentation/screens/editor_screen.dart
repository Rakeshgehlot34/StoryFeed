import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/section_card.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../domain/models/edit_project.dart';
import '../controllers/editor_controller.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final TextEditingController _textOverlayController = TextEditingController();

  @override
  void dispose() {
    _textOverlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);

    // Sync picked video from picker controller if not yet loaded in editor
    ref.listen(videoPickerControllerProvider, (prev, next) {
      final video = next.value;
      if (video != null && editorState.video == null) {
        controller.loadVideo(video);
      }
    });

    final project = editorState.project;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio Video Editor'),
        actions: [
          if (editorState.video != null)
            IconButton(
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Change Video',
              onPressed: () => _pickVideo(context),
            ),
        ],
      ),
      body: project == null
          ? EmptyState(
              icon: Icons.movie_edit,
              title: 'No Video Loaded',
              message: 'Select a video to edit with professional 1-pass FFmpeg transformations.',
              actionLabel: 'Choose Video',
              onAction: () => _pickVideo(context),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(context, project, controller),
                  const SizedBox(height: AppTokens.spaceMd),
                  _buildPreviewActionRow(context, editorState, controller),
                  const SizedBox(height: AppTokens.spaceMd),
                  if (editorState.errorMessage != null) ...[
                    InfoBanner(
                      message: editorState.errorMessage!,
                      type: InfoBannerType.error,
                    ),
                    const SizedBox(height: AppTokens.spaceMd),
                  ],
                  _buildToolSelector(
                    context,
                    editorState.activeToolIndex,
                    controller,
                  ),
                  const SizedBox(height: AppTokens.spaceMd),
                  _buildActiveToolCard(
                    context,
                    project,
                    editorState.activeToolIndex,
                    controller,
                  ),
                  const SizedBox(height: AppTokens.spaceXl),
                  PrimaryButton(
                    label:
                        'Export Studio Video (${Formatters.formatSeconds(project.outputDuration)})',
                    icon: Icons.save_alt_rounded,
                    onPressed: () async {
                      try {
                        await controller.enqueueExport();
                        if (context.mounted) {
                          AppMessenger.showSuccess(
                            context,
                            'Studio edit queued! Processing in foreground service...',
                          );
                          context.go(AppRoutes.jobs);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppMessenger.showError(
                            context,
                            'Failed to export: $e',
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: AppTokens.spaceXl),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    EditProject project,
    EditorController controller,
  ) {
    final theme = Theme.of(context);

    return SectionCard(
      title: 'Project Info',
      icon: Icons.movie_filter_outlined,
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        tooltip: 'Rename Project',
        onPressed: () => _showRenameDialog(context, project, controller),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            'Source: ${project.sourceVideoName} • ${project.sourceWidth}x${project.sourceHeight}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            'Trim: ${Formatters.formatSeconds(project.trim.startSeconds)} → ${Formatters.formatSeconds(project.trim.endSeconds)} '
            '• Speed: ${project.speed.speed}x • Output: ${Formatters.formatSeconds(project.outputDuration)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewActionRow(
    BuildContext context,
    EditorState state,
    EditorController controller,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: state.isPreviewLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_circle_outline_rounded),
            label: Text(
              state.isPreviewLoading
                  ? 'Generating 5s Preview...'
                  : '5s Quick Preview',
            ),
            onPressed: state.isPreviewLoading
                ? null
                : () => controller.generatePreview(),
          ),
        ),
        if (state.previewPath != null) ...[
          const SizedBox(width: AppTokens.spaceSm),
          const Chip(
            avatar: Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: Colors.green,
            ),
            label: Text('Preview Ready'),
          ),
        ],
      ],
    );
  }

  Widget _buildToolSelector(
    BuildContext context,
    int activeIndex,
    EditorController controller,
  ) {
    final tools = [
      (Icons.content_cut_rounded, 'Trim'),
      (Icons.crop_rotate_rounded, 'Canvas'),
      (Icons.speed_rounded, 'Speed'),
      (Icons.color_lens_outlined, 'Color'),
      (Icons.layers_outlined, 'Overlay'),
      (Icons.auto_fix_high_rounded, 'Effects'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tools.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isSelected = activeIndex == idx;

          return Padding(
            padding: const EdgeInsets.only(right: AppTokens.spaceSm),
            child: ChoiceChip(
              avatar: Icon(item.$1, size: 16),
              label: Text(item.$2),
              selected: isSelected,
              onSelected: (_) => controller.setActiveTool(idx),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveToolCard(
    BuildContext context,
    EditProject project,
    int activeIndex,
    EditorController controller,
  ) {
    return switch (activeIndex) {
      0 => _buildTrimTool(context, project, controller),
      1 => _buildCanvasTool(context, project, controller),
      2 => _buildSpeedTool(context, project, controller),
      3 => _buildColorTool(context, project, controller),
      4 => _buildOverlayTool(context, project, controller),
      _ => _buildEffectsTool(context, project, controller),
    };
  }

  Widget _buildTrimTool(
    BuildContext context,
    EditProject project,
    EditorController controller,
  ) {
    final maxSec = project.sourceDurationSeconds > 0
        ? project.sourceDurationSeconds
        : 60.0;

    return SectionCard(
      title: 'Trim Selection',
      icon: Icons.content_cut_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Range: ${Formatters.formatSeconds(project.trim.startSeconds)} → ${Formatters.formatSeconds(project.trim.endSeconds)} '
            '(${Formatters.formatSeconds(project.activeTrimDuration)})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          RangeSlider(
            values: RangeValues(
              project.trim.startSeconds.clamp(0.0, maxSec),
              project.trim.endSeconds > 0
                  ? project.trim.endSeconds.clamp(0.0, maxSec)
                  : maxSec,
            ),
            min: 0.0,
            max: maxSec,
            divisions: maxSec > 10 ? maxSec.toInt() : 10,
            onChanged: (vals) {
              if (vals.end - vals.start >= 0.5) {
                controller.setTrim(vals.start, vals.end);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasTool(
    BuildContext context,
    EditProject project,
    EditorController controller,
  ) {
    return SectionCard(
      title: 'Canvas & Orientation',
      icon: Icons.crop_rotate_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aspect Ratio:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: TargetAspectRatio.values.map((aspect) {
              final isSel = project.canvas.aspectRatio == aspect;
              return ChoiceChip(
                label: Text(aspect.label),
                selected: isSel,
                onSelected: (_) => controller.setCanvas(aspectRatio: aspect),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          const Text(
            'Fit Mode:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: CanvasFitMode.values.map((fit) {
              final isSel = project.canvas.fitMode == fit;
              return ChoiceChip(
                label: Text(fit.label),
                selected: isSel,
                onSelected: (_) => controller.setCanvas(fitMode: fit),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.rotate_right_rounded),
                label: Text('Rotate (${project.transform.rotationDegrees}°)'),
                onPressed: () {
                  final next = (project.transform.rotationDegrees + 90) % 360;
                  controller.setRotation(next);
                },
              ),
              const SizedBox(width: AppTokens.spaceSm),
              FilterChip(
                label: const Text('Flip H'),
                selected: project.transform.hflip,
                onSelected: (_) => controller.toggleHFlip(),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              FilterChip(
                label: const Text('Flip V'),
                selected: project.transform.vflip,
                onSelected: (_) => controller.toggleVFlip(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedTool(
    BuildContext context,
    EditProject project,
    EditorController controller,
  ) {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0];

    return SectionCard(
      title: 'Playback Speed',
      icon: Icons.speed_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Speed: ${project.speed.speed}x',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Wrap(
            spacing: AppTokens.spaceSm,
            runSpacing: AppTokens.spaceXs,
            children: speeds.map((s) {
              final isSel = (project.speed.speed - s).abs() < 0.01;
              return ChoiceChip(
                label: Text('${s}x'),
                selected: isSel,
                onSelected: (_) =>
                    controller.setSpeed(s, project.speed.preservePitch),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          SwitchListTile(
            title: const Text('Preserve Audio Pitch'),
            subtitle: const Text(
              'Maintains natural voice pitch using chained atempo filters',
            ),
            value: project.speed.preservePitch,
            onChanged: (val) => controller.setSpeed(project.speed.speed, val),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildColorTool(
    BuildContext context,
    EditProject project,
    EditorController controller,
  ) {
    return SectionCard(
      title: 'Color & Grading',
      icon: Icons.color_lens_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preset Filters:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Wrap(
            spacing: AppTokens.spaceSm,
            children: ColorFilterPreset.values.map((preset) {
              final isSel = project.color.preset == preset;
              return ChoiceChip(
                label: Text(preset.label),
                selected: isSel,
                onSelected: (_) => controller.setColorFilter(preset: preset),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          Text('Brightness: ${(project.color.brightness * 100).toInt()}%'),
          Slider(
            value: project.color.brightness,
            min: -1.0,
            max: 1.0,
            divisions: 20,
            onChanged: (val) => controller.setColorFilter(brightness: val),
          ),
          Text('Contrast: ${project.color.contrast.toStringAsFixed(2)}x'),
          Slider(
            value: project.color.contrast,
            min: 0.0,
            max: 2.0,
            divisions: 20,
            onChanged: (val) => controller.setColorFilter(contrast: val),
          ),
          Text('Saturation: ${project.color.saturation.toStringAsFixed(2)}x'),
          Slider(
            value: project.color.saturation,
            min: 0.0,
            max: 3.0,
            divisions: 30,
            onChanged: (val) => controller.setColorFilter(saturation: val),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayTool(
    BuildContext context,
    EditProject project,
    EditorController controller,
  ) {
    return SectionCard(
      title: 'Watermark & Text Badge',
      icon: Icons.layers_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Text Overlay:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textOverlayController,
                  decoration: const InputDecoration(
                    hintText: 'Enter overlay text...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              FilledButton.tonal(
                onPressed: () {
                  final text = _textOverlayController.text.trim();
                  if (text.isNotEmpty) {
                    controller.setTextOverlay(TextOverlaySpec(text: text));
                  } else {
                    controller.setTextOverlay(null);
                  }
                },
                child: const Text('Set'),
              ),
            ],
          ),
          if (project.textOverlay != null) ...[
            const SizedBox(height: AppTokens.spaceSm),
            Chip(
              label: Text('Active: "${project.textOverlay!.text}"'),
              onDeleted: () {
                _textOverlayController.clear();
                controller.setTextOverlay(null);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEffectsTool(
    BuildContext context,
    EditProject project,
    EditorController controller,
  ) {
    return SectionCard(
      title: 'Fades & Effects',
      icon: Icons.auto_fix_high_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fade In: ${project.fade.fadeInSeconds.toStringAsFixed(1)}s'),
          Slider(
            value: project.fade.fadeInSeconds,
            min: 0.0,
            max: 5.0,
            divisions: 10,
            onChanged: (val) => controller.setFade(fadeIn: val),
          ),
          Text('Fade Out: ${project.fade.fadeOutSeconds.toStringAsFixed(1)}s'),
          Slider(
            value: project.fade.fadeOutSeconds,
            min: 0.0,
            max: 5.0,
            divisions: 10,
            onChanged: (val) => controller.setFade(fadeOut: val),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          SwitchListTile(
            title: const Text('Reverse Playback'),
            subtitle: Text(
              project.isReverseAllowed
                  ? 'Reverses both video and audio frames'
                  : 'Requires clip <= 15s (current: ${Formatters.formatSeconds(project.activeTrimDuration)})',
            ),
            value: project.reverse,
            onChanged: project.isReverseAllowed
                ? (val) => controller.setReverse(val)
                : null,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    EditProject project,
    EditorController controller,
  ) {
    final textController = TextEditingController(text: project.title);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Project'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = textController.text.trim();
              if (newTitle.isNotEmpty) controller.setTitle(newTitle);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
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
