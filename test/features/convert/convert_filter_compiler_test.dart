import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/convert/domain/convert_filter_compiler.dart';
import 'package:shorts_splitter/features/convert/domain/models/convert_config.dart';

void main() {
  group('ConvertFilterCompiler tests', () {
    const compiler = ConvertFilterCompiler();

    test(
      'compiles MP4 H.264 command with CRF balanced quality and faststart',
      () {
        const config = ConvertConfig(
          format: ConvertOutputFormat.mp4H264,
          resolution: ResolutionPreset.original,
          fps: FpsPreset.original,
          quality: QualityPreset.balanced,
        );

        final args = compiler.compile(
          inputPath: '/input.mp4',
          outputPath: '/output.mp4',
          config: config,
          durationSeconds: 30.0,
        );

        expect(args, contains('-c:v'));
        expect(args, contains('libx264'));
        expect(args, contains('-crf'));
        expect(args, contains('23'));
        expect(args, contains('-c:a'));
        expect(args, contains('aac'));
        expect(args, contains('-movflags'));
        expect(args, contains('+faststart'));
        expect(args.last, '/output.mp4');
      },
    );

    test('compiles MP4 H.265 command with hvc1 tag', () {
      const config = ConvertConfig(
        format: ConvertOutputFormat.mp4H265,
        quality: QualityPreset.high,
      );

      final args = compiler.compile(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        config: config,
        durationSeconds: 15.0,
      );

      expect(args, contains('libx265'));
      expect(args, contains('-tag:v'));
      expect(args, contains('hvc1'));
      expect(args, contains('-crf'));
      expect(args, contains('22'));
    });

    test('compiles WebM VP9 with Opus audio', () {
      const config = ConvertConfig(
        format: ConvertOutputFormat.webm,
        quality: QualityPreset.balanced,
      );

      final args = compiler.compile(
        inputPath: '/input.mp4',
        outputPath: '/output.webm',
        config: config,
        durationSeconds: 20.0,
      );

      expect(args, contains('libvpx-vp9'));
      expect(args, contains('-crf'));
      expect(args, contains('31'));
      expect(args, contains('-c:a'));
      expect(args, contains('libopus'));
    });

    test('compiles downscaling filter when resolution preset is chosen', () {
      const config = ConvertConfig(
        format: ConvertOutputFormat.mp4H264,
        resolution: ResolutionPreset.res720p,
        fps: FpsPreset.fps30,
      );

      final args = compiler.compile(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        config: config,
        durationSeconds: 10.0,
      );

      expect(args, contains('-vf'));
      final vfIndex = args.indexOf('-vf');
      final vfVal = args[vfIndex + 1];
      expect(vfVal, contains('scale='));
      expect(vfVal, contains('1280'));
      expect(vfVal, contains('fps=30'));
    });

    test('compiles target size mode with calculated video bitrate', () {
      const config = ConvertConfig(
        format: ConvertOutputFormat.mp4H264,
        targetSizeMb: 16.0,
        audioBitrateKbps: 192,
      );

      final args = compiler.compile(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        config: config,
        durationSeconds: 60.0,
      );

      expect(args, contains('-b:v'));
      expect(args, isNot(contains('-crf')));
      final bvIndex = args.indexOf('-b:v');
      final bitrate = int.parse(args[bvIndex + 1]);
      // 16MB in 60s is approx ~2.1 Mbps video bitrate
      expect(bitrate, greaterThan(1500000));
      expect(bitrate, lessThan(3000000));
    });

    test('compiles animated GIF with 2-pass palettegen and paletteuse', () {
      const config = ConvertConfig(
        format: ConvertOutputFormat.gif,
        gifConfig: GifConfig(fps: 15, maxWidth: 480),
      );

      final args = compiler.compile(
        inputPath: '/input.mp4',
        outputPath: '/output.gif',
        config: config,
        durationSeconds: 5.0,
      );

      expect(args, contains('-filter_complex'));
      final fcIndex = args.indexOf('-filter_complex');
      final filterVal = args[fcIndex + 1];
      expect(filterVal, contains('fps=15'));
      expect(filterVal, contains('palettegen'));
      expect(filterVal, contains('paletteuse'));
      expect(args, contains('-an'));
      expect(args.last, '/output.gif');
    });

    test('compiles audio extraction for MP3, WAV, AAC, and Opus', () {
      for (final fmt in AudioOutputFormat.values) {
        final config = ConvertConfig(
          format: ConvertOutputFormat.audioOnly,
          audioFormat: fmt,
          audioBitrateKbps: 192,
        );

        final args = compiler.compile(
          inputPath: '/input.mp4',
          outputPath: '/output${fmt.fileExtension}',
          config: config,
          durationSeconds: 10.0,
        );

        expect(args, contains('-vn'));
        expect(args, contains('-c:a'));
        expect(args, contains(fmt.codec));
        if (fmt != AudioOutputFormat.wav) {
          expect(args, contains('-b:a'));
          expect(args, contains('192k'));
        }
      }
    });

    test('mutes audio when muteAudio is true', () {
      const config = ConvertConfig(
        format: ConvertOutputFormat.mp4H264,
        muteAudio: true,
      );

      final args = compiler.compile(
        inputPath: '/input.mp4',
        outputPath: '/output.mp4',
        config: config,
        durationSeconds: 10.0,
      );

      expect(args, contains('-an'));
      expect(args, isNot(contains('-c:a')));
    });
  });
}
