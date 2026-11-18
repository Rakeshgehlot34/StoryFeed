import 'models/screenshot_config.dart';

/// Pure Dart FFmpeg argument compiler for extracting video frames with frame-level accuracy.
class ScreenshotCompiler {
  /// Compiles FFmpeg arguments for extracting a single frame at [timestampSeconds].
  static List<String> buildCaptureArgs({
    required String inputPath,
    required double timestampSeconds,
    required String outputPath,
    required ScreenshotImageFormat format,
    int jpegQuality = 90,
  }) {
    final clampedTimestamp = timestampSeconds >= 0 ? timestampSeconds : 0.0;
    final timeStr = clampedTimestamp.toStringAsFixed(3);

    return [
      '-ss',
      timeStr,
      '-i',
      inputPath,
      '-frames:v',
      '1',
      if (format == ScreenshotImageFormat.jpeg) ...[
        '-q:v',
        _mapJpegQualityToScale(jpegQuality).toString(),
      ],
      '-update',
      '1',
      '-y',
      outputPath,
    ];
  }

  /// Maps a user percentage quality (50..100) to FFmpeg's `-q:v` mjpeg scale (10..2).
  /// In FFmpeg mjpeg, lower scale values indicate higher visual quality.
  static int _mapJpegQualityToScale(int qualityPercent) {
    final clamped = qualityPercent.clamp(50, 100);
    // 100% -> 2, 50% -> 10
    final q = 2 + ((100 - clamped) * 8 / 50.0).round();
    return q.clamp(2, 31);
  }

  /// Formats a timestamp into `mm:ss.mmm` for UI display.
  static String formatTimestamp(double seconds) {
    final totalMs = (seconds * 1000).round();
    final minutes = totalMs ~/ 60000;
    final secs = (totalMs % 60000) ~/ 1000;
    final ms = totalMs % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  /// Formats a timestamp into a file-safe slug e.g. `01m20s500ms`.
  static String formatTimestampSlug(double seconds) {
    final totalMs = (seconds * 1000).round();
    final minutes = totalMs ~/ 60000;
    final secs = (totalMs % 60000) ~/ 1000;
    final ms = totalMs % 1000;
    return '${minutes.toString().padLeft(2, '0')}m${secs.toString().padLeft(2, '0')}s${ms.toString().padLeft(3, '0')}ms';
  }
}
