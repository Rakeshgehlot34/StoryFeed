import 'dart:io';

import 'package:flutter/services.dart';

import '../logger/app_logger.dart';

/// Platform bridge communicating with native Android StorageBridge (API 28-35+).
class StorageBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.shortssplitter.shorts_splitter/storage',
  );

  /// Returns Android Build.VERSION.SDK_INT, or 0 if not running on Android.
  static Future<int> getSdkInt() async {
    if (!Platform.isAndroid) return 0;
    try {
      final sdkInt = await _channel.invokeMethod<int>('getSdkInt');
      return sdkInt ?? 0;
    } catch (e) {
      AppLogger.warning('Failed to get SDK int from native: $e');
      return 0;
    }
  }

  /// Takes persistent read and write permissions on a user-picked SAF tree URI.
  static Future<bool> takePersistableUriPermission(String uri) async {
    if (!Platform.isAndroid) return true;
    try {
      final success = await _channel.invokeMethod<bool>(
        'takePersistableUriPermission',
        {'uri': uri},
      );
      return success ?? false;
    } catch (e) {
      AppLogger.error('takePersistableUriPermission failed: $e');
      return false;
    }
  }

  /// Verifies whether a persisted SAF tree URI still has active write permissions.
  static Future<bool> isPersistedUriValid(String uri) async {
    if (!Platform.isAndroid) return true;
    try {
      final valid = await _channel.invokeMethod<bool>('isPersistedUriValid', {
        'uri': uri,
      });
      return valid ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Copies a local temp MP4 clip to the destination SAF tree directory via DocumentFile.
  static Future<String> writeClipToSaf({
    required String tempFilePath,
    required String treeUri,
    required String fileName,
    String mimeType = 'video/mp4',
  }) async {
    final result = await _channel.invokeMethod<String>('writeClipToSaf', {
      'tempFilePath': tempFilePath,
      'treeUri': treeUri,
      'fileName': fileName,
      'mimeType': mimeType,
    });
    if (result == null || result.isEmpty) {
      throw Exception('Native SAF write returned empty URI');
    }
    return result;
  }

  /// Writes an MP4 clip to the MediaStore video collection (API 29+ only) with IS_PENDING.
  static Future<String> writeClipToMediaStore({
    required String tempFilePath,
    String relativePath = 'Movies/ShortsSplitter',
    required String fileName,
    String mimeType = 'video/mp4',
  }) async {
    final result = await _channel.invokeMethod<String>(
      'writeClipToMediaStore',
      {
        'tempFilePath': tempFilePath,
        'relativePath': relativePath,
        'fileName': fileName,
        'mimeType': mimeType,
      },
    );
    if (result == null || result.isEmpty) {
      throw Exception('Native MediaStore write returned empty URI');
    }
    return result;
  }

  /// Returns available disk space in bytes for the given path.
  static Future<int> getFreeDiskSpace([String? path]) async {
    if (!Platform.isAndroid) return 10 * 1024 * 1024 * 1024; // 10 GB default
    try {
      final bytes = await _channel.invokeMethod<int>('getFreeDiskSpace', {
        'path': path,
      });
      return bytes ?? 1024 * 1024 * 1024;
    } catch (_) {
      return 1024 * 1024 * 1024;
    }
  }

  /// Streams a content:// URI to a local private temp file using 64KB chunks (safe for 1GB+ files).
  static Future<String> copyContentUriToTempFile({
    required String contentUri,
    required String tempDestPath,
  }) async {
    final result = await _channel.invokeMethod<String>(
      'copyContentUriToTempFile',
      {'contentUri': contentUri, 'tempDestPath': tempDestPath},
    );
    if (result == null || result.isEmpty) {
      throw Exception('Failed to stream content URI to temp file');
    }
    return result;
  }

  /// Triggers MediaScannerConnection to index a newly exported MP4 into the gallery.
  static Future<bool> scanMediaFile(String filePath) async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('scanMediaFile', {
        'filePath': filePath,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
