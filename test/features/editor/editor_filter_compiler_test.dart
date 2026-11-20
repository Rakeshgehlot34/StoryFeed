import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/editor/domain/editor_filter_compiler.dart';
import 'package:shorts_splitter/features/editor/domain/models/edit_project.dart';

void main() {
  group('EditorFilterCompiler - 1-Pass Filter Complex Generation', () {
    const testProject = EditProject(
      id: 'proj_compile',
      title: 'Action_Scene',
      sourceVideoPath: '/path/input.mp4',
      sourceVideoName: 'input.mp4',
      sourceDurationSeconds: 30.0,
      sourceWidth: 1920,
      sourceHeight: 1080,
      trim: TrimConfig(startSeconds: 5.0, endSeconds: 15.0), // 10s
      speed: SpeedSpec(speed: 1.5, preservePitch: true),
      transform: TransformSpec(rotationDegrees: 90, hflip: true),
      canvas: CanvasConfig(
        aspectRatio: TargetAspectRatio.vertical916,
        fitMode: CanvasFitMode.cropToFill,
      ),
      fade: FadeSpec(fadeInSeconds: 0.5, fadeOutSeconds: 0.5, fadeAudio: true),
      watermark: WatermarkSpec(
        imagePath: '/path/logo.png',
        position: OverlayPosition.topRight,
        opacity: 0.8,
        scale: 0.15,
      ),
    );

    test(
        'compiles complete 1-pass export command with video and audio filter chains',
        () {
      final cmd = EditorFilterCompiler.compileExport(
        project: testProject,
        resolvedInputPath: '/path/input.mp4',
        outputPath: '/path/output.mp4',
      );

      final args = cmd.arguments;

      // 1. Check seeking and trimming
      expect(args, contains('-ss'));
      expect(args[args.indexOf('-ss') + 1], '5.000');
      expect(args, contains('-t'));
      expect(args[args.indexOf('-t') + 1], '10.000');

      // 2. Check inputs: source video + watermark image
      expect(args, contains('/path/input.mp4'));
      expect(args, contains('/path/logo.png'));

      // 3. Check filter complex structure
      expect(args, contains('-filter_complex'));
      final filterComplex = args[args.indexOf('-filter_complex') + 1];

      // Video filters: transpose=1 (90 deg), hflip, setpts, scale/crop to 9:16 (1080:1920), watermark overlay
      expect(filterComplex, contains('transpose=1'));
      expect(filterComplex, contains('hflip'));
      expect(filterComplex, contains('setpts='));
      expect(filterComplex, contains('crop=1080:1920'));
      expect(filterComplex, contains('overlay=W-w-20:20'));

      // Audio filters: atempo for 1.5x pitch preservation, afade in, afade out
      expect(filterComplex, contains('atempo=1.5'));
      expect(filterComplex, contains('afade=t=in'));
      expect(filterComplex, contains('afade=t=out'));

      // 4. Codec options
      expect(args, contains('-c:v'));
      expect(args, contains('libx264'));
      expect(args, contains('-c:a'));
      expect(args, contains('aac'));
      expect(args.last, equals('/path/output.mp4'));
    });

    test('compiles rapid 5-second preview command with ultrafast preset', () {
      final previewArgs = EditorFilterCompiler.compilePreview(
        project: testProject,
        resolvedInputPath: '/path/input.mp4',
        previewOutputPath: '/path/preview.mp4',
        previewDurationSeconds: 5.0,
      );

      // Duration capped at 5.0s
      expect(previewArgs, contains('-t'));
      expect(previewArgs[previewArgs.indexOf('-t') + 1], '5.000');

      // Ultrafast preset for fast preview generation
      expect(previewArgs, contains('-preset'));
      expect(previewArgs[previewArgs.indexOf('-preset') + 1], 'ultrafast');

      expect(previewArgs.last, equals('/path/preview.mp4'));
    });
  });
}
