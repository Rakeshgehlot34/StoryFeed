import '../../../../app/constants/app_strings.dart';
import '../../../features/video_picker/domain/models/picked_video.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring a valid, readable video with non-zero duration is present.
class SelectVideoValidator {
  const SelectVideoValidator();

  ValidationResult validate(PickedVideo? video) {
    if (video == null) {
      return const ValidationResult(
        issues: [
          ValidationIssue(
            code: 'VIDEO_MISSING',
            fieldId: 'video',
            message: AppStrings.valSelectVideoFirst,
            severity: ValidationSeverity.error,
            actionLabel: 'Choose Video',
          ),
        ],
      );
    }

    final issues = <ValidationIssue>[];

    if (video.duration.inMilliseconds <= 0) {
      issues.add(
        const ValidationIssue(
          code: 'VIDEO_ZERO_DURATION',
          fieldId: 'video',
          message: AppStrings.valVideoZeroDuration,
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (video.sizeInBytes <= 0) {
      issues.add(
        const ValidationIssue(
          code: 'VIDEO_EMPTY_FILE',
          fieldId: 'video',
          message: AppStrings.valVideoUnreadable,
          severity: ValidationSeverity.error,
        ),
      );
    }

    return ValidationResult(issues: issues);
  }
}
