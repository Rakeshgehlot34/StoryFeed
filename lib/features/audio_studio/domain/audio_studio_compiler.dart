import '../../convert/domain/models/convert_config.dart';
import 'models/audio_studio_project.dart';

/// Compiles [AudioStudioConfig] into optimized multi-track FFmpeg mixing commands.
class AudioStudioCompiler {
  const AudioStudioCompiler();

  /// Compiles the argument list for FFmpeg multi-track audio execution.
  List<String> compile({
    required AudioStudioConfig config,
    required String outputPath,
    bool hasSourceAudio = true,
  }) {
    final args = <String>['-y'];

    // Input 0: Source Video
    args.addAll(['-i', config.videoPath]);

    int nextInputIndex = 1;
    int? musicInputIndex;
    int? voInputIndex;

    // Input 1 (Optional): Music track
    final music = config.musicTrack;
    if (music != null && music.sourcePath.trim().isNotEmpty) {
      musicInputIndex = nextInputIndex++;
      if (music.loop) {
        args.addAll(['-stream_loop', '-1', '-i', music.sourcePath]);
      } else {
        args.addAll(['-i', music.sourcePath]);
      }
    }

    // Input 2 (Optional): Voice-over track
    final vo = config.voiceoverTrack;
    if (vo != null && vo.sourcePath.trim().isNotEmpty) {
      voInputIndex = nextInputIndex++;
      args.addAll(['-i', vo.sourcePath]);
    }

    // Case 1: All audio is completely muted or no tracks active
    final includeOriginal = hasSourceAudio &&
        !config.isOriginalMuted &&
        config.originalVolume > 0.01;
    final includeMusic = music != null && !music.isMuted && music.volume > 0.01;
    final includeVo = vo != null && !vo.isMuted && vo.volume > 0.01;

    final filterParts = <String>[];
    final mixInputs = <String>[];

    // Track 0: Original video audio
    if (includeOriginal) {
      filterParts.add(
        '[0:a]volume=${config.originalVolume.toStringAsFixed(2)}[a_orig]',
      );
      mixInputs.add('[a_orig]');
    }

    // Track 2: Voice-over
    if (includeVo && voInputIndex != null) {
      final delayMs = (vo.startTimeSeconds * 1000).toInt();
      if (delayMs > 0) {
        filterParts.add(
          '[$voInputIndex:a]adelay=$delayMs|$delayMs,volume=${vo.volume.toStringAsFixed(2)}[a_vo]',
        );
      } else {
        filterParts.add(
          '[$voInputIndex:a]volume=${vo.volume.toStringAsFixed(2)}[a_vo]',
        );
      }
      mixInputs.add('[a_vo]');
    }

    // Track 1: Music track (with optional sidechain ducking against voiceover)
    if (includeMusic && musicInputIndex != null) {
      final musicVol = music.volume.toStringAsFixed(2);
      final trimDur = config.videoDurationSeconds.toStringAsFixed(3);

      if (includeVo && config.enableDucking) {
        filterParts.add(
          '[$musicInputIndex:a]volume=$musicVol,atrim=0:$trimDur[a_music_raw]',
        );
        // Sidechain compression: compresses music whenever speech/voiceover is loud
        filterParts.add(
          '[a_music_raw][a_vo]sidechaincompress=threshold=0.08:ratio=5:attack=50:release=300[a_music_ducked]',
        );
        mixInputs.insert(includeOriginal ? 1 : 0, '[a_music_ducked]');
      } else {
        filterParts.add(
          '[$musicInputIndex:a]volume=$musicVol,atrim=0:$trimDur[a_music]',
        );
        mixInputs.insert(includeOriginal ? 1 : 0, '[a_music]');
      }
    }

    // Determine output graph structure
    if (mixInputs.isEmpty) {
      if (config.exportMode == AudioStudioExportMode.videoWithAudio) {
        // Strip audio completely
        args.addAll(['-c:v', 'copy', '-an', outputPath]);
        return List.unmodifiable(args);
      } else {
        // Silent audio output
        filterParts.add(
          'anullsrc=r=44100:cl=stereo,atrim=0:${config.videoDurationSeconds.toStringAsFixed(3)}[aout]',
        );
      }
    } else if (mixInputs.length == 1) {
      // Single track: route directly to [aout] via anull passthrough
      final single = mixInputs.first;
      filterParts.add('$single anull [aout]');
    } else {
      // Multi-track mix
      final inputTags = mixInputs.join();
      filterParts.add(
        '$inputTags amix=inputs=${mixInputs.length}:duration=first:dropout_transition=2[aout]',
      );
    }

    args.addAll(['-filter_complex', filterParts.join(';')]);

    if (config.exportMode == AudioStudioExportMode.videoWithAudio) {
      // Stream-copy video directly for instant lossless processing
      args.addAll([
        '-map',
        '0:v',
        '-c:v',
        'copy',
        '-map',
        '[aout]',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-movflags',
        '+faststart',
      ]);
    } else {
      // Extracted audio only
      args.addAll(['-vn', '-map', '[aout]']);
      switch (config.audioFormat) {
        case AudioOutputFormat.mp3:
          args.addAll(['-c:a', 'libmp3lame', '-b:a', '192k']);
        case AudioOutputFormat.aac:
          args.addAll(['-c:a', 'aac', '-b:a', '192k']);
        case AudioOutputFormat.wav:
          args.addAll(['-c:a', 'pcm_s16le']);
        case AudioOutputFormat.opus:
          args.addAll(['-c:a', 'libopus', '-b:a', '128k']);
      }
    }

    args.add(outputPath);
    return List.unmodifiable(args);
  }
}
