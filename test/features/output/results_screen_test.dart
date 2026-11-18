import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/output/domain/models/exported_clip.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/output/presentation/screens/results_screen.dart';
import 'package:shorts_splitter/features/plan_review/domain/models/clip_processing_state.dart';
import 'package:shorts_splitter/features/plan_review/presentation/controllers/part_items_controller.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';

void main() {
  testWidgets(
    'ResultsScreen displays exported clips and dimmed unprocessed clips with Process buttons',
    (WidgetTester tester) async {
      final exportedClips = [
        ExportedClip(
          path: '/test/output/my_clip_part_001.mp4',
          fileName: 'my_clip_part_001.mp4',
          partIndex: 1,
          totalParts: 3,
          duration: const Duration(seconds: 20),
          sizeInBytes: 1024 * 1024 * 5,
          createdAt: DateTime.now(),
        ),
      ];

      final planParts = [
        const PartItem(
          segment: ClipSegment(
            index: 1,
            startSeconds: 0.0,
            durationSeconds: 20.0,
            formattedName: 'my_clip_part_001.mp4',
          ),
          status: ClipProcessingStatus.processed,
          outputPath: '/test/output/my_clip_part_001.mp4',
        ),
        const PartItem(
          segment: ClipSegment(
            index: 2,
            startSeconds: 20.0,
            durationSeconds: 20.0,
            formattedName: 'my_clip_part_002.mp4',
          ),
          status: ClipProcessingStatus.notProcessed,
        ),
        const PartItem(
          segment: ClipSegment(
            index: 3,
            startSeconds: 40.0,
            durationSeconds: 20.0,
            formattedName: 'my_clip_part_003.mp4',
          ),
          status: ClipProcessingStatus.notProcessed,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportedClipsProvider.overrideWith(
              () => _FakeExportedClipsNotifier(exportedClips),
            ),
            outputDirectoryProvider.overrideWith(
              () => _FakeOutputDirectoryNotifier('/test/output'),
            ),
            partItemsControllerProvider.overrideWith(
              () => _FakePartItemsController(planParts),
            ),
          ],
          child: const MaterialApp(home: ResultsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header mentions partial progress
      expect(find.textContaining('Created 1 of 3 shorts'), findsOneWidget);
      expect(find.textContaining('2 remaining'), findsOneWidget);

      // Verify exported clip is present
      expect(find.text('my_clip_part_001.mp4'), findsOneWidget);

      // Verify unprocessed clips are rendered with "Not processed" and "Process" button
      expect(find.text('my_clip_part_002.mp4'), findsOneWidget);
      expect(find.text('my_clip_part_003.mp4'), findsOneWidget);
      expect(find.text('Process'), findsNWidgets(2));

      // Verify "Process Remaining (2 clips)" action button is present
      expect(find.text('Process Remaining (2 clips)'), findsOneWidget);

      // Verify "Done • Create Another" is present
      expect(find.text('Done • Create Another'), findsOneWidget);
    },
  );
}

class _FakeExportedClipsNotifier extends ExportedClipsNotifier {
  final List<ExportedClip> _clips;
  _FakeExportedClipsNotifier(this._clips);

  @override
  Future<List<ExportedClip>> build() async => _clips;
}

class _FakeOutputDirectoryNotifier extends OutputDirectoryNotifier {
  final String _dir;
  _FakeOutputDirectoryNotifier(this._dir);

  @override
  Future<String> build() async => _dir;
}

class _FakePartItemsController extends PartItemsController {
  final List<PartItem> _items;
  _FakePartItemsController(this._items);

  @override
  List<PartItem> build() => _items;
}
