import 'validation_issue.dart';

/// Structured outcome of running pure validation rules.
class ValidationResult {
  final List<ValidationIssue> issues;

  const ValidationResult({this.issues = const []});

  const ValidationResult.valid() : issues = const [];

  factory ValidationResult.fromIssues(List<ValidationIssue> issues) =>
      ValidationResult(issues: List.unmodifiable(issues));

  bool get isValid =>
      !issues.any((i) => i.severity == ValidationSeverity.error);
  bool get hasWarnings =>
      issues.any((i) => i.severity == ValidationSeverity.warning);
  bool get hasErrors => !isValid;

  List<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error).toList();

  List<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning).toList();

  ValidationIssue? get firstError {
    for (final issue in issues) {
      if (issue.severity == ValidationSeverity.error) return issue;
    }
    return null;
  }

  ValidationIssue? get firstIssue => issues.isNotEmpty ? issues.first : null;

  String? errorForField(String fieldId) {
    for (final issue in issues) {
      if (issue.fieldId == fieldId &&
          issue.severity == ValidationSeverity.error) {
        return issue.message;
      }
    }
    return null;
  }

  String? warningForField(String fieldId) {
    for (final issue in issues) {
      if (issue.fieldId == fieldId &&
          issue.severity == ValidationSeverity.warning) {
        return issue.message;
      }
    }
    return null;
  }

  ValidationResult combine(ValidationResult other) {
    if (issues.isEmpty) return other;
    if (other.issues.isEmpty) return this;
    return ValidationResult.fromIssues([...issues, ...other.issues]);
  }

  @override
  String toString() =>
      'ValidationResult(isValid: $isValid, errors: ${errors.length}, warnings: ${warnings.length})';
}
