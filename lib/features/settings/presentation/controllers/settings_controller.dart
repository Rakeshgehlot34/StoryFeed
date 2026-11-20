import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/permission_utils.dart';
import '../../../output/domain/models/storage_strategy.dart';
import '../../../output/presentation/controllers/output_controller.dart';

class SettingsState {
  final bool keepScreenAwake;
  final bool showNotificationProgress;
  final DuplicateHandling duplicateHandling;
  final int tempFilesSizeBytes;
  final bool hasNotificationPermission;
  final bool hasStoragePermission;

  const SettingsState({
    this.keepScreenAwake = true,
    this.showNotificationProgress = true,
    this.duplicateHandling = DuplicateHandling.overwrite,
    this.tempFilesSizeBytes = 0,
    this.hasNotificationPermission = true,
    this.hasStoragePermission = true,
  });

  SettingsState copyWith({
    bool? keepScreenAwake,
    bool? showNotificationProgress,
    DuplicateHandling? duplicateHandling,
    int? tempFilesSizeBytes,
    bool? hasNotificationPermission,
    bool? hasStoragePermission,
  }) {
    return SettingsState(
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      showNotificationProgress:
          showNotificationProgress ?? this.showNotificationProgress,
      duplicateHandling: duplicateHandling ?? this.duplicateHandling,
      tempFilesSizeBytes: tempFilesSizeBytes ?? this.tempFilesSizeBytes,
      hasNotificationPermission:
          hasNotificationPermission ?? this.hasNotificationPermission,
      hasStoragePermission: hasStoragePermission ?? this.hasStoragePermission,
    );
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<SettingsState> {
  AppLifecycleListener? _lifecycleListener;

  @override
  Future<SettingsState> build() async {
    _lifecycleListener ??= AppLifecycleListener(
      onResume: refreshPermissions,
    );
    ref.onDispose(() {
      _lifecycleListener?.dispose();
      _lifecycleListener = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final keepAwake =
        prefs.getBool(AppConstants.prefKeyKeepScreenAwake) ?? true;
    final showNotif =
        prefs.getBool(AppConstants.prefKeyShowNotification) ?? true;
    final dupHandling =
        await ref.read(outputRepositoryProvider).getDuplicateHandling();

    final tempSize = await _calculateTempDirectorySize();
    bool notifGranted = true;
    bool storageGranted = true;

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final notifStatus = await Permission.notification.status.timeout(
          const Duration(seconds: 1),
        );
        notifGranted = notifStatus.isGranted;
      } catch (_) {
        // Graceful fallback for tests or desktop environments
      }
      try {
        storageGranted =
            await PermissionUtils.hasMediaOrStoragePermission().timeout(
          const Duration(seconds: 1),
        );
      } catch (_) {
        // Graceful fallback for tests or desktop environments
      }
    }

    return SettingsState(
      keepScreenAwake: keepAwake,
      showNotificationProgress: showNotif,
      duplicateHandling: dupHandling,
      tempFilesSizeBytes: tempSize,
      hasNotificationPermission: notifGranted,
      hasStoragePermission: storageGranted,
    );
  }

  /// Automatically re-probes permissions when returning from App Settings.
  Future<void> refreshPermissions() async {
    bool notifGranted = true;
    bool storageGranted = true;

    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        final notifStatus = await Permission.notification.status.timeout(
          const Duration(seconds: 1),
        );
        notifGranted = notifStatus.isGranted;
      } catch (_) {}
      try {
        storageGranted =
            await PermissionUtils.hasMediaOrStoragePermission().timeout(
          const Duration(seconds: 1),
        );
      } catch (_) {}
    }

    state = state.whenData(
      (s) => s.copyWith(
        hasNotificationPermission: notifGranted,
        hasStoragePermission: storageGranted,
      ),
    );
  }

  Future<void> toggleKeepScreenAwake(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefKeyKeepScreenAwake, value);
    state = state.whenData((s) => s.copyWith(keepScreenAwake: value));
  }

  Future<void> toggleNotificationProgress(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefKeyShowNotification, value);
    state = state.whenData((s) => s.copyWith(showNotificationProgress: value));
  }

  Future<void> setDuplicateHandling(DuplicateHandling handling) async {
    await ref.read(outputRepositoryProvider).setDuplicateHandling(handling);
    state = state.whenData((s) => s.copyWith(duplicateHandling: handling));
  }

  Future<void> clearTempFilesAndCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync(recursive: true);
        for (final entity in entities) {
          try {
            if (entity is File) entity.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}

    final newSize = await _calculateTempDirectorySize();
    state = state.whenData((s) => s.copyWith(tempFilesSizeBytes: newSize));
  }

  Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Preserve onboarding status so resetting preferences does not force onboarding again
    await prefs.setBool(AppConstants.prefKeyOnboardingCompleted, true);
    ref.invalidate(themeModeProvider);
    ref.invalidate(accentColorProvider);
    ref.invalidateSelf();
  }

  Future<int> _calculateTempDirectorySize() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return 0;
    }
    try {
      final tempDir = await getTemporaryDirectory().timeout(
        const Duration(milliseconds: 250),
        onTimeout: () => Directory('/tmp'),
      );
      if (!tempDir.existsSync()) return 0;
      var total = 0;
      for (final file in tempDir.listSync(recursive: true)) {
        if (file is File) total += file.lengthSync();
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
