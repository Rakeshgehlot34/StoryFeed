import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/convert/domain/models/convert_config.dart';

void main() {
  group('ConvertConfig domain tests', () {
    test(
      'Default config has MP4 H.264, original resolution, balanced quality',
      () {
        const config = ConvertConfig();
        expect(config.format, ConvertOutputFormat.mp4H264);
        expect(config.resolution, ResolutionPreset.original);
        expect(config.fps, FpsPreset.original);
        expect(config.quality, QualityPreset.balanced);
        expect(config.targetSizeMb, isNull);
        expect(config.muteAudio, isFalse);
        expect(config.effectiveExtension, '.mp4');
      },
    );

    test('Effective extension adapts to audio format and gif', () {
      const gifCfg = ConvertConfig(format: ConvertOutputFormat.gif);
      expect(gifCfg.effectiveExtension, '.gif');

      const mp3Cfg = ConvertConfig(
        format: ConvertOutputFormat.audioOnly,
        audioFormat: AudioOutputFormat.mp3,
      );
      expect(mp3Cfg.effectiveExtension, '.mp3');

      const wavCfg = ConvertConfig(
        format: ConvertOutputFormat.audioOnly,
        audioFormat: AudioOutputFormat.wav,
      );
      expect(wavCfg.effectiveExtension, '.wav');

      const aacCfg = ConvertConfig(
        format: ConvertOutputFormat.audioOnly,
        audioFormat: AudioOutputFormat.aac,
      );
      expect(aacCfg.effectiveExtension, '.m4a');
    });

    test('estimateOutputSizeBytes respects targetSizeMb when set', () {
      const config = ConvertConfig(targetSizeMb: 16.0);
      final estBytes = config.estimateOutputSizeBytes(
        durationSeconds: 60.0,
        sourceSizeBytes: 50 * 1024 * 1024,
        sourceWidth: 1920,
        sourceHeight: 1080,
      );
      // 16 MB = 16 * 1024 * 1024 = 16,777,216 bytes
      expect(estBytes, 16 * 1024 * 1024);
    });

    test(
      'estimateOutputSizeBytes calculates audio extraction size correctly',
      () {
        const mp3Cfg = ConvertConfig(
          format: ConvertOutputFormat.audioOnly,
          audioFormat: AudioOutputFormat.mp3,
          audioBitrateKbps: 192,
        );

        // 60 seconds at 192 kbps = 60 * 192000 / 8 = 1,440,000 bytes
        final estBytes = mp3Cfg.estimateOutputSizeBytes(
          durationSeconds: 60.0,
          sourceSizeBytes: 20 * 1024 * 1024,
          sourceWidth: 1920,
          sourceHeight: 1080,
        );
        expect(estBytes, 1440000);
      },
    );

    test(
      'estimateOutputSizeBytes for animated GIF scales with fps and width',
      () {
        const gif15 = ConvertConfig(
          format: ConvertOutputFormat.gif,
          gifConfig: GifConfig(fps: 15, maxWidth: 480),
        );
        final est15 = gif15.estimateOutputSizeBytes(
          durationSeconds: 10.0,
          sourceSizeBytes: 10 * 1024 * 1024,
          sourceWidth: 1920,
          sourceHeight: 1080,
        );

        const gif30 = ConvertConfig(
          format: ConvertOutputFormat.gif,
          gifConfig: GifConfig(fps: 30, maxWidth: 480),
        );
        final est30 = gif30.estimateOutputSizeBytes(
          durationSeconds: 10.0,
          sourceSizeBytes: 10 * 1024 * 1024,
          sourceWidth: 1920,
          sourceHeight: 1080,
        );

        expect(est30, greaterThan(est15));
      },
    );

    test('JSON serialization roundtrip preserves all properties', () {
      const original = ConvertConfig(
        format: ConvertOutputFormat.webm,
        resolution: ResolutionPreset.res720p,
        fps: FpsPreset.fps30,
        quality: QualityPreset.small,
        targetSizeMb: 25.0,
        muteAudio: true,
        audioFormat: AudioOutputFormat.opus,
        audioBitrateKbps: 128,
        gifConfig: GifConfig(fps: 20, maxWidth: 320, dither: 'sierra2_4a'),
        customFileName: 'my_video',
      );

      final json = original.toJson();
      final restored = ConvertConfig.fromJson(json);

      expect(restored.format, ConvertOutputFormat.webm);
      expect(restored.resolution, ResolutionPreset.res720p);
      expect(restored.fps, FpsPreset.fps30);
      expect(restored.quality, QualityPreset.small);
      expect(restored.targetSizeMb, 25.0);
      expect(restored.muteAudio, isTrue);
      expect(restored.audioFormat, AudioOutputFormat.opus);
      expect(restored.audioBitrateKbps, 128);
      expect(restored.gifConfig.fps, 20);
      expect(restored.gifConfig.maxWidth, 320);
      expect(restored.gifConfig.dither, 'sierra2_4a');
      expect(restored.customFileName, 'my_video');
    });
  });
}
