import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../processing/presentation/controllers/processing_controller.dart';
import '../../data/video_picker_repository.dart';
import '../../domain/models/picked_video.dart';

final videoPickerRepositoryProvider = Provider<VideoPickerRepository>((ref) {
  final processor = ref.read(videoProcessorProvider);
  return VideoPickerRepository(videoProcessor: processor);
});

final videoPickerControllerProvider =
    AsyncNotifierProvider<VideoPickerController, PickedVideo?>(
      VideoPickerController.new,
    );

class VideoPickerController extends AsyncNotifier<PickedVideo?> {
  @override
  Future<PickedVideo?> build() async {
    return null;
  }

  Future<void> pickFromGallery() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(videoPickerRepositoryProvider);
      final video = await repo.pickVideoFromGallery();
      state = AsyncData(video);
    } catch (e, st) {
      AppLogger.error('Error in pickFromGallery', error: e, stackTrace: st);
      state = AsyncError(e, st);
    }
  }

  Future<void> pickFromFile() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(videoPickerRepositoryProvider);
      final video = await repo.pickVideoFromFileSystem();
      state = AsyncData(video);
    } catch (e, st) {
      AppLogger.error('Error in pickFromFile', error: e, stackTrace: st);
      state = AsyncError(e, st);
    }
  }

  void clear() {
    state = const AsyncData(null);
  }
}
