import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/convert/presentation/controllers/convert_controller.dart';
import 'package:shorts_splitter/features/convert/presentation/screens/convert_screen.dart';
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
    path: '/data/user/0/cache/convert_test.mp4',
    fileName: 'convert_test.mp4',
    baseName: 'convert_test',
    duration: Duration(seconds: 30),
    sizeInBytes: 15 * 1024 * 1024,
    width: 1920,
    height: 1080,
  );

  testWidgets('ConvertScreen shows EmptyState when no video is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoProcessorProvider.overrideWithValue(fakeProcessor),
          outputDirectoryProvider.overrideWith(
            _FakeOutputDirectoryNotifier.new,
          ),
        ],
        child: const MaterialApp(home: ConvertScreen()),
      ),
    );

    expect(find.text('No Video Selected'), findsOneWidget);
    expect(find.text('Choose Video'), findsOneWidget);
  });

  testWidgets(
    'ConvertScreen renders controls and estimates when video is set',
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
          .read(convertControllerProvider.notifier)
          .setVideo(testVideo);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ConvertScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Target Format'), findsOneWidget);
      expect(find.text('MP4 (H.264)'), findsOneWidget);
      expect(find.text('Animated GIF'), findsOneWidget);
      expect(find.text('Audio Extraction'), findsOneWidget);
      expect(find.text('Output Estimate'), findsOneWidget);
      expect(find.text('Convert Video'), findsOneWidget);
    },
  );

  testWidgets('Tapping format chip switches UI to GIF mode', (tester) async {
    final container = ProviderContainer(
      overrides: [
        videoProcessorProvider.overrideWithValue(fakeProcessor),
        outputDirectoryProvider.overrideWith(_FakeOutputDirectoryNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(convertControllerProvider.notifier)
        .setVideo(testVideo);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ConvertScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Animated GIF'));
    await tester.pumpAndSettle();

    expect(find.text('GIF Settings'), findsOneWidget);
    expect(find.text('Create Animated GIF'), findsOneWidget);
  });
}
