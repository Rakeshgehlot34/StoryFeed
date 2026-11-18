import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/clip_processing_state.dart';
import 'plan_controller.dart';

final partItemsControllerProvider =
    NotifierProvider<PartItemsController, List<PartItem>>(
      PartItemsController.new,
    );

/// Riverpod controller managing the selection and processing state of each planned clip part.
class PartItemsController extends Notifier<List<PartItem>> {
  List<PartItem> _cachedItems = const [];

  @override
  List<PartItem> build() {
    final plan = ref.watch(planReviewControllerProvider);
    if (plan == null) {
      _cachedItems = const [];
      return const [];
    }

    if (_cachedItems.isEmpty) {
      final initial = plan.items.map((item) {
        return PartItem(
          segment: item.toClipSegment(),
          planItem: item,
          isSelected: true,
          status: ClipProcessingStatus.notProcessed,
        );
      }).toList();
      _cachedItems = initial;
      return initial;
    }

    // Synchronize while detecting stale or keeping previous selection/status
    final updated = PartSelectionHelpers.detectStale(
      previousItems: _cachedItems,
      newPlanItems: plan.items,
    );
    _cachedItems = updated;
    return updated;
  }

  void _update(List<PartItem> newItems) {
    _cachedItems = newItems;
    state = newItems;
  }

  void toggleSelect(int partIndex) {
    _update(PartSelectionHelpers.toggleSelection(state, partIndex));
  }

  void selectAll() {
    _update(PartSelectionHelpers.selectAll(state));
  }

  void selectNone() {
    _update(PartSelectionHelpers.selectNone(state));
  }

  void invertSelection() {
    _update(PartSelectionHelpers.invertSelection(state));
  }

  void selectRange(int startPartIndex, int endPartIndex) {
    _update(
      PartSelectionHelpers.selectRange(state, startPartIndex, endPartIndex),
    );
  }

  void updateStatus(
    int partIndex,
    ClipProcessingStatus newStatus, {
    String? outputPath,
    String? failureReason,
  }) {
    _update(
      PartSelectionHelpers.updateStatus(
        state,
        partIndex,
        newStatus,
        outputPath: outputPath,
        failureReason: failureReason,
      ),
    );
  }

  void markProcessing(int partIndex) {
    updateStatus(partIndex, ClipProcessingStatus.processing);
  }

  void markProcessed(int partIndex, String outputPath) {
    updateStatus(
      partIndex,
      ClipProcessingStatus.processed,
      outputPath: outputPath,
    );
  }

  void markFailed(int partIndex, String reason) {
    updateStatus(partIndex, ClipProcessingStatus.failed, failureReason: reason);
  }

  /// Verifies existence on disk for any items marked processed.
  Future<void> verifyDiskFiles() async {
    final verified = await PartSelectionHelpers.verifyDiskFiles(state);
    _update(verified);
  }

  /// Resets all items currently marked [ClipProcessingStatus.processing] back to
  /// [ClipProcessingStatus.notProcessed] (e.g. after cancellation).
  void resetProcessingToNotProcessed() {
    final updated = state.map((item) {
      if (item.status == ClipProcessingStatus.processing) {
        return item.copyWith(status: ClipProcessingStatus.notProcessed);
      }
      return item;
    }).toList();
    _update(updated);
  }
}
