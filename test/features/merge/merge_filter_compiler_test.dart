import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/merge/domain/merge_filter_compiler.dart';
import 'package:shorts_splitter/features/merge/domain/models/merge_project.dart';

void main() {
  group('MergeFilterCompiler - Fast Concat Demuxer Tests', () {
    test('1. Builds fast concat command arguments', () {
      final args = MergeFilterCompiler.buildFastConcatArgs(
        listFilePath: '/tmp/concat_list.txt',
        outputPath: '/storage/output.mp4',
      );

      expect(args, [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        '/tmp/concat_list.txt',
        '-c',
        'copy',
        '-movflags',
        '+faststart',
        '/storage/output.mp4',
      ]);
    });

    test('2. Generates escaped concat file list format', () {
      final content = MergeFilterCompiler.generateConcatListContent([
        '/path/to/clip1.mp4',
        "/path/to/clip's_part2.mp4",
      ]);

      expect(content, contains("file '/path/to/clip1.mp4'"));
      expect(content, contains(r"file '/path/to/clip'\''s_part2.mp4'"));
    });
  });

  group('MergeFilterCompiler - Complex Filter Complex Tests', () {
    const clip1 = MergeClipItem(
      id: 'c1',
      videoPath: '/path/video1.mp4',
      fileName: 'video1.mp4',
      durationSeconds: 10.0,
      width: 1920,
      height: 1080,
      fps: 30.0,
      hasAudio: true,
    );
    const clip2 = MergeClipItem(
      id: 'c2',
      videoPath: '/path/video2.mp4',
      fileName: 'video2.mp4',
      durationSeconds: 8.0,
      width: 1080,
      height: 1920,
      fps: 30.0,
      hasAudio: false, // Silent video!
    );

    test('3. Compiles direct concatenation with synthetic silence for silent video', () {
      const config = MergeConfig(
        clips: [clip1, clip2],
        canvasPreset: CanvasAspectRatioPreset.standard1080p,
        fitMode: CanvasFitMode.fitBlack,
        transition: MergeTransition.none,
      );

      final filterComplex = MergeFilterCompiler.buildFilterComplex(config);

      // Verify aspect ratio normalization with black letterbox
      expect(
        filterComplex,
        contains(
          'scale=w=1920:h=1080:force_original_aspect_ratio=decrease,pad=w=1920:h=1080',
        ),
      );

      // Verify audio normalization: clip1 gets stereo 44.1k, clip2 gets synthetic silence (anullsrc)
      expect(
        filterComplex,
        contains(
          '[0:a]aformat=sample_rates=44100:channel_layouts=stereo[a_norm_0]',
        ),
      );
      expect(
        filterComplex,
        contains(
          'anullsrc=r=44100:cl=stereo,atrim=0:8.000,asetpts=PTS-STARTPTS[a_norm_1]',
        ),
      );

      // Verify concat stream mapping
      expect(
        filterComplex,
        contains(
          '[v_norm_0][a_norm_0][v_norm_1][a_norm_1]concat=n=2:v=1:a=1[v_out][a_out]',
        ),
      );

      final cmd = MergeFilterCompiler.buildComplexMergeArgs(
        config: config,
        outputPath: '/storage/merged.mp4',
      );

      expect(cmd, contains('-map'));
      expect(cmd, contains('[v_out]'));
      expect(cmd, contains('[a_out]'));
      expect(cmd, contains('yuv420p'));
      expect(cmd, contains('+faststart'));
    });

    test(
      '4. Compiles crossfade video and acrossfade audio transition chains',
      () {
        const config = MergeConfig(
          clips: [clip1, clip2],
          canvasPreset: CanvasAspectRatioPreset.standard1080p,
          fitMode: CanvasFitMode.fitBlack,
          transition: MergeTransition.fade,
          transitionDurationSeconds: 1.0,
        );

        final filterComplex = MergeFilterCompiler.buildFilterComplex(config);

        // Transition offset for 1st transition = clip1.duration (10.0) - dur (1.0) = 9.0s
        expect(
          filterComplex,
          contains(
            '[v_norm_0][v_norm_1]xfade=transition=fade:duration=1.000:offset=9.000[xv_1]',
          ),
        );
        expect(
          filterComplex,
          contains(
            '[a_norm_0][a_norm_1]acrossfade=d=1.000:c1=tri:c2=tri[xa_1]',
          ),
        );

        final cmd = MergeFilterCompiler.buildComplexMergeArgs(
          config: config,
          outputPath: '/storage/merged.mp4',
        );

        expect(cmd, contains('-map'));
        expect(cmd, contains('[xv_1]'));
        expect(cmd, contains('[xa_1]'));
      },
    );

    test('5. Compiles blurred background canvas fit mode', () {
      const config = MergeConfig(
        clips: [clip1],
        canvasPreset: CanvasAspectRatioPreset.standard1080p,
        fitMode: CanvasFitMode.fitBlur,
      );

      final filterComplex = MergeFilterCompiler.buildFilterComplex(config);

      expect(filterComplex, contains('gblur=sigma=20'));
      expect(filterComplex, contains('overlay=(W-w)/2:(H-h)/2'));
    });

    test('6. Compiles crop to fill canvas fit mode', () {
      const config = MergeConfig(
        clips: [clip1],
        canvasPreset: CanvasAspectRatioPreset.vertical9x16,
        fitMode: CanvasFitMode.cropFill,
      );

      final filterComplex = MergeFilterCompiler.buildFilterComplex(config);

      expect(
        filterComplex,
        contains(
          'scale=w=1080:h=1920:force_original_aspect_ratio=increase,crop=w=1080:h=1920',
        ),
      );
    });
  });
}
