import 'dart:math' as math;

import 'models/convert_config.dart';

/// Compiles [ConvertConfig] specifications into optimized FFmpeg arguments.
class ConvertFilterCompiler {
  const ConvertFilterCompiler();

  /// Calculates the video bitrate in bits-per-second required to fit within [targetSizeMb].
  static int calculateVideoBitrateBps({
    required double durationSeconds,
    required double targetSizeMb,
    required int audioBitrateKbps,
    required bool muteAudio,
  }) {
    final totalBytes = targetSizeMb * 1024 * 1024;
    final totalBits = totalBytes * 8;
    final dur = durationSeconds > 0.1 ? durationSeconds : 1.0;
    // 2% container muxing overhead (MP4 moov atom / packet headers)
    final overheadBits = totalBits * 0.02;
    final availableBits = totalBits - overheadBits;
    final audioBits = muteAudio ? 0.0 : (audioBitrateKbps * 1000 * dur);
    final videoBits = availableBits - audioBits;
    // Minimum 64 kbps safety floor to prevent corrupt video streams
    return math.max(64000, (videoBits / dur).round());
  }

  /// Compiles the complete FFmpeg command argument array for format conversion or compression.
  List<String> compile({
    required String inputPath,
    required String outputPath,
    required ConvertConfig config,
    required double durationSeconds,
  }) {
    final args = <String>['-y', '-i', inputPath];

    // Case 1: Audio Only Extraction
    if (config.format == ConvertOutputFormat.audioOnly) {
      args.add('-vn');
      switch (config.audioFormat) {
        case AudioOutputFormat.mp3:
          args.addAll([
            '-c:a',
            'libmp3lame',
            '-b:a',
            '${config.audioBitrateKbps}k',
          ]);
        case AudioOutputFormat.aac:
          args.addAll(['-c:a', 'aac', '-b:a', '${config.audioBitrateKbps}k']);
        case AudioOutputFormat.wav:
          args.addAll(['-c:a', 'pcm_s16le']);
        case AudioOutputFormat.opus:
          args.addAll([
            '-c:a',
            'libopus',
            '-b:a',
            '${config.audioBitrateKbps}k',
          ]);
      }
      args.add(outputPath);
      return List.unmodifiable(args);
    }

    // Case 2: Animated GIF with 2-pass palettegen + paletteuse
    if (config.format == ConvertOutputFormat.gif) {
      final fps = config.gifConfig.fps;
      final maxW = config.gifConfig.maxWidth;
      final filter =
          "[0:v]fps=$fps,scale='if(gt(iw,ih),min(iw,$maxW),-2)':'if(gt(iw,ih),-2,min(ih,$maxW))':flags=lanczos,split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=${config.gifConfig.dither}";
      args.addAll(['-filter_complex', filter, '-an', outputPath]);
      return List.unmodifiable(args);
    }

    // Case 3: Video Formats (MP4 H.264, MP4 H.265, WebM VP9, MKV)
    final videoFilters = <String>[];

    // Scaling
    if (config.resolution != ResolutionPreset.original) {
      final maxDim = config.resolution.maxLongDimension;
      videoFilters.add(
        "scale='if(gt(iw,ih),min(iw,$maxDim),-2)':'if(gt(iw,ih),-2,min(ih,$maxDim))'",
      );
    }

    // FPS
    if (config.fps != FpsPreset.original) {
      videoFilters.add('fps=${config.fps.value}');
    }

    if (videoFilters.isNotEmpty) {
      args.addAll(['-vf', videoFilters.join(',')]);
    }

    // Video Codec
    switch (config.format) {
      case ConvertOutputFormat.mp4H264:
      case ConvertOutputFormat.mkv:
        args.addAll([
          '-c:v',
          'libx264',
          '-preset',
          'medium',
          '-pix_fmt',
          'yuv420p',
        ]);
      case ConvertOutputFormat.mp4H265:
        args.addAll([
          '-c:v',
          'libx265',
          '-preset',
          'medium',
          '-pix_fmt',
          'yuv420p',
          '-tag:v',
          'hvc1',
        ]);
      case ConvertOutputFormat.webm:
        args.addAll(['-c:v', 'libvpx-vp9', '-pix_fmt', 'yuv420p']);
      default:
        break;
    }

    // Bitrate & Quality encoding
    if (config.targetSizeMb != null && config.targetSizeMb! > 0) {
      final videoBitrateBps = calculateVideoBitrateBps(
        durationSeconds: durationSeconds,
        targetSizeMb: config.targetSizeMb!,
        audioBitrateKbps: config.audioBitrateKbps,
        muteAudio: config.muteAudio,
      );

      if (config.format == ConvertOutputFormat.webm) {
        args.addAll([
          '-b:v',
          '$videoBitrateBps',
          '-minrate',
          '${(videoBitrateBps * 0.8).round()}',
          '-maxrate',
          '${(videoBitrateBps * 1.2).round()}',
        ]);
      } else {
        args.addAll([
          '-b:v',
          '$videoBitrateBps',
          '-maxrate',
          '${(videoBitrateBps * 1.5).round()}',
          '-bufsize',
          '${(videoBitrateBps * 2).round()}',
        ]);
      }
    } else {
      // Quality Preset CRF
      switch (config.format) {
        case ConvertOutputFormat.mp4H265:
          args.addAll(['-crf', '${config.quality.crfH265}']);
        case ConvertOutputFormat.webm:
          args.addAll(['-crf', '${config.quality.crfVp9}', '-b:v', '0']);
        default:
          args.addAll(['-crf', '${config.quality.crfH264}']);
      }
    }

    // Audio handling
    if (config.muteAudio) {
      args.add('-an');
    } else {
      if (config.format == ConvertOutputFormat.webm) {
        args.addAll(['-c:a', 'libopus', '-b:a', '${config.audioBitrateKbps}k']);
      } else {
        args.addAll(['-c:a', 'aac', '-b:a', '${config.audioBitrateKbps}k']);
      }
    }

    // Web & streaming optimizations for MP4 containers
    if (config.format == ConvertOutputFormat.mp4H264 ||
        config.format == ConvertOutputFormat.mp4H265) {
      args.addAll(['-movflags', '+faststart']);
    }

    args.add(outputPath);
    return List.unmodifiable(args);
  }
}
