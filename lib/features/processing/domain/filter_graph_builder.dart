import '../../split_config/domain/models/background_spec.dart';
import '../../split_config/domain/models/canvas_spec.dart';
import '../../split_config/domain/models/fit_layout.dart';

/// Output from [FilterGraphBuilder] describing filter arguments and additional inputs.
class FilterGraphResult {
  final List<String>
      additionalInputArgs; // e.g. -loop 1 -i bg.png, -i overlay.png
  final String? filterComplex; // -filter_complex argument value
  final String?
      simpleFilter; // -vf argument value (when filter_complex not needed)
  final String outputVideoMap; // e.g. [outv] or 0:v
  final FitLayout? fitLayout;

  const FilterGraphResult({
    this.additionalInputArgs = const [],
    this.filterComplex,
    this.simpleFilter,
    required this.outputVideoMap,
    this.fitLayout,
  });
}

/// Pure, deterministic builder for FFmpeg video transformation filter graphs.
class FilterGraphBuilder {
  FilterGraphBuilder._();

  /// Determines if source video aspect ratio matches canvas aspect ratio within tolerance.
  /// Accounts for rotation metadata (90° and 270° swap effective width and height) and SAR.
  static bool matchesCanvasAspectRatio({
    required int sourceWidth,
    required int sourceHeight,
    required CanvasSpec canvasSpec,
    int rotationDegrees = 0,
    double sar = 1.0,
    double tolerance = 0.015,
  }) {
    if (sourceWidth <= 0 || sourceHeight <= 0) return true;
    final normRotation = (rotationDegrees % 360 + 360) % 360;
    final isSwapped = normRotation == 90 || normRotation == 270;
    final rawSw = isSwapped ? sourceHeight : sourceWidth;
    final rawSh = isSwapped ? sourceWidth : sourceHeight;
    final effectiveSw = (sar > 0.01 && (sar - 1.0).abs() > 0.01)
        ? (rawSw * sar).round()
        : rawSw;

    final sourceAspect = effectiveSw / rawSh;
    final canvasAspect = canvasSpec.aspectRatio;
    return (sourceAspect - canvasAspect).abs() <= tolerance;
  }

  /// Builds the complete FFmpeg filter configuration for a clip using [FitLayout] as single source of truth.
  static FilterGraphResult build({
    required int sourceWidth,
    required int sourceHeight,
    required CanvasSpec canvasSpec,
    required BackgroundSpec backgroundSpec,
    required bool cropToFill,
    int rotationDegrees = 0,
    double sar = 1.0,
    VerticalPosition verticalPosition = VerticalPosition.center,
    double verticalOffsetFraction = 0.0,
    String? overlayPngPath,
    bool displayWholeClip = true,
    double displayDurationSeconds = 3.0,
  }) {
    final cw = canvasSpec.width;
    final ch = canvasSpec.height;

    final fitLayout = FitLayout.calculate(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      canvasWidth: cw,
      canvasHeight: ch,
      rotationDegrees: rotationDegrees,
      sar: sar,
      fitMode: cropToFill ? FitMode.cropToFill : FitMode.fit,
      verticalPosition: verticalPosition,
      verticalOffsetFraction: verticalOffsetFraction,
    );

    final additionalInputs = <String>[];
    int nextInputIndex = 1; // 0 is source video

    // Case 1: Simple Crop to Fill
    if (cropToFill) {
      final cropFilter =
          'scale=$cw:$ch:force_original_aspect_ratio=increase,crop=$cw:$ch,setsar=1';
      return _attachOverlayIfNeeded(
        baseVideoFilter: cropFilter,
        isComplex: false,
        additionalInputs: additionalInputs,
        nextInputIndex: nextInputIndex,
        overlayPngPath: overlayPngPath,
        displayWholeClip: displayWholeClip,
        displayDurationSeconds: displayDurationSeconds,
        fitLayout: fitLayout,
      );
    }

    // Case 2: Source already matches canvas aspect ratio (no letterbox/pillarbox needed)
    if (fitLayout.isMatchesAspect && backgroundSpec is! ImageBackgroundSpec) {
      final fitFilter = 'scale=$cw:$ch,setsar=1';
      return _attachOverlayIfNeeded(
        baseVideoFilter: fitFilter,
        isComplex: false,
        additionalInputs: additionalInputs,
        nextInputIndex: nextInputIndex,
        overlayPngPath: overlayPngPath,
        displayWholeClip: displayWholeClip,
        displayDurationSeconds: displayDurationSeconds,
        fitLayout: fitLayout,
      );
    }

    // Case 3: Fit with Background Fill using exact FitLayout coordinates
    switch (backgroundSpec) {
      case SolidColorBackgroundSpec(:final colorValue):
        final hexColor = _formatFFmpegHexColor(colorValue);
        final padFilter = fitLayout.ffmpegPadFilter(hexColor);
        return _attachOverlayIfNeeded(
          baseVideoFilter: padFilter,
          isComplex: false,
          additionalInputs: additionalInputs,
          nextInputIndex: nextInputIndex,
          overlayPngPath: overlayPngPath,
          displayWholeClip: displayWholeClip,
          displayDurationSeconds: displayDurationSeconds,
          fitLayout: fitLayout,
        );

      case BlurBackgroundSpec():
        // High-performance downscaled background blur centered at canvas
        final tinyW = (cw / 10).round().clamp(64, 160);
        final tinyH = (ch / 10).round().clamp(96, 256);
        final blurComplex =
            '[0:v]scale=$tinyW:$tinyH:force_original_aspect_ratio=increase,crop=$tinyW:$tinyH,'
            'boxblur=5:1,scale=$cw:$ch:flags=bicubic[bg];'
            '[0:v]scale=${fitLayout.width}:${fitLayout.height}[fg];'
            '[bg][fg]overlay=${fitLayout.x}:${fitLayout.y},setsar=1[v_base]';

        return _attachOverlayToComplex(
          baseFilterComplex: blurComplex,
          baseVideoOutputTag: '[v_base]',
          additionalInputs: additionalInputs,
          nextInputIndex: nextInputIndex,
          overlayPngPath: overlayPngPath,
          displayWholeClip: displayWholeClip,
          displayDurationSeconds: displayDurationSeconds,
          fitLayout: fitLayout,
        );

      case ImageBackgroundSpec(:final imagePath):
        final bgInputIdx = nextInputIndex++;
        additionalInputs.addAll(['-loop', '1', '-i', imagePath]);

        final imageComplex =
            '[$bgInputIdx:v]scale=$cw:$ch:force_original_aspect_ratio=increase,crop=$cw:$ch[bg];'
            '[0:v]scale=${fitLayout.width}:${fitLayout.height}[fg];'
            '[bg][fg]overlay=${fitLayout.x}:${fitLayout.y}:shortest=1,setsar=1[v_base]';

        return _attachOverlayToComplex(
          baseFilterComplex: imageComplex,
          baseVideoOutputTag: '[v_base]',
          additionalInputs: additionalInputs,
          nextInputIndex: nextInputIndex,
          overlayPngPath: overlayPngPath,
          displayWholeClip: displayWholeClip,
          displayDurationSeconds: displayDurationSeconds,
          fitLayout: fitLayout,
        );
    }
  }

  static FilterGraphResult _attachOverlayIfNeeded({
    required String baseVideoFilter,
    required bool isComplex,
    required List<String> additionalInputs,
    required int nextInputIndex,
    String? overlayPngPath,
    required bool displayWholeClip,
    required double displayDurationSeconds,
    FitLayout? fitLayout,
  }) {
    if (overlayPngPath == null) {
      return FilterGraphResult(
        additionalInputArgs: additionalInputs,
        simpleFilter: baseVideoFilter,
        outputVideoMap: '0:v',
        fitLayout: fitLayout,
      );
    }

    final overlayInputIdx = nextInputIndex;
    additionalInputs.addAll(['-i', overlayPngPath]);

    final timingClause = displayWholeClip
        ? ''
        : ':enable=\'between(t,0,${displayDurationSeconds.toStringAsFixed(2)})\'';

    final filterComplex = '[0:v]$baseVideoFilter[v_base];'
        '[$overlayInputIdx:v]scale=in_w:in_h[ov];'
        '[v_base][ov]overlay=0:0$timingClause[outv]';

    return FilterGraphResult(
      additionalInputArgs: additionalInputs,
      filterComplex: filterComplex,
      outputVideoMap: '[outv]',
      fitLayout: fitLayout,
    );
  }

  static FilterGraphResult _attachOverlayToComplex({
    required String baseFilterComplex,
    required String baseVideoOutputTag,
    required List<String> additionalInputs,
    required int nextInputIndex,
    String? overlayPngPath,
    required bool displayWholeClip,
    required double displayDurationSeconds,
    FitLayout? fitLayout,
  }) {
    if (overlayPngPath == null) {
      return FilterGraphResult(
        additionalInputArgs: additionalInputs,
        filterComplex: baseFilterComplex.replaceAll(
          baseVideoOutputTag,
          '[outv]',
        ),
        outputVideoMap: '[outv]',
        fitLayout: fitLayout,
      );
    }

    final overlayInputIdx = nextInputIndex;
    additionalInputs.addAll(['-i', overlayPngPath]);

    final timingClause = displayWholeClip
        ? ''
        : ':enable=\'between(t,0,${displayDurationSeconds.toStringAsFixed(2)})\'';

    final fullComplex = '$baseFilterComplex;'
        '[$overlayInputIdx:v]scale=in_w:in_h[ov];'
        '$baseVideoOutputTag[ov]overlay=0:0$timingClause[outv]';

    return FilterGraphResult(
      additionalInputArgs: additionalInputs,
      filterComplex: fullComplex,
      outputVideoMap: '[outv]',
      fitLayout: fitLayout,
    );
  }

  static String _formatFFmpegHexColor(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final hex = '${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
    return '0x${hex.toUpperCase()}';
  }

  /// Compiles common video transformation filter stages:
  /// crop, orientation/flip, speed (setpts), color/contrast/saturation (eq),
  /// video fades, and reverse.
  static String? buildVideoFilterChain({
    int? cropX,
    int? cropY,
    int? cropWidth,
    int? cropHeight,
    int? rotationDegrees,
    bool hflip = false,
    bool vflip = false,
    double? speed,
    double? brightness,
    double? contrast,
    double? saturation,
    double? fadeInSeconds,
    double? fadeOutSeconds,
    double? totalDurationSeconds,
    bool reverse = false,
  }) {
    final filters = <String>[];

    // 1. Reverse
    if (reverse) {
      filters.add('reverse');
    }

    // 2. Crop
    if (cropWidth != null &&
        cropHeight != null &&
        cropWidth > 0 &&
        cropHeight > 0) {
      final x = cropX ?? 0;
      final y = cropY ?? 0;
      filters.add('crop=$cropWidth:$cropHeight:$x:$y');
    }

    // 3. Rotation
    if (rotationDegrees != null) {
      final normalized = (rotationDegrees % 360 + 360) % 360;
      if (normalized == 90) {
        filters.add('transpose=1');
      } else if (normalized == 180) {
        filters.add('transpose=2,transpose=2');
      } else if (normalized == 270) {
        filters.add('transpose=2');
      }
    }

    // 4. Flips
    if (hflip) filters.add('hflip');
    if (vflip) filters.add('vflip');

    // 5. Speed (setpts)
    if (speed != null && (speed - 1.0).abs() >= 0.0001 && speed > 0) {
      final ptsFactor = 1.0 / speed;
      filters.add('setpts=${ptsFactor.toStringAsPrecision(4)}*PTS');
    }

    // 6. Color eq
    final hasColor = (brightness != null && brightness != 0.0) ||
        (contrast != null && (contrast - 1.0).abs() >= 0.01) ||
        (saturation != null && (saturation - 1.0).abs() >= 0.01);
    if (hasColor) {
      final b = (brightness ?? 0.0).clamp(-1.0, 1.0);
      final c = (contrast ?? 1.0).clamp(0.0, 2.0);
      final s = (saturation ?? 1.0).clamp(0.0, 3.0);
      filters.add(
        'eq=brightness=${b.toStringAsFixed(2)}:contrast=${c.toStringAsFixed(2)}:saturation=${s.toStringAsFixed(2)}',
      );
    }

    // 7. Fades
    if (fadeInSeconds != null && fadeInSeconds > 0) {
      filters.add('fade=t=in:st=0:d=${fadeInSeconds.toStringAsFixed(3)}');
    }
    if (fadeOutSeconds != null &&
        fadeOutSeconds > 0 &&
        totalDurationSeconds != null &&
        totalDurationSeconds > fadeOutSeconds) {
      final st = totalDurationSeconds - fadeOutSeconds;
      filters.add(
        'fade=t=out:st=${st.toStringAsFixed(3)}:d=${fadeOutSeconds.toStringAsFixed(3)}',
      );
    }

    if (filters.isEmpty) return null;
    return filters.join(',');
  }
}
