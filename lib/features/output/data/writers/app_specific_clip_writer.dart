import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/storage_bridge.dart';
import '../../../../core/utils/storage_utils.dart';
import '../../domain/clip_writer.dart';
import '../../domain/models/storage_strategy.dart';

/// Strategy 4 (FINAL FALLBACK across all API levels): App-Specific Storage.
/// Writes to `/Android/data/com.shortssplitter.shorts_splitter/files/ShortsSplitter/`.
/// Fully compliant with Android Scoped Storage and requires zero manifest or runtime permissions.
class AppSpecificClipWriter implements ClipWriter {
  @override
  StorageStrategyType get strategyType => StorageStrategyType.appSpecific;

  @override
  Future<bool> isAvailable() async {
    // App-specific external storage is always available and writable
    return true;
  }

  @override
  Future<String> writeClip({
    required File sourceTempFile,
    required String fileName,
    required DuplicateHandling duplicateHandling,
  }) async {
    if (!await sourceTempFile.exists() || await sourceTempFile.length() == 0) {
      throw StorageAccessException(
        'Source temp clip is missing or empty.',
        path: sourceTempFile.path,
      );
    }

    final targetDir = await StorageUtils.getAppDefaultOutputDirectory();
    var destPath = p.join(targetDir.path, fileName);
    var destFile = File(destPath);

    if (await destFile.exists() &&
        duplicateHandling == DuplicateHandling.autoSuffix) {
      destPath = _resolveSuffixPath(targetDir.path, fileName);
      destFile = File(destPath);
    }

    await sourceTempFile.copy(destPath);

    if (!await destFile.exists() || await destFile.length() == 0) {
      throw StorageAccessException(
        'Copy to app-specific directory failed',
        path: destPath,
      );
    }

    await StorageBridge.scanMediaFile(destPath);
    AppLogger.info('App-specific clip written: $destPath');
    return destPath;
  }

  String _resolveSuffixPath(String dir, String originalName) {
    final base = p.basenameWithoutExtension(originalName);
    final ext = p.extension(originalName);
    var index = 1;
    while (File(p.join(dir, '${base}_$index$ext')).existsSync()) {
      index++;
    }
    return p.join(dir, '${base}_$index$ext');
  }
}
