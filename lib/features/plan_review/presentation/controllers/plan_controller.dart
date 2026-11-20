import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../split_config/domain/models/background_spec.dart';
import '../../../split_config/domain/models/canvas_spec.dart';
import '../../../split_config/domain/models/clip_plan.dart';
import '../../../split_config/domain/models/overlay_spec.dart';
import '../../../split_config/domain/models/plan_calculator.dart';
import '../../../split_config/domain/models/trim_range.dart';
import '../../../split_config/presentation/controllers/split_config_controller.dart';
import '../../../video_picker/presentation/controllers/video_picker_controller.dart';

final planReviewControllerProvider =
    NotifierProvider<PlanReviewController, ClipPlan?>(PlanReviewController.new);

/// Compatibility alias
final clipPlanProvider = planReviewControllerProvider;

class PlanReviewController extends Notifier<ClipPlan?> {
  @override
  ClipPlan? build() {
    final video = ref.watch(videoPickerControllerProvider).valueOrNull;
    final config = ref.watch(splitConfigControllerProvider);

    if (video == null) return null;

    final totalSec = video.duration.inMilliseconds / 1000.0;
    final trim =
        config.trimRange ?? TrimRange(startSeconds: 0.0, endSeconds: totalSec);
    final baseName = config.customBaseName?.isNotEmpty == true
        ? config.customBaseName!
        : video.baseName;

    return PlanCalculator.generateAutoPlan(
      trimRange: trim,
      targetClipDurationSeconds: config.targetDurationSeconds,
      mergeShortTrailingClip: config.mergeShortTrailingClip,
      baseName: baseName,
      canvasSpec: config.canvasSpec,
      backgroundSpec: config.backgroundSpec,
      overlaySpec: config.overlaySpec,
      cropToFill: config.cropToFill,
      sourceDurationSeconds: totalSec,
      verticalPosition: config.verticalPosition,
      verticalOffsetFraction: config.verticalOffsetFraction,
      singlePartFileNameMode: config.singlePartFileNameMode,
    );
  }

  void adjustBoundary(int boundaryIndex, double newTime) {
    final current = state;
    if (current == null) return;

    final updatedItems = PlanCalculator.adjustBoundary(
      items: current.items,
      boundaryIndex: boundaryIndex,
      newBoundaryTime: newTime,
      baseName: current.baseName,
      overlaySpec: current.overlaySpec,
      singlePartFileNameMode: current.singlePartFileNameMode,
    );

    state = current.copyWith(items: updatedItems);
  }

  void mergeWithNext(int partIndex) {
    final current = state;
    if (current == null) return;

    final updatedItems = PlanCalculator.mergeWithNext(
      items: current.items,
      index: partIndex,
      baseName: current.baseName,
      overlaySpec: current.overlaySpec,
      singlePartFileNameMode: current.singlePartFileNameMode,
    );

    state = current.copyWith(items: updatedItems);
  }

  void splitPart(int partIndex, double splitTime) {
    final current = state;
    if (current == null) return;

    final updatedItems = PlanCalculator.splitPart(
      items: current.items,
      index: partIndex,
      splitTime: splitTime,
      baseName: current.baseName,
      overlaySpec: current.overlaySpec,
      singlePartFileNameMode: current.singlePartFileNameMode,
    );

    state = current.copyWith(items: updatedItems);
  }

  void updatePartMessage(int partIndex, String? message) {
    final current = state;
    if (current == null) return;

    final updatedItems = PlanCalculator.updatePartMessage(
      items: current.items,
      index: partIndex,
      customMessage: message,
      baseName: current.baseName,
      overlaySpec: current.overlaySpec,
    );

    state = current.copyWith(items: updatedItems);
  }

  void updatePartDetails(
    int indexZeroBased, {
    String? customMessage,
    PartLabelOverride? override,
  }) {
    final current = state;
    if (current == null ||
        indexZeroBased < 0 ||
        indexZeroBased >= current.items.length) {
      return;
    }

    var items = current.items;
    if (override != null) {
      items = PlanCalculator.updatePartLabelOverride(
        items: items,
        index: indexZeroBased,
        override: override,
        baseName: current.baseName,
        overlaySpec: current.overlaySpec,
      );
    }
    items = PlanCalculator.updatePartMessage(
      items: items,
      index: indexZeroBased,
      customMessage: customMessage,
      baseName: current.baseName,
      overlaySpec: current.overlaySpec,
    );

    state = current.copyWith(items: items);
  }

  void setPartLabelOverride(int partIndex, PartLabelOverride override) {
    final current = state;
    if (current == null) return;

    final targetIdx = current.items.indexWhere(
      (it) => it.index == partIndex || it.index == partIndex + 1,
    );
    final idx = (targetIdx != -1)
        ? targetIdx
        : (partIndex >= 0 && partIndex < current.items.length ? partIndex : -1);
    if (idx == -1) return;

    final updatedItems = PlanCalculator.updatePartLabelOverride(
      items: current.items,
      index: idx,
      override: override,
      baseName: current.baseName,
      overlaySpec: current.overlaySpec,
    );

    state = current.copyWith(items: updatedItems);
  }

  void updateBaseName(String newBaseName) {
    final current = state;
    if (current == null) return;
    final sanitized = Formatters.sanitizeFileName(newBaseName.trim());
    if (sanitized.isEmpty) return;

    ref
        .read(splitConfigControllerProvider.notifier)
        .setCustomBaseName(sanitized);

    final updatedItems = PlanCalculator.updateBaseName(
      items: current.items,
      newBaseName: sanitized,
      overlaySpec: current.overlaySpec,
      singlePartFileNameMode: current.singlePartFileNameMode,
    );

    state = current.copyWith(baseName: sanitized, items: updatedItems);
  }

  void resetToAuto() {
    final video = ref.read(videoPickerControllerProvider).valueOrNull;
    final config = ref.read(splitConfigControllerProvider);
    if (video == null) return;

    final totalSec = video.duration.inMilliseconds / 1000.0;
    final trim =
        config.trimRange ?? TrimRange(startSeconds: 0.0, endSeconds: totalSec);

    state = PlanCalculator.generateAutoPlan(
      trimRange: trim,
      targetClipDurationSeconds: config.targetDurationSeconds,
      mergeShortTrailingClip: config.mergeShortTrailingClip,
      baseName: video.baseName,
      canvasSpec: config.canvasSpec,
      backgroundSpec: config.backgroundSpec,
      overlaySpec: config.overlaySpec,
      cropToFill: config.cropToFill,
      sourceDurationSeconds: totalSec,
      verticalPosition: config.verticalPosition,
      verticalOffsetFraction: config.verticalOffsetFraction,
      singlePartFileNameMode: config.singlePartFileNameMode,
    );
  }

  Future<void> setCanvasSpec(CanvasSpec spec) async {
    final current = state;
    if (current == null) return;
    state = current.copyWith(canvasSpec: spec);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyCanvasFormat, spec.format.name);
  }

  Future<void> setBackgroundSpec(BackgroundSpec spec) async {
    final current = state;
    if (current == null) return;
    state = current.copyWith(backgroundSpec: spec);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyBackgroundType, spec.type.name);
    if (spec is SolidColorBackgroundSpec) {
      await prefs.setInt(
        AppConstants.prefKeyBackgroundColorHex,
        spec.colorValue,
      );
    }
  }

  Future<void> setOverlaySpec(OverlaySpec spec) async {
    final current = state;
    if (current == null) return;

    final updatedItems = <ClipPlanItem>[];
    for (int i = 0; i < current.items.length; i++) {
      final item = current.items[i];
      final text = spec.resolveText(
        partIndex: item.index,
        totalParts: current.items.length,
        baseName: current.baseName,
        specificPartOverride: item.customMessage,
        perPartOverride: item.partLabelOverride,
      );
      updatedItems.add(item.copyWith(resolvedMessage: text));
    }

    state = current.copyWith(overlaySpec: spec, items: updatedItems);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.prefKeyOverlayPartLabelMode,
      spec.partLabelMode.name,
    );
    await prefs.setBool(AppConstants.prefKeyOverlayAutoLabel, spec.autoLabel);
    await prefs.setString(AppConstants.prefKeyOverlayTemplate, spec.template);
    await prefs.setString(
      AppConstants.prefKeyOverlayPosition,
      spec.position.name,
    );
  }
}
