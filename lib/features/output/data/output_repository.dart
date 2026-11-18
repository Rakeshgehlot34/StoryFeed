import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/storage_bridge.dart';
import '../../../../core/utils/storage_utils.dart';
import '../domain/clip_writer.dart';
import '../domain/models/exported_clip.dart';
import '../domain/models/storage_strategy.dart';
import 'clip_writer_factory.dart';

class OutputRepository {
  /// Validates and returns the active output directory path or SAF URI.
  /// On every launch:
  /// - If user picked an SAF tree URI, validates that permissions are still granted and folder exists.
  /// - If permission was revoked, prompts user / returns empty to trigger re-picking.
  /// - If none chosen or invalid, resolves to app default external folder.
  Future<String> getSavedOutputDirectoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(AppConstants.prefKeyOutputDirectory);

    if (savedPath != null && savedPath.isNotEmpty) {
      if (savedPath.startsWith('content://')) {
        // Validate SAF persistable permission
        final isValid = await StorageBridge.isPersistedUriValid(savedPath);
        if (isValid) {
          return savedPath;
        }
        AppLogger.warning(
          'Persisted SAF URI $savedPath is invalid or revoked.',
        );
      } else {
        final isWritable = await StorageUtils.testDirectoryWritable(savedPath);
        if (isWritable) {
          return savedPath;
        }
        AppLogger.warning(
          'Saved path $savedPath is no longer directly writable.',
        );
      }
    }

    final defaultDir = await StorageUtils.getAppDefaultOutputDirectory();
    return defaultDir.path;
  }

  /// Saves user selected folder and takes persistable URI permission if it is an SAF tree URI.
  Future<void> saveOutputDirectoryPath(String path) async {
    if (path.startsWith('content://')) {
      final success = await StorageBridge.takePersistableUriPermission(path);
      if (!success) {
        throw StorageAccessException(
          'Failed to take persistable URI permission for SAF folder.',
          path: path,
        );
      }
    } else {
      final isWritable = await StorageUtils.testDirectoryWritable(path);
      if (!isWritable) {
        throw StorageAccessException(
          'Selected folder is not directly writable due to storage permissions or scoped storage restrictions.',
          path: path,
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyOutputDirectory, path);
    AppLogger.info('Saved custom output directory: $path');
  }

  /// Returns duplicate handling preference (overwrite vs auto-suffix).
  Future<DuplicateHandling> getDuplicateHandling() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(AppConstants.prefKeyDuplicateHandling);
    if (value == DuplicateHandling.autoSuffix.name) {
      return DuplicateHandling.autoSuffix;
    }
    return DuplicateHandling.overwrite;
  }

  /// Sets duplicate handling preference.
  Future<void> setDuplicateHandling(DuplicateHandling mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyDuplicateHandling, mode.name);
  }

  /// Resolves the active ClipWriter strategy at runtime based on SDK level and chosen directory.
  Future<ClipWriter> resolveClipWriter() async {
    final path = await getSavedOutputDirectoryPath();
    final safUri = path.startsWith('content://') ? path : null;
    return ClipWriterFactory.resolveWriter(preferredSafUri: safUri);
  }

  Future<void> resetToDefaultDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefKeyOutputDirectory);
    AppLogger.info('Reset output directory to app default.');
  }

  Future<List<ExportedClip>> listClipsInDirectory(String dirPath) async {
    // If it's a content URI, standard directory listing is restricted. Fallback to app directory.
    var resolvedDir = dirPath;
    if (dirPath.startsWith('content://')) {
      final defaultDir = await StorageUtils.getAppDefaultOutputDirectory();
      resolvedDir = defaultDir.path;
    }

    final dir = Directory(resolvedDir);
    if (!await dir.exists()) return const [];

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.mp4'))
        .toList();

    final regex = RegExp(r'_part_(\d+)(?:_\d+)?\.mp4$', caseSensitive: false);
    final clips = <ExportedClip>[];

    for (final file in files) {
      final fileName = p.basename(file.path);
      final match = regex.firstMatch(fileName);
      final partIndex = match != null
          ? (int.tryParse(match.group(1)!) ?? 1)
          : 1;
      final stat = file.statSync();

      clips.add(
        ExportedClip(
          path: file.path,
          fileName: fileName,
          partIndex: partIndex,
          totalParts: 0,
          duration: Duration.zero,
          sizeInBytes: stat.size,
          createdAt: stat.modified,
        ),
      );
    }

    clips.sort((a, b) {
      final cmp = a.partIndex.compareTo(b.partIndex);
      if (cmp != 0) return cmp;
      return a.fileName.compareTo(b.fileName);
    });

    return clips;
  }

  Future<void> deleteClip(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      AppLogger.info('Deleted clip file: $filePath');
    }
  }
}
