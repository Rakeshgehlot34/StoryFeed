import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/history/domain/models/project_record.dart';
import 'package:shorts_splitter/features/history/presentation/widgets/history_project_card.dart';

void main() {
  group('ProjectRecord Partial Completion Domain Tests', () {
    test(
      'Calculates actualProcessedCount and isPartiallyProcessed correctly',
      () {
        final record = ProjectRecord(
          id: '123',
          videoName: 'test.mp4',
          baseName: 'test',
          createdAt: DateTime.now(),
          totalDurationSeconds: 600.0,
          totalShortsCount: 30,
          processedShortsCount: 3,
          canvasFormat: 'Shorts 9:16',
          outputFilePaths: [
            '/out/test_part_001.mp4',
            '/out/test_part_002.mp4',
            '/out/test_part_003.mp4',
          ],
        );

        expect(record.actualProcessedCount, 3);
        expect(record.totalShortsCount, 30);
        expect(record.isPartiallyProcessed, isTrue);
        expect(record.processedBadgeText, '3/30 processed');
      },
    );

    test('Full completion has isPartiallyProcessed false', () {
      final record = ProjectRecord(
        id: '124',
        videoName: 'test.mp4',
        baseName: 'test',
        createdAt: DateTime.now(),
        totalDurationSeconds: 60.0,
        totalShortsCount: 3,
        processedShortsCount: 3,
        canvasFormat: 'Shorts 9:16',
        outputFilePaths: ['/out/1.mp4', '/out/2.mp4', '/out/3.mp4'],
      );

      expect(record.actualProcessedCount, 3);
      expect(record.isPartiallyProcessed, isFalse);
    });

    test('Backwards-compatible JSON serialization and deserialization', () {
      final record = ProjectRecord(
        id: '125',
        videoName: 'old_project.mp4',
        baseName: 'old_project',
        createdAt: DateTime(2026, 11, 18),
        totalDurationSeconds: 120.0,
        totalShortsCount: 10,
        processedShortsCount: 4,
        canvasFormat: 'Shorts 9:16',
        outputFilePaths: ['/p1.mp4', '/p2.mp4', '/p3.mp4', '/p4.mp4'],
      );

      final json = record.toJson();
      final restored = ProjectRecord.fromJson(json);

      expect(restored.id, '125');
      expect(restored.totalShortsCount, 10);
      expect(restored.actualProcessedCount, 4);
      expect(restored.isPartiallyProcessed, isTrue);
      expect(restored.processedBadgeText, '4/10 processed');
    });
  });

  group('HistoryProjectCard Widget Tests with Partial Badges', () {
    testWidgets(
      'Renders "3/30 processed" badge and progress bar when partially completed',
      (tester) async {
        final partialProject = ProjectRecord(
          id: '201',
          videoName: 'mountain_hike.mp4',
          baseName: 'mountain_hike',
          createdAt: DateTime.now(),
          totalDurationSeconds: 600.0,
          totalShortsCount: 30,
          processedShortsCount: 3,
          canvasFormat: 'Shorts 9:16',
          outputFilePaths: const ['/out/1.mp4', '/out/2.mp4', '/out/3.mp4'],
          isFilesAvailable: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HistoryProjectCard(
                project: partialProject,
                onTap: () {},
                onDelete: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify video name
        expect(find.text('mountain_hike.mp4'), findsOneWidget);

        // Verify partial completion badge
        expect(find.text('3/30 processed'), findsOneWidget);

        // Verify LinearProgressIndicator is present
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'Renders standard text without progress bar when fully completed',
      (tester) async {
        final fullProject = ProjectRecord(
          id: '202',
          videoName: 'cooking_show.mp4',
          baseName: 'cooking_show',
          createdAt: DateTime.now(),
          totalDurationSeconds: 120.0,
          totalShortsCount: 6,
          processedShortsCount: 6,
          canvasFormat: 'Shorts 9:16',
          outputFilePaths: const [
            '/out/1.mp4',
            '/out/2.mp4',
            '/out/3.mp4',
            '/out/4.mp4',
            '/out/5.mp4',
            '/out/6.mp4',
          ],
          isFilesAvailable: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HistoryProjectCard(
                project: fullProject,
                onTap: () {},
                onDelete: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('cooking_show.mp4'), findsOneWidget);
        expect(find.textContaining('6 shorts'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      },
    );
  });
}
