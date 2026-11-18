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
import '../../../processing/presentation/controllers/processing_controller.dart';
import '../../../split_config/domain/models/clip_plan.dart';
import '../../../split_config/domain/models/plan_validator.dart';
import '../../../split_config/presentation/controllers/split_config_controller.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';
import '../../domain/models/clip_processing_state.dart';
import '../controllers/part_items_controller.dart';
import '../controllers/plan_controller.dart';
import '../widgets/edit_boundary_dialog.dart';
import '../widgets/overlay_live_preview.dart';
import '../widgets/part_message_dialog.dart';
import '../widgets/plan_header_card.dart';
import '../widgets/plan_part_tile.dart';
import '../widgets/split_part_dialog.dart';

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
    final outputDir = await ref.read(outputDirectoryProvider.future);
    final processingProgress = ref.read(processingControllerProvider);
    final partItems = ref.read(partItemsControllerProvider);

    if (!mounted) return;

    // 1. Validate Video
    final videoResult = _videoValidator.validate(video);
    if (!videoResult.isValid) {
      final issue = videoResult.firstError!;
      AppMessenger.showIssue(
        context,
        issue,
        onAction: () => context.go(AppRoutes.home),
      );
      setState(() => _inlineError = issue.message);
      _scrollToError();
      return;
    }

    // 2. Validate Plan
    final planResult = _planValidator.validate(plan);
    if (!planResult.isValid) {
      final issue = planResult.firstError!;
      AppMessenger.showIssue(context, issue);
      setState(() => _inlineError = issue.message);
      _scrollToError();
      return;
    }

    // 3. Validate Output Location & SAF
    final isSafValid = outputDir.startsWith('content://')
        ? await StorageBridge.isPersistedUriValid(outputDir)
        : true;
    if (!mounted) return;

    final outputResult = _outputValidator.validate(
      outputDirectoryPath: outputDir,
      isSafPermissionValid: isSafValid,
    );
    if (!outputResult.isValid) {
      final issue = outputResult.firstError!;
      AppMessenger.showIssue(
        context,
        issue,
        onAction: () async {
          await ref
              .read(outputDirectoryProvider.notifier)
              .pickAndSetDirectory();
        },
      );
      setState(() => _inlineError = issue.message);
      _scrollToError();
      return;
    }

    // 4. Validate Parts Selection & Storage for selected parts
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
      if (mounted) {
        AppMessenger.showIssue(context, issue);
        setState(() => _inlineError = issue.message);
        _scrollToError();
      }
      return;
    }

    final selectedItems = effectiveItems.where((i) => i.isSelected).toList();
    final selectedPartIndices = selectedItems.map((i) => i.index).toSet();

    // 5. Preflight check
    final totalSelectedDuration = selectedItems.fold<double>(
      0.0,
      (acc, item) => acc + item.durationSeconds,
    );
    final estimatedSize = (totalSelectedDuration * 2.5 * 1024 * 1024).toInt();
    const minSafetyBytes = 150 * 1024 * 1024;
    final requiredBytes = estimatedSize + minSafetyBytes;

    final preflightResult = _preflightValidator.validate(
      isJobAlreadyRunning: processingProgress.isProcessing,
      freeDiskBytes: freeBytes,
      requiredDiskBytes: requiredBytes,
      hasNotificationPermission: true,
    );
    if (!preflightResult.isValid) {
      final issue = preflightResult.firstError!;
      if (mounted) {
        AppMessenger.showIssue(context, issue);
        setState(() => _inlineError = issue.message);
        _scrollToError();
      }
      return;
    }

    // Acquire idempotency lock
    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });

    try {
      if (!mounted) return;
      // Check notification permission (warning only)
      final hasNotificationPerm =
          await PermissionUtils.requestNotificationPermissionIfNeeded(context);
      if (!hasNotificationPerm && mounted) {
        AppMessenger.showWarning(
          context,
          'Notification permission disabled. Progress will not appear in status bar.',
        );
      }

      if (!mounted) return;

      // Navigate to processing screen immediately
      unawaited(context.push(AppRoutes.processing));

      // Launch export job for selected parts
      final success = await ref
          .read(processingControllerProvider.notifier)
          .startSplit(
            video: video!,
            config: config,
            outputDirectoryPath: outputDir,
            plan: plan,
            selectedPartIndices: selectedPartIndices,
          );

      if (!success && mounted) {
        AppMessenger.showError(
          context,
          'Failed to start export: An export is already running or invalid.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
    final plan = ref.watch(planReviewControllerProvider);
    final planNotifier = ref.read(planReviewControllerProvider.notifier);
    final partItems = ref.watch(partItemsControllerProvider);
    final partNotifier = ref.read(partItemsControllerProvider.notifier);

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
    final firstPartMessage = plan.items.isNotEmpty
        ? (plan.items.first.resolvedMessage ?? 'Part 1/${plan.totalParts}')
        : null;

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
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: PrimaryButton(
            icon: Icons.movie_creation_outlined,
            isLoading: _isSubmitting,
            label: _isSubmitting ? 'Starting Export...' : buttonLabel,
            onPressed: _isSubmitting ? null : () => _startCreatingShorts(plan),
          ),
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
        onSave: (customText) =>
            notifier.updatePartMessage(item.index - 1, customText),
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
}
