/// Severity level of a validation issue.
enum ValidationSeverity { info, warning, error, success }

/// A structured validation issue containing an error code, field identifier,
/// user-facing message, severity, and optional actionable resolution callback.
class ValidationIssue {
  final String code;
  final String? fieldId;
  final String message;
  final ValidationSeverity severity;
  final String? actionLabel;

  const ValidationIssue({
    required this.code,
    this.fieldId,
    required this.message,
    this.severity = ValidationSeverity.error,
    this.actionLabel,
  });

  bool get isError => severity == ValidationSeverity.error;
  bool get isWarning => severity == ValidationSeverity.warning;
  bool get isInfo => severity == ValidationSeverity.info;
  bool get isSuccess => severity == ValidationSeverity.success;

  @override
  String toString() =>
      'ValidationIssue(code: $code, fieldId: $fieldId, severity: ${severity.name}, message: $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationIssue &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          fieldId == other.fieldId &&
          message == other.message &&
          severity == other.severity &&
          actionLabel == other.actionLabel;

  @override
  int get hashCode =>
      Object.hash(code, fieldId, message, severity, actionLabel);
}
