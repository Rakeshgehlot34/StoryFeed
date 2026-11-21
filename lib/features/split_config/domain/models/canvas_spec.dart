/// Supported canvas formats for video output.
enum CanvasFormat {
  shorts916,
  square11,
  landscape169;

  String get label => switch (this) {
        CanvasFormat.shorts916 => '9:16 Vertical (Shorts)',
        CanvasFormat.square11 => '1:1 Square',
        CanvasFormat.landscape169 => '16:9 Landscape',
      };

  int get width => switch (this) {
        CanvasFormat.shorts916 => 1080,
        CanvasFormat.square11 => 1080,
        CanvasFormat.landscape169 => 1920,
      };

  int get height => switch (this) {
        CanvasFormat.shorts916 => 1920,
        CanvasFormat.square11 => 1080,
        CanvasFormat.landscape169 => 1080,
      };

  double get aspectRatio => width / height;

  bool get isRecommendedForShorts => this == CanvasFormat.shorts916;

  String? get warningMessage => switch (this) {
        CanvasFormat.landscape169 =>
          '16:9 Landscape is not recommended for YouTube Shorts or Reels.',
        _ => null,
      };
}

/// Target canvas resolution for video output.
enum CanvasResolution {
  standard1080p,
  ultraHd4k;

  String get label => switch (this) {
        CanvasResolution.standard1080p => '1080p (Full HD)',
        CanvasResolution.ultraHd4k => '4K (Ultra HD)',
      };

  int get scaleMultiplier => switch (this) {
        CanvasResolution.standard1080p => 1,
        CanvasResolution.ultraHd4k => 2,
      };

  int get crf => switch (this) {
        CanvasResolution.standard1080p => 22,
        CanvasResolution.ultraHd4k => 18,
      };

  String get h264Level => switch (this) {
        CanvasResolution.standard1080p => '4.1',
        CanvasResolution.ultraHd4k => '5.1',
      };

  String get audioBitrate => switch (this) {
        CanvasResolution.standard1080p => '192k',
        CanvasResolution.ultraHd4k => '320k',
      };
}

/// Canvas specification encapsulating output resolution and aspect ratio.
class CanvasSpec {
  final CanvasFormat format;
  final CanvasResolution resolution;

  const CanvasSpec({
    this.format = CanvasFormat.shorts916,
    this.resolution = CanvasResolution.standard1080p,
  });

  int get width => format.width * resolution.scaleMultiplier;
  int get height => format.height * resolution.scaleMultiplier;
  double get aspectRatio => format.aspectRatio;
  String? get warningMessage => format.warningMessage;

  CanvasSpec copyWith({
    CanvasFormat? format,
    CanvasResolution? resolution,
  }) {
    return CanvasSpec(
      format: format ?? this.format,
      resolution: resolution ?? this.resolution,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasSpec &&
          runtimeType == other.runtimeType &&
          format == other.format &&
          resolution == other.resolution;

  @override
  int get hashCode => Object.hash(format, resolution);
}
