import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/convert/domain/convert_filter_compiler.dart';
import 'package:shorts_splitter/features/convert/domain/models/convert_config.dart';

import '../../utils/output_verifier.dart';

void main() {
  group('Convert & Compression Integration with Real Fixtures', () {
    const fixtureVideo = 'test/fixtures/test_16_9.mp4';
    late Directory tempOutDir;

    setUpAll(() {
      if (!File(fixtureVideo).existsSync()) {
        fail('Fixtures missing. Run scripts/make_fixtures.sh first.');
      }
      tempOutDir = Directory.systemTemp.createTempSync(
        'convert_integration_test_',
      );
    });

    tearDownAll(() {
      if (tempOutDir.existsSync()) {
        tempOutDir.deleteSync(recursive: true);
      }
    });

    const compiler = ConvertFilterCompiler();

    test('converts video to MP4 H.264 with 720p downscaling and compressed bitrate', () async {
      final sourceProbe = await OutputVerifier.probe(fixtureVideo);
      expect(sourceProbe.hasVideo, isTrue);

      const config = ConvertConfig(
        format: ConvertOutputFormat.mp4H264,
        resolution: ResolutionPreset.res720p,
        quality: QualityPreset.small,
      );

      final outPath = '${tempOutDir.path}/test_720p.mp4';
      final args = compiler.compile(
        inputPath: fixtureVideo,
        outputPath: outPath,
        config: config,
        durationSeconds: sourceProbe.duration,
      );

      final res = await Process.run('ffmpeg', args);
      expect(
        res.exitCode,
        0,
        reason: 'FFmpeg convert to MP4 failed: ${res.stderr}',
      );
      expect(File(outPath).existsSync(), isTrue);

      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isTrue);
      expect(outProbe.hasAudio, isTrue);
      expect(outProbe.width, equals(1280));
      expect(outProbe.height, equals(720));
      expect(outProbe.videoCodec, equals('h264'));
      expect(outProbe.audioCodec, equals('aac'));
      expect(outProbe.duration, closeTo(sourceProbe.duration, 0.5));
    });

    test('converts video to Animated GIF with 2-pass palettegen', () async {
      final sourceProbe = await OutputVerifier.probe(fixtureVideo);

      const config = ConvertConfig(
        format: ConvertOutputFormat.gif,
        gifConfig: GifConfig(fps: 15, maxWidth: 480),
      );

      final outPath = '${tempOutDir.path}/test_animated.gif';
      final args = compiler.compile(
        inputPath: fixtureVideo,
        outputPath: outPath,
        config: config,
        durationSeconds: sourceProbe.duration,
      );

      final res = await Process.run('ffmpeg', args);
      expect(
        res.exitCode,
        0,
        reason: 'FFmpeg convert to GIF failed: ${res.stderr}',
      );
      expect(File(outPath).existsSync(), isTrue);

      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isTrue);
      expect(outProbe.hasAudio, isFalse);
      expect(outProbe.videoCodec, equals('gif'));
      expect(outProbe.width, equals(480));
      expect(outProbe.height, equals(270)); // 16:9 of 480 = 270
    });

    test('extracts audio track directly to MP3', () async {
      final sourceProbe = await OutputVerifier.probe(fixtureVideo);

      const config = ConvertConfig(
        format: ConvertOutputFormat.audioOnly,
        audioFormat: AudioOutputFormat.mp3,
        audioBitrateKbps: 192,
      );

      final outPath = '${tempOutDir.path}/extracted_audio.mp3';
      final args = compiler.compile(
        inputPath: fixtureVideo,
        outputPath: outPath,
        config: config,
        durationSeconds: sourceProbe.duration,
      );

      final res = await Process.run('ffmpeg', args);
      expect(
        res.exitCode,
        0,
        reason: 'FFmpeg audio extraction failed: ${res.stderr}',
      );
      expect(File(outPath).existsSync(), isTrue);

      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isFalse);
      expect(outProbe.hasAudio, isTrue);
      expect(outProbe.audioCodec, equals('mp3'));
      expect(outProbe.duration, closeTo(sourceProbe.duration, 0.6));
    });
  });
}
