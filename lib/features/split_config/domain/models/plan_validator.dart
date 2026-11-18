import '../../../../app/constants.dart';
import '../../../../app/constants/app_strings.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/validation/validation_issue.dart';
import '../../../../core/validation/validation_result.dart';
import 'clip_plan.dart';
import 'trim_range.dart';

/// Pure domain validator enforcing all split constraints and hard safety limits.
class PlanValidator {
  const PlanValidator();

  /// Validates a [ClipPlan] and returns a structured [ValidationResult].
  ValidationResult validate(ClipPlan plan) {
    final issues = <ValidationIssue>[];

    if (plan.items.isEmpty) {
      issues.add(
        const ValidationIssue(
          code: 'PLAN_ITEMS_EMPTY',
          fieldId: 'plan_items',
          message: 'Plan must contain at least 1 clip.',
          severity: ValidationSeverity.error,
        ),
      );
      return ValidationResult(issues: issues);
    }

    if (plan.trimRange.startSeconds < 0.0) {
      issues.add(
        const ValidationIssue(
          code: 'TRIM_START_NEGATIVE',
          fieldId: 'trim_start',
          message: 'Trim start position cannot be negative.',
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (plan.trimRange.startSeconds >= plan.trimRange.endSeconds) {
      issues.add(
        const ValidationIssue(
          code: 'TRIM_START_GTE_END',
          fieldId: 'trim_start',
          message: AppStrings.valStartBeforeEnd,
          severity: ValidationSeverity.error,
        ),
      );
    }

    for (int i = 0; i < plan.items.length; i++) {
      final item = plan.items[i];
      final dur = item.durationSeconds;

      if (dur < AppConstants.minClipDurationSeconds) {
        issues.add(
          ValidationIssue(
            code: 'CLIP_TOO_SHORT',
            fieldId: 'clip_${item.index}',
            message:
                'Clip ${item.index} duration (${dur.toStringAsFixed(1)}s) is below 1.0 second minimum.',
            severity: ValidationSeverity.error,
          ),
        );
      }

      if (dur > AppConstants.maxClipDurationSeconds) {
        issues.add(
          ValidationIssue(
            code: 'CLIP_EXCEEDS_180S',
            fieldId: 'clip_${item.index}',
            message:
                'Clip ${item.index} duration (${dur.toStringAsFixed(1)}s) exceeds 180s hard cap.',
            severity: ValidationSeverity.error,
          ),
        );
      }

      if (i < plan.items.length - 1) {
        final next = plan.items[i + 1];
        final diff = (item.endSeconds - next.startSeconds).abs();
        if (diff > 0.005) {
          issues.add(
            ValidationIssue(
              code: 'CLIP_CONTIGUITY_VIOLATION',
              fieldId: 'clip_${item.index}',
              message:
                  'Contiguity violation between clip ${item.index} and ${next.index}',
              severity: ValidationSeverity.error,
            ),
          );
        }
      }
    }

    return ValidationResult(issues: issues);
  }

  /// Validates a [TrimRange] against video duration and bounds.
  static void validateTrimRange(
    TrimRange range,
    double totalSourceDurationSeconds,
  ) {
    if (range.startSeconds < 0.0) {
      throw const PlanValidationException(
        'Trim start position cannot be negative.',
        minAllowedSeconds: 0.0,
      );
    }

    if (range.startSeconds >= range.endSeconds) {
      throw const PlanValidationException(
        'Trim start position must be strictly earlier than end position.',
      );
    }

    if (range.endSeconds > totalSourceDurationSeconds + 0.05) {
      throw PlanValidationException(
        'Trim end position (${range.formattedEnd}) exceeds video duration.',
      );
    }

    if (range.durationSeconds < AppConstants.minClipDurationSeconds) {
      throw PlanValidationException(
        'Selected trim range duration (${range.durationSeconds.toStringAsFixed(1)}s) is under minimum allowed 1.0 second.',
        durationSeconds: range.durationSeconds,
        minAllowedSeconds: AppConstants.minClipDurationSeconds.toDouble(),
      );
    }
  }

  /// Validates a list of [ClipPlanItem]s for duration bounds and strict contiguity.
  static void validatePlanItems(List<ClipPlanItem> items) {
    if (items.isEmpty) {
      throw const PlanValidationException('Plan must contain at least 1 clip.');
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final dur = item.durationSeconds;

      if (dur < AppConstants.minClipDurationSeconds) {
        throw PlanValidationException(
          'Clip ${item.index} duration (${dur.toStringAsFixed(1)}s) is below 1.0 second minimum.',
          durationSeconds: dur,
          minAllowedSeconds: AppConstants.minClipDurationSeconds.toDouble(),
        );
      }

      if (dur > AppConstants.maxClipDurationSeconds) {
        throw PlanValidationException(
          'Clip ${item.index} duration (${dur.toStringAsFixed(1)}s) exceeds YouTube Shorts 180s (3-minute) hard cap.',
          durationSeconds: dur,
          maxAllowedSeconds: AppConstants.maxClipDurationSeconds.toDouble(),
        );
      }

      // Contiguity check with next item
      if (i < items.length - 1) {
        final next = items[i + 1];
        final diff = (item.endSeconds - next.startSeconds).abs();
        if (diff > 0.005) {
          throw PlanValidationException(
            'Contiguity violation between clip ${item.index} and ${next.index}: ${item.endSeconds} != ${next.startSeconds}',
          );
        }
      }
    }
  }

  /// Full plan validation.
  static void validatePlan(ClipPlan plan) {
    validateTrimRange(plan.trimRange, plan.sourceDurationSeconds);
    validatePlanItems(plan.items);
  }
}
