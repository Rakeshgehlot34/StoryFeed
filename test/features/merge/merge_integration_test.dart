import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/merge/domain/merge_filter_compiler.dart';
import 'package:shorts_splitter/features/merge/domain/models/merge_project.dart';

import '../../utils/output_verifier.dart';

void main() {
  group('Video Merge Integration with Real Fixtures', () {
    const fixture16x9 = 'test/fixtures/test_16_9.mp4';
    const fixture9x16 = 'test/fixtures/test_9_16.mp4';
    const fixtureSilent = 'test/fixtures/test_silent.mp4';

    late Directory tempOutDir;

    setUpAll(() {
      if (!File(fixture16x9).existsSync() ||
          !File(fixture9x16).existsSync() ||
          !File(fixtureSilent).existsSync()) {
        fail('Fixtures missing. Run scripts/make_fixtures.sh first.');
      }
      tempOutDir = Directory.systemTemp.createTempSync(
        'merge_integration_test_',
      );
    });

    tearDownAll(() {
      if (tempOutDir.existsSync()) {
        tempOutDir.deleteSync(recursive: true);
      }
    });

    test(
      '1. Executes fast stream copy concatenation on compatible fixtures',
      () async {
        final probe = await OutputVerifier.probe(fixture16x9);
        expect(probe.hasVideo, isTrue);

        final listFile = File('${tempOutDir.path}/concat_list.txt');
        final listContent = MergeFilterCompiler.generateConcatListContent([
          File(fixture16x9).absolute.path,
          File(fixture16x9).absolute.path,
        ]);
        await listFile.writeAsString(listContent);

        final outPath = '${tempOutDir.path}/merged_fast.mp4';
        final args = MergeFilterCompiler.buildFastConcatArgs(
          listFilePath: listFile.path,
          outputPath: outPath,
        );

        final res = await Process.run('ffmpeg', args);
        expect(res.exitCode, 0, reason: 'FFmpeg stderr: ${res.stderr}');

        final outProbe = await OutputVerifier.probe(outPath);
        expect(outProbe.hasVideo, isTrue);
        expect(outProbe.hasAudio, isTrue);
        // Duration should be roughly double original (~20s)
        expect(outProbe.duration, closeTo(probe.duration * 2, 1.0));
        expect(outProbe.width, probe.width);
        expect(outProbe.height, probe.height);
      },
    );

    test(
        '2. Normalizes 16:9 and 9:16 vertical video with letterbox and crossfade transition',
        () async {
      final p16 = await OutputVerifier.probe(fixture16x9);
      final p9 = await OutputVerifier.probe(fixture9x16);

      final clip1 = MergeClipItem(
        id: 'c1',
        videoPath: File(fixture16x9).absolute.path,
        fileName: 'test_16_9.mp4',
        durationSeconds: p16.duration,
        width: p16.width ?? 1920,
        height: p16.height ?? 1080,
        fps: p16.fps ?? 30.0,
        hasAudio: p16.hasAudio,
      );

      final clip2 = MergeClipItem(
        id: 'c2',
        videoPath: File(fixture9x16).absolute.path,
        fileName: 'test_9_16.mp4',
        durationSeconds: p9.duration,
        width: p9.width ?? 1080,
        height: p9.height ?? 1920,
        fps: p9.fps ?? 30.0,
        hasAudio: p9.hasAudio,
      );

      final config = MergeConfig(
        clips: [clip1, clip2],
        canvasPreset: CanvasAspectRatioPreset.standard720p, // 1280x720
        fitMode: CanvasFitMode.fitBlack,
        transition: MergeTransition.fade,
        transitionDurationSeconds: 1.0,
      );

      final outPath = '${tempOutDir.path}/merged_normalized_crossfade.mp4';
      final args = MergeFilterCompiler.buildComplexMergeArgs(
        config: config,
        outputPath: outPath,
      );

      final res = await Process.run('ffmpeg', args);
      expect(res.exitCode, 0, reason: 'FFmpeg stderr: ${res.stderr}');

      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isTrue);
      expect(outProbe.hasAudio, isTrue);
      expect(outProbe.width, 1280);
      expect(outProbe.height, 720);
      // Total duration = p16.duration + p9.duration - 1.0s transition overlap
      final expectedDur = p16.duration + p9.duration - 1.0;
      expect(outProbe.duration, closeTo(expectedDur, 1.0));
    });

    test(
        '3. Concatenates video with silent video fixture using synthetic audio generator',
        () async {
      final p16 = await OutputVerifier.probe(fixture16x9);
      final pSilent = await OutputVerifier.probe(fixtureSilent);

      final clip1 = MergeClipItem(
        id: 'c1',
        videoPath: File(fixture16x9).absolute.path,
        fileName: 'test_16_9.mp4',
        durationSeconds: p16.duration,
        width: p16.width ?? 1920,
        height: p16.height ?? 1080,
        fps: p16.fps ?? 30.0,
        hasAudio: true,
      );

      final clip2 = MergeClipItem(
        id: 'c2',
        videoPath: File(fixtureSilent).absolute.path,
        fileName: 'test_silent.mp4',
        durationSeconds: pSilent.duration,
        width: pSilent.width ?? 1920,
        height: pSilent.height ?? 1080,
        fps: pSilent.fps ?? 30.0,
        hasAudio: false, // Silent input
      );

      final config = MergeConfig(
        clips: [clip1, clip2],
        canvasPreset: CanvasAspectRatioPreset.matchFirst,
        fitMode: CanvasFitMode.fitBlack,
        transition: MergeTransition.none,
      );

      final outPath = '${tempOutDir.path}/merged_silent_synth.mp4';
      final args = MergeFilterCompiler.buildComplexMergeArgs(
        config: config,
        outputPath: outPath,
      );

      final res = await Process.run('ffmpeg', args);
      expect(res.exitCode, 0, reason: 'FFmpeg stderr: ${res.stderr}');

      final outProbe = await OutputVerifier.probe(outPath);
      expect(outProbe.hasVideo, isTrue);
      // Output MUST have audio track preserved with synthetic silence for clip 2
      expect(outProbe.hasAudio, isTrue);
      expect(outProbe.duration, closeTo(p16.duration + pSilent.duration, 1.0));
    });
  });
}
