import '../../../../app/constants/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure pre-flight validator verifying system resources before dispatching export jobs.
class ExportPreflightValidator {
  const ExportPreflightValidator();

  ValidationResult validate({
    required bool isJobAlreadyRunning,
    required int freeDiskBytes,
    required int requiredDiskBytes,
    required bool hasNotificationPermission,
  }) {
    final issues = <ValidationIssue>[];

    if (isJobAlreadyRunning) {
      issues.add(
        const ValidationIssue(
          code: 'EXPORT_ALREADY_RUNNING',
          fieldId: 'export_job',
          message: AppStrings.valExportAlreadyRunning,
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (freeDiskBytes < requiredDiskBytes) {
      final neededStr = Formatters.formatFileSize(requiredDiskBytes);
      final freeStr = Formatters.formatFileSize(freeDiskBytes);
      issues.add(
        ValidationIssue(
          code: 'EXPORT_INSUFFICIENT_STORAGE',
          fieldId: 'storage',
          message: 'Not enough storage: need about $neededStr, $freeStr free',
          severity: ValidationSeverity.error,
        ),
      );
    }

    if (!hasNotificationPermission) {
      issues.add(
        const ValidationIssue(
          code: 'EXPORT_NOTIFICATION_DISABLED',
          fieldId: 'notifications',
          message: AppStrings.valNotificationPermissionWarning,
          severity: ValidationSeverity.warning,
          actionLabel: 'Settings',
        ),
      );
    }

    return ValidationResult(issues: issues);
  }
}
