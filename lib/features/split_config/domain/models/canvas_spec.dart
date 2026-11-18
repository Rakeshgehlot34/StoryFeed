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

/// Canvas specification encapsulating output resolution and aspect ratio.
class CanvasSpec {
  final CanvasFormat format;

  const CanvasSpec({this.format = CanvasFormat.shorts916});

  int get width => format.width;
  int get height => format.height;
  double get aspectRatio => format.aspectRatio;
  String? get warningMessage => format.warningMessage;

  CanvasSpec copyWith({CanvasFormat? format}) {
    return CanvasSpec(format: format ?? this.format);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasSpec &&
          runtimeType == other.runtimeType &&
          format == other.format;

  @override
  int get hashCode => format.hashCode;
}
