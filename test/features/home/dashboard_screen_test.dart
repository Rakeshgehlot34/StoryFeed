import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/app/constants.dart';
import 'package:shorts_splitter/core/database/app_database.dart';
import 'package:shorts_splitter/features/history/domain/models/project_record.dart';
import 'package:shorts_splitter/features/home/presentation/screens/dashboard_screen.dart';

import '../../test_sqlite_helper.dart';

void main() {
  setUpAll(() {
    setupTestSqlite();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('DashboardScreen renders empty state when no projects exist', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyOnboardingCompleted: true,
      AppConstants.prefKeyProjectsHistory: <String>[],
    });

    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    // Initial load
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify creator header
    expect(find.text('ShortsSplitter'), findsOneWidget);
    // Verify Studio Tools Grid on Home Hub
    expect(find.text('Studio Tools'), findsOneWidget);
    expect(find.text('Shorts Maker'), findsOneWidget);
    expect(find.text('Custom Split'), findsOneWidget);

    await inMemoryDb.close();
  });

  testWidgets('DashboardScreen renders populated stats and recent projects', (
    WidgetTester tester,
  ) async {
    final sampleProject = ProjectRecord(
      id: 'proj_1',
      videoName: 'vacation_trip.mp4',
      baseName: 'vacation_trip',
      totalShortsCount: 4,
      totalDurationSeconds: 120.0,
      canvasFormat: '9:16',
      createdAt: DateTime.now(),
      outputFilePaths: const [
        '/storage/emulated/0/Movies/ShortsSplitter/vacation_trip_part_001.mp4',
        '/storage/emulated/0/Movies/ShortsSplitter/vacation_trip_part_002.mp4',
        '/storage/emulated/0/Movies/ShortsSplitter/vacation_trip_part_003.mp4',
        '/storage/emulated/0/Movies/ShortsSplitter/vacation_trip_part_004.mp4',
      ],
    );

    SharedPreferences.setMockInitialValues({
      AppConstants.prefKeyOnboardingCompleted: true,
      AppConstants.prefKeyProjectsHistory: <String>[
        jsonEncode(sampleProject.toJson()),
      ],
    });

    // Provide larger test viewport to see recent projects
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final inMemoryDb = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify stats from sample project
    expect(find.text('4'), findsWidgets); // total shorts count in stats grid
    expect(find.text('vacation_trip.mp4'), findsOneWidget);
    expect(find.textContaining('4 clips'), findsOneWidget);

    await inMemoryDb.close();
  });
}
