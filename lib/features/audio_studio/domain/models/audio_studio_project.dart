import '../../../convert/domain/models/convert_config.dart';

/// Supported track types inside the Audio Studio.
enum AudioTrackType { original, music, voiceover }

/// Export target mode for Audio Studio.
enum AudioStudioExportMode { videoWithAudio, extractedAudio }

extension AudioStudioExportModeExtension on AudioStudioExportMode {
  String get displayName => switch (this) {
        AudioStudioExportMode.videoWithAudio => 'Video with Mixed Audio',
        AudioStudioExportMode.extractedAudio => 'Audio Track Only',
      };

  String get shortName => switch (this) {
        AudioStudioExportMode.videoWithAudio => 'Video',
        AudioStudioExportMode.extractedAudio => 'Audio Track',
      };
}

/// Represents an individual audio layer (Music or Voice-over).
class AudioTrack {
  final AudioTrackType type;
  final String sourcePath;
  final String title;
  final double volume; // 0.0 to 2.0 (100% = 1.0)
  final double startTimeSeconds; // Offset into the video timeline
  final double durationSeconds;
  final bool loop; // Loops music if shorter than video
  final bool isMuted;

  const AudioTrack({
    required this.type,
    required this.sourcePath,
    required this.title,
    this.volume = 1.0,
    this.startTimeSeconds = 0.0,
    this.durationSeconds = 0.0,
    this.loop = false,
    this.isMuted = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'sourcePath': sourcePath,
        'title': title,
        'volume': volume,
        'startTimeSeconds': startTimeSeconds,
        'durationSeconds': durationSeconds,
        'loop': loop,
        'isMuted': isMuted,
      };

  factory AudioTrack.fromJson(Map<String, dynamic> json) => AudioTrack(
        type: AudioTrackType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => AudioTrackType.music,
        ),
        sourcePath: json['sourcePath'] as String? ?? '',
        title: json['title'] as String? ?? 'Track',
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        startTimeSeconds: (json['startTimeSeconds'] as num?)?.toDouble() ?? 0.0,
        durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
        loop: json['loop'] as bool? ?? false,
        isMuted: json['isMuted'] as bool? ?? false,
      );

  AudioTrack copyWith({
    AudioTrackType? type,
    String? sourcePath,
    String? title,
    double? volume,
    double? startTimeSeconds,
    double? durationSeconds,
    bool? loop,
    bool? isMuted,
  }) =>
      AudioTrack(
        type: type ?? this.type,
        sourcePath: sourcePath ?? this.sourcePath,
        title: title ?? this.title,
        volume: volume ?? this.volume,
        startTimeSeconds: startTimeSeconds ?? this.startTimeSeconds,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        loop: loop ?? this.loop,
        isMuted: isMuted ?? this.isMuted,
      );
}

/// Comprehensive specification for mixing multi-track audio.
class AudioStudioConfig {
  final String videoPath;
  final double videoDurationSeconds;
  final double originalVolume; // 0.0 to 2.0
  final bool isOriginalMuted;
  final AudioTrack? musicTrack;
  final AudioTrack? voiceoverTrack;
  final bool enableDucking;
  final double duckingAttenuation; // 0.0 to 1.0 (default 0.25)
  final AudioStudioExportMode exportMode;
  final AudioOutputFormat audioFormat;
  final String? customFileName;

  const AudioStudioConfig({
    required this.videoPath,
    required this.videoDurationSeconds,
    this.originalVolume = 1.0,
    this.isOriginalMuted = false,
    this.musicTrack,
    this.voiceoverTrack,
    this.enableDucking = false,
    this.duckingAttenuation = 0.25,
    this.exportMode = AudioStudioExportMode.videoWithAudio,
    this.audioFormat = AudioOutputFormat.mp3,
    this.customFileName,
  });

  bool get hasActiveAudioTracks {
    final hasOriginal = !isOriginalMuted && originalVolume > 0.01;
    final hasMusic =
        musicTrack != null && !musicTrack!.isMuted && musicTrack!.volume > 0.01;
    final hasVoiceover = voiceoverTrack != null &&
        !voiceoverTrack!.isMuted &&
        voiceoverTrack!.volume > 0.01;
    return hasOriginal || hasMusic || hasVoiceover;
  }

  String get effectiveExtension {
    if (exportMode == AudioStudioExportMode.extractedAudio) {
      return audioFormat.fileExtension;
    }
    return '.mp4';
  }

  Map<String, dynamic> toJson() => {
        'videoPath': videoPath,
        'videoDurationSeconds': videoDurationSeconds,
        'originalVolume': originalVolume,
        'isOriginalMuted': isOriginalMuted,
        'musicTrack': musicTrack?.toJson(),
        'voiceoverTrack': voiceoverTrack?.toJson(),
        'enableDucking': enableDucking,
        'duckingAttenuation': duckingAttenuation,
        'exportMode': exportMode.name,
        'audioFormat': audioFormat.name,
        'customFileName': customFileName,
      };

  factory AudioStudioConfig.fromJson(Map<String, dynamic> json) =>
      AudioStudioConfig(
        videoPath: json['videoPath'] as String? ?? '',
        videoDurationSeconds:
            (json['videoDurationSeconds'] as num?)?.toDouble() ?? 0.0,
        originalVolume: (json['originalVolume'] as num?)?.toDouble() ?? 1.0,
        isOriginalMuted: json['isOriginalMuted'] as bool? ?? false,
        musicTrack: json['musicTrack'] != null
            ? AudioTrack.fromJson(json['musicTrack'] as Map<String, dynamic>)
            : null,
        voiceoverTrack: json['voiceoverTrack'] != null
            ? AudioTrack.fromJson(
                json['voiceoverTrack'] as Map<String, dynamic>,
              )
            : null,
        enableDucking: json['enableDucking'] as bool? ?? false,
        duckingAttenuation:
            (json['duckingAttenuation'] as num?)?.toDouble() ?? 0.25,
        exportMode: AudioStudioExportMode.values.firstWhere(
          (e) => e.name == json['exportMode'],
          orElse: () => AudioStudioExportMode.videoWithAudio,
        ),
        audioFormat: AudioOutputFormat.values.firstWhere(
          (e) => e.name == json['audioFormat'],
          orElse: () => AudioOutputFormat.mp3,
        ),
        customFileName: json['customFileName'] as String?,
      );

  AudioStudioConfig copyWith({
    String? videoPath,
    double? videoDurationSeconds,
    double? originalVolume,
    bool? isOriginalMuted,
    AudioTrack? musicTrack,
    bool clearMusicTrack = false,
    AudioTrack? voiceoverTrack,
    bool clearVoiceoverTrack = false,
    bool? enableDucking,
    double? duckingAttenuation,
    AudioStudioExportMode? exportMode,
    AudioOutputFormat? audioFormat,
    String? customFileName,
  }) =>
      AudioStudioConfig(
        videoPath: videoPath ?? this.videoPath,
        videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
        originalVolume: originalVolume ?? this.originalVolume,
        isOriginalMuted: isOriginalMuted ?? this.isOriginalMuted,
        musicTrack: clearMusicTrack ? null : (musicTrack ?? this.musicTrack),
        voiceoverTrack: clearVoiceoverTrack
            ? null
            : (voiceoverTrack ?? this.voiceoverTrack),
        enableDucking: enableDucking ?? this.enableDucking,
        duckingAttenuation: duckingAttenuation ?? this.duckingAttenuation,
        exportMode: exportMode ?? this.exportMode,
        audioFormat: audioFormat ?? this.audioFormat,
        customFileName: customFileName ?? this.customFileName,
      );
}
