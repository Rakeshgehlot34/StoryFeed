/// Output image format for captured screenshots.
enum ScreenshotImageFormat {
  png('PNG (Lossless)', '.png', 'image/png'),
  jpeg('JPEG (Compressed)', '.jpg', 'image/jpeg');

  final String displayName;
  final String extension;
  final String mimeType;

  const ScreenshotImageFormat(this.displayName, this.extension, this.mimeType);

  static ScreenshotImageFormat fromExtension(String ext) {
    final cleanExt = ext.toLowerCase().replaceAll('.', '');
    if (cleanExt == 'jpg' || cleanExt == 'jpeg') {
      return ScreenshotImageFormat.jpeg;
    }
    return ScreenshotImageFormat.png;
  }
}

/// Mode of capturing screenshots.
enum ScreenshotCaptureMode {
  /// Single instant capture at current playhead position.
  single('Instant Snap', 'Capture frame at current playhead position'),

  /// Capture a user-defined list of specific timestamps.
  timestamps('Timestamps', 'Capture a list of selected timestamps'),

  /// Batch extraction at uniform time intervals or frame counts.
  interval('Interval', 'Extract frames at periodic intervals across video');

  final String label;
  final String description;

  const ScreenshotCaptureMode(this.label, this.description);
}

/// Interval extraction strategy.
enum IntervalType {
  /// Capture every X seconds.
  byDuration('Every X Seconds'),

  /// Capture N evenly spaced frames across the video range.
  byCount('N Equal Frames');

  final String label;

  const IntervalType(this.label);
}

/// Represents an individual captured or planned screenshot item.
class ScreenshotItem {
  final String id;
  final double timestampSeconds;
  final String outputFileName;
  final String? tempFilePath;
  final String? savedPath;
  final int? width;
  final int? height;
  final int? fileSizeBytes;
  final bool isSelected;

  const ScreenshotItem({
    required this.id,
    required this.timestampSeconds,
    required this.outputFileName,
    this.tempFilePath,
    this.savedPath,
    this.width,
    this.height,
    this.fileSizeBytes,
    this.isSelected = false,
  });

  String get formattedTime {
    final totalMs = (timestampSeconds * 1000).round();
    final minutes = totalMs ~/ 60000;
    final seconds = (totalMs % 60000) ~/ 1000;
    final millis = totalMs % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }

  bool get isSaved => savedPath != null && savedPath!.isNotEmpty;

  ScreenshotItem copyWith({
    String? id,
    double? timestampSeconds,
    String? outputFileName,
    String? tempFilePath,
    String? savedPath,
    int? width,
    int? height,
    int? fileSizeBytes,
    bool? isSelected,
  }) {
    return ScreenshotItem(
      id: id ?? this.id,
      timestampSeconds: timestampSeconds ?? this.timestampSeconds,
      outputFileName: outputFileName ?? this.outputFileName,
      tempFilePath: tempFilePath ?? this.tempFilePath,
      savedPath: savedPath ?? this.savedPath,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestampSeconds': timestampSeconds,
        'outputFileName': outputFileName,
        'tempFilePath': tempFilePath,
        'savedPath': savedPath,
        'width': width,
        'height': height,
        'fileSizeBytes': fileSizeBytes,
      };

  factory ScreenshotItem.fromJson(Map<String, dynamic> json) {
    return ScreenshotItem(
      id: json['id'] as String? ?? '',
      timestampSeconds: (json['timestampSeconds'] as num?)?.toDouble() ?? 0.0,
      outputFileName: json['outputFileName'] as String? ?? 'frame.png',
      tempFilePath: json['tempFilePath'] as String?,
      savedPath: json['savedPath'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      fileSizeBytes: json['fileSizeBytes'] as int?,
    );
  }
}

/// Configuration defining parameters for screenshot extraction.
class ScreenshotConfig {
  final String videoPath;
  final String videoTitle;
  final double videoDurationSeconds;
  final int? videoWidth;
  final int? videoHeight;
  final ScreenshotImageFormat format;
  final int jpegQuality;
  final ScreenshotCaptureMode mode;
  final IntervalType intervalType;
  final double intervalSeconds;
  final int frameCount;
  final double startSeconds;
  final double endSeconds;
  final List<double> customTimestamps;
  final String? customBaseName;

  const ScreenshotConfig({
    required this.videoPath,
    required this.videoTitle,
    required this.videoDurationSeconds,
    this.videoWidth,
    this.videoHeight,
    this.format = ScreenshotImageFormat.png,
    this.jpegQuality = 90,
    this.mode = ScreenshotCaptureMode.single,
    this.intervalType = IntervalType.byDuration,
    this.intervalSeconds = 5.0,
    this.frameCount = 10,
    this.startSeconds = 0.0,
    double? endSeconds,
    this.customTimestamps = const [],
    this.customBaseName,
  }) : endSeconds = endSeconds ?? videoDurationSeconds;

  String get effectiveBaseName {
    if (customBaseName != null && customBaseName!.trim().isNotEmpty) {
      return customBaseName!.trim().replaceAll(RegExp(r'[^\w\-_]'), '_');
    }
    final name = videoTitle.contains('.')
        ? videoTitle.substring(0, videoTitle.lastIndexOf('.'))
        : videoTitle;
    return name.replaceAll(RegExp(r'[^\w\-_]'), '_');
  }

  /// Calculates the list of timestamps to capture according to current mode and settings.
  List<double> calculatePlannedTimestamps() {
    final effectiveEnd =
        endSeconds > startSeconds ? endSeconds : videoDurationSeconds;
    final range = effectiveEnd - startSeconds;

    if (range <= 0) {
      return [startSeconds.clamp(0.0, videoDurationSeconds)];
    }

    switch (mode) {
      case ScreenshotCaptureMode.single:
        return [startSeconds.clamp(0.0, videoDurationSeconds)];

      case ScreenshotCaptureMode.timestamps:
        if (customTimestamps.isEmpty) {
          return [startSeconds.clamp(0.0, videoDurationSeconds)];
        }
        final filtered = customTimestamps
            .where((t) => t >= startSeconds && t <= effectiveEnd)
            .toList()
          ..sort();
        return filtered.isEmpty
            ? [startSeconds.clamp(0.0, videoDurationSeconds)]
            : filtered;

      case ScreenshotCaptureMode.interval:
        if (intervalType == IntervalType.byDuration) {
          final step = intervalSeconds > 0.1 ? intervalSeconds : 1.0;
          final List<double> timestamps = [];
          for (double t = startSeconds; t <= effectiveEnd + 0.001; t += step) {
            timestamps.add(
              double.parse(
                t.clamp(startSeconds, effectiveEnd).toStringAsFixed(3),
              ),
            );
            if (t >= effectiveEnd) break;
          }
          return timestamps;
        } else {
          // byCount
          final count = frameCount >= 2 ? frameCount : 2;
          final List<double> timestamps = [];
          final step = range / (count - 1);
          for (int i = 0; i < count; i++) {
            final t = (startSeconds + i * step).clamp(
              startSeconds,
              effectiveEnd,
            );
            timestamps.add(double.parse(t.toStringAsFixed(3)));
          }
          return timestamps;
        }
    }
  }

  /// Calculates planned [ScreenshotItem] objects with formatted filenames.
  List<ScreenshotItem> calculatePlannedItems() {
    final timestamps = calculatePlannedTimestamps();
    final padLength = timestamps.length >= 100 ? 3 : 2;
    final base = effectiveBaseName;
    final ext = format.extension;

    return List.generate(timestamps.length, (index) {
      final t = timestamps[index];
      final totalMs = (t * 1000).round();
      final m = totalMs ~/ 60000;
      final s = (totalMs % 60000) ~/ 1000;
      final ms = totalMs % 1000;
      final timeStr =
          '${m.toString().padLeft(2, '0')}m${s.toString().padLeft(2, '0')}s${ms.toString().padLeft(3, '0')}ms';
      final indexStr = (index + 1).toString().padLeft(padLength, '0');
      final fileName = '${base}_frame_${indexStr}_$timeStr$ext';

      return ScreenshotItem(
        id: 'frame_${index + 1}_$totalMs',
        timestampSeconds: t,
        outputFileName: fileName,
        width: videoWidth,
        height: videoHeight,
      );
    });
  }

  /// Estimates the total byte size of all planned screenshots.
  int estimateTotalSizeBytes() {
    final count = calculatePlannedTimestamps().length;
    final w = videoWidth ?? 1920;
    final h = videoHeight ?? 1080;
    final pixels = w * h;

    // PNG is ~1.5 - 2.5 bytes per pixel on typical video frames.
    // JPEG at 90% is ~0.2 - 0.4 bytes per pixel.
    final bytesPerPixel = format == ScreenshotImageFormat.png
        ? 1.8
        : (0.15 + (jpegQuality / 100.0) * 0.25);

    final perFrameBytes = (pixels * bytesPerPixel).round();
    return perFrameBytes * count;
  }

  ScreenshotConfig copyWith({
    String? videoPath,
    String? videoTitle,
    double? videoDurationSeconds,
    int? videoWidth,
    int? videoHeight,
    ScreenshotImageFormat? format,
    int? jpegQuality,
    ScreenshotCaptureMode? mode,
    IntervalType? intervalType,
    double? intervalSeconds,
    int? frameCount,
    double? startSeconds,
    double? endSeconds,
    List<double>? customTimestamps,
    String? customBaseName,
  }) {
    return ScreenshotConfig(
      videoPath: videoPath ?? this.videoPath,
      videoTitle: videoTitle ?? this.videoTitle,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      format: format ?? this.format,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      mode: mode ?? this.mode,
      intervalType: intervalType ?? this.intervalType,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      frameCount: frameCount ?? this.frameCount,
      startSeconds: startSeconds ?? this.startSeconds,
      endSeconds: endSeconds ?? this.endSeconds,
      customTimestamps: customTimestamps ?? this.customTimestamps,
      customBaseName: customBaseName ?? this.customBaseName,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoPath': videoPath,
        'videoTitle': videoTitle,
        'videoDurationSeconds': videoDurationSeconds,
        'videoWidth': videoWidth,
        'videoHeight': videoHeight,
        'format': format.name,
        'jpegQuality': jpegQuality,
        'mode': mode.name,
        'intervalType': intervalType.name,
        'intervalSeconds': intervalSeconds,
        'frameCount': frameCount,
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'customTimestamps': customTimestamps,
        'customBaseName': customBaseName,
      };

  factory ScreenshotConfig.fromJson(Map<String, dynamic> json) {
    return ScreenshotConfig(
      videoPath: json['videoPath'] as String? ?? '',
      videoTitle: json['videoTitle'] as String? ?? '',
      videoDurationSeconds:
          (json['videoDurationSeconds'] as num?)?.toDouble() ?? 0.0,
      videoWidth: json['videoWidth'] as int?,
      videoHeight: json['videoHeight'] as int?,
      format: ScreenshotImageFormat.values.firstWhere(
        (e) => e.name == json['format'],
        orElse: () => ScreenshotImageFormat.png,
      ),
      jpegQuality: json['jpegQuality'] as int? ?? 90,
      mode: ScreenshotCaptureMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => ScreenshotCaptureMode.single,
      ),
      intervalType: IntervalType.values.firstWhere(
        (e) => e.name == json['intervalType'],
        orElse: () => IntervalType.byDuration,
      ),
      intervalSeconds: (json['intervalSeconds'] as num?)?.toDouble() ?? 5.0,
      frameCount: json['frameCount'] as int? ?? 10,
      startSeconds: (json['startSeconds'] as num?)?.toDouble() ?? 0.0,
      endSeconds: (json['endSeconds'] as num?)?.toDouble(),
      customTimestamps: (json['customTimestamps'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      customBaseName: json['customBaseName'] as String?,
    );
  }
}
