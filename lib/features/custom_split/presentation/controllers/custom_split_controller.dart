import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../jobs/domain/job_queue_controller.dart';
import '../../../jobs/domain/models/job_record.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../domain/custom_split_calculator.dart';
import '../../domain/models/custom_clip_plan.dart';
import '../../domain/models/custom_split_config.dart';

class CustomSplitState {
  final PickedVideo? video;
  final CustomSplitConfig config;
  final CustomClipPlan? plan;
  final bool isCalculating;
  final String? errorMessage;

  const CustomSplitState({
    this.video,
    this.config = const CustomSplitConfig(),
    this.plan,
    this.isCalculating = false,
    this.errorMessage,
  });

  CustomSplitState copyWith({
    PickedVideo? video,
    bool clearVideo = false,
    CustomSplitConfig? config,
    CustomClipPlan? plan,
    bool clearPlan = false,
    bool? isCalculating,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CustomSplitState(
      video: clearVideo ? null : (video ?? this.video),
      config: config ?? this.config,
      plan: clearPlan ? null : (plan ?? this.plan),
      isCalculating: isCalculating ?? this.isCalculating,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final customSplitControllerProvider =
    NotifierProvider<CustomSplitController, CustomSplitState>(
  CustomSplitController.new,
);

class CustomSplitController extends Notifier<CustomSplitState> {
  @override
  CustomSplitState build() {
    return const CustomSplitState();
  }

  void setVideo(PickedVideo video) {
    final videoDuration = video.duration.inMilliseconds / 1000.0;
    final updatedConfig = state.config.copyWith(
      startSeconds: 0.0,
      endSeconds: videoDuration,
      customBaseName: video.baseName,
    );

    state = state.copyWith(
      video: video,
      config: updatedConfig,
      clearErrorMessage: true,
    );

    _recalculatePlan();
  }

  void setMode(CustomSplitMode mode) {
    // If switching to bySize, force precise method because bitrate estimate requires re-encoding
    final method = mode == CustomSplitMode.bySize
        ? SplitMethod.precise
        : state.config.method;
    state = state.copyWith(
      config: state.config.copyWith(mode: mode, method: method),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void setMethod(SplitMethod method) {
    state = state.copyWith(
      config: state.config.copyWith(method: method),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void setTargetDuration(double seconds) {
    state = state.copyWith(
      config: state.config.copyWith(targetDurationSeconds: seconds),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void setTargetPartCount(int count) {
    state = state.copyWith(
      config: state.config.copyWith(targetPartCount: count),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void addSplitPoint(double seconds) {
    final points = List<double>.from(state.config.customSplitPoints);
    if (!points.contains(seconds)) {
      points.add(seconds);
      points.sort();
      state = state.copyWith(
        config: state.config.copyWith(customSplitPoints: points),
        clearErrorMessage: true,
      );
      _recalculatePlan();
    }
  }

  void removeSplitPoint(double seconds) {
    final points = List<double>.from(state.config.customSplitPoints)
      ..remove(seconds);
    state = state.copyWith(
      config: state.config.copyWith(customSplitPoints: points),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void clearSplitPoints() {
    state = state.copyWith(
      config: state.config.copyWith(customSplitPoints: const []),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void setTargetSizeMb(double mb) {
    state = state.copyWith(
      config: state.config.copyWith(targetSizeMb: mb),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void setTrimRange(double start, double end) {
    state = state.copyWith(
      config: state.config.copyWith(startSeconds: start, endSeconds: end),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void setMergeShortTrailingClip(bool merge) {
    state = state.copyWith(
      config: state.config.copyWith(mergeShortTrailingClip: merge),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void setCustomBaseName(String name) {
    state = state.copyWith(
      config: state.config.copyWith(customBaseName: name),
      clearErrorMessage: true,
    );
    _recalculatePlan();
  }

  void adjustBoundary(int clipIndex, double newBoundary) {
    final currentPlan = state.plan;
    if (currentPlan == null) return;

    try {
      final updated = CustomSplitCalculator.adjustBoundary(
        currentPlan,
        clipIndex,
        newBoundary,
      );
      state = state.copyWith(plan: updated, clearErrorMessage: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void mergeWithNext(int clipIndex) {
    final currentPlan = state.plan;
    if (currentPlan == null) return;

    try {
      final updated = CustomSplitCalculator.mergeWithNext(
        currentPlan,
        clipIndex,
      );
      state = state.copyWith(plan: updated, clearErrorMessage: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void splitClip(int clipIndex, double splitPoint) {
    final currentPlan = state.plan;
    if (currentPlan == null) return;

    try {
      final updated = CustomSplitCalculator.splitClip(
        currentPlan,
        clipIndex,
        splitPoint,
      );
      state = state.copyWith(plan: updated, clearErrorMessage: true);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void updateClipCustomName(int clipIndex, String customName) {
    final currentPlan = state.plan;
    if (currentPlan == null ||
        clipIndex < 0 ||
        clipIndex >= currentPlan.items.length) {
      return;
    }

    final updatedItems = List<CustomClipItem>.from(currentPlan.items);
    updatedItems[clipIndex] = updatedItems[clipIndex].copyWith(
      customName: customName,
    );
    state = state.copyWith(
      plan: currentPlan.copyWith(items: updatedItems),
      clearErrorMessage: true,
    );
  }

  void _recalculatePlan() {
    final video = state.video;
    if (video == null) {
      state = state.copyWith(clearPlan: true);
      return;
    }

    state = state.copyWith(isCalculating: true);
    try {
      final videoDuration = video.duration.inMilliseconds / 1000.0;
      final calculatedBitrate = videoDuration > 0
          ? ((video.sizeInBytes * 8) ~/ videoDuration)
          : (5 * 1000 * 1000);

      final plan = CustomSplitCalculator.calculatePlan(
        originalVideoName: video.fileName,
        videoDurationSeconds: videoDuration,
        config: state.config,
        bitrateBps: calculatedBitrate,
      );
      state = state.copyWith(
        plan: plan,
        isCalculating: false,
        clearErrorMessage: true,
      );
    } catch (e) {
      AppLogger.warning('Custom split calculation failed: $e');
      state = state.copyWith(
        clearPlan: true,
        isCalculating: false,
        errorMessage: e is AppException ? e.message : e.toString(),
      );
    }
  }

  /// Enqueues the split plan as a background job in JobQueueController.
  Future<String> enqueueSplitJob() async {
    final video = state.video;
    final plan = state.plan;
    if (video == null || plan == null) {
      throw const VideoProcessingException(
        'Cannot enqueue split job without video and calculated plan.',
      );
    }

    final outputDir = await ref.read(outputDirectoryProvider.future);

    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
    final job = JobRecord(
      id: jobId,
      type: JobType.customSplit,
      title: 'Custom Split: ${plan.baseName} (${plan.totalParts} clips)',
      inputPath: video.path,
      outputDirectory: outputDir,
      totalParts: plan.totalParts,
      createdAt: DateTime.now(),
      payload: {
        'plan': plan.toJson(),
        'config': state.config.copyWith().toString(),
      },
    );

    await ref.read(jobQueueControllerProvider.notifier).enqueueJob(job);
    return jobId;
  }

  void reset() {
    state = const CustomSplitState();
  }
}
