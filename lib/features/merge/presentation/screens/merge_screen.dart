import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../domain/models/merge_project.dart';
import '../controllers/merge_controller.dart';
import '../widgets/merge_clip_tile.dart';
import '../widgets/merge_settings_card.dart';
import '../widgets/merge_summary_card.dart';
import '../widgets/merge_trim_dialog.dart';

/// Screen allowing users to combine multiple video clips into a single video
/// with reordering, canvas aspect ratio normalization, and crossfade transitions.
class MergeScreen extends ConsumerStatefulWidget {
  const MergeScreen({super.key});

  @override
  ConsumerState<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends ConsumerState<MergeScreen> {
  Future<void> _pickVideos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        final paths = result.paths.whereType<String>().toList();
        if (paths.isNotEmpty && mounted) {
          await ref.read(mergeControllerProvider.notifier).addVideos(paths);
        }
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showError(context, 'Failed to pick videos: $e');
      }
    }
  }

  void _showTrimDialog(BuildContext context, MergeClipItem clip) {
    showDialog<void>(
      context: context,
      builder: (ctx) => MergeTrimDialog(
        clip: clip,
        onSave: (start, end) {
          ref
              .read(mergeControllerProvider.notifier)
              .updateClipTrim(
                id: clip.id,
                startTrimSeconds: start,
                endTrimSeconds: end,
              );
        },
      ),
    );
  }

  Future<void> _startMerge(BuildContext context) async {
    final controller = ref.read(mergeControllerProvider.notifier);
    try {
      final job = await controller.dispatchMergeJob();
      if (context.mounted) {
        AppMessenger.showSuccess(
          context,
          'Merge job queued: ${job.title}',
          actionLabel: 'View Queue',
          onAction: () => context.go(AppRoutes.jobs),
        );
        context.go(AppRoutes.jobs);
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.showError(context, 'Failed to start merge: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mergeState = ref.watch(mergeControllerProvider);
    final controller = ref.read(mergeControllerProvider.notifier);
    final hasClips = mergeState.config.clips.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Merge'),
        actions: [
          if (hasClips) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Add Videos',
              onPressed: _pickVideos,
            ),
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              tooltip: 'Clear All',
              onPressed: controller.clearAll,
            ),
          ],
        ],
      ),
      body: _buildBody(context, mergeState, controller),
      bottomNavigationBar: hasClips
          ? _buildBottomBar(context, mergeState)
          : null,
    );
  }

  Widget _buildBody(
    BuildContext context,
    MergeState state,
    MergeController controller,
  ) {
    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: LoadingSkeleton.card(height: 200),
      );
    }

    if (state.errorMessage != null && state.config.clips.isEmpty) {
      return ErrorState(message: state.errorMessage!, onRetry: _pickVideos);
    }

    if (state.config.clips.isEmpty) {
      return EmptyState(
        icon: Icons.call_merge_rounded,
        title: 'No Videos Selected',
        message: 'Select two or more video clips to reorder, normalize canvas, and merge into one continuous video.',
        actionLabel: 'Select Videos',
        onAction: _pickVideos,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      children: [
        MergeSummaryCard(state: state),
        const SizedBox(height: AppTokens.spaceMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Clips Sequence (${state.clipCount})',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add More'),
              onPressed: _pickVideos,
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceXs),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.config.clips.length,
          // ignore: deprecated_member_use
          onReorder: controller.reorderClips,
          itemBuilder: (ctx, index) {
            final clip = state.config.clips[index];
            return MergeClipTile(
              key: ValueKey(clip.id),
              index: index,
              clip: clip,
              onTrimPressed: () => _showTrimDialog(context, clip),
              onDuplicatePressed: () => controller.duplicateClip(clip.id),
              onDeletePressed: () => controller.removeClip(clip.id),
            );
          },
        ),
        const SizedBox(height: AppTokens.spaceMd),
        MergeSettingsCard(state: state, controller: controller),
        const SizedBox(height: AppTokens.spaceXl),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, MergeState state) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SafeArea(
        child: PrimaryButton(
          label: state.canMerge
              ? 'Merge ${state.clipCount} Videos'
              : 'Add at least 2 videos to merge',
          icon: Icons.call_merge_rounded,
          isLoading: state.isAnalyzing,
          onPressed: state.canMerge && !state.isAnalyzing
              ? () => _startMerge(context)
              : null,
        ),
      ),
    );
  }
}
