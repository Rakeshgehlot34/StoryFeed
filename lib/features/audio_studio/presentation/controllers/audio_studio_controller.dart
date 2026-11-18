import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../convert/domain/models/convert_config.dart';
import '../../../jobs/domain/job_queue_controller.dart';
import '../../../jobs/domain/models/job_record.dart';
import '../../../output/presentation/controllers/output_controller.dart';
import '../../../processing/domain/export_job_controller.dart';
import '../../../processing/domain/models/video_metadata.dart';
import '../../../video_picker/domain/models/picked_video.dart';
import '../../data/audio_recording_service.dart';
import '../../domain/models/audio_studio_project.dart';

/// State representation for Audio Studio multi-track editor.
class AudioStudioState {
  final PickedVideo? video;
  final VideoMetadata? metadata;
  final AudioStudioConfig config;
  final bool isRecording;
  final int recordingElapsedSeconds;
  final String? recordedVoiceoverPath;
  final bool isLoading;
  final String? errorMessage;

  const AudioStudioState({
    this.video,
    this.metadata,
    this.config = const AudioStudioConfig(
      videoPath: '',
      videoDurationSeconds: 0.0,
    ),
    this.isRecording = false,
    this.recordingElapsedSeconds = 0,
    this.recordedVoiceoverPath,
    this.isLoading = false,
    this.errorMessage,
  });

  AudioStudioState copyWith({
    PickedVideo? video,
    bool clearVideo = false,
    VideoMetadata? metadata,
    bool clearMetadata = false,
    AudioStudioConfig? config,
    bool? isRecording,
    int? recordingElapsedSeconds,
    String? recordedVoiceoverPath,
    bool clearVoiceoverPath = false,
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AudioStudioState(
      video: clearVideo ? null : (video ?? this.video),
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
      config: config ?? this.config,
      isRecording: isRecording ?? this.isRecording,
      recordingElapsedSeconds:
          recordingElapsedSeconds ?? this.recordingElapsedSeconds,
      recordedVoiceoverPath: clearVoiceoverPath
          ? null
          : (recordedVoiceoverPath ?? this.recordedVoiceoverPath),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  return PlatformAudioRecordingService();
});

final audioStudioControllerProvider =
    NotifierProvider<AudioStudioController, AudioStudioState>(
      AudioStudioController.new,
    );

class AudioStudioController extends Notifier<AudioStudioState> {
  Timer? _recordingTimer;

  @override
  AudioStudioState build() {
    ref.onDispose(() {
      _recordingTimer?.cancel();
    });
    return const AudioStudioState();
  }

  /// Sets source video and initializes multi-track project specifications.
  Future<void> setVideo(PickedVideo video) async {
    state = state.copyWith(
      video: video,
      isLoading: true,
      clearErrorMessage: true,
    );

    try {
      final processor = ref.read(videoProcessorProvider);
      final meta = await processor.getMetadata(video.path);
      final durSec = meta.duration.inMilliseconds / 1000.0;

      state = state.copyWith(
        metadata: meta,
        isLoading: false,
        config: AudioStudioConfig(
          videoPath: video.path,
          videoDurationSeconds: durSec > 0 ? durSec : 1.0,
        ),
      );
    } catch (e) {
      AppLogger.warning('AudioStudio failed to probe video metadata: $e');
      final durSec = video.duration.inMilliseconds / 1000.0;
      state = state.copyWith(
        isLoading: false,
        config: AudioStudioConfig(
          videoPath: video.path,
          videoDurationSeconds: durSec > 0 ? durSec : 1.0,
        ),
      );
    }
  }

  void setOriginalVolume(double volume) {
    state = state.copyWith(
      config: state.config.copyWith(originalVolume: volume.clamp(0.0, 2.0)),
    );
  }

  void toggleOriginalMute() {
    state = state.copyWith(
      config: state.config.copyWith(
        isOriginalMuted: !state.config.isOriginalMuted,
      ),
    );
  }

  void setMusicTrack(AudioTrack track) {
    state = state.copyWith(config: state.config.copyWith(musicTrack: track));
  }

  void removeMusicTrack() {
    state = state.copyWith(
      config: state.config.copyWith(clearMusicTrack: true),
    );
  }

  void setMusicVolume(double volume) {
    if (state.config.musicTrack == null) return;
    state = state.copyWith(
      config: state.config.copyWith(
        musicTrack: state.config.musicTrack!.copyWith(
          volume: volume.clamp(0.0, 2.0),
        ),
      ),
    );
  }

  void setMusicLoop(bool loop) {
    if (state.config.musicTrack == null) return;
    state = state.copyWith(
      config: state.config.copyWith(
        musicTrack: state.config.musicTrack!.copyWith(loop: loop),
      ),
    );
  }

  void setVoiceoverTrack(AudioTrack track) {
    state = state.copyWith(
      config: state.config.copyWith(voiceoverTrack: track),
    );
  }

  void removeVoiceoverTrack() {
    state = state.copyWith(
      config: state.config.copyWith(clearVoiceoverTrack: true),
      clearVoiceoverPath: true,
    );
  }

  void setVoiceoverVolume(double volume) {
    if (state.config.voiceoverTrack == null) return;
    state = state.copyWith(
      config: state.config.copyWith(
        voiceoverTrack: state.config.voiceoverTrack!.copyWith(
          volume: volume.clamp(0.0, 2.0),
        ),
      ),
    );
  }

  void setVoiceoverStartTime(double timeSec) {
    if (state.config.voiceoverTrack == null) return;
    state = state.copyWith(
      config: state.config.copyWith(
        voiceoverTrack: state.config.voiceoverTrack!.copyWith(
          startTimeSeconds: timeSec.clamp(
            0.0,
            state.config.videoDurationSeconds,
          ),
        ),
      ),
    );
  }

  void toggleDucking(bool enable) {
    state = state.copyWith(
      config: state.config.copyWith(enableDucking: enable),
    );
  }

  void setExportMode(AudioStudioExportMode mode) {
    state = state.copyWith(config: state.config.copyWith(exportMode: mode));
  }

  void setAudioFormat(AudioOutputFormat format) {
    state = state.copyWith(config: state.config.copyWith(audioFormat: format));
  }

  /// Begins microphone voice-over recording into a dedicated AAC cache file.
  Future<bool> startVoiceoverRecording() async {
    final service = ref.read(audioRecordingServiceProvider);
    final hasPerm = await service.requestPermission();
    if (!hasPerm) {
      state = state.copyWith(
        errorMessage:
            'Microphone permission is required to record voice-overs.',
      );
      return false;
    }

    String cacheDirPath;
    try {
      final tempDir = await getTemporaryDirectory();
      cacheDirPath = tempDir.path;
    } catch (_) {
      cacheDirPath = Directory.systemTemp.path;
    }

    final voPath = p.join(
      cacheDirPath,
      'voiceover_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    final started = await service.startRecording(voPath);
    if (!started) {
      state = state.copyWith(
        errorMessage: 'Failed to initiate microphone recording.',
      );
      return false;
    }

    _recordingTimer?.cancel();
    state = state.copyWith(
      isRecording: true,
      recordingElapsedSeconds: 0,
      recordedVoiceoverPath: voPath,
      clearErrorMessage: true,
    );

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      state = state.copyWith(
        recordingElapsedSeconds: state.recordingElapsedSeconds + 1,
      );
    });

    return true;
  }

  /// Stops voice-over recording and attaches the new track to the project timeline.
  Future<void> stopVoiceoverRecording() async {
    final service = ref.read(audioRecordingServiceProvider);
    await service.stopRecording();
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final voPath = state.recordedVoiceoverPath;
    final dur = state.recordingElapsedSeconds.toDouble();

    if (voPath != null && dur > 0) {
      final newTrack = AudioTrack(
        type: AudioTrackType.voiceover,
        sourcePath: voPath,
        title: 'Voice-over (${dur.toInt()}s)',
        durationSeconds: dur,
        volume: 1.0,
      );
      state = state.copyWith(
        isRecording: false,
        config: state.config.copyWith(voiceoverTrack: newTrack),
      );
    } else {
      state = state.copyWith(isRecording: false);
    }
  }

  /// Enqueues the audio studio job into the sequential JobQueueController.
  Future<String> enqueueAudioStudioJob() async {
    final video = state.video;
    if (video == null) {
      throw const VideoProcessingException(
        'No active video loaded in Audio Studio.',
      );
    }

    final outputDir = await ref.read(outputDirectoryProvider.future);
    final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';

    final baseName = state.config.customFileName?.trim().isNotEmpty == true
        ? state.config.customFileName!.trim()
        : p.basenameWithoutExtension(video.path);

    final job = JobRecord(
      id: jobId,
      type: JobType.audioStudio,
      title: 'Audio Studio: $baseName (${state.config.exportMode.shortName})',
      inputPath: video.path,
      outputDirectory: outputDir,
      totalParts: 1,
      createdAt: DateTime.now(),
      payload: {'config': state.config.toJson()},
    );

    await ref.read(jobQueueControllerProvider.notifier).enqueueJob(job);
    return jobId;
  }

  void reset() {
    _recordingTimer?.cancel();
    state = const AudioStudioState();
  }
}
