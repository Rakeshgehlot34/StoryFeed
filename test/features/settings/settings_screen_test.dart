import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/app/constants.dart';
import 'package:shorts_splitter/app/constants/app_strings.dart';
import 'package:shorts_splitter/app/theme.dart';
import 'package:shorts_splitter/app/theme/app_colors.dart';
import 'package:shorts_splitter/features/output/domain/models/storage_strategy.dart';
import 'package:shorts_splitter/features/settings/presentation/screens/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'SettingsScreen displays output, appearance, and processing settings',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyThemeMode: 'system',
        AppConstants.prefKeyAccentColor: 'red',
        AppConstants.prefKeyDuplicateHandling: 'overwrite',
      });

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SettingsScreen())),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(AppStrings.settingsTitle), findsOneWidget);
      expect(find.text(AppStrings.setSectionOutput), findsOneWidget);
      expect(find.text('Shorts Splitting Defaults'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(AppStrings.setSectionProcessing),
        200,
      );
      expect(find.text(AppStrings.setSectionProcessing), findsOneWidget);
    },
  );

  testWidgets(
    'SettingsScreen updates and persists theme mode and accent color',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        AppConstants.prefKeyThemeMode: 'system',
        AppConstants.prefKeyAccentColor: 'red',
        AppConstants.prefKeyDuplicateHandling: 'overwrite',
      });

      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Change ThemeMode via notifier directly or UI
      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.prefKeyThemeMode), 'dark');
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // Change AccentColor via notifier
      await container
          .read(accentColorProvider.notifier)
          .setAccentColor(AppAccentColor.emerald);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(prefs.getString(AppConstants.prefKeyAccentColor), 'emerald');
      expect(container.read(accentColorProvider), AppAccentColor.emerald);
    },
  );

  testWidgets('SettingsScreen updates duplicate handling setting', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyDuplicateHandling: 'overwrite',
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SettingsScreen())),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Dropdown exists with Overwrite
    expect(find.text('Overwrite'), findsOneWidget);

    // Tap dropdown and select Auto-suffix
    await tester.tap(find.text('Overwrite'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Auto-suffix').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(AppConstants.prefKeyDuplicateHandling),
      DuplicateHandling.autoSuffix.name,
    );
  });
}
