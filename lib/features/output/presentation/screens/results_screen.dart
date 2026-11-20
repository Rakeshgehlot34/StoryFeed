import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/clip_tile.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/secondary_button.dart';
import '../../../plan_review/domain/models/clip_processing_state.dart';
import '../../../plan_review/presentation/controllers/part_items_controller.dart';
import '../../../plan_review/presentation/controllers/plan_controller.dart';
import '../../../processing/domain/export_job_controller.dart';
import '../../../processing/presentation/controllers/processing_controller.dart';
import '../../../split_config/presentation/controllers/split_config_controller.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../domain/models/exported_clip.dart';
import '../controllers/output_controller.dart';
import '../widgets/convert_to_shorts_dialog.dart';

/// Screen presenting exported clips with sharing, full preview, storage actions,
/// and selective indicators for unprocessed clips in the plan.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipsAsync = ref.watch(exportedClipsProvider);
    final outputDirAsync = ref.watch(outputDirectoryProvider);
    final plan = ref.watch(planReviewControllerProvider);
    final partItems = ref.watch(partItemsControllerProvider);
    final notifier = ref.read(exportedClipsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exported Clips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share all clips',
            onPressed: () => _shareAll(clipsAsync.valueOrNull ?? []),
          ),
        ],
      ),
      body: clipsAsync.when(
        loading: () => _buildLoading(),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(exportedClipsProvider),
        ),
        data: (clips) {
          if (clips.isEmpty && partItems.isEmpty) {
            return EmptyState(
              icon: Icons.video_library_outlined,
              title: 'No Exported Clips',
              message:
                  'Exported shorts will appear here once processing completes.',
              actionLabel: AppStrings.createShorts,
              onAction: () => _createAnother(context, ref),
            );
          }
          final dirPath = outputDirAsync.valueOrNull ?? '';
          return _buildContent(
            context,
            ref,
            clips,
            dirPath,
            notifier,
            planParts: partItems,
            totalPlanParts: plan?.totalParts ??
                (partItems.isNotEmpty ? partItems.length : clips.length),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      children: [
        LoadingSkeleton.card(height: 80),
        const SizedBox(height: AppTokens.spaceMd),
        LoadingSkeleton.tile(),
        const SizedBox(height: AppTokens.spaceSm),
        LoadingSkeleton.tile(),
        const SizedBox(height: AppTokens.spaceSm),
        LoadingSkeleton.tile(),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<ExportedClip> clips,
    String dirPath,
    ExportedClipsNotifier notifier, {
    required List<PartItem> planParts,
    required int totalPlanParts,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPartial = totalPlanParts > clips.length && clips.isNotEmpty;
    final remainingCount = totalPlanParts - clips.length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceLg,
            vertical: AppTokens.spaceMd,
          ),
          color: isPartial
              ? colorScheme.secondaryContainer.withValues(alpha: 0.35)
              : colorScheme.primaryContainer.withValues(alpha: 0.35),
          child: Row(
            children: [
              Icon(
                isPartial
                    ? Icons.pie_chart_outline_rounded
                    : Icons.check_circle_rounded,
                color: isPartial ? colorScheme.secondary : colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPartial
                          ? 'Created ${clips.length} of $totalPlanParts shorts ($remainingCount remaining)'
                          : 'Successfully created ${clips.length} ${clips.length == 1 ? 'clip' : 'clips'}!',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPartial
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                    if (dirPath.isNotEmpty)
                      Text(
                        'Saved to: $dirPath',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceLg,
            vertical: AppTokens.spaceSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  icon: Icons.folder_open_outlined,
                  label: 'Open Folder',
                  onPressed:
                      dirPath.isNotEmpty ? () => OpenFilex.open(dirPath) : null,
                ),
              ),
              const SizedBox(width: AppTokens.spaceMd),
              Expanded(
                child: SecondaryButton(
                  icon: Icons.share_outlined,
                  label: 'Share All',
                  onPressed: () => _shareAll(clips),
                ),
              ),
            ],
          ),
        ),
        if (clips.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceLg,
              vertical: AppTokens.spaceSm,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceMd,
              vertical: AppTokens.spaceSm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  radius: 16,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Convert to 9:16 Shorts',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        'Format into 9:16 vertical canvas with part labels ({n}/{total}) and background blur.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.movie_filter_rounded, size: 16),
                  label: const Text('Convert'),
                  onPressed: () =>
                      _showConvertToShortsDialog(context, ref, clips),
                ),
              ],
            ),
          ),
        ],
        const Divider(height: 1),
        Expanded(
          child: _buildClipsList(
            context,
            ref,
            clips,
            planParts,
            totalPlanParts,
            notifier,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isPartial && clips.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        'Convert ${clips.length == 1 ? 'Clip' : 'All ${clips.length} Clips'} to 9:16 Shorts',
                      ),
                      onPressed: () =>
                          _showConvertToShortsDialog(context, ref, clips),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                ],
                if (isPartial) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.playlist_play_rounded),
                      label: Text('Process Remaining ($remainingCount clips)'),
                      onPressed: () => context.push(AppRoutes.planReview),
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    label: const Text('Done • Create Another'),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () => _createAnother(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClipsList(
    BuildContext context,
    WidgetRef ref,
    List<ExportedClip> clips,
    List<PartItem> planParts,
    int totalPlanParts,
    ExportedClipsNotifier notifier,
  ) {
    // If no plan is cached, show exported clips directly
    if (planParts.isEmpty || totalPlanParts <= clips.length) {
      return ListView.separated(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        itemCount: clips.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.spaceSm),
        itemBuilder: (context, index) {
          final clip = clips[index];
          return ClipTile(
            clip: clip,
            onPreview: () => context.push(
              AppRoutes.player,
              extra: {'clips': clips, 'initialIndex': index},
            ),
            onConvert: () => _showConvertToShortsDialog(
              context,
              ref,
              clips,
              initialSelectedPartIndex: clip.partIndex,
            ),
            onDelete: () => _confirmDelete(context, clip, notifier),
          );
        },
      );
    }

    // Map existing clips by partIndex
    final clipMap = {for (final c in clips) c.partIndex: c};

    return ListView.separated(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      itemCount: planParts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppTokens.spaceSm),
      itemBuilder: (context, index) {
        final partItem = planParts[index];
        final exportedClip = clipMap[partItem.index];

        if (exportedClip != null) {
          final clipIndex = clips.indexOf(exportedClip);
          return ClipTile(
            clip: exportedClip,
            onPreview: () => context.push(
              AppRoutes.player,
              extra: {
                'clips': clips,
                'initialIndex': clipIndex >= 0 ? clipIndex : 0,
              },
            ),
            onConvert: () => _showConvertToShortsDialog(
              context,
              ref,
              clips,
              initialSelectedPartIndex: exportedClip.partIndex,
            ),
            onDelete: () => _confirmDelete(context, exportedClip, notifier),
          );
        }

        // Render dimmed unprocessed clip row with quick Process button
        return _buildUnprocessedPartCard(context, ref, partItem);
      },
    );
  }

  Future<void> _showConvertToShortsDialog(
    BuildContext context,
    WidgetRef ref,
    List<ExportedClip> clips, {
    int? initialSelectedPartIndex,
  }) async {
    if (clips.isEmpty) {
      AppMessenger.showInfo(context, 'No clips available to convert.');
      return;
    }

    final params = await showDialog<ConvertToShortsParams>(
      context: context,
      builder: (ctx) => ConvertToShortsDialog(
        clips: clips,
        initialSelectedPartIndex: initialSelectedPartIndex,
      ),
    );

    if (params == null || params.selectedPartIndices.isEmpty) return;

    final activeRecord = ref.read(exportJobControllerProvider).activeRecord;
    final projectId =
        activeRecord?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final plan = ref.read(planReviewControllerProvider);

    final success = await ref
        .read(processingControllerProvider.notifier)
        .startStage2Conversion(
          projectId: projectId,
          selectedPartIndices: params.selectedPartIndices,
          config: params.config,
          replaceStrategy: params.replaceStrategy,
          plan: plan,
        );

    if (context.mounted && success) {
      unawaited(context.push(AppRoutes.processing));
    }
  }

  Widget _buildUnprocessedPartCard(
    BuildContext context,
    WidgetRef ref,
    PartItem part,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              child: Text(
                '${part.index}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.formattedName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${part.formattedTimeRange} • Not processed',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: const Text('Process'),
              onPressed: () {
                // Select only this part in controller and navigate to plan review
                ref
                    .read(partItemsControllerProvider.notifier)
                    .selectRange(part.index, part.index);
                context.push(AppRoutes.planReview);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareAll(List<ExportedClip> clips) {
    if (clips.isEmpty) return;
    final files = clips.map((c) => XFile(c.path)).toList();
    Share.shareXFiles(
      files,
      text: 'YouTube Shorts clips generated with ShortsSplitter',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExportedClip clip,
    ExportedClipsNotifier notifier,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Clip?',
      message:
          'Are you sure you want to delete "${clip.fileName}" from storage?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      await notifier.deleteClip(clip);
    }
  }

  void _createAnother(BuildContext context, WidgetRef ref) {
    ref.read(videoPickerControllerProvider.notifier).clear();
    ref.read(splitConfigControllerProvider.notifier).resetForNewVideo();
    context.go(AppRoutes.create);
  }
}
