import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'storage_bridge.dart';

/// Intelligent permission manager executing lazy, version-aware permission requests
/// matching Android 9 (API 28) through Android 15+ (API 35+).
class PermissionUtils {
  PermissionUtils._();

  /// Requests all core app permissions (Videos/Photos/Storage, Notifications, Microphone)
  /// on first launch or during onboarding.
  static Future<Map<Permission, PermissionStatus>> requestAllAppPermissions({
    BuildContext? context,
  }) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return {};
    }

    final permissionsToRequest = <Permission>[];

    if (Platform.isAndroid) {
      final sdkInt = await StorageBridge.getSdkInt();
      if (sdkInt >= 33) {
        // API 33+ (Android 13+): Granular media — shows as "Photos and videos" in App Info
        permissionsToRequest.add(Permission.videos);
        permissionsToRequest.add(Permission.photos);
        // API 34+ (Android 14+): Partial / selected-only access toggle in App Info.
        // Must be requested alongside videos/photos so the system shows the
        // "Allow access to media" dialog with a "Select photos and videos" option.
        if (sdkInt >= 34) {
          permissionsToRequest.add(Permission.mediaLibrary);
        }
        permissionsToRequest.add(Permission.notification);
      } else {
        // API 28–32 (Android 9–12): Legacy "Storage" group — shows as "Storage" in App Info
        permissionsToRequest.add(Permission.storage);
      }
      permissionsToRequest.add(Permission.microphone);
    } else if (Platform.isIOS) {
      permissionsToRequest.add(Permission.photos);
      permissionsToRequest.add(Permission.notification);
      permissionsToRequest.add(Permission.microphone);
    }

    if (permissionsToRequest.isEmpty) return {};
    final result = await permissionsToRequest.request();

    if (context != null && context.mounted) {
      final isPermanentlyDenied =
          result.values.any((s) => s.isPermanentlyDenied);
      if (isPermanentlyDenied) {
        final sdkInt = await StorageBridge.getSdkInt();
        final name = (Platform.isAndroid && sdkInt >= 33)
            ? 'Photos and Videos'
            : 'Storage';
        if (context.mounted) {
          await showSettingsDialog(
            context: context,
            permissionName: name,
          );
        }
      }
    }

    return result;
  }

  /// Checks whether media/storage permission is granted.
  static Future<bool> hasMediaOrStoragePermission() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    if (!Platform.isAndroid) return true;

    final sdkInt = await StorageBridge.getSdkInt();
    if (sdkInt >= 33) {
      final videoStatus = await Permission.videos.status;
      return videoStatus.isGranted || videoStatus.isLimited;
    } else {
      final storageStatus = await Permission.storage.status;
      return storageStatus.isGranted;
    }
  }

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

  /// Prompts user to exempt app from battery optimizations for long background exports.
  static Future<bool> requestBatteryOptimizationExemptionIfNeeded(
    BuildContext? context,
  ) async {
    if (!Platform.isAndroid) return true;
    final isIgnored = await StorageBridge.isIgnoringBatteryOptimizations();
    if (isIgnored) return true;

    if (context != null && context.mounted) {
      final shouldProceed = await showRationaleDialog(
        context: context,
        title: 'Background Export Optimization',
        message:
            'To prevent Android from freezing long video exports when your screen is turned off or when switching apps, please allow unrestricted background activity.',
      );
      if (!shouldProceed) return false;
    }

    return StorageBridge.requestIgnoreBatteryOptimizations();
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
            message:
                'ShortsSplitter requires storage access to read videos from your device.',
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

  /// Verifies all necessary storage and media permissions before launching an export.
  static Future<bool> ensureExportStoragePermissions(
    BuildContext context,
    String outputDir,
  ) async {
    if (!Platform.isAndroid) return true;

    final sdkInt = await StorageBridge.getSdkInt();

    // On Android 9 (API 28), direct public storage write requires WRITE_EXTERNAL_STORAGE
    if (sdkInt == 28 && !outputDir.startsWith('content://')) {
      if (!context.mounted) return false;
      final hasWrite = await requestApi28WritePermissionIfNeeded(context);
      return hasWrite;
    }

    return true;
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
