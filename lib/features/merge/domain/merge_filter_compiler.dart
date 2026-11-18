import 'models/merge_project.dart';

/// Pure compiler for FFmpeg command arguments and filter complexes
/// supporting fast stream copy concatenation and complex normalized merging
/// with transitions and aspect ratio adaptation.
class MergeFilterCompiler {
  MergeFilterCompiler._();

  /// Builds arguments for FFmpeg concat demuxer (lossless stream copy).
  ///
  /// Requires all input files to have identical codecs, dimensions, fps, and audio tracks.
  static List<String> buildFastConcatArgs({
    required String listFilePath,
    required String outputPath,
  }) {
    return [
      '-y',
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      listFilePath,
      '-c',
      'copy',
      '-movflags',
      '+faststart',
      outputPath,
    ];
  }

  /// Generates the contents for the concat demuxer list text file.
  static String generateConcatListContent(List<String> filePaths) {
    final buffer = StringBuffer();
    for (final path in filePaths) {
      // Escape single quotes for FFmpeg concat demuxer format: ' -> '\''
      final escaped = path.replaceAll("'", r"'\''");
      buffer.writeln("file '$escaped'");
    }
    return buffer.toString();
  }

  /// Builds arguments for complex multi-clip merging with aspect ratio normalization,
  /// background padding/blur/crop, synthetic audio for silent inputs, and crossfade transitions.
  static List<String> buildComplexMergeArgs({
    required MergeConfig config,
    required String outputPath,
  }) {
    if (config.clips.isEmpty) {
      throw ArgumentError('MergeConfig must contain at least one clip.');
    }

    final args = <String>['-y'];

    // 1. Declare all video inputs
    for (final clip in config.clips) {
      args.addAll(['-i', clip.videoPath]);
    }

    // 2. Build filter graph
    final filterComplex = buildFilterComplex(config);
    args.addAll(['-filter_complex', filterComplex]);

    // 3. Map filtered streams
    final lastIdx = config.clips.length - 1;
    final videoOutTag = config.transition.isNone || config.clips.length == 1
        ? '[v_out]'
        : '[xv_$lastIdx]';
    final audioOutTag = config.transition.isNone || config.clips.length == 1
        ? '[a_out]'
        : '[xa_$lastIdx]';

    args.addAll([
      '-map',
      videoOutTag,
      '-map',
      audioOutTag,
      '-c:v',
      'libx264',
      '-preset',
      'veryfast',
      '-crf',
      '23',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-movflags',
      '+faststart',
      outputPath,
    ]);

    return args;
  }

  /// Compiles the complete -filter_complex string.
  static String buildFilterComplex(MergeConfig config) {
    final filters = <String>[];
    final count = config.clips.length;
    final targetW = config.resolvedWidth;
    final targetH = config.resolvedHeight;

    // Normalization per clip
    for (int i = 0; i < count; i++) {
      final clip = config.clips[i];
      final vTrimmed = _buildVideoTrimAndNormalize(
        clip: clip,
        index: i,
        targetW: targetW,
        targetH: targetH,
        fitMode: config.fitMode,
      );
      filters.add(vTrimmed);

      final aNormalized = _buildAudioNormalize(clip: clip, index: i);
      filters.add(aNormalized);
    }

    // Direct concat or transitions
    if (config.transition.isNone || count == 1) {
      final concatInputs = StringBuffer();
      for (int i = 0; i < count; i++) {
        concatInputs.write('[v_norm_$i][a_norm_$i]');
      }
      filters.add('${concatInputs}concat=n=$count:v=1:a=1[v_out][a_out]');
    } else {
      // Cascaded xfade for video and acrossfade for audio
      final dur = config.transitionDurationSeconds;
      double currentOffset = config.clips[0].effectiveDurationSeconds - dur;

      for (int i = 1; i < count; i++) {
        final prevV = i == 1 ? '[v_norm_0]' : '[xv_${i - 1}]';
        final nextV = '[v_norm_$i]';
        final outV = '[xv_$i]';

        final safeOffset = currentOffset > 0.05 ? currentOffset : 0.05;
        filters.add(
          '$prevV${nextV}xfade=transition=${config.transition.name}:duration=${dur.toStringAsFixed(3)}:offset=${safeOffset.toStringAsFixed(3)}$outV',
        );

        final prevA = i == 1 ? '[a_norm_0]' : '[xa_${i - 1}]';
        final nextA = '[a_norm_$i]';
        final outA = '[xa_$i]';

        filters.add(
          '$prevA${nextA}acrossfade=d=${dur.toStringAsFixed(3)}:c1=tri:c2=tri$outA',
        );

        if (i < count - 1) {
          currentOffset += config.clips[i].effectiveDurationSeconds - dur;
        }
      }
    }

    return filters.join(';\n');
  }

  static String _buildVideoTrimAndNormalize({
    required MergeClipItem clip,
    required int index,
    required int targetW,
    required int targetH,
    required CanvasFitMode fitMode,
  }) {
    final trimFilters = <String>[];
    if (clip.startTrimSeconds > 0.0 || clip.endTrimSeconds != null) {
      final start = clip.startTrimSeconds.toStringAsFixed(3);
      if (clip.endTrimSeconds != null) {
        final end = clip.endTrimSeconds!.toStringAsFixed(3);
        trimFilters.add('trim=start=$start:end=$end,setpts=PTS-STARTPTS');
      } else {
        trimFilters.add('trim=start=$start,setpts=PTS-STARTPTS');
      }
    }

    final trimChain = trimFilters.isNotEmpty ? ',${trimFilters.join(",")}' : '';

    switch (fitMode) {
      case CanvasFitMode.fitBlack:
        return '[$index:v]null$trimChain,scale=w=$targetW:h=$targetH:force_original_aspect_ratio=decrease,pad=w=$targetW:h=$targetH:x=(ow-iw)/2:y=(oh-ih)/2:color=black,setsar=1,fps=fps=30[v_norm_$index]';

      case CanvasFitMode.cropFill:
        return '[$index:v]null$trimChain,scale=w=$targetW:h=$targetH:force_original_aspect_ratio=increase,crop=w=$targetW:h=$targetH,setsar=1,fps=fps=30[v_norm_$index]';

      case CanvasFitMode.fitBlur:
        final prefix =
            '[$index:v]null$trimChain,split=2[fg_raw_$index][bg_raw_$index];\n'
            '[bg_raw_$index]scale=w=$targetW:h=$targetH:force_original_aspect_ratio=increase,crop=w=$targetW:h=$targetH,gblur=sigma=20[bg_blur_$index];\n'
            '[fg_raw_$index]scale=w=$targetW:h=$targetH:force_original_aspect_ratio=decrease[fg_sc_$index];\n'
            '[bg_blur_$index][fg_sc_$index]overlay=(W-w)/2:(H-h)/2,setsar=1,fps=fps=30[v_norm_$index]';
        return prefix;
    }
  }

  static String _buildAudioNormalize({
    required MergeClipItem clip,
    required int index,
  }) {
    if (!clip.hasAudio) {
      final dur = clip.effectiveDurationSeconds.toStringAsFixed(3);
      return 'anullsrc=r=44100:cl=stereo,atrim=0:$dur,asetpts=PTS-STARTPTS[a_norm_$index]';
    }

    final audioFilters = <String>[];
    if (clip.startTrimSeconds > 0.0 || clip.endTrimSeconds != null) {
      final start = clip.startTrimSeconds.toStringAsFixed(3);
      if (clip.endTrimSeconds != null) {
        final end = clip.endTrimSeconds!.toStringAsFixed(3);
        audioFilters.add('atrim=start=$start:end=$end,asetpts=PTS-STARTPTS');
      } else {
        audioFilters.add('atrim=start=$start,asetpts=PTS-STARTPTS');
      }
    }
    audioFilters.add('aformat=sample_rates=44100:channel_layouts=stereo');

    return '[$index:a]${audioFilters.join(",")}[a_norm_$index]';
  }
}
