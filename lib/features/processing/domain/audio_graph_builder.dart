/// Pure, deterministic compiler for FFmpeg audio filter graphs.
/// Generates atempo chains for pitch-preserving speed changes, volume adjustments,
/// audio fades, delay, and multi-track mixing.
class AudioGraphBuilder {
  AudioGraphBuilder._();

  /// Builds a sequence of `atempo` filters that collectively achieve the target [speed].
  ///
  /// FFmpeg's `atempo` filter strictly accepts values in the range [0.5, 2.0].
  /// To achieve speeds outside this interval (e.g., 0.25x or 4.0x), multiple
  /// `atempo` filters must be chained in series.
  static List<String> buildAtempoChain(double speed) {
    if (speed <= 0) {
      throw ArgumentError.value(
        speed,
        'speed',
        'Audio speed must be greater than 0',
      );
    }

    if ((speed - 1.0).abs() < 0.0001) {
      return const [];
    }

    final filters = <String>[];
    double remaining = speed;

    if (remaining > 2.0) {
      while (remaining > 2.0) {
        filters.add('atempo=2.0');
        remaining /= 2.0;
      }
      if ((remaining - 1.0).abs() >= 0.0001) {
        filters.add('atempo=${_formatTempo(remaining)}');
      }
    } else if (remaining < 0.5) {
      while (remaining < 0.5) {
        filters.add('atempo=0.5');
        remaining /= 0.5;
      }
      if ((remaining - 1.0).abs() >= 0.0001) {
        filters.add('atempo=${_formatTempo(remaining)}');
      }
    } else {
      filters.add('atempo=${_formatTempo(remaining)}');
    }

    return filters;
  }

  static String _formatTempo(double val) {
    final fixed = val.toStringAsFixed(3);
    if (fixed.contains('.')) {
      final trimmed =
          fixed.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      return trimmed.contains('.') ? trimmed : '$trimmed.0';
    }
    return '$fixed.0';
  }

  /// Builds a unified audio filter string (`-af` argument value) applying volume,
  /// atempo speed scaling, fade-in, fade-out, and reverse.
  static String? buildAudioFilters({
    double? volume,
    double? speed,
    double? fadeInSeconds,
    double? fadeOutSeconds,
    double? totalDurationSeconds,
    bool reverse = false,
  }) {
    final filters = <String>[];

    // 1. Reverse
    if (reverse) {
      filters.add('areverse');
    }

    // 2. Speed (pitch-preserving atempo chain)
    if (speed != null && (speed - 1.0).abs() >= 0.0001) {
      filters.addAll(buildAtempoChain(speed));
    }

    // 3. Volume adjustment
    if (volume != null && (volume - 1.0).abs() >= 0.001) {
      filters.add('volume=${volume.toStringAsFixed(2)}');
    }

    // 4. Fade in
    if (fadeInSeconds != null && fadeInSeconds > 0) {
      filters.add('afade=t=in:st=0:d=${fadeInSeconds.toStringAsFixed(3)}');
    }

    // 5. Fade out
    if (fadeOutSeconds != null &&
        fadeOutSeconds > 0 &&
        totalDurationSeconds != null &&
        totalDurationSeconds > fadeOutSeconds) {
      final startTime = totalDurationSeconds - fadeOutSeconds;
      filters.add(
        'afade=t=out:st=${startTime.toStringAsFixed(3)}:d=${fadeOutSeconds.toStringAsFixed(3)}',
      );
    }

    if (filters.isEmpty) return null;
    return filters.join(',');
  }

  /// Builds a filter complex segment to mix two audio tracks (e.g. video speech + background music).
  ///
  /// Produces:
  /// `[0:a]volume=1.0[a1];[1:a]volume=0.5[a2];[a1][a2]amix=inputs=2:duration=first:dropout_transition=2[aout]`
  static String buildAudioMixFilterComplex({
    String track1Tag = '0:a',
    String track2Tag = '1:a',
    double track1Volume = 1.0,
    double track2Volume = 0.5,
    String outputTag = 'aout',
  }) {
    return '[$track1Tag]volume=${track1Volume.toStringAsFixed(2)}[a_mix1];'
        '[$track2Tag]volume=${track2Volume.toStringAsFixed(2)}[a_mix2];'
        '[a_mix1][a_mix2]amix=inputs=2:duration=first:dropout_transition=2[$outputTag]';
  }
}
