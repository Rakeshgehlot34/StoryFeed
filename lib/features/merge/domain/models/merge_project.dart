/// Canvas aspect ratio presets for merged video output.
enum CanvasAspectRatioPreset {
  matchFirst('Match First Video', null, null),
  vertical9x16('9:16 Vertical (Shorts / Reels)', 1080, 1920),
  horizontal16x9('16:9 Landscape (YouTube)', 1920, 1080),
  square1x1('1:1 Square (Instagram)', 1080, 1080),
  standard720p('720p HD Landscape', 1280, 720),
  standard1080p('1080p Full HD Landscape', 1920, 1080);

  final String label;
  final int? targetWidth;
  final int? targetHeight;

  const CanvasAspectRatioPreset(
    this.label,
    this.targetWidth,
    this.targetHeight,
  );

  double? get aspectRatio =>
      (targetWidth != null && targetHeight != null && targetHeight! > 0)
          ? targetWidth! / targetHeight!
          : null;
}

/// Fit mode for scaling videos into the target canvas.
enum CanvasFitMode {
  fitBlack('Letterbox / Pillarbox (Black)'),
  fitBlur('Blurred Video Background'),
  cropFill('Crop to Fill Canvas');

  final String label;

  const CanvasFitMode(this.label);
}

/// Transition effect between adjacent video clips.
enum MergeTransition {
  none('Direct Cut', 'Direct concatenation without overlap'),
  fade('Crossfade', 'Smooth dissolve crossfade transition'),
  wipeleft('Wipe Left', 'Wipe transition towards left edge'),
  wiperight('Wipe Right', 'Wipe transition towards right edge'),
  slideleft('Slide Left', 'Slide transition towards left edge'),
  slideright('Slide Right', 'Slide transition towards right edge');

  final String label;
  final String description;

  const MergeTransition(this.label, this.description);

  bool get isNone => this == MergeTransition.none;
}

/// Strategy for joining input videos.
enum MergeMethod {
  auto('Auto (Fast if compatible, else Precise)'),
  fast('Fast Stream Copy (No re-encode)'),
  precise('Precise Re-encode (Aspect fit & transitions)');

  final String label;

  const MergeMethod(this.label);
}

/// Represents an individual video clip within the merge sequence.
class MergeClipItem {
  final String id;
  final String videoPath;
  final String fileName;
  final double durationSeconds;
  final int width;
  final int height;
  final double fps;
  final bool hasAudio;
  final double startTrimSeconds;
  final double? endTrimSeconds;

  const MergeClipItem({
    required this.id,
    required this.videoPath,
    required this.fileName,
    required this.durationSeconds,
    this.width = 1920,
    this.height = 1080,
    this.fps = 30.0,
    this.hasAudio = true,
    this.startTrimSeconds = 0.0,
    this.endTrimSeconds,
  });

  double get effectiveDurationSeconds {
    final end = (endTrimSeconds != null && endTrimSeconds! > startTrimSeconds)
        ? endTrimSeconds!
        : durationSeconds;
    final dur = end - startTrimSeconds;
    return dur > 0.05 ? dur : 0.05;
  }

  String get resolutionString =>
      (width > 0 && height > 0) ? '${width}x$height' : 'Unknown';

  String get formattedDuration {
    final totalMs = (effectiveDurationSeconds * 1000).round();
    final minutes = totalMs ~/ 60000;
    final seconds = (totalMs % 60000) ~/ 1000;
    final millis = totalMs % 1000;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${(millis ~/ 100).toString()}s';
  }

  MergeClipItem copyWith({
    String? id,
    String? videoPath,
    String? fileName,
    double? durationSeconds,
    int? width,
    int? height,
    double? fps,
    bool? hasAudio,
    double? startTrimSeconds,
    double? endTrimSeconds,
  }) {
    return MergeClipItem(
      id: id ?? this.id,
      videoPath: videoPath ?? this.videoPath,
      fileName: fileName ?? this.fileName,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      hasAudio: hasAudio ?? this.hasAudio,
      startTrimSeconds: startTrimSeconds ?? this.startTrimSeconds,
      endTrimSeconds: endTrimSeconds ?? this.endTrimSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'videoPath': videoPath,
        'fileName': fileName,
        'durationSeconds': durationSeconds,
        'width': width,
        'height': height,
        'fps': fps,
        'hasAudio': hasAudio,
        'startTrimSeconds': startTrimSeconds,
        'endTrimSeconds': endTrimSeconds,
      };

  factory MergeClipItem.fromJson(Map<String, dynamic> json) {
    return MergeClipItem(
      id: json['id'] as String? ?? '',
      videoPath: json['videoPath'] as String? ?? '',
      fileName: json['fileName'] as String? ?? 'clip.mp4',
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      width: json['width'] as int? ?? 1920,
      height: json['height'] as int? ?? 1080,
      fps: (json['fps'] as num?)?.toDouble() ?? 30.0,
      hasAudio: json['hasAudio'] as bool? ?? true,
      startTrimSeconds: (json['startTrimSeconds'] as num?)?.toDouble() ?? 0.0,
      endTrimSeconds: (json['endTrimSeconds'] as num?)?.toDouble(),
    );
  }
}

/// Complete configuration specification for a video merge project.
class MergeConfig {
  final List<MergeClipItem> clips;
  final CanvasAspectRatioPreset canvasPreset;
  final int? customWidth;
  final int? customHeight;
  final CanvasFitMode fitMode;
  final MergeTransition transition;
  final double transitionDurationSeconds;
  final MergeMethod method;
  final String? customBaseName;

  const MergeConfig({
    this.clips = const [],
    this.canvasPreset = CanvasAspectRatioPreset.matchFirst,
    this.customWidth,
    this.customHeight,
    this.fitMode = CanvasFitMode.fitBlack,
    this.transition = MergeTransition.none,
    this.transitionDurationSeconds = 0.5,
    this.method = MergeMethod.auto,
    this.customBaseName,
  });

  bool get isEmpty => clips.isEmpty;
  bool get canMerge => clips.length >= 2;

  String get effectiveBaseName {
    if (customBaseName != null && customBaseName!.trim().isNotEmpty) {
      return customBaseName!.trim().replaceAll(RegExp(r'[^\w\-_]'), '_');
    }
    if (clips.isNotEmpty) {
      final first = clips.first.fileName;
      final name = first.contains('.')
          ? first.substring(0, first.lastIndexOf('.'))
          : first;
      return '${name}_merged';
    }
    return 'merged_video';
  }

  /// Target width resolved from preset or first clip.
  int get resolvedWidth {
    if (canvasPreset.targetWidth != null) return canvasPreset.targetWidth!;
    if (customWidth != null && customWidth! > 0) return customWidth!;
    if (clips.isNotEmpty && clips.first.width > 0) return clips.first.width;
    return 1920;
  }

  /// Target height resolved from preset or first clip.
  int get resolvedHeight {
    if (canvasPreset.targetHeight != null) return canvasPreset.targetHeight!;
    if (customHeight != null && customHeight! > 0) return customHeight!;
    if (clips.isNotEmpty && clips.first.height > 0) return clips.first.height;
    return 1080;
  }

  /// Evaluates whether clips are strictly compatible with FFmpeg's concat demuxer (stream copy).
  bool isFastConcatCompatible() {
    if (clips.length < 2) return false;
    if (!transition.isNone) return false;

    final first = clips.first;
    if (first.startTrimSeconds > 0.0 || first.endTrimSeconds != null) {
      return false;
    }
    for (int i = 1; i < clips.length; i++) {
      final c = clips[i];
      if (c.width != first.width ||
          c.height != first.height ||
          (c.fps - first.fps).abs() > 0.5 ||
          c.hasAudio != first.hasAudio ||
          c.startTrimSeconds > 0.0 ||
          c.endTrimSeconds != null) {
        return false;
      }
    }
    return true;
  }

  /// Resolved encoding method based on compatibility and user choice.
  MergeMethod get effectiveMethod {
    if (method == MergeMethod.auto) {
      return isFastConcatCompatible() ? MergeMethod.fast : MergeMethod.precise;
    }
    return method;
  }

  /// Total duration of the resulting merged video accounting for transition overlaps.
  double calculateTotalDurationSeconds() {
    if (clips.isEmpty) return 0.0;
    double total = 0.0;
    for (final clip in clips) {
      total += clip.effectiveDurationSeconds;
    }

    if (transition != MergeTransition.none && clips.length > 1) {
      final overlap = (clips.length - 1) * transitionDurationSeconds;
      total = (total - overlap).clamp(0.1, double.infinity);
    }
    return total;
  }

  /// Estimates the output file size in bytes based on input durations and target resolution.
  int estimateOutputSizeBytes() {
    final totalDuration = calculateTotalDurationSeconds();
    if (totalDuration <= 0) return 0;

    if (effectiveMethod == MergeMethod.fast && clips.isNotEmpty) {
      // Sum proportional sizes of inputs
      double total = 0.0;
      for (final c in clips) {
        // Average ~600KB/s on 1080p
        total += c.effectiveDurationSeconds * 600 * 1024;
      }
      return total.round();
    }

    // Precise re-encode: calculate from resolution and 23 CRF (~1.5-2.5 Mbps for 1080p, ~3-4 Mbps for vertical 1080x1920)
    final pixels = resolvedWidth * resolvedHeight;
    final bitrateBps = pixels >= 1920 * 1080 ? 2500000 : 1200000;
    final videoBytes = (bitrateBps * totalDuration) / 8.0;
    final audioBytes = (192000 * totalDuration) / 8.0;
    return (videoBytes + audioBytes).round();
  }

  MergeConfig copyWith({
    List<MergeClipItem>? clips,
    CanvasAspectRatioPreset? canvasPreset,
    int? customWidth,
    int? customHeight,
    CanvasFitMode? fitMode,
    MergeTransition? transition,
    double? transitionDurationSeconds,
    MergeMethod? method,
    String? customBaseName,
  }) {
    return MergeConfig(
      clips: clips ?? this.clips,
      canvasPreset: canvasPreset ?? this.canvasPreset,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      fitMode: fitMode ?? this.fitMode,
      transition: transition ?? this.transition,
      transitionDurationSeconds:
          transitionDurationSeconds ?? this.transitionDurationSeconds,
      method: method ?? this.method,
      customBaseName: customBaseName ?? this.customBaseName,
    );
  }

  Map<String, dynamic> toJson() => {
        'clips': clips.map((c) => c.toJson()).toList(),
        'canvasPreset': canvasPreset.name,
        'customWidth': customWidth,
        'customHeight': customHeight,
        'fitMode': fitMode.name,
        'transition': transition.name,
        'transitionDurationSeconds': transitionDurationSeconds,
        'method': method.name,
        'customBaseName': customBaseName,
      };

  factory MergeConfig.fromJson(Map<String, dynamic> json) {
    return MergeConfig(
      clips: (json['clips'] as List<dynamic>?)
              ?.map((e) => MergeClipItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      canvasPreset: CanvasAspectRatioPreset.values.firstWhere(
        (e) => e.name == json['canvasPreset'],
        orElse: () => CanvasAspectRatioPreset.matchFirst,
      ),
      customWidth: json['customWidth'] as int?,
      customHeight: json['customHeight'] as int?,
      fitMode: CanvasFitMode.values.firstWhere(
        (e) => e.name == json['fitMode'],
        orElse: () => CanvasFitMode.fitBlack,
      ),
      transition: MergeTransition.values.firstWhere(
        (e) => e.name == json['transition'],
        orElse: () => MergeTransition.none,
      ),
      transitionDurationSeconds:
          (json['transitionDurationSeconds'] as num?)?.toDouble() ?? 0.5,
      method: MergeMethod.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => MergeMethod.auto,
      ),
      customBaseName: json['customBaseName'] as String?,
    );
  }
}
