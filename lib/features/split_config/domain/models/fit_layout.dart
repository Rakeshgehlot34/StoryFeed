/// Fit mode specifying whether to scale to fit with padding or crop to fill canvas.
enum FitMode {
  fit,
  cropToFill;

  String get label => switch (this) {
        FitMode.fit => 'Fit (Pillarbox/Letterbox)',
        FitMode.cropToFill => 'Crop to Fill',
      };
}

/// Vertical alignment options for video placement on canvas.
enum VerticalPosition {
  center,
  top,
  bottom;

  String get label => switch (this) {
        VerticalPosition.center => 'Center',
        VerticalPosition.top => 'Top',
        VerticalPosition.bottom => 'Bottom',
      };
}

/// Pure mathematical layout specification defining exact integer pixel coordinates
/// and normalized bounding boxes for video rendering and FFmpeg filter compilation.
///
/// Shared single source of truth used by both Flutter live preview and FilterGraphBuilder.
class FitLayout {
  final int x;
  final int y;
  final int width;
  final int height;
  final int canvasWidth;
  final int canvasHeight;
  final int topBand;
  final int bottomBand;
  final int leftBand;
  final int rightBand;
  final double normalizedX;
  final double normalizedY;
  final double normalizedWidth;
  final double normalizedHeight;
  final bool isMatchesAspect;
  final bool hasPadding;

  const FitLayout({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.topBand,
    required this.bottomBand,
    required this.leftBand,
    required this.rightBand,
    required this.normalizedX,
    required this.normalizedY,
    required this.normalizedWidth,
    required this.normalizedHeight,
    required this.isMatchesAspect,
    required this.hasPadding,
  });

  /// Calculates deterministic, integer-even pixel geometry for placing a video of
  /// [sourceWidth] x [sourceHeight] into a canvas of [canvasWidth] x [canvasHeight].
  static FitLayout calculate({
    required int sourceWidth,
    required int sourceHeight,
    required int canvasWidth,
    required int canvasHeight,
    int rotationDegrees = 0,
    double sar = 1.0,
    FitMode fitMode = FitMode.fit,
    VerticalPosition verticalPosition = VerticalPosition.center,
    double verticalOffsetFraction = 0.0,
    double aspectTolerance = 0.015,
  }) {
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        canvasWidth <= 0 ||
        canvasHeight <= 0) {
      return FitLayout._fallback(canvasWidth, canvasHeight);
    }

    // 1. Account for rotation metadata (90° and 270° swap effective width and height)
    final normRotation = (rotationDegrees % 360 + 360) % 360;
    final isSwapped = normRotation == 90 || normRotation == 270;
    final rawSw = isSwapped ? sourceHeight : sourceWidth;
    final rawSh = isSwapped ? sourceWidth : sourceHeight;

    // 2. Account for Sample Aspect Ratio (non-square pixel anamorphic stretching)
    final effectiveSw = (sar > 0.01 && (sar - 1.0).abs() > 0.01)
        ? (rawSw * sar).round()
        : rawSw;
    final effectiveSh = rawSh;

    final sourceAspect = effectiveSw / effectiveSh;
    final canvasAspect = canvasWidth / canvasHeight;
    final isMatchesAspect =
        (sourceAspect - canvasAspect).abs() <= aspectTolerance;

    // Case A: Source matches canvas aspect ratio
    if (isMatchesAspect && fitMode == FitMode.fit) {
      final w = _makeEven(canvasWidth);
      final h = _makeEven(canvasHeight);
      return FitLayout(
        x: 0,
        y: 0,
        width: w,
        height: h,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        topBand: 0,
        bottomBand: 0,
        leftBand: 0,
        rightBand: 0,
        normalizedX: 0.0,
        normalizedY: 0.0,
        normalizedWidth: 1.0,
        normalizedHeight: 1.0,
        isMatchesAspect: true,
        hasPadding: false,
      );
    }

    // Case B: Crop to Fill
    if (fitMode == FitMode.cropToFill) {
      int scaledW;
      int scaledH;
      if (sourceAspect > canvasAspect) {
        // Source is wider: fit height, crop sides
        scaledH = _makeEven(canvasHeight);
        scaledW = _makeEven((canvasHeight * sourceAspect).round());
      } else {
        // Source is taller: fit width, crop top/bottom
        scaledW = _makeEven(canvasWidth);
        scaledH = _makeEven((canvasWidth / sourceAspect).round());
      }

      return FitLayout(
        x: 0,
        y: 0,
        width: scaledW,
        height: scaledH,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        topBand: 0,
        bottomBand: 0,
        leftBand: 0,
        rightBand: 0,
        normalizedX: 0.0,
        normalizedY: 0.0,
        normalizedWidth: 1.0,
        normalizedHeight: 1.0,
        isMatchesAspect: isMatchesAspect,
        hasPadding: false,
      );
    }

    // Case C: Scale to Fit (Letterbox or Pillarbox)
    int scaledW;
    int scaledH;

    if (sourceAspect > canvasAspect) {
      // Letterbox (black/background bands on top & bottom)
      scaledW = _makeEven(canvasWidth);
      scaledH = _makeEven(
        (canvasWidth / sourceAspect).round().clamp(2, canvasHeight),
      );
    } else {
      // Pillarbox (black/background bands on left & right)
      scaledH = _makeEven(canvasHeight);
      scaledW = _makeEven(
        (canvasHeight * sourceAspect).round().clamp(2, canvasWidth),
      );
    }

    final freeSpaceX = canvasWidth - scaledW;
    final freeSpaceY = canvasHeight - scaledH;

    // Horizontal is always centered unless canvas is wider than video
    final x = _makeEven((freeSpaceX / 2.0).round().clamp(0, freeSpaceX));

    // Vertical position and manual offset (-20% to +20% of free vertical space)
    final clampedOffset = verticalOffsetFraction.clamp(-0.20, 0.20);
    double targetY;

    switch (verticalPosition) {
      case VerticalPosition.center:
        targetY = (freeSpaceY / 2.0) + (freeSpaceY * clampedOffset);
      case VerticalPosition.top:
        targetY = 0.0 + (freeSpaceY * clampedOffset.clamp(0.0, 0.20));
      case VerticalPosition.bottom:
        targetY = freeSpaceY + (freeSpaceY * clampedOffset.clamp(-0.20, 0.0));
    }

    final y = _makeEven(targetY.round().clamp(0, freeSpaceY));

    final topBand = y;
    final bottomBand = canvasHeight - (y + scaledH);
    final leftBand = x;
    final rightBand = canvasWidth - (x + scaledW);

    return FitLayout(
      x: x,
      y: y,
      width: scaledW,
      height: scaledH,
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      topBand: topBand,
      bottomBand: bottomBand,
      leftBand: leftBand,
      rightBand: rightBand,
      normalizedX: canvasWidth > 0 ? x / canvasWidth : 0.0,
      normalizedY: canvasHeight > 0 ? y / canvasHeight : 0.0,
      normalizedWidth: canvasWidth > 0 ? scaledW / canvasWidth : 1.0,
      normalizedHeight: canvasHeight > 0 ? scaledH / canvasHeight : 1.0,
      isMatchesAspect: isMatchesAspect,
      hasPadding:
          topBand > 0 || bottomBand > 0 || leftBand > 0 || rightBand > 0,
    );
  }

  static int _makeEven(int val) {
    if (val <= 0) return 0;
    return (val % 2 == 0) ? val : val - 1;
  }

  static FitLayout _fallback(int cw, int ch) {
    final w = cw > 0 ? _makeEven(cw) : 1080;
    final h = ch > 0 ? _makeEven(ch) : 1920;
    return FitLayout(
      x: 0,
      y: 0,
      width: w,
      height: h,
      canvasWidth: w,
      canvasHeight: h,
      topBand: 0,
      bottomBand: 0,
      leftBand: 0,
      rightBand: 0,
      normalizedX: 0.0,
      normalizedY: 0.0,
      normalizedWidth: 1.0,
      normalizedHeight: 1.0,
      isMatchesAspect: true,
      hasPadding: false,
    );
  }

  /// Generates the explicit FFmpeg pad filter string.
  /// Guarantees exact integer pixel alignment with zero default fallback reliance.
  String ffmpegPadFilter(String hexColor) {
    return 'scale=$width:$height,pad=$canvasWidth:$canvasHeight:$x:$y:color=$hexColor,setsar=1';
  }

  /// Generates the explicit FFmpeg overlay position string: e.g. "overlay=x:y".
  String ffmpegOverlayArgs({bool shortest = false}) {
    final suffix = shortest ? ':shortest=1' : '';
    return 'overlay=$x:$y$suffix,setsar=1';
  }

  @override
  String toString() =>
      'FitLayout(${width}x$height at ($x,$y), bands: [T:$topBand, B:$bottomBand, L:$leftBand, R:$rightBand], canvas: ${canvasWidth}x$canvasHeight)';
}
