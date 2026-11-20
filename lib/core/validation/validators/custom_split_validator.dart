import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring custom split timestamps are within video bounds,
/// non-duplicate, and maintain at least 1.0s between cuts.
class CustomSplitValidator {
  const CustomSplitValidator();

  ValidationResult validatePoint({
    required double pointSeconds,
    required double maxDurationSeconds,
    required List<double> existingPoints,
  }) {
    final issues = <ValidationIssue>[];

    if (pointSeconds <= 0.0 || pointSeconds >= maxDurationSeconds) {
      issues.add(
        const ValidationIssue(
          code: 'CUSTOM_POINT_OUT_OF_BOUNDS',
          fieldId: 'split_point',
          message: 'Timestamp must be strictly within the video duration',
          severity: ValidationSeverity.error,
        ),
      );
      return ValidationResult(issues: issues);
    }

    for (final existing in existingPoints) {
      if ((existing - pointSeconds).abs() < 0.05) {
        issues.add(
          const ValidationIssue(
            code: 'CUSTOM_POINT_DUPLICATE',
            fieldId: 'split_point',
            message: AppStrings.valCustomPointDuplicate,
            severity: ValidationSeverity.error,
          ),
        );
        return ValidationResult(issues: issues);
      }

      if ((existing - pointSeconds).abs() <
          AppConstants.minClipDurationSeconds) {
        issues.add(
          const ValidationIssue(
            code: 'CUSTOM_POINT_TOO_CLOSE',
            fieldId: 'split_point',
            message: AppStrings.valCustomPointTooClose,
            severity: ValidationSeverity.error,
          ),
        );
        return ValidationResult(issues: issues);
      }
    }

    return ValidationResult(issues: issues);
  }

  ValidationResult validatePlan({
    required List<double> points,
    required double totalDurationSeconds,
  }) {
    final issues = <ValidationIssue>[];

    if (points.isEmpty) {
      issues.add(
        const ValidationIssue(
          code: 'CUSTOM_POINTS_EMPTY',
          fieldId: 'split_points',
          message: AppStrings.valCustomPointsEmpty,
          severity: ValidationSeverity.error,
        ),
      );
      return ValidationResult(issues: issues);
    }

    final sorted = List<double>.from(points)..sort();
    var prev = 0.0;
    for (final pt in sorted) {
      if (pt - prev < AppConstants.minClipDurationSeconds) {
        issues.add(
          const ValidationIssue(
            code: 'CUSTOM_SEGMENT_UNDER_1S',
            fieldId: 'split_points',
            message: 'All generated clips must be at least 1.0 second long',
            severity: ValidationSeverity.error,
          ),
        );
        break;
      }
      prev = pt;
    }

    if (totalDurationSeconds - prev < AppConstants.minClipDurationSeconds) {
      issues.add(
        const ValidationIssue(
          code: 'CUSTOM_FINAL_SEGMENT_UNDER_1S',
          fieldId: 'split_points',
          message:
              'The final remaining clip is under 1.0 second. Adjust the last split point.',
          severity: ValidationSeverity.error,
        ),
      );
    }

    return ValidationResult(issues: issues);
  }
}
