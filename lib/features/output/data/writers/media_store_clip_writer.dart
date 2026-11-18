import 'dart:io';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/storage_bridge.dart';
import '../../domain/clip_writer.dart';
import '../../domain/models/storage_strategy.dart';

/// Strategy 3 (FALLBACK for Android 10+ / API 29+): MediaStore Video Collection.
/// Inserts clips into MediaStore with RELATIVE_PATH = "Movies/ShortsSplitter" and IS_PENDING.
/// Automatically indexes clips in Google Photos/Gallery without broad permissions. Never used on API 28.
class MediaStoreClipWriter implements ClipWriter {
  static const String defaultRelativePath = 'Movies/ShortsSplitter';

  @override
  StorageStrategyType get strategyType => StorageStrategyType.mediaStore;

  @override
  Future<bool> isAvailable() async {
    final sdkInt = await StorageBridge.getSdkInt();
    // MediaStore RELATIVE_PATH requires API 29+
    if (Platform.isAndroid && sdkInt < 29) return false;
    return true;
  }

  @override
  Future<String> writeClip({
    required File sourceTempFile,
    required String fileName,
    required DuplicateHandling duplicateHandling,
  }) async {
    final sdkInt = await StorageBridge.getSdkInt();
    if (sdkInt < 29 && Platform.isAndroid) {
      throw const StorageAccessException(
        'MediaStore RELATIVE_PATH strategy cannot be used on API 28.',
        path: defaultRelativePath,
      );
    }

    if (!await sourceTempFile.exists() || await sourceTempFile.length() == 0) {
      throw StorageAccessException(
        'Source temp clip is missing or empty.',
        path: sourceTempFile.path,
      );
    }

    try {
      final mediaUri = await StorageBridge.writeClipToMediaStore(
        tempFilePath: sourceTempFile.path,
        relativePath: defaultRelativePath,
        fileName: fileName,
        mimeType: 'video/mp4',
      );

      AppLogger.info('MediaStore clip written: $fileName -> $mediaUri');
      return mediaUri;
    } catch (e, st) {
      AppLogger.error('MediaStoreClipWriter failed', error: e, stackTrace: st);
      throw StorageAccessException(
        'Failed to save clip to MediaStore: $e',
        path: defaultRelativePath,
        cause: e,
        stackTrace: st,
      );
    }
  }
}
