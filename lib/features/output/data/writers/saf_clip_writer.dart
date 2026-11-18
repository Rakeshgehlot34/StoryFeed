import 'dart:io';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/storage_bridge.dart';
import '../../domain/clip_writer.dart';
import '../../domain/models/storage_strategy.dart';

/// Strategy 1 (PRIMARY for API 28+): Storage Access Framework (SAF).
/// Writes clips into a user-selected folder tree URI with persistable read/write grants.
/// Validates active folder permissions on every launch and avoids Scoped Storage restrictions.
class SafClipWriter implements ClipWriter {
  final String treeUri;

  const SafClipWriter({required this.treeUri});

  @override
  StorageStrategyType get strategyType => StorageStrategyType.saf;

  @override
  Future<bool> isAvailable() async {
    if (treeUri.isEmpty) return false;
    if (!Platform.isAndroid) return true;
    return StorageBridge.isPersistedUriValid(treeUri);
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

    try {
      final targetFileName = fileName;
      final uriString = await StorageBridge.writeClipToSaf(
        tempFilePath: sourceTempFile.path,
        treeUri: treeUri,
        fileName: targetFileName,
        mimeType: 'video/mp4',
      );

      AppLogger.info(
        'SAF clip successfully written: $targetFileName -> $uriString',
      );
      return uriString;
    } catch (e, st) {
      AppLogger.error('SafClipWriter failed', error: e, stackTrace: st);
      throw StorageAccessException(
        'Failed to save clip to user-selected SAF folder: $e',
        path: treeUri,
        cause: e,
        stackTrace: st,
      );
    }
  }
}
