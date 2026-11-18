import 'dart:io';

import 'package:flutter/services.dart';

import '../logger/app_logger.dart';

typedef ForegroundCancelCallback = void Function();

/// Manages native Android Foreground Service notifications during export.
class ForegroundServiceManager {
  static const MethodChannel _channel = MethodChannel(
    'com.shortssplitter.shorts_splitter/foreground_service',
  );

  static ForegroundCancelCallback? _onCancelCallback;
  static bool _isInitialized = false;

  /// Initializes the callback handler for notification action button taps.
  static void initialize({ForegroundCancelCallback? onCancel}) {
    _onCancelCallback = onCancel;
    if (_isInitialized) return;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationCancelAction') {
        AppLogger.info('User tapped Cancel on foreground notification');
        _onCancelCallback?.call();
      }
    });
    _isInitialized = true;
  }

  /// Sets or updates the active cancel callback.
  static void setCancelCallback(ForegroundCancelCallback? onCancel) {
    _onCancelCallback = onCancel;
  }

  /// Starts or updates the foreground service notification.
  static Future<bool> startOrUpdate({
    required String title,
    required String message,
    required int progress,
  }) async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('startOrUpdateService', {
        'title': title,
        'message': message,
        'progress': progress,
      });
      return res ?? false;
    } catch (e) {
      AppLogger.warning('Failed to update foreground service: $e');
      return false;
    }
  }

  /// Stops the foreground service and dismisses the notification.
  static Future<bool> stop() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('stopService');
      return res ?? false;
    } catch (e) {
      AppLogger.warning('Failed to stop foreground service: $e');
      return false;
    }
  }

  /// Shows a completed export notification that navigates to the Results screen.
  static Future<bool> showCompleted({
    required String title,
    required String message,
  }) async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>(
        'showCompletedNotification',
        {'title': title, 'message': message},
      );
      return res ?? false;
    } catch (e) {
      AppLogger.warning('Failed to show completed notification: $e');
      return false;
    }
  }
}
