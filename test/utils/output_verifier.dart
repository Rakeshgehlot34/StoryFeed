import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Parsed metadata from `ffprobe` JSON stream inspection.
class ProbeResult {
  final double duration;
  final int sizeBytes;
  final bool hasVideo;
  final bool hasAudio;
  final int? width;
  final int? height;
  final String? videoCodec;
  final double? fps;
  final int? rotation;
  final String? audioCodec;
  final int? sampleRate;
  final int? channels;

  const ProbeResult({
    required this.duration,
    required this.sizeBytes,
    required this.hasVideo,
    required this.hasAudio,
    this.width,
    this.height,
    this.videoCodec,
    this.fps,
    this.rotation,
    this.audioCodec,
    this.sampleRate,
    this.channels,
  });

  double get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : 0.0;
}

/// Simple RGB pixel representation for video frame inspection.
class PixelColor {
  final int r;
  final int g;
  final int b;

  const PixelColor(this.r, this.g, this.b);

  @override
  String toString() => 'PixelColor(R: $r, G: $g, B: $b)';

  bool isNear(PixelColor other, {int tolerance = 15}) {
    return (r - other.r).abs() <= tolerance &&
        (g - other.g).abs() <= tolerance &&
        (b - other.b).abs() <= tolerance;
  }
}

/// Headless verification utility executing system `ffprobe` and `ffmpeg`
/// to deterministically validate media output properties and frame pixels in tests.
class OutputVerifier {
  OutputVerifier._();

  /// Inspects media stream properties using `ffprobe`.
  static Future<ProbeResult> probe(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('Target media file does not exist', filePath);
    }

    final result = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_entries',
      'format=duration,size:stream=index,codec_name,codec_type,width,height,r_frame_rate,sample_rate,channels:stream_tags:stream_side_data',
      '-of',
      'json',
      filePath,
    ]);

    if (result.exitCode != 0) {
      throw ProcessException(
        'ffprobe',
        ['-v', 'error', filePath],
        result.stderr.toString(),
        result.exitCode,
      );
    }

    final data = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final format = data['format'] as Map<String, dynamic>? ?? {};
    final streams =
        (data['streams'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    final duration =
        double.tryParse(format['duration']?.toString() ?? '0') ?? 0.0;
    final sizeBytes = int.tryParse(format['size']?.toString() ?? '0') ?? 0;

    Map<String, dynamic>? videoStream;
    Map<String, dynamic>? audioStream;

    for (final s in streams) {
      if (s['codec_type'] == 'video' && videoStream == null) {
        videoStream = s;
      } else if (s['codec_type'] == 'audio' && audioStream == null) {
        audioStream = s;
      }
    }

    int? width;
    int? height;
    String? videoCodec;
    double? fps;
    int? rotation;

    if (videoStream != null) {
      width = videoStream['width'] as int?;
      height = videoStream['height'] as int?;
      videoCodec = videoStream['codec_name'] as String?;

      final fpsStr = videoStream['r_frame_rate'] as String?;
      if (fpsStr != null && fpsStr.contains('/')) {
        final parts = fpsStr.split('/');
        final num = double.tryParse(parts[0]);
        final den = double.tryParse(parts[1]);
        if (num != null && den != null && den > 0) {
          fps = num / den;
        }
      }

      final tags = videoStream['tags'] as Map<String, dynamic>?;
      if (tags != null) {
        final rotVal = tags['rotate'] ?? tags['ROTATE'] ?? tags['rotation'];
        if (rotVal != null) {
          rotation = int.tryParse(rotVal.toString());
        }
      }

      final sideData = videoStream['side_data_list'] as List<dynamic>?;
      if (sideData != null && sideData.isNotEmpty) {
        for (final sd in sideData) {
          if (sd is Map<String, dynamic> && sd['rotation'] != null) {
            rotation = (double.tryParse(sd['rotation'].toString()) ?? 0)
                .toInt();
          }
        }
      }
    }

    String? audioCodec;
    int? sampleRate;
    int? channels;

    if (audioStream != null) {
      audioCodec = audioStream['codec_name'] as String?;
      sampleRate = int.tryParse(audioStream['sample_rate']?.toString() ?? '');
      channels = audioStream['channels'] as int?;
    }

    return ProbeResult(
      duration: duration,
      sizeBytes: sizeBytes,
      hasVideo: videoStream != null,
      hasAudio: audioStream != null,
      width: width,
      height: height,
      videoCodec: videoCodec,
      fps: fps,
      rotation: rotation,
      audioCodec: audioCodec,
      sampleRate: sampleRate,
      channels: channels,
    );
  }

  /// Extracts the exact RGB color of a pixel at ([x], [y]) at the given [timestamp].
  static Future<PixelColor> extractPixelColor({
    required String filePath,
    double timestamp = 0.0,
    required int x,
    required int y,
  }) async {
    final result = await Process.run('ffmpeg', [
      '-ss',
      timestamp.toStringAsFixed(3),
      '-i',
      filePath,
      '-vframes',
      '1',
      '-vf',
      'crop=2:2:$x:$y',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgb24',
      '-',
    ], stdoutEncoding: null);

    if (result.exitCode != 0) {
      throw ProcessException(
        'ffmpeg',
        ['crop pixel'],
        'Failed to extract pixel: ${result.stderr}',
        result.exitCode,
      );
    }

    final bytes = result.stdout as List<int>;
    if (bytes.length < 3) {
      throw StateError(
        'FFmpeg returned insufficient raw RGB bytes: ${bytes.length}',
      );
    }

    return PixelColor(bytes[0], bytes[1], bytes[2]);
  }

  /// Asserts that the media file has the expected resolution.
  static Future<void> assertResolution(
    String filePath,
    int expectedWidth,
    int expectedHeight,
  ) async {
    final probeResult = await probe(filePath);
    expect(
      probeResult.width,
      equals(expectedWidth),
      reason: 'Video width mismatch',
    );
    expect(
      probeResult.height,
      equals(expectedHeight),
      reason: 'Video height mismatch',
    );
  }

  /// Asserts that the media file duration matches within [toleranceSeconds].
  static Future<void> assertDuration(
    String filePath,
    double expectedDuration, {
    double toleranceSeconds = 0.5,
  }) async {
    final probeResult = await probe(filePath);
    expect(
      (probeResult.duration - expectedDuration).abs(),
      lessThanOrEqualTo(toleranceSeconds),
      reason:
          'Expected duration ~$expectedDuration s, but got ${probeResult.duration} s',
    );
  }

  /// Asserts that the media file has (or lacks) an audio track.
  static Future<void> assertHasAudio(String filePath, bool expected) async {
    final probeResult = await probe(filePath);
    expect(
      probeResult.hasAudio,
      equals(expected),
      reason: 'Audio track presence mismatch',
    );
  }
}
