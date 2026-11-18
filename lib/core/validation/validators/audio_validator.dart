import 'dart:io';

import '../../../../app/constants/app_strings.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring audio tracks, music files, and voice-over recordings
/// exist and are configured properly before rendering.
class AudioValidator {
  const AudioValidator();

  ValidationResult validate({
    required bool isOriginalAudioEnabled,
    String? musicFilePath,
    String? voiceoverFilePath,
    bool requiresAudioTrack = false,
    bool hasMicrophonePermission = true,
    bool isVoiceoverAttempted = false,
  }) {
    final issues = <ValidationIssue>[];

    if (isVoiceoverAttempted && !hasMicrophonePermission) {
      issues.add(
        const ValidationIssue(
          code: 'AUDIO_MIC_PERMISSION_DENIED',
          fieldId: 'audio_voiceover',
          message: AppStrings.valMicPermissionRequired,
          severity: ValidationSeverity.error,
          actionLabel: 'Open Settings',
        ),
      );
    }

    if (musicFilePath != null) {
      if (musicFilePath.trim().isEmpty) {
        issues.add(
          const ValidationIssue(
            code: 'AUDIO_MUSIC_PATH_EMPTY',
            fieldId: 'audio_music',
            message: AppStrings.valChooseMusicOrSwitch,
            severity: ValidationSeverity.error,
            actionLabel: 'Choose Music',
          ),
        );
      } else {
        final file = File(musicFilePath);
        if (!file.existsSync()) {
          issues.add(
            const ValidationIssue(
              code: 'AUDIO_MUSIC_NOT_FOUND',
              fieldId: 'audio_music',
              message: 'Selected music file does not exist on device',
              severity: ValidationSeverity.error,
              actionLabel: 'Choose Music',
            ),
          );
        }
      }
    }

    if (voiceoverFilePath != null) {
      if (voiceoverFilePath.trim().isEmpty) {
        issues.add(
          const ValidationIssue(
            code: 'AUDIO_VOICEOVER_EMPTY',
            fieldId: 'audio_voiceover',
            message: AppStrings.valVoiceoverRequired,
            severity: ValidationSeverity.error,
          ),
        );
      } else {
        final file = File(voiceoverFilePath);
        if (!file.existsSync()) {
          issues.add(
            const ValidationIssue(
              code: 'AUDIO_VOICEOVER_NOT_FOUND',
              fieldId: 'audio_voiceover',
              message: 'Voice-over recording file does not exist',
              severity: ValidationSeverity.error,
            ),
          );
        }
      }
    }

    // If original audio is disabled/muted and user requested an audio operation, verify at least one track exists
    if (requiresAudioTrack &&
        !isOriginalAudioEnabled &&
        (musicFilePath == null || musicFilePath.isEmpty) &&
        (voiceoverFilePath == null || voiceoverFilePath.isEmpty)) {
      issues.add(
        const ValidationIssue(
          code: 'AUDIO_NO_ACTIVE_TRACK',
          fieldId: 'audio_studio',
          message: AppStrings.valChooseMusicOrSwitch,
          severity: ValidationSeverity.error,
        ),
      );
    }

    return ValidationResult(issues: issues);
  }
}
