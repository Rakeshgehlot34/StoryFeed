import 'dart:io';

import '../../../../app/constants/app_strings.dart';
import '../../../features/split_config/domain/models/overlay_spec.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring text overlays and logos have non-empty templates
/// and existing asset files when enabled.
class OverlayValidator {
  const OverlayValidator();

  ValidationResult validate(OverlaySpec overlaySpec, {String? logoPath}) {
    final issues = <ValidationIssue>[];

    final isOverlayActive =
        overlaySpec.autoLabel ||
        (overlaySpec.allPartsMessage != null &&
            overlaySpec.allPartsMessage!.isNotEmpty);

    if (isOverlayActive) {
      if (overlaySpec.template.trim().isEmpty) {
        issues.add(
          const ValidationIssue(
            code: 'OVERLAY_TEXT_EMPTY',
            fieldId: 'overlay_template',
            message: AppStrings.valEnterOverlayMessage,
            severity: ValidationSeverity.error,
          ),
        );
      }

      if (!overlaySpec.displayWholeClip &&
          overlaySpec.displayDurationSeconds <= 0.0) {
        issues.add(
          const ValidationIssue(
            code: 'OVERLAY_DURATION_INVALID',
            fieldId: 'overlay_duration',
            message: 'Overlay display duration must be greater than 0 seconds',
            severity: ValidationSeverity.error,
          ),
        );
      }
    }

    if (logoPath != null && logoPath.isNotEmpty) {
      final file = File(logoPath);
      if (!file.existsSync()) {
        issues.add(
          const ValidationIssue(
            code: 'OVERLAY_LOGO_NOT_FOUND',
            fieldId: 'overlay_logo',
            message: AppStrings.valChooseLogoImage,
            severity: ValidationSeverity.error,
          ),
        );
      }
    }

    return ValidationResult(issues: issues);
  }
}
