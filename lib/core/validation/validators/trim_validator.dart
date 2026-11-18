import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring start/end trim boundaries are valid, non-negative,
/// strictly ordered, at least 1.0s apart, and within the total video duration.
class TrimValidator {
  const TrimValidator();

  ValidationResult validate({
    required double startSeconds,
    required double endSeconds,
    required double totalDurationSeconds,
  }) {
    final issues = <ValidationIssue>[];

    if (startSeconds < 0.0) {
      issues.add(
        const ValidationIssue(
          code: 'TRIM_START_NEGATIVE',
          fieldId: 'trim_start',
          message: 'Start time cannot be negative',
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (startSeconds >= endSeconds) {
      issues.add(
        const ValidationIssue(
          code: 'TRIM_START_GTE_END',
          fieldId: 'trim_start',
          message: AppStrings.valStartBeforeEnd,
          severity: ValidationSeverity.error,
        ),
      );
    }

    final duration = endSeconds - startSeconds;
    if (duration < AppConstants.minClipDurationSeconds &&
        startSeconds < endSeconds) {
      issues.add(
        const ValidationIssue(
          code: 'TRIM_DURATION_TOO_SHORT',
          fieldId: 'trim_range',
          message: AppStrings.valRangeMin1s,
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (endSeconds > totalDurationSeconds + 0.05) {
      final maxStr = Formatters.formatPrecise(totalDurationSeconds);
      issues.add(
        ValidationIssue(
          code: 'TRIM_END_EXCEEDS_DURATION',
          fieldId: 'trim_end',
          message: 'Time is beyond the video length (max $maxStr)',
          severity: ValidationSeverity.error,
        ),
      );
    }

    return ValidationResult(issues: issues);
  }
}
