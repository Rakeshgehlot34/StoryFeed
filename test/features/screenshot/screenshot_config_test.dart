import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/screenshot/domain/models/screenshot_config.dart';

void main() {
  group('ScreenshotConfig Tests', () {
    const baseConfig = ScreenshotConfig(
      videoPath: '/storage/sample.mp4',
      videoTitle: 'sample.mp4',
      videoDurationSeconds: 60.0,
      videoWidth: 1920,
      videoHeight: 1080,
    );

    test('1. Calculates single playhead timestamp correctly', () {
      final config = baseConfig.copyWith(
        mode: ScreenshotCaptureMode.single,
        startSeconds: 15.25,
      );

      final timestamps = config.calculatePlannedTimestamps();
      expect(timestamps, [15.25]);
    });

    test('2. Filters and sorts custom timestamps within range', () {
      final config = baseConfig.copyWith(
        mode: ScreenshotCaptureMode.timestamps,
        startSeconds: 10.0,
        endSeconds: 40.0,
        customTimestamps: [35.5, 5.0, 20.0, 50.0, 12.3],
      );

      final timestamps = config.calculatePlannedTimestamps();
      expect(timestamps, [12.3, 20.0, 35.5]);
    });

    test('3. Generates interval timestamps by duration correctly', () {
      final config = baseConfig.copyWith(
        mode: ScreenshotCaptureMode.interval,
        intervalType: IntervalType.byDuration,
        intervalSeconds: 10.0,
        startSeconds: 0.0,
        endSeconds: 30.0,
      );

      final timestamps = config.calculatePlannedTimestamps();
      expect(timestamps, [0.0, 10.0, 20.0, 30.0]);
    });

    test('4. Generates interval timestamps by frame count evenly', () {
      final config = baseConfig.copyWith(
        mode: ScreenshotCaptureMode.interval,
        intervalType: IntervalType.byCount,
        frameCount: 5,
        startSeconds: 0.0,
        endSeconds: 40.0,
      );

      final timestamps = config.calculatePlannedTimestamps();
      expect(timestamps, [0.0, 10.0, 20.0, 30.0, 40.0]);
    });

    test(
      '5. Builds planned items with zero-padded names and formatted time',
      () {
        final config = baseConfig.copyWith(
          mode: ScreenshotCaptureMode.interval,
          intervalType: IntervalType.byDuration,
          intervalSeconds: 20.0,
          startSeconds: 0.0,
          endSeconds: 40.0,
          format: ScreenshotImageFormat.png,
          customBaseName: 'my_clip',
        );

        final items = config.calculatePlannedItems();
        expect(items.length, 3);
        expect(items[0].outputFileName, 'my_clip_frame_01_00m00s000ms.png');
        expect(items[1].outputFileName, 'my_clip_frame_02_00m20s000ms.png');
        expect(items[2].outputFileName, 'my_clip_frame_03_00m40s000ms.png');
        expect(items[1].formattedTime, '00:20.000');
      },
    );

    test('6. Estimates total byte sizes for PNG and JPEG formats', () {
      final pngConfig = baseConfig.copyWith(
        mode: ScreenshotCaptureMode.interval,
        intervalType: IntervalType.byCount,
        frameCount: 10,
        format: ScreenshotImageFormat.png,
      );

      final jpegConfig = baseConfig.copyWith(
        mode: ScreenshotCaptureMode.interval,
        intervalType: IntervalType.byCount,
        frameCount: 10,
        format: ScreenshotImageFormat.jpeg,
        jpegQuality: 90,
      );

      final pngBytes = pngConfig.estimateTotalSizeBytes();
      final jpegBytes = jpegConfig.estimateTotalSizeBytes();

      expect(pngBytes, greaterThan(0));
      expect(jpegBytes, greaterThan(0));
      // Lossless PNG should estimate larger than JPEG
      expect(pngBytes, greaterThan(jpegBytes));
    });

    test('7. Serializes to JSON and deserializes identically', () {
      final config = baseConfig.copyWith(
        format: ScreenshotImageFormat.jpeg,
        jpegQuality: 85,
        mode: ScreenshotCaptureMode.timestamps,
        customTimestamps: [1.5, 4.2],
        customBaseName: 'export_series',
      );

      final json = config.toJson();
      final restored = ScreenshotConfig.fromJson(json);

      expect(restored.videoPath, config.videoPath);
      expect(restored.format, ScreenshotImageFormat.jpeg);
      expect(restored.jpegQuality, 85);
      expect(restored.mode, ScreenshotCaptureMode.timestamps);
      expect(restored.customTimestamps, [1.5, 4.2]);
      expect(restored.customBaseName, 'export_series');
    });
  });
}
