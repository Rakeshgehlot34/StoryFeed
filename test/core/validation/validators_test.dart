import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/app/constants/app_strings.dart';
import 'package:shorts_splitter/core/validation/validators/audio_validator.dart';
import 'package:shorts_splitter/core/validation/validators/background_validator.dart';
import 'package:shorts_splitter/core/validation/validators/custom_split_validator.dart';
import 'package:shorts_splitter/core/validation/validators/export_preflight_validator.dart';
import 'package:shorts_splitter/core/validation/validators/output_location_validator.dart';
import 'package:shorts_splitter/core/validation/validators/overlay_validator.dart';
import 'package:shorts_splitter/core/validation/validators/parts_selection_validator.dart';
import 'package:shorts_splitter/core/validation/validators/select_video_validator.dart';
import 'package:shorts_splitter/core/validation/validators/split_settings_validator.dart';
import 'package:shorts_splitter/core/validation/validators/trim_validator.dart';
import 'package:shorts_splitter/features/plan_review/domain/models/clip_processing_state.dart';
import 'package:shorts_splitter/features/split_config/domain/models/background_spec.dart';
import 'package:shorts_splitter/features/split_config/domain/models/clip_segment.dart';
import 'package:shorts_splitter/features/split_config/domain/models/overlay_spec.dart';
import 'package:shorts_splitter/features/video_picker/domain/models/picked_video.dart';

void main() {
  group('SelectVideoValidator Tests', () {
    const validator = SelectVideoValidator();

    test('Fails when video is null', () {
      final res = validator.validate(null);
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valSelectVideoFirst);
    });

    test('Fails when duration is zero', () {
      const video = PickedVideo(
        path: '/video.mp4',
        fileName: 'video.mp4',
        baseName: 'video',
        sizeInBytes: 100,
        duration: Duration.zero,
        width: 1920,
        height: 1080,
      );
      final res = validator.validate(video);
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valVideoZeroDuration);
    });

    test('Fails when file size is zero', () {
      const video = PickedVideo(
        path: '/video.mp4',
        fileName: 'video.mp4',
        baseName: 'video',
        sizeInBytes: 0,
        duration: Duration(seconds: 10),
        width: 1920,
        height: 1080,
      );
      final res = validator.validate(video);
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valVideoUnreadable);
    });

    test('Passes on valid video', () {
      const video = PickedVideo(
        path: '/video.mp4',
        fileName: 'video.mp4',
        baseName: 'video',
        sizeInBytes: 1000,
        duration: Duration(seconds: 60),
        width: 1920,
        height: 1080,
      );
      final res = validator.validate(video);
      expect(res.isValid, isTrue);
    });
  });

  group('TrimValidator Tests', () {
    const validator = TrimValidator();

    test('Fails when start >= end', () {
      final res = validator.validate(
        startSeconds: 15.0,
        endSeconds: 10.0,
        totalDurationSeconds: 60.0,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valStartBeforeEnd);
    });

    test('Fails when end exceeds total duration', () {
      final res = validator.validate(
        startSeconds: 0.0,
        endSeconds: 65.0,
        totalDurationSeconds: 60.0,
      );
      expect(res.isValid, isFalse);
      expect(
        res.firstError?.message,
        contains('Time is beyond the video length'),
      );
    });

    test('Fails when range is less than 1.0 second', () {
      final res = validator.validate(
        startSeconds: 5.0,
        endSeconds: 5.5,
        totalDurationSeconds: 60.0,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valRangeMin1s);
    });

    test('Passes on valid trim range', () {
      final res = validator.validate(
        startSeconds: 5.0,
        endSeconds: 35.0,
        totalDurationSeconds: 60.0,
      );
      expect(res.isValid, isTrue);
    });
  });

  group('SplitSettingsValidator Tests', () {
    const validator = SplitSettingsValidator();

    test('Fails when clip length is null', () {
      final res = validator.validate(
        targetDurationSeconds: null,
        totalTrimDurationSeconds: 60.0,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valEnterClipDuration);
    });

    test('Fails when clip length is less than 1 second', () {
      final res = validator.validate(
        targetDurationSeconds: 0,
        totalTrimDurationSeconds: 60.0,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valClipDurationMin);
    });

    test('Fails when clip length exceeds 180s in Shorts mode', () {
      final res = validator.validate(
        targetDurationSeconds: 200,
        totalTrimDurationSeconds: 600.0,
        isShortsMode: true,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valClipDurationShortsMax);
    });

    test('Fails when clip count exceeds sane cap (500)', () {
      final res = validator.validate(
        targetDurationSeconds: 1,
        totalTrimDurationSeconds: 600.0,
        isShortsMode: false,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valPartCountExceeded);
    });

    test('Passes on valid split configuration', () {
      final res = validator.validate(
        targetDurationSeconds: 60,
        totalTrimDurationSeconds: 120.0,
        isShortsMode: true,
      );
      expect(res.isValid, isTrue);
    });
  });

  group('BackgroundValidator Tests', () {
    const validator = BackgroundValidator();

    test('Fails when solid color has invalid ARGB range', () {
      const bg = SolidColorBackgroundSpec(colorValue: -1);
      final res = validator.validate(bg);
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valInvalidHexColor);
    });

    test('Fails when image background has empty path', () {
      const bg = ImageBackgroundSpec(imagePath: '');
      final res = validator.validate(bg);
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valChooseBackgroundImage);
    });

    test('Passes on valid blur background', () {
      const bg = BlurBackgroundSpec();
      final res = validator.validate(bg);
      expect(res.isValid, isTrue);
    });
  });

  group('OverlayValidator Tests', () {
    const validator = OverlayValidator();

    test('Fails when text overlay template is empty', () {
      const overlay = OverlaySpec(autoLabel: true, template: '');
      final res = validator.validate(overlay);
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valEnterOverlayMessage);
    });

    test('Passes on valid auto-label overlay', () {
      const overlay = OverlaySpec(
        autoLabel: true,
        template: 'Part {n}/{total}',
      );
      final res = validator.validate(overlay);
      expect(res.isValid, isTrue);
    });
  });

  group('AudioValidator Tests', () {
    const validator = AudioValidator();

    test('Fails when music path is empty', () {
      final res = validator.validate(
        isOriginalAudioEnabled: true,
        musicFilePath: '',
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valChooseMusicOrSwitch);
    });

    test('Fails when voiceover attempted without mic permission', () {
      final res = validator.validate(
        isOriginalAudioEnabled: true,
        isVoiceoverAttempted: true,
        hasMicrophonePermission: false,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valMicPermissionRequired);
    });

    test('Fails when all audio muted and audio operation requires track', () {
      final res = validator.validate(
        isOriginalAudioEnabled: false,
        requiresAudioTrack: true,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valChooseMusicOrSwitch);
    });

    test('Passes on default configuration with original audio', () {
      final res = validator.validate(isOriginalAudioEnabled: true);
      expect(res.isValid, isTrue);
    });
  });

  group('OutputLocationValidator Tests', () {
    const validator = OutputLocationValidator();

    test('Fails when path is empty or null', () {
      final res = validator.validate(
        outputDirectoryPath: '',
        isSafPermissionValid: false,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valChooseSaveLocation);
    });

    test('Fails when SAF permission is revoked', () {
      final res = validator.validate(
        outputDirectoryPath: 'content://tree/primary/Movies',
        isSafPermissionValid: false,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valFolderAccessLost);
    });

    test('Passes on valid SAF path with active permission', () {
      final res = validator.validate(
        outputDirectoryPath: 'content://tree/primary/Movies',
        isSafPermissionValid: true,
      );
      expect(res.isValid, isTrue);
    });
  });

  group('ExportPreflightValidator Tests', () {
    const validator = ExportPreflightValidator();

    test('Fails when another export is already running', () {
      final res = validator.validate(
        isJobAlreadyRunning: true,
        freeDiskBytes: 500000000,
        requiredDiskBytes: 10000000,
        hasNotificationPermission: true,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valExportAlreadyRunning);
    });

    test('Fails when free disk space is insufficient', () {
      final res = validator.validate(
        isJobAlreadyRunning: false,
        freeDiskBytes: 50 * 1024 * 1024,
        requiredDiskBytes: 100 * 1024 * 1024,
        hasNotificationPermission: true,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, contains('Not enough storage'));
    });

    test('Shows warning when notifications are disabled', () {
      final res = validator.validate(
        isJobAlreadyRunning: false,
        freeDiskBytes: 500 * 1024 * 1024,
        requiredDiskBytes: 100 * 1024 * 1024,
        hasNotificationPermission: false,
      );
      expect(res.isValid, isTrue);
      expect(res.issues.length, 1);
      expect(
        res.issues.first.message,
        AppStrings.valNotificationPermissionWarning,
      );
    });

    test('Passes clean when storage is sufficient and no job running', () {
      final res = validator.validate(
        isJobAlreadyRunning: false,
        freeDiskBytes: 500 * 1024 * 1024,
        requiredDiskBytes: 100 * 1024 * 1024,
        hasNotificationPermission: true,
      );
      expect(res.isValid, isTrue);
      expect(res.issues, isEmpty);
    });
  });

  group('CustomSplitValidator Tests', () {
    const validator = CustomSplitValidator();

    test('Fails when custom split points list is empty in validatePlan', () {
      final res = validator.validatePlan(
        points: [],
        totalDurationSeconds: 60.0,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valCustomPointsEmpty);
    });

    test('Fails when a point is out of bounds in validatePoint', () {
      final res = validator.validatePoint(
        pointSeconds: 65.0,
        maxDurationSeconds: 60.0,
        existingPoints: [],
      );
      expect(res.isValid, isFalse);
    });

    test('Fails when a point is duplicate in validatePoint', () {
      final res = validator.validatePoint(
        pointSeconds: 15.0,
        maxDurationSeconds: 60.0,
        existingPoints: [15.0],
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valCustomPointDuplicate);
    });

    test('Fails when points are closer than 1.0s in validatePoint', () {
      final res = validator.validatePoint(
        pointSeconds: 15.4,
        maxDurationSeconds: 60.0,
        existingPoints: [15.0],
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valCustomPointTooClose);
    });

    test(
      'Passes on strictly increasing points with >= 1s spacing in validatePlan',
      () {
        final res = validator.validatePlan(
          points: [10.0, 25.0, 40.0],
          totalDurationSeconds: 60.0,
        );
        expect(res.isValid, isTrue);
      },
    );
  });

  group('PartsSelectionValidator Tests', () {
    const validator = PartsSelectionValidator();

    final testItems = [
      const PartItem(
        segment: ClipSegment(
          index: 1,
          startSeconds: 0.0,
          durationSeconds: 20.0,
          formattedName: 'test_part_001.mp4',
        ),
        isSelected: false,
      ),
      const PartItem(
        segment: ClipSegment(
          index: 2,
          startSeconds: 20.0,
          durationSeconds: 20.0,
          formattedName: 'test_part_002.mp4',
        ),
        isSelected: false,
      ),
    ];

    test('Fails when no parts are selected', () {
      final res = validator.validate(
        items: testItems,
        freeDiskBytes: 1024 * 1024 * 1024,
      );
      expect(res.isValid, isFalse);
      expect(res.firstError?.message, AppStrings.valSelectAtLeastOnePart);
    });

    test('Fails when disk space is insufficient for selected parts', () {
      final selectedItems = [
        testItems[0].copyWith(isSelected: true),
        testItems[1].copyWith(isSelected: true),
      ];

      final res = validator.validate(
        items: selectedItems,
        freeDiskBytes: 10 * 1024 * 1024, // only 10MB free
      );
      expect(res.isValid, isFalse);
      expect(
        res.firstError?.message,
        contains('Not enough storage for 2 selected parts'),
      );
    });

    test(
      'Passes when at least 1 part is selected and storage is sufficient',
      () {
        final selectedItems = [
          testItems[0].copyWith(isSelected: true),
          testItems[1],
        ];

        final res = validator.validate(
          items: selectedItems,
          freeDiskBytes: 1024 * 1024 * 1024,
        );
        expect(res.isValid, isTrue);
      },
    );
  });
}
