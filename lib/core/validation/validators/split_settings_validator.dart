import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring clip length, naming prefix, and estimated clip counts
/// conform to Shorts platform constraints (1s - 180s hard cap, 500 clips safe limit).
class SplitSettingsValidator {
  static const int maxClipsCap = 500;

  const SplitSettingsValidator();

  ValidationResult validate({
    required int? targetDurationSeconds,
    required double totalTrimDurationSeconds,
    String? customBaseName,
    bool isShortsMode = true,
  }) {
    final issues = <ValidationIssue>[];

    if (targetDurationSeconds == null) {
      issues.add(
        const ValidationIssue(
          code: 'DURATION_EMPTY',
          fieldId: 'target_duration',
          message: AppStrings.valEnterClipDuration,
          severity: ValidationSeverity.error,
        ),
      );
      return ValidationResult(issues: issues);
    }

    if (targetDurationSeconds < AppConstants.minClipDurationSeconds) {
      issues.add(
        const ValidationIssue(
          code: 'DURATION_TOO_SHORT',
          fieldId: 'target_duration',
          message: AppStrings.valClipDurationMin,
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (isShortsMode &&
        targetDurationSeconds > AppConstants.maxClipDurationSeconds) {
      issues.add(
        const ValidationIssue(
          code: 'DURATION_EXCEEDS_SHORTS_CAP',
          fieldId: 'target_duration',
          message: AppStrings.valClipDurationShortsMax,
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (customBaseName != null && customBaseName.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          code: 'PREFIX_EMPTY_WHITESPACE',
          fieldId: 'base_name',
          message: 'File name prefix cannot be blank',
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (targetDurationSeconds > 0 && totalTrimDurationSeconds > 0) {
      final estimatedClips = (totalTrimDurationSeconds / targetDurationSeconds)
          .ceil();
      if (estimatedClips > maxClipsCap) {
        issues.add(
          const ValidationIssue(
            code: 'PART_COUNT_EXCEEDED',
            fieldId: 'target_duration',
            message: AppStrings.valPartCountExceeded,
            severity: ValidationSeverity.error,
          ),
        );
      }
    }

    return ValidationResult(issues: issues);
  }
}
