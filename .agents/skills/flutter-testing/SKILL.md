---
name: flutter-testing
description: Testing patterns for unit, widget, and Riverpod provider tests, including FakeVideoProcessor, SharedPreferences mocking, and file picker doubles.
---

# Flutter Testing Strategies for ShortsSplitter

## Trigger Conditions
Use this skill when:
- Writing new unit tests for domain entities, algorithms, or repositories.
- Writing widget tests for screens or controllers.
- Mocking external dependencies (`SharedPreferences`, platform channels, `VideoProcessor`).

---

## 1. Fake VideoProcessor Double
Never use the real `FFmpegVideoProcessor` in test environments. Use `FakeVideoProcessor`:

```dart
// test/fakes/fake_video_processor.dart
import 'dart:async';
import 'package:shorts_splitter/core/result.dart';
import 'package:shorts_splitter/core/errors/app_exception.dart';
import 'package:shorts_splitter/features/processing/domain/video_processor.dart';
import 'package:shorts_splitter/features/split_config/domain/clip_segment.dart';
import 'package:shorts_splitter/features/split_config/presentation/providers/split_config_controller.dart';

class FakeVideoProcessor implements VideoProcessor {
  bool shouldFail = false;
  final _progressController = StreamController<SplitProgress>.broadcast();

  @override
  Stream<SplitProgress> get progressStream => _progressController.stream;

  @override
  Future<Result<VideoMetadata, AppException>> probeVideo(String filePath) async {
    if (shouldFail) {
      return Result.failure(const AppException.format('Fake probe error'));
    }
    return Result.success(
      const VideoMetadata(
        durationSeconds: 180,
        width: 1920,
        height: 1080,
        bitrate: 5000000,
        formatName: 'mp4',
      ),
    );
  }

  @override
  Future<Result<List<String>, AppException>> splitVideo({
    required String inputPath,
    required List<ClipSegment> segments,
    required String outputDirectory,
    required ProcessingMode mode,
    required AspectRatioOption aspectRatio,
  }) async {
    if (shouldFail) {
      return Result.failure(const AppException.processing('Fake split failure'));
    }

    final outputs = <String>[];
    for (var i = 0; i < segments.length; i++) {
      _progressController.add(
        SplitProgress(
          currentClip: i + 1,
          totalClips: segments.length,
          clipProgress: 1.0,
          overallProgress: (i + 1) / segments.length,
        ),
      );
      outputs.add('$outputDirectory/${segments[i].fileName}');
    }
    return Result.success(outputs);
  }

  @override
  Future<void> cancel() async {
    // No-op for fake
  }

  @override
  void dispose() {
    _progressController.close();
  }
}
```

---

## 2. SharedPreferences & Storage Mocking
Isolate tests from the platform plugin:

```dart
setUp(() {
  SharedPreferences.setMockInitialValues({
    AppConstants.prefsOutputDirKey: '/mock/output/dir',
  });
});
```

---

## 3. Riverpod Provider Container Testing
Test business controllers without inflating Flutter widgets:

```dart
test('SplitConfigController updates clip duration and recalculates segments', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  final notifier = container.read(splitConfigProvider.notifier);
  notifier.setDuration(45);

  final state = container.read(splitConfigProvider);
  expect(state.clipDurationSeconds, 45);
});
```

---

## 4. Full Widget Test Pattern
Test UI interaction and state updates:

```dart
testWidgets('HomeScreen displays app bar and video picker button', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: HomeScreen(),
      ),
    ),
  );

  expect(find.text('ShortsSplitter'), findsOneWidget);
  expect(find.text('Select Video'), findsOneWidget);
});
```

