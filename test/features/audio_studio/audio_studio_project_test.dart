import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/audio_studio/domain/models/audio_studio_project.dart';
import 'package:shorts_splitter/features/convert/domain/models/convert_config.dart';

void main() {
  group('AudioStudioProject domain tests', () {
    test('AudioTrack default values and copyWith', () {
      const track = AudioTrack(
        type: AudioTrackType.music,
        sourcePath: '/music.mp3',
        title: 'Background Beat',
      );

      expect(track.volume, 1.0);
      expect(track.startTimeSeconds, 0.0);
      expect(track.loop, isFalse);
      expect(track.isMuted, isFalse);

      final updated = track.copyWith(volume: 0.5, loop: true);
      expect(updated.volume, 0.5);
      expect(updated.loop, isTrue);
      expect(updated.title, 'Background Beat');
    });

    test('AudioStudioConfig hasActiveAudioTracks logic', () {
      // Default with original audio
      const cfg1 = AudioStudioConfig(
        videoPath: '/video.mp4',
        videoDurationSeconds: 30.0,
      );
      expect(cfg1.hasActiveAudioTracks, isTrue);

      // Muted original and no tracks
      final cfg2 = cfg1.copyWith(isOriginalMuted: true);
      expect(cfg2.hasActiveAudioTracks, isFalse);

      // Muted original but music present
      final cfg3 = cfg2.copyWith(
        musicTrack: const AudioTrack(
          type: AudioTrackType.music,
          sourcePath: '/m.mp3',
          title: 'Music',
          volume: 0.8,
        ),
      );
      expect(cfg3.hasActiveAudioTracks, isTrue);
    });

    test('AudioStudioConfig effectiveExtension reflects export mode', () {
      const videoMode = AudioStudioConfig(
        videoPath: '/video.mp4',
        videoDurationSeconds: 20.0,
        exportMode: AudioStudioExportMode.videoWithAudio,
      );
      expect(videoMode.effectiveExtension, '.mp4');

      const audioMp3Mode = AudioStudioConfig(
        videoPath: '/video.mp4',
        videoDurationSeconds: 20.0,
        exportMode: AudioStudioExportMode.extractedAudio,
        audioFormat: AudioOutputFormat.mp3,
      );
      expect(audioMp3Mode.effectiveExtension, '.mp3');

      const audioWavMode = AudioStudioConfig(
        videoPath: '/video.mp4',
        videoDurationSeconds: 20.0,
        exportMode: AudioStudioExportMode.extractedAudio,
        audioFormat: AudioOutputFormat.wav,
      );
      expect(audioWavMode.effectiveExtension, '.wav');
    });

    test(
      'JSON serialization roundtrip preserves all multi-track properties',
      () {
        const original = AudioStudioConfig(
          videoPath: '/source.mp4',
          videoDurationSeconds: 45.0,
          originalVolume: 0.7,
          isOriginalMuted: false,
          musicTrack: AudioTrack(
            type: AudioTrackType.music,
            sourcePath: '/music.mp3',
            title: 'Acoustic Song',
            volume: 0.4,
            loop: true,
          ),
          voiceoverTrack: AudioTrack(
            type: AudioTrackType.voiceover,
            sourcePath: '/vo.m4a',
            title: 'Narrator',
            volume: 1.2,
            startTimeSeconds: 2.5,
            durationSeconds: 15.0,
          ),
          enableDucking: true,
          duckingAttenuation: 0.2,
          exportMode: AudioStudioExportMode.videoWithAudio,
          audioFormat: AudioOutputFormat.aac,
          customFileName: 'custom_audio_mix',
        );

        final json = original.toJson();
        final restored = AudioStudioConfig.fromJson(json);

        expect(restored.videoPath, '/source.mp4');
        expect(restored.videoDurationSeconds, 45.0);
        expect(restored.originalVolume, 0.7);
        expect(restored.isOriginalMuted, isFalse);
        expect(restored.musicTrack, isNotNull);
        expect(restored.musicTrack!.title, 'Acoustic Song');
        expect(restored.musicTrack!.loop, isTrue);
        expect(restored.voiceoverTrack, isNotNull);
        expect(restored.voiceoverTrack!.startTimeSeconds, 2.5);
        expect(restored.enableDucking, isTrue);
        expect(restored.customFileName, 'custom_audio_mix');
      },
    );
  });
}
