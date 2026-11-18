import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/merge/domain/models/merge_project.dart';
import 'package:shorts_splitter/features/merge/presentation/controllers/merge_controller.dart';
import 'package:shorts_splitter/features/merge/presentation/screens/merge_screen.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/shared/widgets/empty_state.dart';

import '../../fakes/fake_video_processor.dart';

class _PreloadedMergeController extends MergeController {
  final MergeState _initial;
  _PreloadedMergeController(this._initial);

  @override
  MergeState build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoProcessor fakeProcessor;

  const clip1 = MergeClipItem(
    id: 'c1',
    videoPath: '/mock/clip1.mp4',
    fileName: 'clip1.mp4',
    durationSeconds: 10.0,
    width: 1920,
    height: 1080,
  );

  const clip2 = MergeClipItem(
    id: 'c2',
    videoPath: '/mock/clip2.mp4',
    fileName: 'clip2.mp4',
    durationSeconds: 15.0,
    width: 1920,
    height: 1080,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
  });

  Widget createWidgetUnderTest({MergeState? initialState}) {
    return ProviderScope(
      overrides: [
        videoProcessorProvider.overrideWithValue(fakeProcessor),
        if (initialState != null)
          mergeControllerProvider.overrideWith(
            () => _PreloadedMergeController(initialState),
          ),
      ],
      child: const MaterialApp(home: MergeScreen()),
    );
  }

  group('MergeScreen Widget Tests', () {
    testWidgets('1. Displays EmptyState when no clips are added', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No Videos Selected'), findsOneWidget);
      expect(find.text('Select Videos'), findsOneWidget);
    });

    testWidgets(
      '2. Displays Summary, Clip list, Settings, and Merge button when clips present',
      (tester) async {
        const stateWithClips = MergeState(
          config: MergeConfig(clips: [clip1, clip2]),
        );

        await tester.pumpWidget(
          createWidgetUnderTest(initialState: stateWithClips),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EmptyState), findsNothing);
        expect(find.text('Total Clips'), findsOneWidget);
        expect(find.text('clip1.mp4'), findsOneWidget);
        expect(find.text('clip2.mp4'), findsOneWidget);
        expect(find.text('Canvas & Aspect Ratio'), findsOneWidget);
        expect(find.text('Transitions'), findsOneWidget);
        expect(find.text('Merge 2 Videos'), findsOneWidget);
      },
    );

    testWidgets('3. Tapping delete removes the clip from the list', (
      tester,
    ) async {
      const stateWithClips = MergeState(
        config: MergeConfig(clips: [clip1, clip2]),
      );

      await tester.pumpWidget(
        createWidgetUnderTest(initialState: stateWithClips),
      );
      await tester.pumpAndSettle();

      final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButtons, findsNWidgets(2));

      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('clip1.mp4'), findsNothing);
      expect(find.text('clip2.mp4'), findsOneWidget);
      expect(find.text('Add at least 2 videos to merge'), findsOneWidget);
    });

    testWidgets('4. Tapping duplicate clones the clip in the list', (
      tester,
    ) async {
      const stateWithClips = MergeState(
        config: MergeConfig(clips: [clip1, clip2]),
      );

      await tester.pumpWidget(
        createWidgetUnderTest(initialState: stateWithClips),
      );
      await tester.pumpAndSettle();

      final duplicateButtons = find.byIcon(Icons.copy_rounded);
      expect(duplicateButtons, findsNWidgets(2));

      await tester.tap(duplicateButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Merge 3 Videos'), findsOneWidget);
    });
  });
}
