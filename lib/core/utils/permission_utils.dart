import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'storage_bridge.dart';

/// Intelligent permission manager executing lazy, version-aware permission requests
/// matching Android 9 (API 28) through Android 15+ (API 35+).
class PermissionUtils {
  PermissionUtils._();

  /// Requests notification permission lazily before starting background export on Android 13+ (API 33+).
  static Future<bool> requestNotificationPermissionIfNeeded(
    BuildContext? context,
  ) async {
    if (!Platform.isAndroid) return true;

    final sdkInt = await StorageBridge.getSdkInt();
    if (sdkInt < 33) {
      return true; // Notification permission introduced in Android 13
    }

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    if (context != null && context.mounted) {
      final shouldProceed = await showRationaleDialog(
        context: context,
        title: 'Notification Permission',
        message:
            'ShortsSplitter needs notification access to display export progress '
            'and allow you to cancel long video splits when the app is in the background.',
      );
      if (!shouldProceed) return false;
    }

    final result = await Permission.notification.request();
    if (result.isPermanentlyDenied && context != null && context.mounted) {
      await showSettingsDialog(
        context: context,
        permissionName: 'Notifications',
      );
    }
    return result.isGranted;
  }

  /// Lazily requests video reading permission based on Android SDK level.
  /// Note: If using the system file picker / SAF, no storage permission is needed.
  static Future<bool> requestVideoReadPermissionIfNeeded(
    BuildContext? context,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final sdkInt = await StorageBridge.getSdkInt();

    if (Platform.isAndroid) {
      if (sdkInt >= 33) {
        // API 33+: Granular READ_MEDIA_VIDEO
        final status = await Permission.videos.status;
        if (status.isGranted || status.isLimited) return true;

        if (context != null && context.mounted) {
          final proceed = await showRationaleDialog(
            context: context,
            title: 'Media Access Required',
            message:
                'ShortsSplitter requires access to your video library to select '
                'and inspect the source video for splitting.',
          );
          if (!proceed) return false;
        }

        final result = await Permission.videos.request();
        if (result.isPermanentlyDenied && context != null && context.mounted) {
          await showSettingsDialog(
            context: context,
            permissionName: 'Photos and Videos',
          );
        }
        return result.isGranted || result.isLimited;
      } else {
        // API 28-32: READ_EXTERNAL_STORAGE
        final status = await Permission.storage.status;
        if (status.isGranted) return true;

        if (context != null && context.mounted) {
          final proceed = await showRationaleDialog(
            context: context,
            title: 'Storage Access Required',
            message: 'ShortsSplitter requires storage access to read videos from your device.',
          );
          if (!proceed) return false;
        }

        final result = await Permission.storage.request();
        if (result.isPermanentlyDenied && context != null && context.mounted) {
          await showSettingsDialog(context: context, permissionName: 'Storage');
        }
        return result.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted || status.isLimited) return true;
      final result = await Permission.photos.request();
      return result.isGranted || result.isLimited;
    }

    return true;
  }

  /// Requests write storage permission on Android 9 (API 28) for the Direct Public Storage fallback.
  static Future<bool> requestApi28WritePermissionIfNeeded(
    BuildContext? context,
  ) async {
    if (!Platform.isAndroid) return true;
    final sdkInt = await StorageBridge.getSdkInt();
    if (sdkInt != 28) return true; // Only applicable to API 28

    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    if (context != null && context.mounted) {
      final proceed = await showRationaleDialog(
        context: context,
        title: 'Storage Permission Required',
        message:
            'On Android 9, ShortsSplitter needs storage permission to save '
            'clips into your Movies/ShortsSplitter folder.',
      );
      if (!proceed) return false;
    }

    final result = await Permission.storage.request();
    if (result.isPermanentlyDenied && context != null && context.mounted) {
      await showSettingsDialog(context: context, permissionName: 'Storage');
    }
    return result.isGranted;
  }

  /// Displays a Material 3 rationale dialog explaining why a permission is requested.
  static Future<bool> showRationaleDialog({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Displays dialog guiding the user to open app settings when a permission is permanently denied.
  static Future<void> showSettingsDialog({
    required BuildContext context,
    required String permissionName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$permissionName Permission Denied'),
        content: Text(
          '$permissionName permission was permanently denied. Please enable it in '
          'App Settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
