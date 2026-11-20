import '../../../../app/constants/app_strings.dart';
import '../../../features/plan_review/domain/models/clip_processing_state.dart';
import '../../utils/formatters.dart';
import '../validation_issue.dart';
import '../validation_result.dart';

/// Pure validator ensuring selective clip operations meet selection and storage criteria.
class PartsSelectionValidator {
  const PartsSelectionValidator();

  ValidationResult validate({
    required List<PartItem> items,
    required int freeDiskBytes,
    double bytesPerSecond = 500 * 1024,
    int minSafetyBytes = 50 * 1024 * 1024,
  }) {
    final issues = <ValidationIssue>[];

    final selected = items.where((i) => i.isSelected).toList();
    if (selected.isEmpty) {
      issues.add(
        const ValidationIssue(
          code: 'NO_PARTS_SELECTED',
          fieldId: 'part_selection',
          message: AppStrings.valSelectAtLeastOnePart,
          severity: ValidationSeverity.error,
        ),
      );
      return ValidationResult(issues: issues);
    }

    final selectedDuration = selected.fold<double>(
      0.0,
      (sum, item) => sum + item.durationSeconds,
    );
    final estimatedBytes =
        (selectedDuration * bytesPerSecond).toInt() + minSafetyBytes;

    if (freeDiskBytes < estimatedBytes) {
      final neededStr = Formatters.formatFileSize(estimatedBytes);
      issues.add(
        ValidationIssue(
          code: 'EXPORT_INSUFFICIENT_STORAGE_SELECTED',
          fieldId: 'storage',
          message:
              'Not enough storage for ${selected.length} selected parts: about $neededStr needed',
          severity: ValidationSeverity.error,
        ),
      );
    }

    return ValidationResult(issues: issues);
  }
}
