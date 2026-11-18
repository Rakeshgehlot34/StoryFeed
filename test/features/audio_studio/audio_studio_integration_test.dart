import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/audio_studio/domain/audio_studio_compiler.dart';
import 'package:shorts_splitter/features/audio_studio/domain/models/audio_studio_project.dart';
import 'package:shorts_splitter/features/convert/domain/models/convert_config.dart';

import '../../utils/output_verifier.dart';

void main() {
  group('Audio Studio Integration with Real Fixtures', () {
    const fixtureVideo = 'test/fixtures/test_16_9.mp4';
    const fixtureAudio = 'test/fixtures/test_audio.mp3';
    late Directory tempOutDir;

    setUpAll(() {
      if (!File(fixtureVideo).existsSync() ||
          !File(fixtureAudio).existsSync()) {
        fail('Fixtures missing. Run scripts/make_fixtures.sh first.');
      }
      tempOutDir = Directory.systemTemp.createTempSync(
        'audio_studio_integration_test_',
      );
    });

    tearDownAll(() {
      if (tempOutDir.existsSync()) {
        tempOutDir.deleteSync(recursive: true);
      }
    });

    const compiler = AudioStudioCompiler();

    test('replaces video audio with background music track', () async {
      final sourceProbe = await OutputVerifier.probe(fixtureVideo);
      expect(sourceProbe.hasVideo, isTrue);

      final config = AudioStudioConfig(
        videoPath: fixtureVideo,
        videoDurationSeconds: sourceProbe.duration,
        isOriginalMuted: true,
        musicTrack: const AudioTrack(
          type: AudioTrackType.music,
          sourcePath: fixtureAudio,
          title: 'test_audio.mp3',
          volume: 0.8,
          loop: true,
        ),
      );

      final outPath = '${tempOutDir.path}/test_replaced_audio.mp4';
      final args = compiler.compile(
        config: config,
        outputPath: outPath,
        hasSourceAudio: true,
      );

      final res = await Process.run('ffmpeg', args);
      expect(
        res.exitCode,
        0,
        reason: 'FFmpeg replace audio failed: ${res.stderr}',
      );
      expect(File(outPath).existsSync(), isTrue);

      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isTrue);
      expect(outProbe.hasAudio, isTrue);
      expect(outProbe.videoCodec, equals('h264'));
      expect(outProbe.audioCodec, equals('aac'));
      expect(outProbe.duration, closeTo(sourceProbe.duration, 0.5));
    });

    test('mixes original audio with background music and ducking', () async {
      final sourceProbe = await OutputVerifier.probe(fixtureVideo);

      final config = AudioStudioConfig(
        videoPath: fixtureVideo,
        videoDurationSeconds: sourceProbe.duration,
        originalVolume: 0.9,
        isOriginalMuted: false,
        musicTrack: const AudioTrack(
          type: AudioTrackType.music,
          sourcePath: fixtureAudio,
          title: 'test_audio.mp3',
          volume: 0.5,
          loop: true,
        ),
        enableDucking: false,
      );

      final outPath = '${tempOutDir.path}/test_mixed_audio.mp4';
      final args = compiler.compile(
        config: config,
        outputPath: outPath,
        hasSourceAudio: true,
      );

      final res = await Process.run('ffmpeg', args);
      expect(res.exitCode, 0, reason: 'FFmpeg audio mix failed: ${res.stderr}');
      expect(File(outPath).existsSync(), isTrue);

      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isTrue);
      expect(outProbe.hasAudio, isTrue);
      expect(outProbe.audioCodec, equals('aac'));
      expect(outProbe.duration, closeTo(sourceProbe.duration, 0.5));
    });

    test('extracts mixed multi-track audio to standalone MP3', () async {
      final sourceProbe = await OutputVerifier.probe(fixtureVideo);

      final config = AudioStudioConfig(
        videoPath: fixtureVideo,
        videoDurationSeconds: sourceProbe.duration,
        originalVolume: 0.5,
        exportMode: AudioStudioExportMode.extractedAudio,
        audioFormat: AudioOutputFormat.mp3,
        musicTrack: const AudioTrack(
          type: AudioTrackType.music,
          sourcePath: fixtureAudio,
          title: 'test_audio.mp3',
          volume: 0.7,
        ),
      );

      final outPath = '${tempOutDir.path}/test_extracted_mix.mp3';
      final args = compiler.compile(
        config: config,
        outputPath: outPath,
        hasSourceAudio: true,
      );

      final res = await Process.run('ffmpeg', args);
      expect(
        res.exitCode,
        0,
        reason: 'FFmpeg audio extract failed: ${res.stderr}',
      );
      expect(File(outPath).existsSync(), isTrue);

      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isFalse);
      expect(outProbe.hasAudio, isTrue);
      expect(outProbe.audioCodec, equals('mp3'));
      expect(outProbe.duration, closeTo(sourceProbe.duration, 0.5));
    });
  });
}
