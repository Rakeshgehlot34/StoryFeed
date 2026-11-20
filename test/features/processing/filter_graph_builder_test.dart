import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/processing/domain/filter_graph_builder.dart';
import 'package:shorts_splitter/features/split_config/domain/models/background_spec.dart';
import 'package:shorts_splitter/features/split_config/domain/models/canvas_spec.dart';

void main() {
  group('FilterGraphBuilder Tests', () {
    const shortsCanvas = CanvasSpec(
      format: CanvasFormat.shorts916,
    ); // 1080x1920
    const squareCanvas = CanvasSpec(format: CanvasFormat.square11); // 1080x1080
    const landscapeCanvas = CanvasSpec(
      format: CanvasFormat.landscape169,
    ); // 1920x1080

    test('1. Solid color background generates scale-down and pad filter', () {
      final result = FilterGraphBuilder.build(
        sourceWidth: 1920,
        sourceHeight: 1080, // 16:9 source to 9:16 canvas
        canvasSpec: shortsCanvas,
        backgroundSpec: const SolidColorBackgroundSpec(colorValue: 0xFFFFFFFF),
        cropToFill: false,
      );

      expect(result.simpleFilter, isNotNull);
      expect(result.simpleFilter, contains('scale=1080:608'));
      expect(
        result.simpleFilter,
        contains('pad=1080:1920:0:656:color=0xFFFFFF'),
      );
      expect(result.simpleFilter, contains('setsar=1'));
      expect(result.additionalInputArgs, isEmpty);
      expect(result.fitLayout, isNotNull);
      expect(result.fitLayout!.width, equals(1080));
      expect(result.fitLayout!.height, equals(608));
      expect(result.fitLayout!.topBand, equals(656));
      expect(result.fitLayout!.bottomBand, equals(656));
    });

    test(
      '2. Crop to fill generates scale-up and centered crop without padding',
      () {
        final result = FilterGraphBuilder.build(
          sourceWidth: 1920,
          sourceHeight: 1080,
          canvasSpec: shortsCanvas,
          backgroundSpec: const SolidColorBackgroundSpec(),
          cropToFill: true,
        );

        expect(result.simpleFilter, isNotNull);
        expect(
          result.simpleFilter,
          equals(
            'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1',
          ),
        );
      },
    );

    test(
        '3. Blurred video background generates 2-stream filter_complex graph with fast downscaled blur',
        () {
      final result = FilterGraphBuilder.build(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasSpec: shortsCanvas,
        backgroundSpec: const BlurBackgroundSpec(),
        cropToFill: false,
      );

      expect(result.filterComplex, isNotNull);
      expect(
        result.filterComplex,
        contains('boxblur=5:1,scale=1080:1920:flags=bicubic[bg]'),
      );
      expect(result.filterComplex, contains('[0:v]scale=1080:608[fg]'));
      expect(
        result.filterComplex,
        contains('[bg][fg]overlay=0:656,setsar=1[outv]'),
      );
      expect(result.outputVideoMap, equals('[outv]'));
    });

    test(
      '4. Custom image background loads looped image and composites foreground',
      () {
        final result = FilterGraphBuilder.build(
          sourceWidth: 1920,
          sourceHeight: 1080,
          canvasSpec: squareCanvas, // 1080x1080
          backgroundSpec: const ImageBackgroundSpec(imagePath: '/tmp/bg.jpg'),
          cropToFill: false,
        );

        expect(
          result.additionalInputArgs,
          equals(['-loop', '1', '-i', '/tmp/bg.jpg']),
        );
        expect(result.filterComplex, isNotNull);
        expect(
          result.filterComplex,
          contains(
            '[1:v]scale=1080:1080:force_original_aspect_ratio=increase,crop=1080:1080[bg]',
          ),
        );
        expect(result.filterComplex, contains('[0:v]scale=1080:608[fg]'));
        expect(
          result.filterComplex,
          contains('[bg][fg]overlay=0:236:shortest=1,setsar=1[outv]'),
        );
      },
    );

    test(
      '5. Source matching canvas aspect ratio needs no letterbox padding',
      () {
        final result = FilterGraphBuilder.build(
          sourceWidth: 1080,
          sourceHeight: 1920, // 9:16 source into 9:16 canvas
          canvasSpec: shortsCanvas,
          backgroundSpec: const SolidColorBackgroundSpec(),
          cropToFill: false,
        );

        expect(result.simpleFilter, equals('scale=1080:1920,setsar=1'));
      },
    );

    test('6. Overlay PNG attachment handles whole clip vs timed display', () {
      // Whole clip
      final wholeClipResult = FilterGraphBuilder.build(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasSpec: landscapeCanvas,
        backgroundSpec: const SolidColorBackgroundSpec(),
        cropToFill: false,
        overlayPngPath: '/tmp/overlay.png',
        displayWholeClip: true,
      );

      expect(
        wholeClipResult.additionalInputArgs,
        equals(['-i', '/tmp/overlay.png']),
      );
      expect(wholeClipResult.filterComplex, contains('overlay=0:0[outv]'));
      expect(wholeClipResult.filterComplex, isNot(contains('enable=')));

      // Timed (first 3.0 seconds)
      final timedResult = FilterGraphBuilder.build(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasSpec: landscapeCanvas,
        backgroundSpec: const SolidColorBackgroundSpec(),
        cropToFill: false,
        overlayPngPath: '/tmp/overlay.png',
        displayWholeClip: false,
        displayDurationSeconds: 3.0,
      );

      expect(
        timedResult.filterComplex,
        contains("overlay=0:0:enable='between(t,0,3.00)'[outv]"),
      );
    });

    test(
        '7. buildVideoFilterChain compiles crop, rotation, flip, speed, color eq, fades, and reverse',
        () {
      final filter = FilterGraphBuilder.buildVideoFilterChain(
        cropX: 10,
        cropY: 20,
        cropWidth: 800,
        cropHeight: 600,
        rotationDegrees: 90,
        hflip: true,
        vflip: true,
        speed: 2.0,
        brightness: 0.1,
        contrast: 1.2,
        saturation: 1.5,
        fadeInSeconds: 1.0,
        fadeOutSeconds: 2.0,
        totalDurationSeconds: 10.0,
        reverse: true,
      );

      expect(filter, isNotNull);
      expect(filter, contains('reverse'));
      expect(filter, contains('crop=800:600:10:20'));
      expect(filter, contains('transpose=1'));
      expect(filter, contains('hflip'));
      expect(filter, contains('vflip'));
      expect(filter, contains('setpts=0.5000*PTS'));
      expect(
        filter,
        contains('eq=brightness=0.10:contrast=1.20:saturation=1.50'),
      );
      expect(filter, contains('fade=t=in:st=0:d=1.000'));
      expect(filter, contains('fade=t=out:st=8.000:d=2.000'));
    });

    test(
      '8. buildVideoFilterChain returns null when no filters are specified',
      () {
        final filter = FilterGraphBuilder.buildVideoFilterChain();
        expect(filter, isNull);
      },
    );
  });
}
