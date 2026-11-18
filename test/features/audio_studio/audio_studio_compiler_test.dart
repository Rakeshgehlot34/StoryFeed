import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/audio_studio/domain/audio_studio_compiler.dart';
import 'package:shorts_splitter/features/audio_studio/domain/models/audio_studio_project.dart';
import 'package:shorts_splitter/features/convert/domain/models/convert_config.dart';

void main() {
  group('AudioStudioCompiler tests', () {
    const compiler = AudioStudioCompiler();

    test('compiles audio muting when all tracks are muted', () {
      const config = AudioStudioConfig(
        videoPath: '/input.mp4',
        videoDurationSeconds: 10.0,
        isOriginalMuted: true,
      );

      final args = compiler.compile(
        config: config,
        outputPath: '/output.mp4',
        hasSourceAudio: true,
      );

      expect(args, contains('-an'));
      expect(args, contains('-c:v'));
      expect(args, contains('copy'));
      expect(args.last, '/output.mp4');
    });

    test('compiles single music replacement when original is muted', () {
      const config = AudioStudioConfig(
        videoPath: '/input.mp4',
        videoDurationSeconds: 15.0,
        isOriginalMuted: true,
        musicTrack: AudioTrack(
          type: AudioTrackType.music,
          sourcePath: '/song.mp3',
          title: 'Song',
          volume: 0.8,
          loop: true,
        ),
      );

      final args = compiler.compile(
        config: config,
        outputPath: '/output.mp4',
        hasSourceAudio: true,
      );

      expect(args, contains('-stream_loop'));
      expect(args, contains('-1'));
      expect(args, contains('/song.mp3'));
      expect(args, contains('-filter_complex'));
      final fcIndex = args.indexOf('-filter_complex');
      expect(args[fcIndex + 1], contains('volume=0.80'));
      expect(args[fcIndex + 1], contains('atrim=0:15.000'));
      expect(args, contains('-map'));
      expect(args, contains('[aout]'));
      expect(args, contains('copy')); // video copy
    });

    test('compiles 3-track audio mix with sidechain ducking', () {
      const config = AudioStudioConfig(
        videoPath: '/input.mp4',
        videoDurationSeconds: 30.0,
        originalVolume: 0.5,
        musicTrack: AudioTrack(
          type: AudioTrackType.music,
          sourcePath: '/music.mp3',
          title: 'Music',
          volume: 0.4,
        ),
        voiceoverTrack: AudioTrack(
          type: AudioTrackType.voiceover,
          sourcePath: '/vo.m4a',
          title: 'Voiceover',
          volume: 1.5,
          startTimeSeconds: 3.0,
        ),
        enableDucking: true,
      );

      final args = compiler.compile(
        config: config,
        outputPath: '/output.mp4',
        hasSourceAudio: true,
      );

      expect(args, contains('-filter_complex'));
      final fcIndex = args.indexOf('-filter_complex');
      final filterVal = args[fcIndex + 1];

      // Ducking filter present
      expect(filterVal, contains('sidechaincompress'));
      // Voiceover delay present (3.0s = 3000ms)
      expect(filterVal, contains('adelay=3000|3000'));
      // amix with 3 tracks
      expect(filterVal, contains('amix=inputs=3'));
    });

    test(
      'compiles standalone audio extraction for MP3, WAV, AAC, and Opus',
      () {
        for (final fmt in AudioOutputFormat.values) {
          final config = AudioStudioConfig(
            videoPath: '/input.mp4',
            videoDurationSeconds: 20.0,
            exportMode: AudioStudioExportMode.extractedAudio,
            audioFormat: fmt,
            musicTrack: const AudioTrack(
              type: AudioTrackType.music,
              sourcePath: '/bg.mp3',
              title: 'BG',
              volume: 0.7,
            ),
          );

          final args = compiler.compile(
            config: config,
            outputPath: '/output${fmt.fileExtension}',
            hasSourceAudio: true,
          );

          expect(args, contains('-vn'));
          expect(args, contains('-map'));
          expect(args, contains('[aout]'));
          expect(args, contains('-c:a'));
          expect(args, contains(fmt.codec));
        }
      },
    );

    test('handles silent video gracefully without accessing input 0 audio', () {
      const config = AudioStudioConfig(
        videoPath: '/silent.mp4',
        videoDurationSeconds: 10.0,
        musicTrack: AudioTrack(
          type: AudioTrackType.music,
          sourcePath: '/music.mp3',
          title: 'Music',
          volume: 1.0,
        ),
      );

      final args = compiler.compile(
        config: config,
        outputPath: '/out.mp4',
        hasSourceAudio: false,
      );

      final fcIndex = args.indexOf('-filter_complex');
      final filterVal = args[fcIndex + 1];
      // Should NOT reference [0:a]
      expect(filterVal, isNot(contains('[0:a]')));
      // Should reference input 1
      expect(filterVal, contains('[1:a]'));
    });
  });
}
