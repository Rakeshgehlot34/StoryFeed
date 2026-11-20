import '../../../../core/errors/app_exception.dart';

/// Aspect ratio canvas formats supported by the editor.
enum TargetAspectRatio { original, vertical916, square11, landscape169 }

extension TargetAspectRatioExtension on TargetAspectRatio {
  String get label => switch (this) {
        TargetAspectRatio.original => 'Original',
        TargetAspectRatio.vertical916 => '9:16 (Shorts/Reels)',
        TargetAspectRatio.square11 => '1:1 (Square)',
        TargetAspectRatio.landscape169 => '16:9 (Landscape)',
      };

  (int width, int height) get dimensions => switch (this) {
        TargetAspectRatio.original => (0, 0),
        TargetAspectRatio.vertical916 => (1080, 1920),
        TargetAspectRatio.square11 => (1080, 1080),
        TargetAspectRatio.landscape169 => (1920, 1080),
      };
}

/// Canvas background fit strategies when source doesn't match target aspect ratio.
enum CanvasFitMode { fitWithColor, fitWithBlur, cropToFill }

extension CanvasFitModeExtension on CanvasFitMode {
  String get label => switch (this) {
        CanvasFitMode.fitWithColor => 'Solid Color',
        CanvasFitMode.fitWithBlur => 'Blurred Background',
        CanvasFitMode.cropToFill => 'Crop to Fill',
      };
}

/// Position options for watermarks and text badges.
enum OverlayPosition { topLeft, topRight, bottomLeft, bottomRight, center }

extension OverlayPositionExtension on OverlayPosition {
  String get label => switch (this) {
        OverlayPosition.topLeft => 'Top Left',
        OverlayPosition.topRight => 'Top Right',
        OverlayPosition.bottomLeft => 'Bottom Left',
        OverlayPosition.bottomRight => 'Bottom Right',
        OverlayPosition.center => 'Center',
      };

  String get ffmpegCoordinates => switch (this) {
        OverlayPosition.topLeft => '20:20',
        OverlayPosition.topRight => 'W-w-20:20',
        OverlayPosition.bottomLeft => '20:H-h-20',
        OverlayPosition.bottomRight => 'W-w-20:H-h-20',
        OverlayPosition.center => '(W-w)/2:(H-h)/2',
      };
}

/// Color filter presets for quick aesthetic adjustments.
enum ColorFilterPreset { none, vibrant, cinematic, vintage, bw }

extension ColorFilterPresetExtension on ColorFilterPreset {
  String get label => switch (this) {
        ColorFilterPreset.none => 'None',
        ColorFilterPreset.vibrant => 'Vibrant',
        ColorFilterPreset.cinematic => 'Cinematic',
        ColorFilterPreset.vintage => 'Vintage',
        ColorFilterPreset.bw => 'B & W',
      };
}

/// Trimming bounds.
class TrimConfig {
  final double startSeconds;
  final double endSeconds;

  const TrimConfig({this.startSeconds = 0.0, this.endSeconds = 0.0});

  double get duration =>
      (endSeconds > startSeconds) ? (endSeconds - startSeconds) : 0.0;

  TrimConfig copyWith({double? startSeconds, double? endSeconds}) => TrimConfig(
        startSeconds: startSeconds ?? this.startSeconds,
        endSeconds: endSeconds ?? this.endSeconds,
      );

  Map<String, dynamic> toJson() => {
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
      };

  factory TrimConfig.fromJson(Map<String, dynamic> json) => TrimConfig(
        startSeconds: (json['startSeconds'] as num?)?.toDouble() ?? 0.0,
        endSeconds: (json['endSeconds'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Transformation specs (crop, rotation, mirror flips).
class TransformSpec {
  final int? cropX;
  final int? cropY;
  final int? cropWidth;
  final int? cropHeight;
  final int rotationDegrees; // 0, 90, 180, 270
  final bool hflip;
  final bool vflip;

  const TransformSpec({
    this.cropX,
    this.cropY,
    this.cropWidth,
    this.cropHeight,
    this.rotationDegrees = 0,
    this.hflip = false,
    this.vflip = false,
  });

  bool get hasCrop =>
      cropWidth != null &&
      cropHeight != null &&
      cropWidth! > 0 &&
      cropHeight! > 0;
  bool get hasTransform => hasCrop || rotationDegrees != 0 || hflip || vflip;

  TransformSpec copyWith({
    int? cropX,
    int? cropY,
    int? cropWidth,
    int? cropHeight,
    int? rotationDegrees,
    bool? hflip,
    bool? vflip,
  }) =>
      TransformSpec(
        cropX: cropX ?? this.cropX,
        cropY: cropY ?? this.cropY,
        cropWidth: cropWidth ?? this.cropWidth,
        cropHeight: cropHeight ?? this.cropHeight,
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        hflip: hflip ?? this.hflip,
        vflip: vflip ?? this.vflip,
      );

  Map<String, dynamic> toJson() => {
        'cropX': cropX,
        'cropY': cropY,
        'cropWidth': cropWidth,
        'cropHeight': cropHeight,
        'rotationDegrees': rotationDegrees,
        'hflip': hflip,
        'vflip': vflip,
      };

  factory TransformSpec.fromJson(Map<String, dynamic> json) => TransformSpec(
        cropX: json['cropX'] as int?,
        cropY: json['cropY'] as int?,
        cropWidth: json['cropWidth'] as int?,
        cropHeight: json['cropHeight'] as int?,
        rotationDegrees: json['rotationDegrees'] as int? ?? 0,
        hflip: json['hflip'] as bool? ?? false,
        vflip: json['vflip'] as bool? ?? false,
      );
}

/// Canvas configuration.
class CanvasConfig {
  final TargetAspectRatio aspectRatio;
  final CanvasFitMode fitMode;
  final int backgroundColorHex;

  const CanvasConfig({
    this.aspectRatio = TargetAspectRatio.original,
    this.fitMode = CanvasFitMode.fitWithColor,
    this.backgroundColorHex = 0xFF000000,
  });

  CanvasConfig copyWith({
    TargetAspectRatio? aspectRatio,
    CanvasFitMode? fitMode,
    int? backgroundColorHex,
  }) =>
      CanvasConfig(
        aspectRatio: aspectRatio ?? this.aspectRatio,
        fitMode: fitMode ?? this.fitMode,
        backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      );

  Map<String, dynamic> toJson() => {
        'aspectRatio': aspectRatio.name,
        'fitMode': fitMode.name,
        'backgroundColorHex': backgroundColorHex,
      };

  factory CanvasConfig.fromJson(Map<String, dynamic> json) => CanvasConfig(
        aspectRatio: TargetAspectRatio.values.byName(
          json['aspectRatio'] as String? ?? 'original',
        ),
        fitMode: CanvasFitMode.values.byName(
          json['fitMode'] as String? ?? 'fitWithColor',
        ),
        backgroundColorHex: json['backgroundColorHex'] as int? ?? 0xFF000000,
      );
}

/// Playback speed and audio pitch preservation.
class SpeedSpec {
  final double speed; // 0.25 to 4.0
  final bool preservePitch;

  const SpeedSpec({this.speed = 1.0, this.preservePitch = true});

  bool get isModified => (speed - 1.0).abs() >= 0.001;

  SpeedSpec copyWith({double? speed, bool? preservePitch}) => SpeedSpec(
        speed: speed ?? this.speed,
        preservePitch: preservePitch ?? this.preservePitch,
      );

  Map<String, dynamic> toJson() => {
        'speed': speed,
        'preservePitch': preservePitch,
      };

  factory SpeedSpec.fromJson(Map<String, dynamic> json) => SpeedSpec(
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        preservePitch: json['preservePitch'] as bool? ?? true,
      );
}

/// Color correction and grading.
class ColorFilterSpec {
  final double brightness; // -1.0 to 1.0, default 0.0
  final double contrast; // 0.0 to 2.0, default 1.0
  final double saturation; // 0.0 to 3.0, default 1.0
  final ColorFilterPreset preset;

  const ColorFilterSpec({
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.preset = ColorFilterPreset.none,
  });

  bool get isModified =>
      brightness != 0.0 ||
      (contrast - 1.0).abs() >= 0.01 ||
      (saturation - 1.0).abs() >= 0.01 ||
      preset != ColorFilterPreset.none;

  ColorFilterSpec copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    ColorFilterPreset? preset,
  }) =>
      ColorFilterSpec(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        preset: preset ?? this.preset,
      );

  Map<String, dynamic> toJson() => {
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'preset': preset.name,
      };

  factory ColorFilterSpec.fromJson(Map<String, dynamic> json) =>
      ColorFilterSpec(
        brightness: (json['brightness'] as num?)?.toDouble() ?? 0.0,
        contrast: (json['contrast'] as num?)?.toDouble() ?? 1.0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 1.0,
        preset: ColorFilterPreset.values.byName(
          json['preset'] as String? ?? 'none',
        ),
      );
}

/// Transition fades for video and audio.
class FadeSpec {
  final double fadeInSeconds;
  final double fadeOutSeconds;
  final bool fadeAudio;

  const FadeSpec({
    this.fadeInSeconds = 0.0,
    this.fadeOutSeconds = 0.0,
    this.fadeAudio = true,
  });

  bool get hasFade => fadeInSeconds > 0 || fadeOutSeconds > 0;

  FadeSpec copyWith({
    double? fadeInSeconds,
    double? fadeOutSeconds,
    bool? fadeAudio,
  }) =>
      FadeSpec(
        fadeInSeconds: fadeInSeconds ?? this.fadeInSeconds,
        fadeOutSeconds: fadeOutSeconds ?? this.fadeOutSeconds,
        fadeAudio: fadeAudio ?? this.fadeAudio,
      );

  Map<String, dynamic> toJson() => {
        'fadeInSeconds': fadeInSeconds,
        'fadeOutSeconds': fadeOutSeconds,
        'fadeAudio': fadeAudio,
      };

  factory FadeSpec.fromJson(Map<String, dynamic> json) => FadeSpec(
        fadeInSeconds: (json['fadeInSeconds'] as num?)?.toDouble() ?? 0.0,
        fadeOutSeconds: (json['fadeOutSeconds'] as num?)?.toDouble() ?? 0.0,
        fadeAudio: json['fadeAudio'] as bool? ?? true,
      );
}

/// Watermark image overlay.
class WatermarkSpec {
  final String imagePath;
  final OverlayPosition position;
  final double opacity; // 0.1 to 1.0
  final double scale; // fraction of video width (0.05 to 0.4)

  const WatermarkSpec({
    required this.imagePath,
    this.position = OverlayPosition.topRight,
    this.opacity = 0.8,
    this.scale = 0.15,
  });

  WatermarkSpec copyWith({
    String? imagePath,
    OverlayPosition? position,
    double? opacity,
    double? scale,
  }) =>
      WatermarkSpec(
        imagePath: imagePath ?? this.imagePath,
        position: position ?? this.position,
        opacity: opacity ?? this.opacity,
        scale: scale ?? this.scale,
      );

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'position': position.name,
        'opacity': opacity,
        'scale': scale,
      };

  factory WatermarkSpec.fromJson(Map<String, dynamic> json) => WatermarkSpec(
        imagePath: json['imagePath'] as String,
        position: OverlayPosition.values.byName(
          json['position'] as String? ?? 'topRight',
        ),
        opacity: (json['opacity'] as num?)?.toDouble() ?? 0.8,
        scale: (json['scale'] as num?)?.toDouble() ?? 0.15,
      );
}

/// Text overlay badge.
class TextOverlaySpec {
  final String text;
  final OverlayPosition position;
  final int fontSize;
  final int fontColorHex;
  final int? backgroundColorHex;

  const TextOverlaySpec({
    required this.text,
    this.position = OverlayPosition.bottomRight,
    this.fontSize = 28,
    this.fontColorHex = 0xFFFFFFFF,
    this.backgroundColorHex = 0x80000000,
  });

  TextOverlaySpec copyWith({
    String? text,
    OverlayPosition? position,
    int? fontSize,
    int? fontColorHex,
    int? backgroundColorHex,
  }) =>
      TextOverlaySpec(
        text: text ?? this.text,
        position: position ?? this.position,
        fontSize: fontSize ?? this.fontSize,
        fontColorHex: fontColorHex ?? this.fontColorHex,
        backgroundColorHex: backgroundColorHex ?? this.backgroundColorHex,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'position': position.name,
        'fontSize': fontSize,
        'fontColorHex': fontColorHex,
        'backgroundColorHex': backgroundColorHex,
      };

  factory TextOverlaySpec.fromJson(Map<String, dynamic> json) =>
      TextOverlaySpec(
        text: json['text'] as String,
        position: OverlayPosition.values.byName(
          json['position'] as String? ?? 'bottomRight',
        ),
        fontSize: json['fontSize'] as int? ?? 28,
        fontColorHex: json['fontColorHex'] as int? ?? 0xFFFFFFFF,
        backgroundColorHex: json['backgroundColorHex'] as int?,
      );
}

/// Complete non-destructive project representation for the Studio Video Editor.
class EditProject {
  final String id;
  final String title;
  final String sourceVideoPath;
  final String sourceVideoName;
  final double sourceDurationSeconds;
  final int sourceWidth;
  final int sourceHeight;
  final TrimConfig trim;
  final TransformSpec transform;
  final CanvasConfig canvas;
  final SpeedSpec speed;
  final ColorFilterSpec color;
  final FadeSpec fade;
  final WatermarkSpec? watermark;
  final TextOverlaySpec? textOverlay;
  final bool reverse;

  const EditProject({
    required this.id,
    required this.title,
    required this.sourceVideoPath,
    required this.sourceVideoName,
    required this.sourceDurationSeconds,
    required this.sourceWidth,
    required this.sourceHeight,
    this.trim = const TrimConfig(),
    this.transform = const TransformSpec(),
    this.canvas = const CanvasConfig(),
    this.speed = const SpeedSpec(),
    this.color = const ColorFilterSpec(),
    this.fade = const FadeSpec(),
    this.watermark,
    this.textOverlay,
    this.reverse = false,
  });

  double get activeTrimDuration => (trim.endSeconds > trim.startSeconds)
      ? (trim.endSeconds - trim.startSeconds)
      : sourceDurationSeconds;

  double get outputDuration =>
      speed.speed > 0 ? (activeTrimDuration / speed.speed) : activeTrimDuration;

  bool get isReverseAllowed => activeTrimDuration <= 15.0;

  void validate() {
    if (sourceDurationSeconds <= 0) {
      throw const PlanValidationException(
        'Source video duration must be greater than zero.',
      );
    }
    if (activeTrimDuration < 0.5) {
      throw const PlanValidationException(
        'Trim duration must be at least 0.5 seconds.',
      );
    }
    if (reverse && !isReverseAllowed) {
      throw const PlanValidationException(
        'Reverse playback is strictly limited to video clips of 15 seconds or shorter to prevent device memory exhaustion.',
      );
    }
    if (speed.speed < 0.25 || speed.speed > 4.0) {
      throw const PlanValidationException(
        'Speed must be bounded within [0.25x, 4.0x].',
      );
    }
  }

  EditProject copyWith({
    String? id,
    String? title,
    String? sourceVideoPath,
    String? sourceVideoName,
    double? sourceDurationSeconds,
    int? sourceWidth,
    int? sourceHeight,
    TrimConfig? trim,
    TransformSpec? transform,
    CanvasConfig? canvas,
    SpeedSpec? speed,
    ColorFilterSpec? color,
    FadeSpec? fade,
    WatermarkSpec? watermark,
    bool clearWatermark = false,
    TextOverlaySpec? textOverlay,
    bool clearTextOverlay = false,
    bool? reverse,
  }) =>
      EditProject(
        id: id ?? this.id,
        title: title ?? this.title,
        sourceVideoPath: sourceVideoPath ?? this.sourceVideoPath,
        sourceVideoName: sourceVideoName ?? this.sourceVideoName,
        sourceDurationSeconds:
            sourceDurationSeconds ?? this.sourceDurationSeconds,
        sourceWidth: sourceWidth ?? this.sourceWidth,
        sourceHeight: sourceHeight ?? this.sourceHeight,
        trim: trim ?? this.trim,
        transform: transform ?? this.transform,
        canvas: canvas ?? this.canvas,
        speed: speed ?? this.speed,
        color: color ?? this.color,
        fade: fade ?? this.fade,
        watermark: clearWatermark ? null : (watermark ?? this.watermark),
        textOverlay:
            clearTextOverlay ? null : (textOverlay ?? this.textOverlay),
        reverse: reverse ?? this.reverse,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sourceVideoPath': sourceVideoPath,
        'sourceVideoName': sourceVideoName,
        'sourceDurationSeconds': sourceDurationSeconds,
        'sourceWidth': sourceWidth,
        'sourceHeight': sourceHeight,
        'trim': trim.toJson(),
        'transform': transform.toJson(),
        'canvas': canvas.toJson(),
        'speed': speed.toJson(),
        'color': color.toJson(),
        'fade': fade.toJson(),
        'watermark': watermark?.toJson(),
        'textOverlay': textOverlay?.toJson(),
        'reverse': reverse,
      };

  factory EditProject.fromJson(Map<String, dynamic> json) => EditProject(
        id: json['id'] as String,
        title: json['title'] as String,
        sourceVideoPath: json['sourceVideoPath'] as String,
        sourceVideoName: json['sourceVideoName'] as String,
        sourceDurationSeconds:
            (json['sourceDurationSeconds'] as num).toDouble(),
        sourceWidth: json['sourceWidth'] as int,
        sourceHeight: json['sourceHeight'] as int,
        trim: TrimConfig.fromJson(json['trim'] as Map<String, dynamic>),
        transform: TransformSpec.fromJson(
          json['transform'] as Map<String, dynamic>,
        ),
        canvas: CanvasConfig.fromJson(json['canvas'] as Map<String, dynamic>),
        speed: SpeedSpec.fromJson(json['speed'] as Map<String, dynamic>),
        color: ColorFilterSpec.fromJson(json['color'] as Map<String, dynamic>),
        fade: FadeSpec.fromJson(json['fade'] as Map<String, dynamic>),
        watermark: json['watermark'] != null
            ? WatermarkSpec.fromJson(json['watermark'] as Map<String, dynamic>)
            : null,
        textOverlay: json['textOverlay'] != null
            ? TextOverlaySpec.fromJson(
                json['textOverlay'] as Map<String, dynamic>,
              )
            : null,
        reverse: json['reverse'] as bool? ?? false,
      );
}
