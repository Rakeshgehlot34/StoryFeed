import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../output/domain/safe_clip_replacer.dart';
import '../../../split_config/domain/models/clip_plan.dart';
import '../../../split_config/domain/models/split_config.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../domain/export_job_controller.dart';
import '../../domain/models/processing_progress.dart';

export '../../domain/export_job_controller.dart' show videoProcessorProvider;

final processingControllerProvider =
    NotifierProvider<ProcessingController, ProcessingProgress>(
  ProcessingController.new,
);

/// Presentation-layer adapter observing the domain-layer ExportJobController.
/// Disposing this provider NEVER cancels or stops active background processing jobs.
class ProcessingController extends Notifier<ProcessingProgress> {
  @override
  ProcessingProgress build() {
    final jobState = ref.watch(exportJobControllerProvider);
    return jobState.progress;
  }

  Future<bool> startSplit({
    required PickedVideo video,
    required SplitConfig config,
    required String outputDirectoryPath,
    ClipPlan? plan,
    Set<int>? selectedPartIndices,
  }) async {
    final jobNotifier = ref.read(exportJobControllerProvider.notifier);
    return jobNotifier.startNewJob(
      video: video,
      config: config,
      outputDirectoryPath: outputDirectoryPath,
      plan: plan,
      selectedPartIndices: selectedPartIndices,
    );
  }

  /// Converts a targeted selection of raw split parts to 9:16 Shorts format (Stage 2 conversion).
  Future<bool> startStage2Conversion({
    required String projectId,
    required List<int> selectedPartIndices,
    required SplitConfig config,
    ReplaceStrategy replaceStrategy = ReplaceStrategy.replace,
    ClipPlan? plan,
  }) async {
    final jobNotifier = ref.read(exportJobControllerProvider.notifier);
    return jobNotifier.startStage2Conversion(
      projectId: projectId,
      selectedPartIndices: selectedPartIndices,
      config: config,
      replaceStrategy: replaceStrategy,
      plan: plan,
    );
  }

  Future<void> cancel() async {
    final jobNotifier = ref.read(exportJobControllerProvider.notifier);
    await jobNotifier.cancelActiveJob();
  }
}
