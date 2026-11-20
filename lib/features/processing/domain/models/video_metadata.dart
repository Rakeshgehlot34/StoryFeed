/// Extracted technical metadata for a video stream.
class VideoMetadata {
  final Duration duration;
  final int sizeInBytes;
  final int width;
  final int height;
  final double fps;
  final int bitrate;
  final String format;
  final bool hasAudio;
  final int rotation;
  final double sar;

  const VideoMetadata({
    required this.duration,
    required this.sizeInBytes,
    required this.width,
    required this.height,
    this.fps = 30.0,
    this.bitrate = 0,
    this.format = '',
    this.hasAudio = true,
    this.rotation = 0,
    this.sar = 1.0,
  });

  /// Display width accounting for rotation and pixel aspect ratio.
  int get displayWidth {
    final norm = (rotation % 360 + 360) % 360;
    final w =
        (sar > 0 && (sar - 1.0).abs() > 0.001) ? (width * sar).round() : width;
    return (norm == 90 || norm == 270) ? height : w;
  }

  /// Display height accounting for rotation.
  int get displayHeight {
    final norm = (rotation % 360 + 360) % 360;
    final w =
        (sar > 0 && (sar - 1.0).abs() > 0.001) ? (width * sar).round() : width;
    return (norm == 90 || norm == 270) ? w : height;
  }

  double get aspectRatio => (displayWidth > 0 && displayHeight > 0)
      ? displayWidth / displayHeight
      : 16 / 9;

  bool get isVertical => displayHeight > displayWidth;
}
