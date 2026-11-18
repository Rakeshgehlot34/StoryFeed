import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/screenshot/domain/models/screenshot_config.dart';
import 'package:shorts_splitter/features/screenshot/domain/screenshot_compiler.dart';

import '../../utils/output_verifier.dart';

void main() {
  group('Screenshot Integration Tests with Real Fixtures', () {
    const fixtureVideo = 'test/fixtures/test_16_9.mp4';
    late Directory tempOutDir;

    setUpAll(() {
      if (!File(fixtureVideo).existsSync()) {
        fail(
          'Fixture missing: $fixtureVideo. Run scripts/make_fixtures.sh first.',
        );
      }
      tempOutDir = Directory.systemTemp.createTempSync(
        'screenshot_integration_test_',
      );
    });

    tearDownAll(() {
      if (tempOutDir.existsSync()) {
        tempOutDir.deleteSync(recursive: true);
      }
    });

    test('1. Extracts full-resolution lossless PNG frame at 1.5s', () async {
      final outputPath = '${tempOutDir.path}/frame_1500ms.png';

      final args = ScreenshotCompiler.buildCaptureArgs(
        inputPath: fixtureVideo,
        timestampSeconds: 1.5,
        outputPath: outputPath,
        format: ScreenshotImageFormat.png,
      );

      final result = await Process.run('ffmpeg', args);
      expect(
        result.exitCode,
        0,
        reason: 'FFmpeg command failed: ${result.stderr}',
      );

      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.lengthSync(), greaterThan(10000));

      final probe = await OutputVerifier.probe(outputPath);
      expect(probe.width, 1920);
      expect(probe.height, 1080);
      expect(probe.videoCodec, 'png');
    });

    test(
      '2. Extracts high-quality JPEG frame at 3.0s with quality setting',
      () async {
        final outputPath = '${tempOutDir.path}/frame_3000ms.jpg';

        final args = ScreenshotCompiler.buildCaptureArgs(
          inputPath: fixtureVideo,
          timestampSeconds: 3.0,
          outputPath: outputPath,
          format: ScreenshotImageFormat.jpeg,
          jpegQuality: 85,
        );

        final result = await Process.run('ffmpeg', args);
        expect(
          result.exitCode,
          0,
          reason: 'FFmpeg command failed: ${result.stderr}',
        );

        final outputFile = File(outputPath);
        expect(outputFile.existsSync(), isTrue);
        expect(outputFile.lengthSync(), greaterThan(5000));

        final probe = await OutputVerifier.probe(outputPath);
        expect(probe.width, 1920);
        expect(probe.height, 1080);
        expect(probe.videoCodec, 'mjpeg');
      },
    );

    test('3. Batch extracts 3 interval frames across video', () async {
      const config = ScreenshotConfig(
        videoPath: fixtureVideo,
        videoTitle: 'test_16_9.mp4',
        videoDurationSeconds: 10.0,
        mode: ScreenshotCaptureMode.interval,
        intervalType: IntervalType.byCount,
        frameCount: 3,
        startSeconds: 1.0,
        endSeconds: 5.0,
        format: ScreenshotImageFormat.png,
      );

      final plannedItems = config.calculatePlannedItems();
      expect(plannedItems.length, 3);

      for (final item in plannedItems) {
        final outputPath = '${tempOutDir.path}/${item.outputFileName}';
        final args = ScreenshotCompiler.buildCaptureArgs(
          inputPath: config.videoPath,
          timestampSeconds: item.timestampSeconds,
          outputPath: outputPath,
          format: config.format,
        );

        final result = await Process.run('ffmpeg', args);
        expect(result.exitCode, 0);

        final f = File(outputPath);
        expect(f.existsSync(), isTrue);
        expect(f.lengthSync(), greaterThan(5000));

        final probe = await OutputVerifier.probe(outputPath);
        expect(probe.width, 1920);
        expect(probe.height, 1080);
      }
    });
  });
}
