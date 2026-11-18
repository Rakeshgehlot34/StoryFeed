import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/editor/presentation/controllers/editor_controller.dart';
import 'package:shorts_splitter/features/editor/presentation/screens/editor_screen.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';

import '../../fakes/fake_video_processor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoProcessor fakeProcessor;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
  });

  const testVideo = PickedVideo(
    path: '/data/user/0/cache/editor_test.mp4',
    fileName: 'editor_test.mp4',
    baseName: 'editor_test',
    duration: Duration(seconds: 30),
    sizeInBytes: 10 * 1024 * 1024,
    width: 1920,
    height: 1080,
  );

  testWidgets('EditorScreen shows EmptyState when no video is loaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [videoProcessorProvider.overrideWithValue(fakeProcessor)],
        child: const MaterialApp(home: EditorScreen()),
      ),
    );

    expect(find.text('No Video Loaded'), findsOneWidget);
    expect(find.text('Choose Video'), findsOneWidget);
  });

  testWidgets(
    'EditorScreen renders tool selector and switches active tool docks',
    (tester) async {
      final container = ProviderContainer(
        overrides: [videoProcessorProvider.overrideWithValue(fakeProcessor)],
      );
      addTearDown(container.dispose);

      container.read(editorControllerProvider.notifier).loadVideo(testVideo);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditorScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and preview button
      expect(find.text('Project Info'), findsOneWidget);
      expect(find.text('editor_test_edited'), findsOneWidget);
      expect(find.text('5s Quick Preview'), findsOneWidget);

      // Default tool is Trim
      expect(find.text('Trim Selection'), findsOneWidget);

      // Switch to Speed tool
      await tester.tap(find.text('Speed'));
      await tester.pumpAndSettle();

      expect(find.text('Playback Speed'), findsOneWidget);
      expect(find.text('Preserve Audio Pitch'), findsOneWidget);

      // Switch to Color tool
      await tester.tap(find.text('Color'));
      await tester.pumpAndSettle();

      expect(find.text('Color & Grading'), findsOneWidget);
      expect(find.text('Preset Filters:'), findsOneWidget);

      // Verify Export button presence
      expect(find.textContaining('Export Studio Video'), findsOneWidget);
    },
  );
}
