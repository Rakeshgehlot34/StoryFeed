import 'dart:io';

import '../../../../app/constants/app_strings.dart';
import '../../../features/split_config/domain/models/background_spec.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring background fill options (blur, solid color, image)
/// have valid assets and correct color specs.
class BackgroundValidator {
  const BackgroundValidator();

  ValidationResult validate(BackgroundSpec backgroundSpec) {
    final issues = <ValidationIssue>[];

    switch (backgroundSpec) {
      case ImageBackgroundSpec(:final imagePath):
        if (imagePath.trim().isEmpty) {
          issues.add(
            const ValidationIssue(
              code: 'BACKGROUND_IMAGE_EMPTY',
              fieldId: 'background_spec',
              message: AppStrings.valChooseBackgroundImage,
              severity: ValidationSeverity.error,
              actionLabel: 'Pick Image',
            ),
          );
        } else {
          final file = File(imagePath);
          if (!file.existsSync()) {
            issues.add(
              const ValidationIssue(
                code: 'BACKGROUND_IMAGE_NOT_FOUND',
                fieldId: 'background_spec',
                message:
                    'Selected background image file was not found on device',
                severity: ValidationSeverity.error,
                actionLabel: 'Pick Image',
              ),
            );
          }
        }
        break;

      case SolidColorBackgroundSpec(:final colorValue):
        // Ensure colorValue has alpha and is valid 32-bit ARGB
        if (colorValue < 0 || colorValue > 0xFFFFFFFF) {
          issues.add(
            const ValidationIssue(
              code: 'BACKGROUND_COLOR_INVALID',
              fieldId: 'background_color',
              message: AppStrings.valInvalidHexColor,
              severity: ValidationSeverity.error,
            ),
          );
        }
        break;

      case BlurBackgroundSpec():
        // Always valid
        break;
    }

    return ValidationResult(issues: issues);
  }
}
