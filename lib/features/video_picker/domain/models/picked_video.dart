import '../../../../core/utils/formatters.dart';

/// Domain model representing a user-selected video file with its extracted metadata.
class PickedVideo {
  final String path;
  final String fileName;
  final String baseName;
  final Duration duration;
  final int sizeInBytes;
  final int width;
  final int height;
  final double fps;
  final String? mimeType;

  const PickedVideo({
    required this.path,
    required this.fileName,
    required this.baseName,
    required this.duration,
    required this.sizeInBytes,
    required this.width,
    required this.height,
    this.fps = 30.0,
    this.mimeType,
  });

  String get formattedDuration => Formatters.formatDuration(duration);
  String get formattedSize => Formatters.formatFileSize(sizeInBytes);
  String get resolution =>
      (width > 0 && height > 0) ? '${width}x$height' : 'Unknown';
  double get aspectRatio => (width > 0 && height > 0) ? width / height : 16 / 9;
  bool get isVertical => height > width;

  PickedVideo copyWith({
    String? path,
    String? fileName,
    String? baseName,
    Duration? duration,
    int? sizeInBytes,
    int? width,
    int? height,
    double? fps,
    String? mimeType,
  }) {
    return PickedVideo(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      baseName: baseName ?? this.baseName,
      duration: duration ?? this.duration,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      mimeType: mimeType ?? this.mimeType,
    );
  }
}
