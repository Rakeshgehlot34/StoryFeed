import 'dart:io';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/storage_bridge.dart';
import '../domain/clip_writer.dart';
import 'writers/app_specific_clip_writer.dart';
import 'writers/direct_public_clip_writer.dart';
import 'writers/media_store_clip_writer.dart';
import 'writers/saf_clip_writer.dart';

/// Runtime factory that chooses the active ClipWriter strategy according to Android SDK version
/// and user configuration.
class ClipWriterFactory {
  /// Resolves the optimal ClipWriter based on Android API level and storage availability:
  /// 1. PRIMARY (API 28+): SAF if a valid user-selected tree URI exists.
  /// 2. FALLBACK on API 28: Direct public storage (Movies/ShortsSplitter).
  /// 3. FALLBACK on API 29+: MediaStore Video collection (RELATIVE_PATH + IS_PENDING).
  /// 4. FINAL FALLBACK: App-specific external files directory.
  static Future<ClipWriter> resolveWriter({
    String? preferredSafUri,
    int? overrideSdkInt,
    bool? isAndroid,
  }) async {
    final sdkInt = overrideSdkInt ?? await StorageBridge.getSdkInt();
    final android = isAndroid ?? (overrideSdkInt != null || Platform.isAndroid);

    // 1. Try Primary: SAF (API 28+)
    if (preferredSafUri != null && preferredSafUri.isNotEmpty) {
      final safWriter = SafClipWriter(treeUri: preferredSafUri);
      if (await safWriter.isAvailable()) {
        AppLogger.info('Resolved Storage Strategy: SAF (${safWriter.treeUri})');
        return safWriter;
      }
      AppLogger.warning(
        'Persisted SAF URI is invalid or revoked. Falling back...',
      );
    }

    // Non-Android platforms (iOS, desktop) fallback directly to app-specific storage
    if (!android) {
      return AppSpecificClipWriter();
    }

    // 2. Fallback on Android 9 (API 28 only)
    if (sdkInt == 28) {
      final directWriter = DirectPublicClipWriter();
      if (await directWriter.isAvailable()) {
        AppLogger.info('Resolved Storage Strategy: Direct Public (API 28)');
        return directWriter;
      }
      AppLogger.warning(
        'Direct public storage permission denied on API 28. Falling back...',
      );
    }

    // 3. Fallback on Android 10+ (API 29+)
    if (sdkInt >= 29) {
      final mediaStoreWriter = MediaStoreClipWriter();
      if (await mediaStoreWriter.isAvailable()) {
        AppLogger.info('Resolved Storage Strategy: MediaStore (API $sdkInt)');
        return mediaStoreWriter;
      }
      AppLogger.warning(
        'MediaStore unavailable. Falling back to app-specific...',
      );
    }

    // 4. Final Fallback: App-Specific Storage
    AppLogger.info('Resolved Storage Strategy: AppSpecific (Final Fallback)');
    return AppSpecificClipWriter();
  }
}
