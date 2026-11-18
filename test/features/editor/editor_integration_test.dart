import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/editor/domain/editor_filter_compiler.dart';
import 'package:shorts_splitter/features/editor/domain/models/edit_project.dart';

import '../../utils/output_verifier.dart';

void main() {
  group('Studio Editor Integration with Real Fixtures', () {
    const fixtureVideo = 'test/fixtures/test_16_9.mp4';
    const fixtureLogo = 'test/fixtures/test_logo.png';
    late Directory tempOutDir;

    setUpAll(() {
      if (!File(fixtureVideo).existsSync() || !File(fixtureLogo).existsSync()) {
        fail('Fixtures missing. Run scripts/make_fixtures.sh first.');
      }
      tempOutDir = Directory.systemTemp.createTempSync(
        'editor_integration_test_',
      );
    });

    tearDownAll(() {
      if (tempOutDir.existsSync()) {
        tempOutDir.deleteSync(recursive: true);
      }
    });

    test('compiles and executes 1-pass edit with trim, speed, canvas scaling, and watermark', () async {
      // 1. Probe input fixture
      final sourceProbe = await OutputVerifier.probe(fixtureVideo);
      expect(sourceProbe.hasVideo, isTrue);
      expect(sourceProbe.width, 1920);
      expect(sourceProbe.height, 1080);

      // 2. Configure EditProject:
      // - Trim: 1.0s to 7.0s (6.0s duration)
      // - Speed: 1.5x (output duration: 4.0s)
      // - Canvas: Vertical 9:16 (1080x1920) crop to fill
      // - Color: Vibrant preset
      // - Watermark: test_logo.png at top-right
      // - Fades: 0.5s in and out
      final project = EditProject(
        id: 'real_test_proj',
        title: 'integration_edit',
        sourceVideoPath: fixtureVideo,
        sourceVideoName: 'test_16_9.mp4',
        sourceDurationSeconds: sourceProbe.duration,
        sourceWidth: sourceProbe.width!,
        sourceHeight: sourceProbe.height!,
        trim: const TrimConfig(startSeconds: 1.0, endSeconds: 7.0),
        speed: const SpeedSpec(speed: 1.5, preservePitch: true),
        canvas: const CanvasConfig(
          aspectRatio: TargetAspectRatio.vertical916,
          fitMode: CanvasFitMode.cropToFill,
        ),
        color: const ColorFilterSpec(preset: ColorFilterPreset.vibrant),
        watermark: const WatermarkSpec(
          imagePath: fixtureLogo,
          position: OverlayPosition.topRight,
          opacity: 0.85,
          scale: 0.2,
        ),
        fade: const FadeSpec(
          fadeInSeconds: 0.5,
          fadeOutSeconds: 0.5,
          fadeAudio: true,
        ),
      );

      final outPath = '${tempOutDir.path}/integration_edit.mp4';

      // 3. Compile 1-pass FFmpeg command
      final command = EditorFilterCompiler.compileExport(
        project: project,
        resolvedInputPath: fixtureVideo,
        outputPath: outPath,
      );

      // 4. Run native FFmpeg command directly
      final res = await Process.run('ffmpeg', command.arguments);
      expect(
        res.exitCode,
        0,
        reason: 'FFmpeg 1-pass edit failed: ${res.stderr}',
      );
      expect(File(outPath).existsSync(), isTrue);

      // 5. Verify output using OutputVerifier
      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isTrue);
      expect(outProbe.hasAudio, isTrue);
      expect(outProbe.width, equals(1080));
      expect(outProbe.height, equals(1920));
      expect(outProbe.videoCodec, equals('h264'));
      expect(outProbe.audioCodec, equals('aac'));
      // 6s source trimmed at 1.5x speed = 4.0s output
      expect(outProbe.duration, closeTo(4.0, 0.6));
    });
  });
}
