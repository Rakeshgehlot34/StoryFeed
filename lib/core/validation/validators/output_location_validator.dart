import 'dart:io';

import '../../../../app/constants/app_strings.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring output directory exists and has active write permissions.
class OutputLocationValidator {
  const OutputLocationValidator();

  ValidationResult validate({
    required String? outputDirectoryPath,
    required bool isSafPermissionValid,
  }) {
    final issues = <ValidationIssue>[];

    if (outputDirectoryPath == null || outputDirectoryPath.trim().isEmpty) {
      issues.add(
        const ValidationIssue(
          code: 'OUTPUT_DIR_EMPTY',
          fieldId: 'output_directory',
          message: AppStrings.valChooseSaveLocation,
          severity: ValidationSeverity.error,
          actionLabel: 'Choose Folder',
        ),
      );
      return ValidationResult(issues: issues);
    }

    if (outputDirectoryPath.startsWith('content://')) {
      if (!isSafPermissionValid) {
        issues.add(
          const ValidationIssue(
            code: 'OUTPUT_SAF_PERMISSION_REVOKED',
            fieldId: 'output_directory',
            message: AppStrings.valFolderAccessLost,
            severity: ValidationSeverity.error,
            actionLabel: 'Choose Folder',
          ),
        );
      }
    } else {
      final dir = Directory(outputDirectoryPath);
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      if (!dir.existsSync()) {
        issues.add(
          const ValidationIssue(
            code: 'OUTPUT_DIR_NOT_FOUND',
            fieldId: 'output_directory',
            message:
                'Chosen output directory does not exist or is not accessible',
            severity: ValidationSeverity.error,
            actionLabel: 'Choose Folder',
          ),
        );
      }
    }

    return ValidationResult(issues: issues);
  }
}
