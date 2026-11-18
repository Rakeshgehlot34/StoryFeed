import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/audio_studio/data/audio_recording_service.dart';
import 'package:shorts_splitter/features/audio_studio/domain/models/audio_studio_project.dart';
import 'package:shorts_splitter/features/audio_studio/presentation/controllers/audio_studio_controller.dart';
import 'package:shorts_splitter/features/jobs/domain/job_queue_controller.dart';
import 'package:shorts_splitter/features/jobs/domain/models/job_record.dart';
import 'package:shorts_splitter/features/output/presentation/controllers/output_controller.dart';
import 'package:shorts_splitter/features/processing/domain/export_job_controller.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';

import '../../fakes/fake_video_processor.dart';

class _FakeOutputDirectoryNotifier extends OutputDirectoryNotifier {
  @override
  Future<String> build() async => '/fake/output/directory';
}

class _FakeAudioRecordingService implements AudioRecordingService {
  bool recordingActive = false;
  bool permissionGranted = true;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  @override
  Future<bool> startRecording(String destFilePath) async {
    recordingActive = true;
    return true;
  }

  @override
  Future<bool> stopRecording() async {
    recordingActive = false;
    return true;
  }

  @override
  Future<bool> isRecording() async => recordingActive;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeVideoProcessor fakeProcessor;
  late _FakeAudioRecordingService fakeRecordingService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeProcessor = FakeVideoProcessor();
    fakeRecordingService = _FakeAudioRecordingService();
    container = ProviderContainer(
      overrides: [
        videoProcessorProvider.overrideWithValue(fakeProcessor),
        outputDirectoryProvider.overrideWith(_FakeOutputDirectoryNotifier.new),
        audioRecordingServiceProvider.overrideWithValue(fakeRecordingService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  const testVideo = PickedVideo(
    path: '/cache/audio_test_video.mp4',
    fileName: 'audio_test_video.mp4',
    baseName: 'audio_test_video',
    duration: Duration(seconds: 40),
    sizeInBytes: 20 * 1024 * 1024,
    width: 1920,
    height: 1080,
  );

  test(
    'setVideo initializes multi-track project with video duration',
    () async {
      final controller = container.read(audioStudioControllerProvider.notifier);
      await controller.setVideo(testVideo);

      final state = container.read(audioStudioControllerProvider);
      expect(state.video, equals(testVideo));
      expect(state.config.videoPath, testVideo.path);
      expect(state.config.originalVolume, 1.0);
      expect(state.config.isOriginalMuted, isFalse);
      expect(state.isLoading, isFalse);
    },
  );

  test('volume adjustments and muting update config state', () async {
    final controller = container.read(audioStudioControllerProvider.notifier);
    await controller.setVideo(testVideo);

    controller.setOriginalVolume(0.4);
    expect(
      container.read(audioStudioControllerProvider).config.originalVolume,
      0.4,
    );

    controller.toggleOriginalMute();
    expect(
      container.read(audioStudioControllerProvider).config.isOriginalMuted,
      isTrue,
    );

    controller.toggleDucking(true);
    expect(
      container.read(audioStudioControllerProvider).config.enableDucking,
      isTrue,
    );
  });

  test('adding, modifying, and removing music track updates state', () async {
    final controller = container.read(audioStudioControllerProvider.notifier);
    await controller.setVideo(testVideo);

    const track = AudioTrack(
      type: AudioTrackType.music,
      sourcePath: '/music/rock.mp3',
      title: 'Rock Track',
      volume: 0.8,
    );

    controller.setMusicTrack(track);
    expect(
      container.read(audioStudioControllerProvider).config.musicTrack?.title,
      'Rock Track',
    );

    controller.setMusicVolume(1.5);
    expect(
      container.read(audioStudioControllerProvider).config.musicTrack?.volume,
      1.5,
    );

    controller.setMusicLoop(true);
    expect(
      container.read(audioStudioControllerProvider).config.musicTrack?.loop,
      isTrue,
    );

    controller.removeMusicTrack();
    expect(
      container.read(audioStudioControllerProvider).config.musicTrack,
      isNull,
    );
  });

  test('voiceover recording lifecycle adds recorded track', () async {
    final controller = container.read(audioStudioControllerProvider.notifier);
    await controller.setVideo(testVideo);

    final started = await controller.startVoiceoverRecording();
    expect(started, isTrue);
    expect(container.read(audioStudioControllerProvider).isRecording, isTrue);

    await controller.stopVoiceoverRecording();
    expect(container.read(audioStudioControllerProvider).isRecording, isFalse);
  });

  test(
    'enqueueAudioStudioJob adds job to unified JobQueueController',
    () async {
      final controller = container.read(audioStudioControllerProvider.notifier);
      await controller.setVideo(testVideo);

      final jobId = await controller.enqueueAudioStudioJob();
      expect(jobId, startsWith('job_'));

      final queueState = container.read(jobQueueControllerProvider);
      expect(queueState.jobs.any((j) => j.id == jobId), isTrue);

      final queuedJob = queueState.jobs.firstWhere((j) => j.id == jobId);
      expect(queuedJob.type, JobType.audioStudio);
    },
  );
}
