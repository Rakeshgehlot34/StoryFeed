import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/audio_studio/presentation/controllers/audio_studio_controller.dart';
import 'package:shorts_splitter/features/audio_studio/presentation/screens/audio_studio_screen.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';

import '../../fakes/fake_video_processor.dart';

class _FakeOutputDirectoryNotifier extends OutputDirectoryNotifier {
  @override
  Future<String> build() async => '/fake/output/directory';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoProcessor fakeProcessor;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
  });

  const testVideo = PickedVideo(
    path: '/data/user/0/cache/audio_screen_test.mp4',
    fileName: 'audio_screen_test.mp4',
    baseName: 'audio_screen_test',
    duration: Duration(seconds: 30),
    sizeInBytes: 12 * 1024 * 1024,
    width: 1920,
    height: 1080,
  );

  testWidgets(
    'AudioStudioScreen displays EmptyState when no video is selected',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoProcessorProvider.overrideWithValue(fakeProcessor),
            outputDirectoryProvider.overrideWith(
              _FakeOutputDirectoryNotifier.new,
            ),
          ],
          child: const MaterialApp(home: AudioStudioScreen()),
        ),
      );

      expect(find.text('No Video Selected'), findsOneWidget);
      expect(find.text('Choose Video'), findsOneWidget);
    },
  );

  testWidgets(
    'AudioStudioScreen displays timeline mixer and track cards when video is set',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          videoProcessorProvider.overrideWithValue(fakeProcessor),
          outputDirectoryProvider.overrideWith(
            _FakeOutputDirectoryNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(audioStudioControllerProvider.notifier)
          .setVideo(testVideo);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AudioStudioScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Timeline Mixer'), findsOneWidget);
      expect(find.text('Original Audio Track'), findsOneWidget);
      expect(find.text('Background Music'), findsOneWidget);
      expect(find.text('Voice-over Track'), findsOneWidget);
      expect(find.text('Smart Audio Ducking'), findsOneWidget);
      expect(find.text('Export Studio Video'), findsOneWidget);
    },
  );

  testWidgets('AudioStudioScreen toggles mute original audio switch', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        videoProcessorProvider.overrideWithValue(fakeProcessor),
        outputDirectoryProvider.overrideWith(_FakeOutputDirectoryNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(audioStudioControllerProvider.notifier)
        .setVideo(testVideo);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AudioStudioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final muteSwitchFinder = find.widgetWithText(
      SwitchListTile,
      'Mute Original Audio',
    );
    expect(muteSwitchFinder, findsOneWidget);

    await tester.tap(muteSwitchFinder);
    await tester.pumpAndSettle();

    expect(
      container.read(audioStudioControllerProvider).config.isOriginalMuted,
      isTrue,
    );
  });
}
