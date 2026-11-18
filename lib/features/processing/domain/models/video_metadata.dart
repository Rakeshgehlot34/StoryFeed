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

  const VideoMetadata({
    required this.duration,
    required this.sizeInBytes,
    required this.width,
    required this.height,
    this.fps = 30.0,
    this.bitrate = 0,
    this.format = '',
    this.hasAudio = true,
  });

  double get aspectRatio => (width > 0 && height > 0) ? width / height : 16 / 9;
  bool get isVertical => height > width;
}
