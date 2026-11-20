import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/split_config/domain/models/fit_layout.dart';

void main() {
  group('FitLayout Unit Tests - Pure Geometry & Symmetry', () {
    const canvasW = 1080;
    const canvasH = 1920;

    test(
      '1. 16:9 Landscape (1920x1080) on 9:16 Canvas (1080x1920) - Centered',
      () {
        final layout = FitLayout.calculate(
          sourceWidth: 1920,
          sourceHeight: 1080,
          canvasWidth: canvasW,
          canvasHeight: canvasH,
          verticalPosition: VerticalPosition.center,
          verticalOffsetFraction: 0.0,
        );

        expect(layout.width, equals(1080));
        expect(layout.height, equals(608)); // Even integer
        expect(layout.x, equals(0));
        expect(layout.y, equals(656));
        expect(layout.topBand, equals(656));
        expect(layout.bottomBand, equals(656));
        expect(layout.leftBand, equals(0));
        expect(layout.rightBand, equals(0));
        expect(layout.topBand, equals(layout.bottomBand)); // Perfect symmetry
        expect(layout.isMatchesAspect, isFalse);
        expect(layout.hasPadding, isTrue);

        // FFmpeg filter helpers
        expect(
          layout.ffmpegPadFilter('0xFFFFFF'),
          equals('scale=1080:608,pad=1080:1920:0:656:color=0xFFFFFF,setsar=1'),
        );
        expect(layout.ffmpegOverlayArgs(), equals('overlay=0:656,setsar=1'));
      },
    );

    test('2. 4:3 SD (1440x1080) on 9:16 Canvas (1080x1920) - Centered', () {
      final layout = FitLayout.calculate(
        sourceWidth: 1440,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        verticalPosition: VerticalPosition.center,
      );

      expect(layout.width, equals(1080));
      expect(layout.height, equals(810));
      expect(layout.x, equals(0));
      // Even pixel alignment keeps y even (554)
      expect(layout.y % 2, equals(0));
      expect(layout.topBand, inInclusiveRange(554, 556));
      expect(layout.bottomBand, inInclusiveRange(554, 556));
    });

    test('3. 1:1 Square (1080x1080) on 9:16 Canvas (1080x1920) - Centered', () {
      final layout = FitLayout.calculate(
        sourceWidth: 1080,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        verticalPosition: VerticalPosition.center,
      );

      expect(layout.width, equals(1080));
      expect(layout.height, equals(1080));
      expect(layout.topBand, equals(420));
      expect(layout.bottomBand, equals(420));
      expect(layout.topBand, equals(layout.bottomBand)); // Symmetry
    });

    test(
        '4. 4:5 Instagram Portrait (1080x1350) on 9:16 Canvas (1080x1920) - Centered',
        () {
      final layout = FitLayout.calculate(
        sourceWidth: 1080,
        sourceHeight: 1350,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        verticalPosition: VerticalPosition.center,
      );

      expect(layout.width, equals(1080));
      expect(layout.height, equals(1350));
      expect(layout.y % 2, equals(0));
      expect(layout.topBand, inInclusiveRange(284, 286));
      expect(layout.bottomBand, inInclusiveRange(284, 286));
    });

    test('5. 9:16 Matching Source (1080x1920) on 9:16 Canvas - No Padding', () {
      final layout = FitLayout.calculate(
        sourceWidth: 1080,
        sourceHeight: 1920,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
      );

      expect(layout.width, equals(1080));
      expect(layout.height, equals(1920));
      expect(layout.x, equals(0));
      expect(layout.y, equals(0));
      expect(layout.topBand, equals(0));
      expect(layout.bottomBand, equals(0));
      expect(layout.isMatchesAspect, isTrue);
      expect(layout.hasPadding, isFalse);
    });

    test(
      '6. 21:9 Ultra-Wide (2560x1080) on 9:16 Canvas (1080x1920) - Centered',
      () {
        final layout = FitLayout.calculate(
          sourceWidth: 2560,
          sourceHeight: 1080,
          canvasWidth: canvasW,
          canvasHeight: canvasH,
        );

        expect(layout.width, equals(1080));
        expect(layout.height, equals(456)); // Even integer
        expect(layout.topBand, equals(732));
        expect(layout.bottomBand, equals(732));
        expect(layout.topBand, equals(layout.bottomBand));
      },
    );

    test('7. Rotated Metadata (90° and 270°) swaps effective width and height',
        () {
      // Raw 1920x1080 with 90° rotation should be treated as portrait 1080x1920
      final layout90 = FitLayout.calculate(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        rotationDegrees: 90,
      );

      expect(layout90.isMatchesAspect, isTrue);
      expect(layout90.width, equals(1080));
      expect(layout90.height, equals(1920));
      expect(layout90.hasPadding, isFalse);

      final layout270 = FitLayout.calculate(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        rotationDegrees: 270,
      );
      expect(layout270.isMatchesAspect, isTrue);
    });

    test('8. Non-square SAR scales effective width', () {
      // 1440x1080 with SAR 1.333333 is 16:9 display aspect
      final layout = FitLayout.calculate(
        sourceWidth: 1440,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        sar: 4 / 3,
      );

      expect(layout.width, equals(1080));
      expect(layout.height, equals(608)); // Same as 16:9
      expect(layout.topBand, equals(656));
      expect(layout.bottomBand, equals(656));
    });

    test('9. Odd Dimensions guarantee integer-even pixel outputs', () {
      final layout = FitLayout.calculate(
        sourceWidth: 1919,
        sourceHeight: 1079,
        canvasWidth: 1080,
        canvasHeight: 1920,
      );

      expect(layout.width % 2, equals(0));
      expect(layout.height % 2, equals(0));
      expect(layout.x % 2, equals(0));
      expect(layout.y % 2, equals(0));
    });

    test('10. Vertical Position: Top, Center, Bottom', () {
      final center = FitLayout.calculate(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        verticalPosition: VerticalPosition.center,
      );
      expect(center.topBand, equals(656));
      expect(center.bottomBand, equals(656));

      final top = FitLayout.calculate(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        verticalPosition: VerticalPosition.top,
      );
      expect(top.y, equals(0));
      expect(top.topBand, equals(0));
      expect(top.bottomBand, equals(1312));

      final bottom = FitLayout.calculate(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        verticalPosition: VerticalPosition.bottom,
      );
      expect(bottom.y, equals(1312));
      expect(bottom.bottomBand, equals(0));
      expect(bottom.topBand, equals(1312));
    });

    test('11. Manual Vertical Offset clamped to [-0.20, +0.20]', () {
      // freeSpace is 1920 - 608 = 1312
      final offsetPlus = FitLayout.calculate(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        verticalOffsetFraction:
            0.10, // Move down by 10% of freeSpace = 131.2 -> 131px
      );
      // center y is 656, 656 + 131 = 787
      expect(offsetPlus.y, inInclusiveRange(780, 794));

      // Test extreme clamping: +0.50 should clamp to +0.20
      final offsetClamped = FitLayout.calculate(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        verticalOffsetFraction: 0.50,
      );
      // max offset is 0.20 * 1312 = 262.4 -> 656 + 262 = 918
      expect(offsetClamped.y, inInclusiveRange(910, 924));
    });

    test('12. Crop to Fill mode fills canvas completely without padding', () {
      final cropLayout = FitLayout.calculate(
        sourceWidth: 1920,
        sourceHeight: 1080,
        canvasWidth: canvasW,
        canvasHeight: canvasH,
        fitMode: FitMode.cropToFill,
      );

      // In Crop to Fill, width scales up to cover canvas (3412), height is 1920
      expect(cropLayout.width, equals(3412));
      expect(cropLayout.height, equals(1920));
      expect(cropLayout.hasPadding, isFalse);
      expect(cropLayout.topBand, equals(0));
      expect(cropLayout.bottomBand, equals(0));
    });
  });
}
