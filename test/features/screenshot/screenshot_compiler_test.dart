import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/screenshot/domain/models/screenshot_config.dart';
import 'package:shorts_splitter/features/screenshot/domain/screenshot_compiler.dart';

void main() {
  group('ScreenshotCompiler Tests', () {
    test('1. Compiles single frame capture arguments for PNG', () {
      final args = ScreenshotCompiler.buildCaptureArgs(
        inputPath: '/storage/video.mp4',
        timestampSeconds: 12.345,
        outputPath: '/cache/frame_1.png',
        format: ScreenshotImageFormat.png,
      );

      expect(args, [
        '-ss',
        '12.345',
        '-i',
        '/storage/video.mp4',
        '-frames:v',
        '1',
        '-update',
        '1',
        '-y',
        '/cache/frame_1.png',
      ]);
    });

    test(
      '2. Compiles single frame capture arguments for JPEG with quality scale',
      () {
        final args100 = ScreenshotCompiler.buildCaptureArgs(
          inputPath: '/storage/video.mp4',
          timestampSeconds: 5.0,
          outputPath: '/cache/frame_100.jpg',
          format: ScreenshotImageFormat.jpeg,
          jpegQuality: 100,
        );

        // 100% quality maps to FFmpeg -q:v 2
        expect(args100.contains('-q:v'), isTrue);
        final qIndex100 = args100.indexOf('-q:v');
        expect(args100[qIndex100 + 1], '2');

        final args50 = ScreenshotCompiler.buildCaptureArgs(
          inputPath: '/storage/video.mp4',
          timestampSeconds: 5.0,
          outputPath: '/cache/frame_50.jpg',
          format: ScreenshotImageFormat.jpeg,
          jpegQuality: 50,
        );

        // 50% quality maps to FFmpeg -q:v 10
        expect(args50.contains('-q:v'), isTrue);
        final qIndex50 = args50.indexOf('-q:v');
        expect(args50[qIndex50 + 1], '10');
      },
    );

    test('3. Clamps negative timestamps to 0.000', () {
      final args = ScreenshotCompiler.buildCaptureArgs(
        inputPath: '/storage/video.mp4',
        timestampSeconds: -5.0,
        outputPath: '/cache/frame_zero.png',
        format: ScreenshotImageFormat.png,
      );

      expect(args[0], '-ss');
      expect(args[1], '0.000');
    });

    test('4. Formats timestamps for display and filename slugs', () {
      expect(ScreenshotCompiler.formatTimestamp(65.123), '01:05.123');
      expect(ScreenshotCompiler.formatTimestamp(0.0), '00:00.000');
      expect(ScreenshotCompiler.formatTimestampSlug(65.123), '01m05s123ms');
      expect(ScreenshotCompiler.formatTimestampSlug(0.5), '00m00s500ms');
    });
  });
}
