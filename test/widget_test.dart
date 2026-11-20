import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/app/constants.dart';
import 'package:shorts_splitter/core/database/app_database.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';
import 'package:shorts_splitter/main.dart';

import 'test_sqlite_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyOnboardingCompleted: true,
    });
  });

  testWidgets('ShortsSplitterApp initial smoke test', (
    WidgetTester tester,
  ) async {
    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const ShortsSplitterApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify app title or branding is displayed
    expect(find.text(AppConstants.appName), findsWidgets);
    // Verify studio tools on Home Hub
    expect(find.text('Shorts Maker'), findsOneWidget);
    expect(find.text('Studio Tools'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets(
      'ShortsSplitterApp shows onboarding when not completed and skips to home',
      (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyOnboardingCompleted: false,
    });

    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const ShortsSplitterApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify onboarding screen is visible with skip button
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Split Any Video in Seconds'), findsOneWidget);

    // Tap Skip button
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // After skipping, user arrives on Home Hub
    expect(find.text('Shorts Maker'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets('ShortsSplitterApp onboarding includes permissions page', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyOnboardingCompleted: false,
    });

    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const ShortsSplitterApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Advance to Page 2 (Permissions Page)
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Verify Permissions page is visible
    expect(find.text('Allow Permissions'), findsOneWidget);
    expect(find.text('Grant All Permissions'), findsOneWidget);
    expect(find.text('Photos & Videos'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Microphone'), findsOneWidget);

    // Tap Grant All Permissions
    await tester.tap(find.text('Grant All Permissions'));
    await tester.pumpAndSettle();

    expect(find.text('Permissions Granted'), findsOneWidget);

    await inMemoryDb.close();
  });

  group('ClipSegment calculation tests', () {
    test(
        'Calculates exact segments with contiguous timestamps and zero-padded names',
        () {
      // 4 minutes 10 seconds = 250 seconds, 60s target
      final segments = ClipSegment.calculateSegments(
        totalDurationSeconds: 250.0,
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: true,
        baseName: 'my_video',
      );

      expect(segments.length, 5);
      expect(segments[0].formattedName, 'my_video_part_001.mp4');
      expect(segments[0].startSeconds, 0.0);
      expect(segments[0].durationSeconds, 60.0);
      expect(segments[0].endSeconds, 60.0);

      expect(segments[1].formattedName, 'my_video_part_002.mp4');
      expect(segments[1].startSeconds, 60.0);
      expect(segments[1].durationSeconds, 60.0);

      expect(segments[4].formattedName, 'my_video_part_005.mp4');
      expect(segments[4].startSeconds, 240.0);
      expect(segments[4].durationSeconds, 10.0);
    });

    test(
        'Merges trailing remainder under 3 seconds into previous clip when enabled',
        () {
      // 62 seconds total with 60s target: remainder is 2s (< 3s threshold)
      final segments = ClipSegment.calculateSegments(
        totalDurationSeconds: 62.0,
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: true,
        baseName: 'podcast',
      );

      expect(segments.length, 1);
      expect(segments[0].formattedName, 'podcast_part_001.mp4');
      expect(segments[0].durationSeconds, 62.0);
      expect(segments[0].isMergedTrailing, isTrue);
    });

    test('Does not merge trailing remainder when toggle is disabled', () {
      final segments = ClipSegment.calculateSegments(
        totalDurationSeconds: 62.0,
        targetClipDurationSeconds: 60,
        mergeShortTrailingClip: false,
        baseName: 'podcast',
      );

      expect(segments.length, 2);
      expect(segments[0].formattedName, 'podcast_part_001.mp4');
      expect(segments[0].durationSeconds, 60.0);
      expect(segments[1].formattedName, 'podcast_part_002.mp4');
      expect(segments[1].durationSeconds, 2.0);
    });
  });
}
