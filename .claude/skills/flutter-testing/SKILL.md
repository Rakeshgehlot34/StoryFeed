---
name: flutter-testing
description: Comprehensive testing guide for unit tests, Riverpod provider overrides, widget testing, fake VideoProcessor implementation, and mocking SharedPreferences/FilePicker.
---

# Testing Guide for ShortsSplitter

This skill provides patterns for writing reliable tests for `ShortsSplitter`.

---

## 1. Fake VideoProcessor Pattern

Because FFmpeg native binaries cannot run inside headless Dart test runners, we test video processing logic using a `FakeVideoProcessor`.

```dart
import 'dart:async';
import 'package:shorts_splitter/features/processing/domain/models/processing_progress.dart';
import 'package:shorts_splitter/features/processing/domain/models/video_metadata.dart';
import 'package:shorts_splitter/features/processing/domain/video_processor.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';
import 'package:shorts_splitter/features/split_config/domain/models/split_config.dart';

class FakeVideoProcessor implements VideoProcessor {
  bool isCancelled = false;

  @override
  Future<VideoMetadata> getMetadata(String videoPath) async {
    return const VideoMetadata(
      duration: Duration(minutes: 2),
      sizeInBytes: 25 * 1024 * 1024,
      width: 1920,
      height: 1080,
      fps: 30.0,
      format: 'mp4',
    );
  }

  @override
  Stream<ProcessingProgress> splitVideo({
    required String inputPath,
    required List<ClipSegment> segments,
    required String outputDirectoryPath,
    required SplitMode mode,
    required AspectRatioOption aspectRatio,
    required String baseName,
  }) async* {
    for (int i = 0; i < segments.length; i++) {
      if (isCancelled) {
        yield ProcessingProgress(
          status: ProcessingStatus.cancelled,
          currentClipIndex: i + 1,
          totalClips: segments.length,
        );
        return;
      }
      yield ProcessingProgress(
        status: ProcessingStatus.processing,
        currentClipIndex: i + 1,
        totalClips: segments.length,
        currentClipProgress: 1.0,
        overallProgress: (i + 1) / segments.length,
        currentClipName: segments[i].formattedName,
        outputPaths: [for (int j = 0; j <= i; j++) '$outputDirectoryPath/${segments[j].formattedName}'],
      );
    }
    yield ProcessingProgress(
      status: ProcessingStatus.completed,
      currentClipIndex: segments.length,
      totalClips: segments.length,
      currentClipProgress: 1.0,
      overallProgress: 1.0,
      currentClipName: 'Completed',
    );
  }

  @override
  Future<void> cancel() async {
    isCancelled = true;
  }

  @override
  Future<void> dispose() async {}
}
```

---

## 2. Mocking SharedPreferences in Tests

Before pumping any widget or reading providers that access `SharedPreferences`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'pref_output_directory': '/mock/storage/ShortsSplitter',
      'pref_target_duration': 60,
    });
  });
}
```

---

## 3. Riverpod Provider Container Testing

Test controllers directly without building the full UI widget tree:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/processing/presentation/controllers/processing_controller.dart';
import 'package:shorts_splitter/features/split_config/domain/models/split_config.dart';
import 'package:shorts_splitter/features/split_config/presentation/controllers/split_config_controller.dart';

void main() {
  test('SplitConfigController updates mode and forces precise on vertical crop', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        videoProcessorProvider.overrideWithValue(FakeVideoProcessor()),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(splitConfigControllerProvider.notifier);

    // Initial default is fast mode
    expect(container.read(splitConfigControllerProvider).mode, SplitMode.fast);

    // Selecting vertical crop automatically promotes mode to precise
    controller.setAspectRatio(AspectRatioOption.cropVertical);

    expect(container.read(splitConfigControllerProvider).mode, SplitMode.precise);
    expect(container.read(splitConfigControllerProvider).aspectRatio, AspectRatioOption.cropVertical);
  });
}
```

---

## 4. Widget Testing with Overrides

```dart
testWidgets('Renders HomeScreen and triggers gallery pick', (tester) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoProcessorProvider.overrideWithValue(FakeVideoProcessor()),
      ],
      child: const ShortsSplitterApp(),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('ShortsSplitter'), findsOneWidget);
  expect(find.text('Pick from Gallery'), findsOneWidget);
});
```

