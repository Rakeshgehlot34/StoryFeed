import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/merge/domain/models/merge_project.dart';

void main() {
  group('CanvasAspectRatioPreset Tests', () {
    test('1. Resolves aspect ratios correctly', () {
      expect(
        CanvasAspectRatioPreset.vertical9x16.aspectRatio,
        closeTo(9 / 16, 0.001),
      );
      expect(
        CanvasAspectRatioPreset.horizontal16x9.aspectRatio,
        closeTo(16 / 9, 0.001),
      );
      expect(CanvasAspectRatioPreset.square1x1.aspectRatio, 1.0);
      expect(CanvasAspectRatioPreset.matchFirst.aspectRatio, isNull);
    });
  });

  group('MergeClipItem Tests', () {
    test('2. Calculates effective duration and formatting', () {
      const clip = MergeClipItem(
        id: 'c1',
        videoPath: '/path/clip1.mp4',
        fileName: 'clip1.mp4',
        durationSeconds: 12.5,
        width: 1920,
        height: 1080,
        fps: 30.0,
      );

      expect(clip.effectiveDurationSeconds, 12.5);
      expect(clip.resolutionString, '1920x1080');
      expect(clip.formattedDuration, '00:12.5s');

      final trimmed = clip.copyWith(
        startTrimSeconds: 2.0,
        endTrimSeconds: 10.0,
      );
      expect(trimmed.effectiveDurationSeconds, 8.0);
      expect(trimmed.formattedDuration, '00:08.0s');
    });

    test('3. Serializes and deserializes clip item to JSON', () {
      const clip = MergeClipItem(
        id: 'c2',
        videoPath: '/path/clip2.mp4',
        fileName: 'clip2.mp4',
        durationSeconds: 5.4,
        width: 1080,
        height: 1920,
        fps: 60.0,
        hasAudio: false,
        startTrimSeconds: 1.0,
        endTrimSeconds: 4.0,
      );

      final json = clip.toJson();
      final reconstructed = MergeClipItem.fromJson(json);

      expect(reconstructed.id, 'c2');
      expect(reconstructed.videoPath, '/path/clip2.mp4');
      expect(reconstructed.durationSeconds, 5.4);
      expect(reconstructed.width, 1080);
      expect(reconstructed.height, 1920);
      expect(reconstructed.fps, 60.0);
      expect(reconstructed.hasAudio, isFalse);
      expect(reconstructed.startTrimSeconds, 1.0);
      expect(reconstructed.endTrimSeconds, 4.0);
      expect(reconstructed.effectiveDurationSeconds, 3.0);
    });
  });

  group('MergeConfig Tests', () {
    const clip1 = MergeClipItem(
      id: 'c1',
      videoPath: '/path/clip1.mp4',
      fileName: 'clip1.mp4',
      durationSeconds: 10.0,
      width: 1920,
      height: 1080,
      fps: 30.0,
    );
    const clip2 = MergeClipItem(
      id: 'c2',
      videoPath: '/path/clip2.mp4',
      fileName: 'clip2.mp4',
      durationSeconds: 15.0,
      width: 1920,
      height: 1080,
      fps: 30.0,
    );

    test('4. Calculates total duration without transitions', () {
      const config = MergeConfig(
        clips: [clip1, clip2],
        transition: MergeTransition.none,
      );

      expect(config.canMerge, isTrue);
      expect(config.calculateTotalDurationSeconds(), 25.0);
      expect(config.effectiveBaseName, 'clip1_merged');
    });

    test('5. Calculates total duration with crossfade transition overlap', () {
      const config = MergeConfig(
        clips: [clip1, clip2],
        transition: MergeTransition.fade,
        transitionDurationSeconds: 1.0,
      );

      // Total = 10 + 15 - 1.0 = 24.0s
      expect(config.calculateTotalDurationSeconds(), 24.0);
    });

    test('6. Evaluates fast concat demuxer compatibility', () {
      const compatibleConfig = MergeConfig(
        clips: [clip1, clip2],
        transition: MergeTransition.none,
      );
      expect(compatibleConfig.isFastConcatCompatible(), isTrue);
      expect(compatibleConfig.effectiveMethod, MergeMethod.fast);

      // Incompatible if transition present
      final withTransition = compatibleConfig.copyWith(
        transition: MergeTransition.wipeleft,
      );
      expect(withTransition.isFastConcatCompatible(), isFalse);
      expect(withTransition.effectiveMethod, MergeMethod.precise);

      // Incompatible if resolution differs
      const clipDiffRes = MergeClipItem(
        id: 'c3',
        videoPath: '/path/clip3.mp4',
        fileName: 'clip3.mp4',
        durationSeconds: 8.0,
        width: 1080,
        height: 1920,
      );
      final withDiffRes = compatibleConfig.copyWith(
        clips: [clip1, clipDiffRes],
      );
      expect(withDiffRes.isFastConcatCompatible(), isFalse);

      // Incompatible if trimmed
      final withTrim = compatibleConfig.copyWith(
        clips: [clip1.copyWith(startTrimSeconds: 1.0), clip2],
      );
      expect(withTrim.isFastConcatCompatible(), isFalse);
    });

    test('7. Estimates output file size accurately', () {
      const config = MergeConfig(
        clips: [clip1, clip2],
        canvasPreset: CanvasAspectRatioPreset.standard1080p,
      );

      final estimatedBytes = config.estimateOutputSizeBytes();
      expect(estimatedBytes, greaterThan(1024 * 1024)); // > 1MB
    });

    test('8. Serializes and deserializes MergeConfig to JSON', () {
      const config = MergeConfig(
        clips: [clip1, clip2],
        canvasPreset: CanvasAspectRatioPreset.vertical9x16,
        fitMode: CanvasFitMode.fitBlur,
        transition: MergeTransition.fade,
        transitionDurationSeconds: 0.8,
        method: MergeMethod.precise,
        customBaseName: 'my_awesome_compilation',
      );

      final json = config.toJson();
      final restored = MergeConfig.fromJson(json);

      expect(restored.clips.length, 2);
      expect(restored.canvasPreset, CanvasAspectRatioPreset.vertical9x16);
      expect(restored.fitMode, CanvasFitMode.fitBlur);
      expect(restored.transition, MergeTransition.fade);
      expect(restored.transitionDurationSeconds, 0.8);
      expect(restored.method, MergeMethod.precise);
      expect(restored.customBaseName, 'my_awesome_compilation');
      expect(restored.effectiveBaseName, 'my_awesome_compilation');
    });
  });
}
