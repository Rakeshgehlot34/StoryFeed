import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/custom_split/domain/custom_split_calculator.dart';
import 'package:shorts_splitter/features/custom_split/domain/models/custom_split_config.dart';

import '../../utils/output_verifier.dart';

void main() {
  group('Custom Split Integration with Real Fixtures', () {
    const fixturePath = 'test/fixtures/test_70s.mp4';
    late Directory tempOutDir;

    setUpAll(() async {
      final fixture = File(fixturePath);
      if (!fixture.existsSync()) {
        fail(
          'Fixture $fixturePath not found. Run scripts/make_fixtures.sh first.',
        );
      }
      tempOutDir = Directory.systemTemp.createTempSync('custom_split_test_');
    });

    tearDownAll(() {
      if (tempOutDir.existsSync()) {
        tempOutDir.deleteSync(recursive: true);
      }
    });

    test(
      'calculates and executes fast stream-copy split on 70s fixture',
      () async {
        // 1. Probe source video with OutputVerifier
        final sourceProbe = await OutputVerifier.probe(fixturePath);
        expect(sourceProbe.hasVideo, isTrue);
        expect(sourceProbe.duration, closeTo(70.0, 1.0));

        // 2. Generate CustomClipPlan for 30s clips (fast stream copy)
        const config = CustomSplitConfig(
          mode: CustomSplitMode.byDuration,
          method: SplitMethod.fast,
          targetDurationSeconds: 30.0,
          startSeconds: 0.0,
          endSeconds: 70.0,
          mergeShortTrailingClip:
              true, // Remainder 10s > 3s, so remains independent 3 parts
        );

        final plan = CustomSplitCalculator.calculatePlan(
          originalVideoName: 'test_70s.mp4',
          videoDurationSeconds: sourceProbe.duration,
          config: config,
        );

        expect(plan.totalParts, 3);
        expect(plan.items[0].durationSeconds, 30.0);
        expect(plan.items[1].durationSeconds, 30.0);
        expect(plan.items[2].durationSeconds, closeTo(10.0, 1.0));

        // 3. Execute fast stream-copy command pattern
        final part1 = plan.items[0];
        final outPath = '${tempOutDir.path}/${part1.formattedName}';

        final res = await Process.run('ffmpeg', [
          '-y',
          '-ss',
          part1.startSeconds.toStringAsFixed(3),
          '-i',
          fixturePath,
          '-t',
          part1.durationSeconds.toStringAsFixed(3),
          '-c',
          'copy',
          '-avoid_negative_ts',
          'make_zero',
          outPath,
        ]);

        expect(
          res.exitCode,
          0,
          reason: 'FFmpeg fast stream copy failed: ${res.stderr}',
        );
        expect(File(outPath).existsSync(), isTrue);

        // 4. Verify output clip using OutputVerifier
        final clipProbe = await OutputVerifier.probe(outPath);
        expect(clipProbe.hasVideo, isTrue);
        expect(clipProbe.hasAudio, isTrue);
        expect(clipProbe.width, equals(sourceProbe.width));
        expect(clipProbe.height, equals(sourceProbe.height));
        expect(clipProbe.duration, closeTo(30.0, 1.0));
      },
    );

    test(
      'calculates and executes precise re-encoded split on 70s fixture',
      () async {
        final sourceProbe = await OutputVerifier.probe(fixturePath);

        // Mode: byParts into 2 equal parts (35s each)
        const config = CustomSplitConfig(
          mode: CustomSplitMode.byParts,
          method: SplitMethod.precise,
          targetPartCount: 2,
          startSeconds: 0.0,
          endSeconds: 70.0,
        );

        final plan = CustomSplitCalculator.calculatePlan(
          originalVideoName: 'test_70s.mp4',
          videoDurationSeconds: sourceProbe.duration,
          config: config,
        );

        expect(plan.totalParts, 2);
        final part2 = plan.items[1];
        expect(part2.startSeconds, closeTo(35.0, 0.5));
        expect(part2.durationSeconds, closeTo(35.0, 0.5));

        final outPath = '${tempOutDir.path}/${part2.formattedName}';

        final res = await Process.run('ffmpeg', [
          '-y',
          '-ss',
          part2.startSeconds.toStringAsFixed(3),
          '-i',
          fixturePath,
          '-t',
          part2.durationSeconds.toStringAsFixed(3),
          '-c:v',
          'libx264',
          '-preset',
          'veryfast',
          '-crf',
          '22',
          '-c:a',
          'aac',
          '-b:a',
          '128k',
          '-pix_fmt',
          'yuv420p',
          outPath,
        ]);

        expect(
          res.exitCode,
          0,
          reason: 'FFmpeg precise encode failed: ${res.stderr}',
        );
        expect(File(outPath).existsSync(), isTrue);

        final clipProbe = await OutputVerifier.probe(outPath);
        expect(clipProbe.hasVideo, isTrue);
        expect(clipProbe.hasAudio, isTrue);
        expect(clipProbe.videoCodec, equals('h264'));
        expect(clipProbe.audioCodec, equals('aac'));
        expect(clipProbe.duration, closeTo(35.0, 0.5));
      },
    );
  });
}
