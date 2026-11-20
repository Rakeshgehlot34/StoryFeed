import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/output/domain/models/exported_clip.dart';
import 'package:shorts_splitter/features/output/domain/safe_clip_replacer.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/output/presentation/screens/results_screen.dart';
import 'package:shorts_splitter/features/output/presentation/widgets/convert_to_shorts_dialog.dart';
import 'package:shorts_splitter/features/split_config/domain/models/canvas_spec.dart';

class _FakeOutputDirectoryNotifier extends OutputDirectoryNotifier {
  final String _dir;
  _FakeOutputDirectoryNotifier(this._dir);

  @override
  Future<String> build() async => _dir;
}

class _FakeExportedClipsNotifier extends ExportedClipsNotifier {
  final List<ExportedClip> _clips;
  _FakeExportedClipsNotifier(this._clips);

  @override
  Future<List<ExportedClip>> build() async => _clips;
}

void main() {
  final testClips = [
    ExportedClip(
      path: '/movies/ShortsSplitter/nature_part_001.mp4',
      fileName: 'nature_part_001.mp4',
      partIndex: 1,
      totalParts: 2,
      duration: const Duration(seconds: 180),
      sizeInBytes: 1024 * 1024 * 15,
      createdAt: DateTime.now(),
    ),
    ExportedClip(
      path: '/movies/ShortsSplitter/nature_part_002.mp4',
      fileName: 'nature_part_002.mp4',
      partIndex: 2,
      totalParts: 2,
      duration: const Duration(seconds: 180),
      sizeInBytes: 1024 * 1024 * 14,
      createdAt: DateTime.now(),
    ),
  ];

  testWidgets(
    'ConvertToShortsDialog displays 9:16 vertical option, part labels, and returns params',
    (WidgetTester tester) async {
      ConvertToShortsParams? resultParams;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  resultParams = await showDialog<ConvertToShortsParams>(
                    context: context,
                    builder: (ctx) => ConvertToShortsDialog(clips: testClips),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check header and options
      expect(find.text('Convert to 9:16 Shorts'), findsOneWidget);
      expect(find.text('Target Canvas Format'), findsOneWidget);
      expect(find.text('9:16 Vertical'), findsOneWidget);
      expect(find.text('Blurred Background'), findsOneWidget);
      expect(find.text('Add Part Number Label'), findsOneWidget);

      // Tap convert button
      final convertBtn = find.text('Convert (2 Shorts)');
      expect(convertBtn, findsOneWidget);
      await tester.tap(convertBtn);
      await tester.pumpAndSettle();

      // Dialog popped and returned configured params
      expect(resultParams, isNotNull);
      expect(resultParams!.selectedPartIndices, [1, 2]);
      expect(
        resultParams!.config.canvasSpec.format,
        CanvasFormat.shorts916,
      );
      expect(resultParams!.config.overlaySpec.autoLabel, isTrue);
      expect(resultParams!.replaceStrategy, ReplaceStrategy.replace);
    },
  );

  testWidgets(
    'ResultsScreen renders Convert to 9:16 Shorts banner and action buttons',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            outputDirectoryProvider.overrideWith(
              () => _FakeOutputDirectoryNotifier('/movies/ShortsSplitter'),
            ),
            exportedClipsProvider.overrideWith(
              () => _FakeExportedClipsNotifier(testClips),
            ),
          ],
          child: const MaterialApp(home: ResultsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the banner card is present
      expect(find.text('Convert to 9:16 Shorts'), findsWidgets);
      expect(
        find.textContaining('Format into 9:16 vertical canvas'),
        findsOneWidget,
      );

      // Verify bottom action button is present
      expect(find.text('Convert All 2 Clips to 9:16 Shorts'), findsOneWidget);

      // Verify per-clip convert button exists on each tile
      expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
    },
  );
}
