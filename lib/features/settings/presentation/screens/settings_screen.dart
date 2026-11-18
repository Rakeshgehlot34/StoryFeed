import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../app/theme.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/settings_tile.dart';
import '../../../output/domain/models/storage_strategy.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../player/data/player_service.dart';
import '../../../split_config/presentation/controllers/split_config_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final outputDirAsync = ref.watch(outputDirectoryProvider);
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: settingsAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          children: List.generate(6, (_) => LoadingSkeleton.tile()),
        ),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceSm,
          ),
          children: [
            _buildOutputSection(context, ref, outputDirAsync, settings),
            const Divider(),
            _buildAppearanceSection(context, ref, themeMode, accentColor),
            const Divider(),
            _buildProcessingSection(context, ref, settings),
            const Divider(),
            _buildPermissionsSection(context, settings),
            const Divider(),
            _buildAboutSection(context, ref),
            const SizedBox(height: AppTokens.spaceXxl),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<String> outputDirAsync,
    SettingsState settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(AppStrings.setSectionOutput),
        SettingsTile(
          icon: Icons.folder_outlined,
          title: AppStrings.setSaveLocation,
          subtitle: outputDirAsync.valueOrNull ?? 'Loading...',
          trailing: TextButton(
            onPressed: () {
              ref.read(outputDirectoryProvider.notifier).pickAndSetDirectory();
            },
            child: const Text(AppStrings.actionChange),
          ),
        ),
        const SettingsTile(
          icon: Icons.title_rounded,
          title: AppStrings.setNamingPattern,
          subtitle: '{originalName}_part_{NNN}.mp4 (Zero-padded contiguity)',
        ),
        SettingsTile(
          icon: Icons.content_copy_rounded,
          title: AppStrings.setDuplicateHandling,
          subtitle: settings.duplicateHandling == DuplicateHandling.overwrite
              ? 'Overwrite existing file'
              : 'Auto-suffix (_1, _2)',
          trailing: DropdownButton<DuplicateHandling>(
            value: settings.duplicateHandling,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(
                value: DuplicateHandling.overwrite,
                child: Text('Overwrite'),
              ),
              DropdownMenuItem(
                value: DuplicateHandling.autoSuffix,
                child: Text('Auto-suffix'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setDuplicateHandling(val);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
    AppAccentColor accentColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(AppStrings.setSectionAppearance),
        SettingsTile(
          icon: Icons.brightness_medium_rounded,
          title: AppStrings.setThemeMode,
          subtitle: themeMode.name.toUpperCase(),
          trailing: DropdownButton<ThemeMode>(
            value: themeMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
            onChanged: (val) {
              if (val != null) {
                ref.read(themeModeProvider.notifier).setThemeMode(val);
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceSm,
          ),
          child: Row(
            children: [
              const Text('Accent:'),
              const SizedBox(width: AppTokens.spaceMd),
              ...AppAccentColor.values.map((color) {
                final isSelected = color == accentColor;
                return Padding(
                  padding: const EdgeInsets.only(right: AppTokens.spaceSm),
                  child: InkWell(
                    onTap: () {
                      ref
                          .read(accentColorProvider.notifier)
                          .setAccentColor(color);
                    },
                    borderRadius: AppTokens.borderRadiusFull,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.seedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingSection(
    BuildContext context,
    WidgetRef ref,
    SettingsState settings,
  ) {
    final controller = ref.read(settingsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(AppStrings.setSectionProcessing),
        SwitchListTile(
          secondary: const Icon(Icons.screen_lock_portrait_outlined),
          title: const Text(AppStrings.setKeepScreenAwake),
          subtitle: const Text('Optional: keeps display on during exports'),
          value: settings.keepScreenAwake,
          onChanged: (val) => controller.toggleKeepScreenAwake(val),
        ),
        Consumer(
          builder: (context, ref, _) {
            final playerService = ref.watch(playerServiceProvider);
            return SwitchListTile(
              secondary: const Icon(Icons.play_circle_outline),
              title: const Text('Resume Playback on Return'),
              subtitle: const Text(
                'Auto-resume video preview when returning to the app',
              ),
              value: playerService.resumeWhenReturning,
              onChanged: (val) => playerService.setResumeWhenReturning(val),
            );
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text(AppStrings.setShowNotification),
          value: settings.showNotificationProgress,
          onChanged: (val) => controller.toggleNotificationProgress(val),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.battery_saver_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tip: On devices with aggressive OEM battery cleaners, exempt ShortsSplitter from Battery Optimization in Android Settings to ensure background encoding is never killed.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        SettingsTile(
          icon: Icons.cleaning_services_outlined,
          title: AppStrings.setClearCache,
          subtitle:
              '${Formatters.formatFileSize(settings.tempFilesSizeBytes)} cached',
          trailing: TextButton(
            onPressed: () => controller.clearTempFilesAndCache(),
            child: const Text('Clear'),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(
    BuildContext context,
    SettingsState settings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Permissions & Access'),
        SettingsTile(
          icon: Icons.storage_outlined,
          title: 'Storage & Media Access',
          subtitle: settings.hasStoragePermission
              ? 'Granted'
              : 'Missing Permissions',
          trailing: !settings.hasStoragePermission
              ? TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Grant'),
                )
              : const Icon(Icons.check_circle_rounded, color: Colors.green),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(AppStrings.setSectionAbout),
        const SettingsTile(
          icon: Icons.info_outline_rounded,
          title: AppConstants.appName,
          subtitle: 'Version ${AppConstants.appVersion}',
        ),
        SettingsTile(
          icon: Icons.policy_outlined,
          title: 'License & Legal',
          subtitle: 'View open source licenses',
          onTap: () => showLicensePage(context: context),
        ),
        const Padding(
          padding: EdgeInsets.all(AppTokens.spaceMd),
          child: Text(
            AppStrings.setPrivacy,
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ),
        SettingsTile(
          icon: Icons.restore_rounded,
          title: AppStrings.setResetAll,
          subtitle: 'Restore factory default preferences',
          onTap: () async {
            final confirm = await ConfirmDialog.show(
              context: context,
              title: AppStrings.setResetAll,
              message: AppStrings.setResetConfirm,
              isDestructive: true,
            );
            if (confirm) {
              await ref
                  .read(settingsControllerProvider.notifier)
                  .resetAllSettings();
              ref.invalidate(splitConfigControllerProvider);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTokens.spaceMd,
        top: AppTokens.spaceMd,
        bottom: AppTokens.spaceXs,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
