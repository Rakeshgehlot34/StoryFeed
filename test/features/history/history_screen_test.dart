import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/app/constants.dart';
import 'package:shorts_splitter/app/constants/app_strings.dart';
import 'package:shorts_splitter/core/database/app_database.dart';
import 'package:shorts_splitter/features/history/domain/models/project_record.dart';
import 'package:shorts_splitter/features/history/presentation/screens/history_screen.dart';

import '../../test_sqlite_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HistoryScreen renders list of past projects', (
    WidgetTester tester,
  ) async {
    final sampleProject = ProjectRecord(
      id: 'proj_h1',
      videoName: 'epic_sunset.mp4',
      baseName: 'epic_sunset',
      totalShortsCount: 3,
      totalDurationSeconds: 90.0,
      canvasFormat: '9:16',
      createdAt: DateTime.now(),
      outputFilePaths: const [
        '/storage/emulated/0/Movies/ShortsSplitter/epic_sunset_part_001.mp4',
        '/storage/emulated/0/Movies/ShortsSplitter/epic_sunset_part_002.mp4',
        '/storage/emulated/0/Movies/ShortsSplitter/epic_sunset_part_003.mp4',
      ],
    );

    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyProjectsHistory: <String>[
        jsonEncode(sampleProject.toJson()),
      ],
    });

    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(AppStrings.historyTitle), findsOneWidget);
    expect(find.text('epic_sunset.mp4'), findsOneWidget);
    expect(find.textContaining('3 parts'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets('HistoryScreen delete with undo snackbar restores project', (
    WidgetTester tester,
  ) async {
    final sampleProject = ProjectRecord(
      id: 'proj_undo_test',
      videoName: 'guitar_solo.mp4',
      baseName: 'guitar_solo',
      totalShortsCount: 2,
      totalDurationSeconds: 60.0,
      canvasFormat: '9:16',
      createdAt: DateTime.now(),
      outputFilePaths: const [
        '/storage/emulated/0/Movies/ShortsSplitter/guitar_solo_part_001.mp4',
        '/storage/emulated/0/Movies/ShortsSplitter/guitar_solo_part_002.mp4',
      ],
    );

    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyProjectsHistory: <String>[
        jsonEncode(sampleProject.toJson()),
      ],
    });

    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('guitar_solo.mp4'), findsOneWidget);

    // Tap delete button on the project card
    final deleteButton = find.byTooltip('Delete project record');
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify deleted snackbar is shown
    expect(find.text(AppStrings.historyDeletedSnackbar), findsOneWidget);
    expect(find.text(AppStrings.actionUndo), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text(AppStrings.actionUndo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Project should be restored in the list
    expect(find.text('guitar_solo.mp4'), findsOneWidget);

    await inMemoryDb.close();
  });
}
