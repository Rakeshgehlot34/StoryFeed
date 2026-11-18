import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'output_verifier.dart';

void main() {
  group('OutputVerifier Tests with Real Fixtures', () {
    const fixtureDir = 'test/fixtures';

    setUpAll(() {
      final f169 = File('$fixtureDir/test_16_9.mp4');
      if (!f169.existsSync()) {
        fail(
          'Test fixtures not found. Please run scripts/make_fixtures.sh first.',
        );
      }
    });

    test('1. probes 16:9 test video correctly', () async {
      final probe = await OutputVerifier.probe('$fixtureDir/test_16_9.mp4');
      expect(probe.hasVideo, isTrue);
      expect(probe.hasAudio, isTrue);
      expect(probe.width, equals(1920));
      expect(probe.height, equals(1080));
      expect(probe.duration, closeTo(10.0, 0.5));
      expect(probe.fps, closeTo(30.0, 0.5));
    });

    test('2. probes 9:16 vertical video correctly', () async {
      final probe = await OutputVerifier.probe('$fixtureDir/test_9_16.mp4');
      expect(probe.hasVideo, isTrue);
      expect(probe.width, equals(1080));
      expect(probe.height, equals(1920));
      expect(probe.duration, closeTo(10.0, 0.5));
    });

    test('3. probes silent video without audio track', () async {
      final probe = await OutputVerifier.probe('$fixtureDir/test_silent.mp4');
      expect(probe.hasVideo, isTrue);
      expect(probe.hasAudio, isFalse);
      expect(probe.audioCodec, isNull);
    });

    test('4. probes rotated video flag', () async {
      final probe = await OutputVerifier.probe('$fixtureDir/test_rotated.mp4');
      expect(probe.rotation, equals(90));
    });

    test('5. probes audio-only MP3 file', () async {
      final probe = await OutputVerifier.probe('$fixtureDir/test_audio.mp3');
      expect(probe.hasVideo, isFalse);
      expect(probe.hasAudio, isTrue);
      expect(probe.audioCodec, equals('mp3'));
      expect(probe.duration, closeTo(10.0, 0.5));
    });

    test('6. extracts pixel color from video frame', () async {
      final color = await OutputVerifier.extractPixelColor(
        filePath: '$fixtureDir/test_16_9.mp4',
        timestamp: 1.0,
        x: 10,
        y: 10,
      );
      expect(color.r, inInclusiveRange(0, 255));
      expect(color.g, inInclusiveRange(0, 255));
      expect(color.b, inInclusiveRange(0, 255));
    });
  });
}
