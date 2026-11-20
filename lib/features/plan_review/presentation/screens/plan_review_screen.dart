import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/permission_utils.dart';
import '../../../../core/utils/storage_bridge.dart';
import '../../../../core/validation/validators/export_preflight_validator.dart';
import '../../../../core/validation/validators/output_location_validator.dart';
import '../../../../core/validation/validators/parts_selection_validator.dart';
import '../../../../core/validation/validators/select_video_validator.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/info_banner.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../processing/domain/filter_graph_builder.dart';
import '../../../processing/presentation/controllers/processing_controller.dart';
import '../../../split_config/domain/models/background_spec.dart';
import '../../../split_config/domain/models/clip_plan.dart';
import '../../../split_config/domain/models/plan_validator.dart';
import '../../../split_config/domain/models/split_config.dart';
import '../../../split_config/presentation/controllers/split_config_controller.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../domain/models/clip_processing_state.dart';
import '../controllers/part_items_controller.dart';
import '../controllers/plan_controller.dart';
import '../widgets/edit_boundary_dialog.dart';
import '../widgets/overlay_live_preview.dart';
import '../widgets/part_message_dialog.dart';
import '../widgets/part_preview_dialog.dart';
import '../widgets/plan_header_card.dart';
import '../widgets/plan_part_tile.dart';
import '../widgets/split_part_dialog.dart';
import '../widgets/workflow_choice_dialog.dart';

class PlanReviewScreen extends ConsumerStatefulWidget {
  const PlanReviewScreen({super.key});

  @override
  ConsumerState<PlanReviewScreen> createState() => _PlanReviewScreenState();
}

class _PlanReviewScreenState extends ConsumerState<PlanReviewScreen> {
  final GlobalKey _errorBannerKey = GlobalKey();
  bool _isSubmitting = false;
  String? _inlineError;

  static const _planValidator = PlanValidator();
  static const _videoValidator = SelectVideoValidator();
  static const _outputValidator = OutputLocationValidator();
  static const _preflightValidator = ExportPreflightValidator();
  static const _partsSelectionValidator = PartsSelectionValidator();

  Future<void> _startCreatingShorts(
    ClipPlan plan, {
    Set<int>? specificPartIndices,
  }) async {
    if (_isSubmitting) return;

    final video = ref.read(videoPickerControllerProvider).valueOrNull;
    final config = ref.read(splitConfigControllerProvider);
    final rawOutputDir = await ref.read(outputDirectoryProvider.future);
    final processingProgress = ref.read(processingControllerProvider);
    final partItems = ref.read(partItemsControllerProvider);

    if (!mounted) return;

    // 1. Validate Video with Explicit Dialog
    final videoResult = _videoValidator.validate(video);
    if (!videoResult.isValid) {
      final issue = videoResult.firstError!;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.video_library_outlined,
            size: 38,
            color: Theme.of(ctx).colorScheme.error,
          ),
          title: const Text('Source Video Required'),
          content: Text(issue.message),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go(AppRoutes.home);
              },
              child: const Text('Select Video'),
            ),
          ],
        ),
      );
      setState(() => _inlineError = issue.message);
      _scrollToError();
      return;
    }

    // 2. Validate Plan with Explicit Dialog
    final planResult = _planValidator.validate(plan);
    if (!planResult.isValid) {
      final issue = planResult.firstError!;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            size: 38,
            color: Theme.of(ctx).colorScheme.error,
          ),
          title: const Text('Split Plan Issue'),
          content: Text(issue.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Review Boundaries'),
            ),
          ],
        ),
      );
      setState(() => _inlineError = issue.message);
      _scrollToError();
      return;
    }

    // 3. Ensure Output Folder & SAF Permissions with Interactive Dialog
    final outputDir = await _ensureValidOutputDirectoryWithDialog(
      context,
      rawOutputDir,
    );
    if (outputDir == null) {
      if (mounted) {
        setState(
          () => _inlineError =
              'Export stopped: A valid save folder is required to write clips.',
        );
        _scrollToError();
      }
      return;
    }
    if (!mounted) return;

    // 4. Ensure Native Storage Permissions (Android 9 write permissions)
    final hasStoragePerms =
        await PermissionUtils.ensureExportStoragePermissions(
      context,
      outputDir,
    );
    if (!hasStoragePerms) {
      if (mounted) {
        setState(
          () => _inlineError =
              'Export stopped: Storage permission was not granted.',
        );
        _scrollToError();
      }
      return;
    }
    if (!mounted) return;

    // 5. Validate Parts Selection & Storage for selected parts
    final freeBytes = await StorageBridge.getFreeDiskSpace();
    if (!mounted) return;

    final effectiveItems = specificPartIndices != null
        ? partItems.map((i) {
            return i.copyWith(
              isSelected: specificPartIndices.contains(i.index),
            );
          }).toList()
        : partItems;

    final selectionResult = _partsSelectionValidator.validate(
      items: effectiveItems,
      freeDiskBytes: freeBytes,
    );
    if (!selectionResult.isValid) {
      final issue = selectionResult.firstError!;
      final selectAll = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.checklist_rtl_rounded,
            size: 38,
            color: Theme.of(ctx).colorScheme.primary,
          ),
          title: const Text('No Clips Selected'),
          content: Text(issue.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Select All Clips'),
            ),
          ],
        ),
      );

      if (selectAll == true && mounted) {
        ref.read(partItemsControllerProvider.notifier).selectAll();
        await _startCreatingShorts(
          plan,
          specificPartIndices: specificPartIndices,
        );
      } else if (mounted) {
        setState(() => _inlineError = issue.message);
        _scrollToError();
      }
      return;
    }

    final selectedItems = effectiveItems.where((i) => i.isSelected).toList();
    final selectedPartIndices = selectedItems.map((i) => i.index).toSet();

    // 6. Preflight check
    final totalSelectedDuration = selectedItems.fold<double>(
      0.0,
      (acc, item) => acc + item.durationSeconds,
    );
    final estimatedSize = (totalSelectedDuration * 500 * 1024).toInt();
    const minSafetyBytes = 50 * 1024 * 1024;
    final requiredBytes = estimatedSize + minSafetyBytes;

    final preflightResult = _preflightValidator.validate(
      isJobAlreadyRunning: processingProgress.isProcessing,
      freeDiskBytes: freeBytes,
      requiredDiskBytes: requiredBytes,
      hasNotificationPermission: true,
    );
    if (!preflightResult.isValid) {
      final issue = preflightResult.firstError!;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.storage_rounded,
            size: 38,
            color: Theme.of(ctx).colorScheme.error,
          ),
          title: const Text('Cannot Start Export'),
          content: Text(issue.message),
          actions: [
            if (issue.code == 'EXPORT_ALREADY_RUNNING')
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push(AppRoutes.processing);
                },
                child: const Text('View Active Export'),
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
          ],
        ),
      );
      setState(() => _inlineError = issue.message);
      _scrollToError();
      return;
    }

    // 7. Check if workflow choice is recommended for long plans
    var effectiveConfig = config;
    if (specificPartIndices == null &&
        (plan.totalParts >= 20 || plan.totalPlannedDurationSeconds >= 1200)) {
      final choice = await showDialog<SplitWorkflowType>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => WorkflowChoiceDialog(
          totalParts: plan.totalParts,
          totalDurationSeconds: plan.totalPlannedDurationSeconds,
        ),
      );
      if (choice == null) {
        setState(
          () => _inlineError =
              'Export paused: Please select a workflow mode to proceed.',
        );
        return;
      }
      if (choice == SplitWorkflowType.twoStage) {
        // If user specifically requested precise mode in settings, preserve exact frame accuracy
        if (config.mode != SplitMode.precise) {
          effectiveConfig = config.copyWith(mode: SplitMode.fast);
        }
      }
    }

    // Acquire idempotency lock
    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      if (!mounted) return;
      // 8. Notification permission check with explicit rationale
      final hasNotificationPerm =
          await PermissionUtils.requestNotificationPermissionIfNeeded(context);
      if (!hasNotificationPerm && mounted) {
        AppMessenger.showWarning(
          context,
          'Notification permission disabled. Progress will not appear in status bar.',
        );
      }

      if (!mounted) return;

      // 9. Battery optimization exemption check
      if (plan.totalPlannedDurationSeconds >= 600 || plan.totalParts >= 20) {
        await PermissionUtils.requestBatteryOptimizationExemptionIfNeeded(
          context,
        );
      }

      if (!mounted) return;

      // 10. Launch export job for selected parts
      final success =
          await ref.read(processingControllerProvider.notifier).startSplit(
                video: video!,
                config: effectiveConfig,
                outputDirectoryPath: outputDir,
                plan: plan,
                selectedPartIndices: selectedPartIndices,
              );

      if (!mounted) return;

      if (success) {
        unawaited(context.push(AppRoutes.processing));
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: Theme.of(ctx).colorScheme.error,
            ),
            title: const Text('Export Could Not Start'),
            content: const Text(
              'The export engine could not start. Please ensure another export is not already running and that your output storage is accessible.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: Icon(
              Icons.error_outline_rounded,
              size: 38,
              color: Theme.of(ctx).colorScheme.error,
            ),
            title: const Text('Export Error'),
            content: Text(
              'An unexpected error occurred while starting export: $e',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _ensureValidOutputDirectoryWithDialog(
    BuildContext context,
    String currentOutputDir,
  ) async {
    bool isSafValid = true;
    if (currentOutputDir.startsWith('content://')) {
      isSafValid = await StorageBridge.isPersistedUriValid(currentOutputDir);
    }

    final outputResult = _outputValidator.validate(
      outputDirectoryPath: currentOutputDir,
      isSafPermissionValid: isSafValid,
    );

    if (outputResult.isValid) {
      return currentOutputDir;
    }

    final issue = outputResult.firstError!;
    if (!context.mounted) return null;
    final shouldPick = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.folder_shared_outlined,
          size: 40,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: const Text('Save Folder Access Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issue.message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'ShortsSplitter requires a designated folder with active write permissions to save your exported video clips.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: () => Navigator.of(ctx).pop(true),
            label: const Text('Choose Save Folder'),
          ),
        ],
      ),
    );

    if (shouldPick == true && mounted) {
      final success = await ref
          .read(outputDirectoryProvider.notifier)
          .pickAndSetDirectory();
      if (success) {
        final newDir = await ref.read(outputDirectoryProvider.future);
        return newDir;
      }
    }

    return null;
  }

  Future<void> _showPreviewClipDialog(
    BuildContext context,
    ClipPlanItem item,
    ClipPlan plan,
    PickedVideo? video,
  ) async {
    if (video == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.error_outline, size: 36),
          title: const Text('Source Video Required'),
          content: const Text(
            'Please select a video file first to preview clips.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Check media/video read permissions before previewing
    final hasPerm =
        await PermissionUtils.requestVideoReadPermissionIfNeeded(context);
    if (!hasPerm) {
      if (context.mounted) {
        AppMessenger.showWarning(
          context,
          'Video permission required to preview video playback.',
        );
      }
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => PartPreviewDialog(
        video: video,
        item: item,
        plan: plan,
      ),
    );
  }

  void _scrollToError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_errorBannerKey.currentContext != null) {
        Scrollable.ensureVisible(
          _errorBannerKey.currentContext!,
          duration: AppTokens.durationNormal,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planReviewControllerProvider);
    final planNotifier = ref.read(planReviewControllerProvider.notifier);
    final partItems = ref.watch(partItemsControllerProvider);
    final partNotifier = ref.read(partItemsControllerProvider.notifier);
    final video = ref.watch(videoPickerControllerProvider).valueOrNull;

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan Review')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 16),
              const Text('No active split plan found.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Return Home'),
              ),
            ],
          ),
        ),
      );
    }

    final selectedCount = partItems.where((i) => i.isSelected).length;
    final totalCount = plan.totalParts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset to auto-suggested plan',
            onPressed: () => _confirmReset(context, planNotifier),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          PlanHeaderCard(
            plan: plan,
            onEditBaseName: () =>
                _showEditBaseNameDialog(context, plan.baseName, planNotifier),
          ),
          const SizedBox(height: 16),
          if (plan.totalParts == 1) ...[
            const InfoBanner(
              message: 'Your video fits in 1 short. No splitting needed!',
              type: InfoBannerType.info,
            ),
            const SizedBox(height: 12),
          ],
          if (plan.totalParts == 1 &&
              video != null &&
              FilterGraphBuilder.matchesCanvasAspectRatio(
                sourceWidth: video.width,
                sourceHeight: video.height,
                canvasSpec: plan.canvasSpec,
              ) &&
              plan.backgroundSpec.type == BackgroundType.solidColor &&
              !plan.cropToFill) ...[
            const InfoBanner(
              message: 'Already Shorts-ready: Fast stream copy available.',
              type: InfoBannerType.info,
            ),
            const SizedBox(height: 12),
          ],
          if (_inlineError != null) ...[
            KeyedSubtree(
              key: _errorBannerKey,
              child: InfoBanner(
                message: _inlineError!,
                type: InfoBannerType.error,
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildLivePreviewSection(context, plan),
          const SizedBox(height: 20),
          _buildSequenceHeader(context, plan.totalParts),
          const SizedBox(height: 10),
          _buildSelectionActionBar(
            context,
            selectedCount: selectedCount,
            totalCount: totalCount,
            partNotifier: partNotifier,
          ),
          const SizedBox(height: 10),
          ..._buildPartTiles(
            context,
            plan,
            planNotifier,
            partItems,
            partNotifier,
          ),
          const SizedBox(height: 90),
        ],
      ),
      bottomSheet: _buildBottomActionBar(
        context,
        plan,
        selectedCount: selectedCount,
        partItems: partItems,
      ),
    );
  }

  Widget _buildLivePreviewSection(BuildContext context, ClipPlan plan) {
    final theme = Theme.of(context);
    final video = ref.watch(videoPickerControllerProvider).valueOrNull;
    final firstPartMessage =
        plan.items.isNotEmpty ? plan.items.first.resolvedMessage : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Overlay Preview',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        OverlayLivePreview(
          canvasSpec: plan.canvasSpec,
          backgroundSpec: plan.backgroundSpec,
          overlaySpec: plan.overlaySpec,
          previewText: firstPartMessage,
          sourceWidth: video?.width ?? 1920,
          sourceHeight: video?.height ?? 1080,
          verticalPosition: plan.verticalPosition,
          verticalOffsetFraction: plan.verticalOffsetFraction,
          cropToFill: plan.cropToFill,
          onPreviewTap: plan.items.isNotEmpty && video != null
              ? () => _showPreviewClipDialog(
                    context,
                    plan.items.first,
                    plan,
                    video,
                  )
              : null,
        ),
      ],
    );
  }

  Widget _buildSequenceHeader(BuildContext context, int totalParts) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          'Planned Sequence ($totalParts clips)',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Contiguous (0 gaps)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionActionBar(
    BuildContext context, {
    required int selectedCount,
    required int totalCount,
    required PartItemsController partNotifier,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_box_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '$selectedCount of $totalCount selected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => partNotifier.selectAll(),
                child: const Text('Select All'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => partNotifier.selectNone(),
                child: const Text('Deselect'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () => partNotifier.invertSelection(),
                child: const Text('Invert'),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                tooltip: 'Selection options',
                onSelected: (val) {
                  switch (val) {
                    case 'not_converted':
                      partNotifier.selectNotConverted();
                      break;
                    case 'failed':
                      partNotifier.selectFailed();
                      break;
                    case 'next_10':
                      partNotifier.selectNextN(10);
                      break;
                    case 'next_20':
                      partNotifier.selectNextN(20);
                      break;
                    case 'range':
                      _showSelectRangeDialog(context, totalCount, partNotifier);
                      break;
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'not_converted',
                    child: Text('Select Not Converted'),
                  ),
                  PopupMenuItem(
                    value: 'failed',
                    child: Text('Select Failed'),
                  ),
                  PopupMenuItem(
                    value: 'next_10',
                    child: Text('Select Next 10'),
                  ),
                  PopupMenuItem(
                    value: 'next_20',
                    child: Text('Select Next 20'),
                  ),
                  PopupMenuItem(
                    value: 'range',
                    child: Text('Select Range...'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPartTiles(
    BuildContext context,
    ClipPlan plan,
    PlanReviewController notifier,
    List<PartItem> partItems,
    PartItemsController partNotifier,
  ) {
    final video = ref.watch(videoPickerControllerProvider).valueOrNull;
    final tiles = <Widget>[];
    for (int i = 0; i < plan.items.length; i++) {
      final item = plan.items[i];
      final isLast = (i == plan.items.length - 1);
      final nextItem = isLast ? null : plan.items[i + 1];

      // Match item with corresponding PartItem
      final partItem = i < partItems.length
          ? partItems[i]
          : PartItem(segment: item.toClipSegment(), planItem: item);

      tiles.add(
        PlanPartTile(
          item: item,
          isLast: isLast,
          nextItem: nextItem,
          isSelected: partItem.isSelected,
          status: partItem.status,
          onToggleSelect: (_) => partNotifier.toggleSelect(item.index),
          onPreview: video != null
              ? () => _showPreviewClipDialog(context, item, plan, video)
              : null,
          onRetry: () =>
              _startCreatingShorts(plan, specificPartIndices: {item.index}),
          onEditMessage: () => _showEditMessageDialog(context, item, notifier),
          onAdjustBoundary: isLast
              ? null
              : () => _showAdjustBoundaryDialog(
                    context,
                    item,
                    nextItem!,
                    i,
                    notifier,
                  ),
          onMergeWithNext: isLast ? null : () => notifier.mergeWithNext(i),
          onSplitPart: () => _showSplitPartDialog(context, item, i, notifier),
          onTrimToCap: isLast
              ? null
              : () => notifier.adjustBoundary(
                    i,
                    item.startSeconds + AppConstants.maxClipDurationSeconds,
                  ),
          onResplitPrecisely: () =>
              _showSplitPartDialog(context, item, i, notifier),
        ),
      );
    }
    return tiles;
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    ClipPlan plan, {
    required int selectedCount,
    required List<PartItem> partItems,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final selectedDuration = partItems
        .where((i) => i.isSelected)
        .fold<double>(0.0, (acc, i) => acc + i.durationSeconds);

    final String buttonLabel;
    if (selectedCount == 0) {
      buttonLabel = 'Select parts to process';
    } else if (plan.totalParts == 1 && selectedCount == 1) {
      buttonLabel =
          'Create 1 Short (${plan.totalPlannedDurationSeconds.toStringAsFixed(1)}s)';
    } else if (selectedCount == plan.totalParts) {
      buttonLabel =
          'Create ${plan.totalParts} Shorts (${plan.totalPlannedDurationSeconds.toStringAsFixed(1)}s)';
    } else {
      buttonLabel =
          'Create $selectedCount of ${plan.totalParts} Shorts (${selectedDuration.toStringAsFixed(1)}s)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_inlineError != null) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: colorScheme.onErrorContainer,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Dismiss error',
                      onPressed: () => setState(() => _inlineError = null),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: PrimaryButton(
                icon: Icons.movie_creation_outlined,
                isLoading: _isSubmitting,
                label: _isSubmitting ? 'Starting Export...' : buttonLabel,
                onPressed:
                    _isSubmitting ? null : () => _startCreatingShorts(plan),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMessageDialog(
    BuildContext context,
    ClipPlanItem item,
    PlanReviewController notifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => PartMessageDialog(
        item: item,
        onSave: (customText, override) => notifier.updatePartDetails(
          item.index - 1,
          customMessage: customText,
          override: override,
        ),
      ),
    );
  }

  void _showAdjustBoundaryDialog(
    BuildContext context,
    ClipPlanItem left,
    ClipPlanItem right,
    int boundaryIndex,
    PlanReviewController notifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => EditBoundaryDialog(
        leftPart: left,
        rightPart: right,
        onSave: (newBoundary) =>
            notifier.adjustBoundary(boundaryIndex, newBoundary),
      ),
    );
  }

  void _showSplitPartDialog(
    BuildContext context,
    ClipPlanItem part,
    int index,
    PlanReviewController notifier,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SplitPartDialog(
        part: part,
        onSplit: (splitTime) => notifier.splitPart(index, splitTime),
      ),
    );
  }

  void _confirmReset(BuildContext context, PlanReviewController notifier) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Split Plan?'),
        content: const Text(
          'This will discard your custom boundaries and part messages, restoring the default plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              notifier.resetToAuto();
              Navigator.of(ctx).pop();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditBaseNameDialog(
    BuildContext context,
    String currentBaseName,
    PlanReviewController notifier,
  ) async {
    final controller = TextEditingController(text: currentBaseName);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit File Name Prefix'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This prefix will be applied to all split clips across all pages (e.g. {prefix}_part_001.mp4).',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'File Name Prefix',
                    hintText: 'e.g. my_awesome_clip',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.drive_file_rename_outline),
                  ),
                  autofocus: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Prefix cannot be empty';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
              child: const Text('Save & Apply to All'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      notifier.updateBaseName(result);
    }
  }

  Future<void> _showSelectRangeDialog(
    BuildContext context,
    int totalCount,
    PartItemsController partNotifier,
  ) async {
    final startController = TextEditingController(text: '1');
    final endController =
        TextEditingController(text: totalCount > 10 ? '10' : '$totalCount');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Range of Parts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Start Part #'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: endController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'End Part #'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (result == true) {
      final start = int.tryParse(startController.text) ?? 1;
      final end = int.tryParse(endController.text) ?? totalCount;
      partNotifier.selectRange(start, end);
    }
  }
}
