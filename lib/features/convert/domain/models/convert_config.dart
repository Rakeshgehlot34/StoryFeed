import 'dart:math' as math;

/// Target output format for format conversion and compression.
enum ConvertOutputFormat { mp4H264, mp4H265, webm, mkv, gif, audioOnly }

extension ConvertOutputFormatExtension on ConvertOutputFormat {
  String get displayName => switch (this) {
    ConvertOutputFormat.mp4H264 => 'MP4 (H.264)',
    ConvertOutputFormat.mp4H265 => 'MP4 (H.265 / HEVC)',
    ConvertOutputFormat.webm => 'WebM (VP9)',
    ConvertOutputFormat.mkv => 'MKV (Matroska)',
    ConvertOutputFormat.gif => 'Animated GIF',
    ConvertOutputFormat.audioOnly => 'Audio Extraction',
  };

  String get shortName => switch (this) {
    ConvertOutputFormat.mp4H264 => 'MP4',
    ConvertOutputFormat.mp4H265 => 'HEVC',
    ConvertOutputFormat.webm => 'WebM',
    ConvertOutputFormat.mkv => 'MKV',
    ConvertOutputFormat.gif => 'GIF',
    ConvertOutputFormat.audioOnly => 'Audio',
  };

  String get defaultExtension => switch (this) {
    ConvertOutputFormat.mp4H264 => '.mp4',
    ConvertOutputFormat.mp4H265 => '.mp4',
    ConvertOutputFormat.webm => '.webm',
    ConvertOutputFormat.mkv => '.mkv',
    ConvertOutputFormat.gif => '.gif',
    ConvertOutputFormat.audioOnly => '.mp3',
  };

  bool get isVideo =>
      this != ConvertOutputFormat.gif && this != ConvertOutputFormat.audioOnly;

  bool get supportsAudio => this != ConvertOutputFormat.gif;
}

/// Standard video resolution constraints.
enum ResolutionPreset { original, res4k, res1080p, res720p, res480p, res360p }

extension ResolutionPresetExtension on ResolutionPreset {
  String get displayName => switch (this) {
    ResolutionPreset.original => 'Original Resolution',
    ResolutionPreset.res4k => '4K UHD (2160p)',
    ResolutionPreset.res1080p => 'Full HD (1080p)',
    ResolutionPreset.res720p => 'HD (720p)',
    ResolutionPreset.res480p => 'SD (480p)',
    ResolutionPreset.res360p => 'Low (360p)',
  };

  int get maxLongDimension => switch (this) {
    ResolutionPreset.original => 0,
    ResolutionPreset.res4k => 3840,
    ResolutionPreset.res1080p => 1920,
    ResolutionPreset.res720p => 1280,
    ResolutionPreset.res480p => 854,
    ResolutionPreset.res360p => 640,
  };
}

/// Video frame rate presets.
enum FpsPreset { original, fps60, fps30, fps24, fps15 }

extension FpsPresetExtension on FpsPreset {
  String get displayName => switch (this) {
    FpsPreset.original => 'Original FPS',
    FpsPreset.fps60 => '60 FPS',
    FpsPreset.fps30 => '30 FPS',
    FpsPreset.fps24 => '24 FPS (Cinematic)',
    FpsPreset.fps15 => '15 FPS (Compact)',
  };

  int get value => switch (this) {
    FpsPreset.original => 0,
    FpsPreset.fps60 => 60,
    FpsPreset.fps30 => 30,
    FpsPreset.fps24 => 24,
    FpsPreset.fps15 => 15,
  };
}

/// Quality presets controlling Constant Rate Factor (CRF).
enum QualityPreset { high, balanced, small, ultraSmall }

extension QualityPresetExtension on QualityPreset {
  String get displayName => switch (this) {
    QualityPreset.high => 'High Quality (CRF 18)',
    QualityPreset.balanced => 'Balanced (CRF 23 - Recommended)',
    QualityPreset.small => 'Compact Size (CRF 28)',
    QualityPreset.ultraSmall => 'Maximum Compression (CRF 32)',
  };

  int get crfH264 => switch (this) {
    QualityPreset.high => 18,
    QualityPreset.balanced => 23,
    QualityPreset.small => 28,
    QualityPreset.ultraSmall => 32,
  };

  int get crfH265 => switch (this) {
    QualityPreset.high => 22,
    QualityPreset.balanced => 28,
    QualityPreset.small => 32,
    QualityPreset.ultraSmall => 36,
  };

  int get crfVp9 => switch (this) {
    QualityPreset.high => 24,
    QualityPreset.balanced => 31,
    QualityPreset.small => 37,
    QualityPreset.ultraSmall => 42,
  };
}

/// Supported audio extraction formats.
enum AudioOutputFormat { mp3, aac, wav, opus }

extension AudioOutputFormatExtension on AudioOutputFormat {
  String get displayName => switch (this) {
    AudioOutputFormat.mp3 => 'MP3 (Universal)',
    AudioOutputFormat.aac => 'AAC / M4A (High Fidelity)',
    AudioOutputFormat.wav => 'WAV (Uncompressed PCM)',
    AudioOutputFormat.opus => 'Opus (High Efficiency)',
  };

  String get fileExtension => switch (this) {
    AudioOutputFormat.mp3 => '.mp3',
    AudioOutputFormat.aac => '.m4a',
    AudioOutputFormat.wav => '.wav',
    AudioOutputFormat.opus => '.opus',
  };

  String get codec => switch (this) {
    AudioOutputFormat.mp3 => 'libmp3lame',
    AudioOutputFormat.aac => 'aac',
    AudioOutputFormat.wav => 'pcm_s16le',
    AudioOutputFormat.opus => 'libopus',
  };
}

/// Settings specific to animated GIF generation.
class GifConfig {
  final int fps;
  final int maxWidth;
  final String dither;

  const GifConfig({
    this.fps = 15,
    this.maxWidth = 480,
    this.dither = 'bayer:bayer_scale=5',
  });

  Map<String, dynamic> toJson() => {
    'fps': fps,
    'maxWidth': maxWidth,
    'dither': dither,
  };

  factory GifConfig.fromJson(Map<String, dynamic> json) => GifConfig(
    fps: (json['fps'] as num?)?.toInt() ?? 15,
    maxWidth: (json['maxWidth'] as num?)?.toInt() ?? 480,
    dither: json['dither'] as String? ?? 'bayer:bayer_scale=5',
  );

  GifConfig copyWith({int? fps, int? maxWidth, String? dither}) => GifConfig(
    fps: fps ?? this.fps,
    maxWidth: maxWidth ?? this.maxWidth,
    dither: dither ?? this.dither,
  );
}

/// Comprehensive configuration for video conversion and compression.
class ConvertConfig {
  final ConvertOutputFormat format;
  final ResolutionPreset resolution;
  final FpsPreset fps;
  final QualityPreset quality;
  final double? targetSizeMb;
  final bool muteAudio;
  final AudioOutputFormat audioFormat;
  final int audioBitrateKbps;
  final GifConfig gifConfig;
  final String? customFileName;

  const ConvertConfig({
    this.format = ConvertOutputFormat.mp4H264,
    this.resolution = ResolutionPreset.original,
    this.fps = FpsPreset.original,
    this.quality = QualityPreset.balanced,
    this.targetSizeMb,
    this.muteAudio = false,
    this.audioFormat = AudioOutputFormat.mp3,
    this.audioBitrateKbps = 192,
    this.gifConfig = const GifConfig(),
    this.customFileName,
  });

  /// Resolves the final file extension according to format and audio codec.
  String get effectiveExtension {
    if (format == ConvertOutputFormat.audioOnly) {
      return audioFormat.fileExtension;
    }
    return format.defaultExtension;
  }

  /// Estimates the output size in bytes based on input video attributes and settings.
  int estimateOutputSizeBytes({
    required double durationSeconds,
    required int sourceSizeBytes,
    required int sourceWidth,
    required int sourceHeight,
  }) {
    if (durationSeconds <= 0) return 0;

    // Explicit target MB takes absolute precedence
    if (targetSizeMb != null && targetSizeMb! > 0) {
      return (targetSizeMb! * 1024 * 1024).round();
    }

    // Audio-only extraction
    if (format == ConvertOutputFormat.audioOnly) {
      if (audioFormat == AudioOutputFormat.wav) {
        // 44100 Hz * 2 channels * 16 bits (2 bytes) = 176,400 bytes/second
        return (durationSeconds * 176400).round();
      }
      final bytesPerSec = (audioBitrateKbps * 1000) / 8;
      return (durationSeconds * bytesPerSec).round();
    }

    // Animated GIF
    if (format == ConvertOutputFormat.gif) {
      final gifFps = gifConfig.fps;
      final w = gifConfig.maxWidth;
      // An average 480p GIF frame with a 256 color palette is ~20KB
      final frameBytes = (w / 480.0) * 20000;
      return (durationSeconds * gifFps * frameBytes).round();
    }

    // Video formats (MP4, WebM, MKV)
    final effectiveLongDim = resolution.maxLongDimension > 0
        ? math.min(
            resolution.maxLongDimension,
            math.max(sourceWidth, sourceHeight),
          )
        : math.max(sourceWidth, sourceHeight);

    double baseBitrateMbps;
    if (effectiveLongDim >= 3000) {
      baseBitrateMbps = switch (quality) {
        QualityPreset.high => 28.0,
        QualityPreset.balanced => 16.0,
        QualityPreset.small => 10.0,
        QualityPreset.ultraSmall => 6.0,
      };
    } else if (effectiveLongDim >= 1800) {
      baseBitrateMbps = switch (quality) {
        QualityPreset.high => 10.0,
        QualityPreset.balanced => 5.5,
        QualityPreset.small => 3.0,
        QualityPreset.ultraSmall => 1.8,
      };
    } else if (effectiveLongDim >= 1200) {
      baseBitrateMbps = switch (quality) {
        QualityPreset.high => 5.0,
        QualityPreset.balanced => 2.8,
        QualityPreset.small => 1.6,
        QualityPreset.ultraSmall => 0.9,
      };
    } else if (effectiveLongDim >= 800) {
      baseBitrateMbps = switch (quality) {
        QualityPreset.high => 2.2,
        QualityPreset.balanced => 1.2,
        QualityPreset.small => 0.7,
        QualityPreset.ultraSmall => 0.4,
      };
    } else {
      baseBitrateMbps = switch (quality) {
        QualityPreset.high => 1.2,
        QualityPreset.balanced => 0.7,
        QualityPreset.small => 0.4,
        QualityPreset.ultraSmall => 0.25,
      };
    }

    if (fps == FpsPreset.fps15) {
      baseBitrateMbps *= 0.65;
    } else if (fps == FpsPreset.fps24) {
      baseBitrateMbps *= 0.85;
    } else if (fps == FpsPreset.fps60) {
      baseBitrateMbps *= 1.4;
    }

    // HEVC and VP9 offer ~35% bitrate savings for similar visual quality
    if (format == ConvertOutputFormat.mp4H265 ||
        format == ConvertOutputFormat.webm) {
      baseBitrateMbps *= 0.65;
    }

    final videoBytes = (durationSeconds * (baseBitrateMbps * 1000000 / 8));
    final audioBytes = muteAudio
        ? 0.0
        : (durationSeconds * (audioBitrateKbps * 1000 / 8));

    return (videoBytes + audioBytes).round();
  }

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'resolution': resolution.name,
    'fps': fps.name,
    'quality': quality.name,
    'targetSizeMb': targetSizeMb,
    'muteAudio': muteAudio,
    'audioFormat': audioFormat.name,
    'audioBitrateKbps': audioBitrateKbps,
    'gifConfig': gifConfig.toJson(),
    'customFileName': customFileName,
  };

  factory ConvertConfig.fromJson(Map<String, dynamic> json) => ConvertConfig(
    format: ConvertOutputFormat.values.firstWhere(
      (e) => e.name == json['format'],
      orElse: () => ConvertOutputFormat.mp4H264,
    ),
    resolution: ResolutionPreset.values.firstWhere(
      (e) => e.name == json['resolution'],
      orElse: () => ResolutionPreset.original,
    ),
    fps: FpsPreset.values.firstWhere(
      (e) => e.name == json['fps'],
      orElse: () => FpsPreset.original,
    ),
    quality: QualityPreset.values.firstWhere(
      (e) => e.name == json['quality'],
      orElse: () => QualityPreset.balanced,
    ),
    targetSizeMb: (json['targetSizeMb'] as num?)?.toDouble(),
    muteAudio: json['muteAudio'] as bool? ?? false,
    audioFormat: AudioOutputFormat.values.firstWhere(
      (e) => e.name == json['audioFormat'],
      orElse: () => AudioOutputFormat.mp3,
    ),
    audioBitrateKbps: (json['audioBitrateKbps'] as num?)?.toInt() ?? 192,
    gifConfig: json['gifConfig'] != null
        ? GifConfig.fromJson(json['gifConfig'] as Map<String, dynamic>)
        : const GifConfig(),
    customFileName: json['customFileName'] as String?,
  );

  ConvertConfig copyWith({
    ConvertOutputFormat? format,
    ResolutionPreset? resolution,
    FpsPreset? fps,
    QualityPreset? quality,
    double? targetSizeMb,
    bool clearTargetSize = false,
    bool? muteAudio,
    AudioOutputFormat? audioFormat,
    int? audioBitrateKbps,
    GifConfig? gifConfig,
    String? customFileName,
  }) => ConvertConfig(
    format: format ?? this.format,
    resolution: resolution ?? this.resolution,
    fps: fps ?? this.fps,
    quality: quality ?? this.quality,
    targetSizeMb: clearTargetSize ? null : (targetSizeMb ?? this.targetSizeMb),
    muteAudio: muteAudio ?? this.muteAudio,
    audioFormat: audioFormat ?? this.audioFormat,
    audioBitrateKbps: audioBitrateKbps ?? this.audioBitrateKbps,
    gifConfig: gifConfig ?? this.gifConfig,
    customFileName: customFileName ?? this.customFileName,
  );
}
