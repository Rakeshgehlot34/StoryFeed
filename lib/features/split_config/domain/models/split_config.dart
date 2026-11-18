import '../../../../app/constants.dart';
import 'background_spec.dart';
import 'canvas_spec.dart';
import 'overlay_spec.dart';
import 'trim_range.dart';

enum SplitMode {
  /// Stream copy (-c copy): blazing fast, cuts at nearest keyframes, no re-encoding.
  fast,

  /// Re-encode (-c:v libx264): frame-accurate cuts, supports cropping and filters.
  precise,
}

enum AspectRatioOption {
  /// Keep original video aspect ratio (16:9, 4:3, etc.)
  original,

  /// Center-crop to 9:16 vertical (standard YouTube Shorts full bleed)
  cropVertical,

  /// 9:16 vertical canvas with blurred background & centered original video
  blurVertical,
}

/// User-configured parameters for video splitting and output canvas styling.
class SplitConfig {
  final int targetDurationSeconds;
  final SplitMode mode;
  final CanvasSpec canvasSpec;
  final BackgroundSpec backgroundSpec;
  final OverlaySpec overlaySpec;
  final bool cropToFill;
  final bool mergeShortTrailingClip;
  final TrimRange? trimRange;
  final String? customBaseName;

  const SplitConfig({
    this.targetDurationSeconds = AppConstants.defaultClipDurationSeconds,
    this.mode = SplitMode.fast,
    this.canvasSpec = const CanvasSpec(),
    this.backgroundSpec = BackgroundSpec.defaultSpec,
    this.overlaySpec = const OverlaySpec(),
    this.cropToFill = false,
    this.mergeShortTrailingClip = true,
    this.trimRange,
    this.customBaseName,
  });

  /// Compatibility getter for legacy aspect ratio enum.
  AspectRatioOption get aspectRatio {
    if (cropToFill) {
      return AspectRatioOption.cropVertical;
    }
    if (backgroundSpec is BlurBackgroundSpec) {
      return AspectRatioOption.blurVertical;
    }
    return AspectRatioOption.original;
  }

  /// When visual transforms (canvas formatting, crop, background fill, or text overlay)
  /// or precise trim timestamps are active, FFmpeg MUST re-encode.
  bool get requiresReencode =>
      mode == SplitMode.precise ||
      cropToFill ||
      backgroundSpec is! SolidColorBackgroundSpec ||
      overlaySpec.autoLabel ||
      overlaySpec.allPartsMessage != null ||
      trimRange != null;

  SplitConfig copyWith({
    int? targetDurationSeconds,
    SplitMode? mode,
    CanvasSpec? canvasSpec,
    BackgroundSpec? backgroundSpec,
    OverlaySpec? overlaySpec,
    bool? cropToFill,
    bool? mergeShortTrailingClip,
    TrimRange? trimRange,
    String? customBaseName,
  }) {
    return SplitConfig(
      targetDurationSeconds:
          targetDurationSeconds ?? this.targetDurationSeconds,
      mode: mode ?? this.mode,
      canvasSpec: canvasSpec ?? this.canvasSpec,
      backgroundSpec: backgroundSpec ?? this.backgroundSpec,
      overlaySpec: overlaySpec ?? this.overlaySpec,
      cropToFill: cropToFill ?? this.cropToFill,
      mergeShortTrailingClip:
          mergeShortTrailingClip ?? this.mergeShortTrailingClip,
      trimRange: trimRange ?? this.trimRange,
      customBaseName: customBaseName ?? this.customBaseName,
    );
  }
}
