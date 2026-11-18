import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logger/app_logger.dart';
import '../../data/output_repository.dart';
import '../../domain/models/exported_clip.dart';
import '../../domain/models/storage_strategy.dart';

final outputRepositoryProvider = Provider<OutputRepository>((ref) {
  return OutputRepository();
});

final duplicateHandlingProvider =
    AsyncNotifierProvider<DuplicateHandlingNotifier, DuplicateHandling>(
      DuplicateHandlingNotifier.new,
    );

class DuplicateHandlingNotifier extends AsyncNotifier<DuplicateHandling> {
  @override
  Future<DuplicateHandling> build() async {
    final repo = ref.read(outputRepositoryProvider);
    return repo.getDuplicateHandling();
  }

  Future<void> setMode(DuplicateHandling mode) async {
    state = AsyncData(mode);
    final repo = ref.read(outputRepositoryProvider);
    await repo.setDuplicateHandling(mode);
  }
}

final outputDirectoryProvider =
    AsyncNotifierProvider<OutputDirectoryNotifier, String>(
      OutputDirectoryNotifier.new,
    );

class OutputDirectoryNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final repo = ref.read(outputRepositoryProvider);
    return repo.getSavedOutputDirectoryPath();
  }

  Future<bool> pickAndSetDirectory() async {
    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to save YouTube Shorts clips',
      );

      if (selectedPath == null || selectedPath.isEmpty) {
        return false;
      }

      state = const AsyncLoading();
      final repo = ref.read(outputRepositoryProvider);
      await repo.saveOutputDirectoryPath(selectedPath);
      state = AsyncData(selectedPath);
      ref.invalidate(exportedClipsProvider);
      return true;
    } catch (e, st) {
      AppLogger.error(
        'Failed to set output directory',
        error: e,
        stackTrace: st,
      );
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> resetToDefault() async {
    state = const AsyncLoading();
    final repo = ref.read(outputRepositoryProvider);
    await repo.resetToDefaultDirectory();
    final defaultPath = await repo.getSavedOutputDirectoryPath();
    state = AsyncData(defaultPath);
    ref.invalidate(exportedClipsProvider);
  }
}

final exportedClipsProvider =
    AsyncNotifierProvider<ExportedClipsNotifier, List<ExportedClip>>(
      ExportedClipsNotifier.new,
    );

class ExportedClipsNotifier extends AsyncNotifier<List<ExportedClip>> {
  @override
  Future<List<ExportedClip>> build() async {
    final dirPath = await ref.watch(outputDirectoryProvider.future);
    final repo = ref.read(outputRepositoryProvider);
    return repo.listClipsInDirectory(dirPath);
  }

  void setClips(List<ExportedClip> clips) {
    state = AsyncData(clips);
  }

  Future<void> deleteClip(ExportedClip clip) async {
    final repo = ref.read(outputRepositoryProvider);
    await repo.deleteClip(clip.path);
    final currentList = state.valueOrNull ?? [];
    state = AsyncData(currentList.where((c) => c.path != clip.path).toList());
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
