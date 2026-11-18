import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';
import 'theme/app_colors.dart';
import 'theme/app_tokens.dart';

/// Provider for managing ThemeMode persistence (system, light, dark).
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadFromPrefs();
    return ThemeMode.system;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(AppConstants.prefKeyThemeMode);
    if (savedMode != null) {
      state = switch (savedMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyThemeMode, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}

/// Provider for managing user-selected accent color seed.
final accentColorProvider =
    NotifierProvider<AccentColorNotifier, AppAccentColor>(
      AccentColorNotifier.new,
    );

class AccentColorNotifier extends Notifier<AppAccentColor> {
  @override
  AppAccentColor build() {
    _loadFromPrefs();
    return AppAccentColor.red;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(AppConstants.prefKeyAccentColor);
    if (savedName != null) {
      for (final color in AppAccentColor.values) {
        if (color.name == savedName) {
          state = color;
          break;
        }
      }
    }
  }

  Future<void> setAccentColor(AppAccentColor color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefKeyAccentColor, color.name);
  }
}

/// Material 3 Themes for ShortsSplitter supporting dynamic accent colors and accessibility text scaling.
class AppTheme {
  AppTheme._();

  static ThemeData lightTheme([Color seedColor = const Color(0xFFFF0033)]) {
    return _buildTheme(Brightness.light, seedColor);
  }

  static ThemeData darkTheme([Color seedColor = const Color(0xFFFF0033)]) {
    return _buildTheme(Brightness.dark, seedColor);
  }

  static ThemeData _buildTheme(Brightness brightness, Color seedColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? colorScheme.surface
          : colorScheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: AppTokens.elevationNone,
        scrolledUnderElevation: AppTokens.elevationSm,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppTokens.elevationNone,
        color: isDark ? colorScheme.surfaceContainer : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: AppTokens.borderRadiusLg,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.3 : 0.5,
            ),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: AppTokens.elevationNone,
          minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceXl,
            vertical: AppTokens.spaceMd,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMd),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceXl,
            vertical: AppTokens.spaceMd,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMd),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceXl,
            vertical: AppTokens.spaceMd,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppTokens.borderRadiusMd),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMd,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMd,
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.borderRadiusMd,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceLg,
          vertical: AppTokens.spaceMd,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        elevation: AppTokens.elevationSm,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        elevation: AppTokens.elevationSm,
        labelType: NavigationRailLabelType.all,
        groupAlignment: -0.5,
      ),
    );
  }
}
