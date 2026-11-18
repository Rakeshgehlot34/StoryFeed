import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/app/router.dart';
import 'package:shorts_splitter/features/create/presentation/screens/trim_screen.dart';
import 'package:shorts_splitter/features/player/data/player_service.dart';
import 'package:shorts_splitter/features/split_config/domain/models/split_config.dart';
import 'package:shorts_splitter/features/split_config/presentation/controllers/split_config_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';
import 'package:shorts_splitter/features/video_picker/presentation/controllers/video_picker_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerService.resetInstance();
  });

  tearDown(() {
    PlayerService.instance.stopAndRelease();
  });

  Widget createTestWidget({PickedVideo? video, SplitConfig? config}) {
    return ProviderScope(
      overrides: [
        if (video != null)
          videoPickerControllerProvider.overrideWith(
            () => _FakeVideoPickerNotifier(video),
          ),
        if (config != null)
          splitConfigControllerProvider.overrideWith(
            () => _FakeSplitConfigNotifier(config),
          ),
      ],
      child: MaterialApp(
        navigatorObservers: [appRouteObserver],
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: TrimScreen(),
        ),
      ),
    );
  }

  group('TrimScreen UI tests', () {
    testWidgets(
      'Renders timeline, trim badges, nudge controls, and next button',
      (tester) async {
        const fakeVideo = PickedVideo(
          path: '/test/video.mp4',
          fileName: 'video.mp4',
          baseName: 'video',
          sizeInBytes: 1024 * 1024,
          duration: Duration(seconds: 120),
          width: 1920,
          height: 1080,
        );

        await tester.pumpWidget(createTestWidget(video: fakeVideo));
        await tester.pumpAndSettle();

        expect(find.text('Timeline & Range'), findsOneWidget);
        expect(find.text('Trim Positions'), findsOneWidget);
        expect(find.text('Fine Nudge Controls'), findsOneWidget);
        expect(find.text('START'), findsOneWidget);
        expect(find.text('END'), findsOneWidget);
        expect(find.text('Set Start Here'), findsOneWidget);
        expect(find.text('Set End Here'), findsOneWidget);
        expect(find.text('Reset to Full'), findsOneWidget);
        expect(find.text('Next: Split Settings'), findsOneWidget);
      },
    );

    testWidgets('Tapping Reset to Full resets start to 0.000s', (tester) async {
      const fakeVideo = PickedVideo(
        path: '/test/video.mp4',
        fileName: 'video.mp4',
        baseName: 'video',
        sizeInBytes: 1024 * 1024,
        duration: Duration(seconds: 90),
        width: 1920,
        height: 1080,
      );

      await tester.pumpWidget(createTestWidget(video: fakeVideo));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset to Full'));
      await tester.pumpAndSettle();

      expect(find.text('00:00.000'), findsAtLeastNWidgets(1));
    });
  });
}

class _FakeVideoPickerNotifier extends VideoPickerController {
  final PickedVideo? _video;
  _FakeVideoPickerNotifier(this._video);

  @override
  Future<PickedVideo?> build() async => _video;
}

class _FakeSplitConfigNotifier extends SplitConfigController {
  final SplitConfig _initial;
  _FakeSplitConfigNotifier(this._initial);

  @override
  SplitConfig build() => _initial;
}
