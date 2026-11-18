/// Base class for all application-level exceptions.
sealed class AppException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Thrown when a selected video format is invalid or unsupported.
final class UnsupportedVideoFormatException extends AppException {
  const UnsupportedVideoFormatException(
    super.message, [
    super.cause,
    super.stackTrace,
  ]);
}

/// Thrown when available device storage is insufficient for processing.
final class InsufficientStorageException extends AppException {
  final int requiredBytes;
  final int availableBytes;

  const InsufficientStorageException(
    String message, {
    required this.requiredBytes,
    required this.availableBytes,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);
}

/// Thrown when required system permissions are denied.
final class PermissionDeniedException extends AppException {
  final String permissionName;
  final bool isPermanentlyDenied;

  const PermissionDeniedException(
    String message, {
    required this.permissionName,
    this.isPermanentlyDenied = false,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);
}

/// Thrown when the user or system cancels an in-flight operation.
final class OperationCancelledException extends AppException {
  const OperationCancelledException([
    super.message = 'The operation was cancelled by the user.',
  ]);
}

/// Thrown when FFmpeg or underlying video processing fails.
final class VideoProcessingException extends AppException {
  final int? returnCode;
  final String? executionLogs;

  const VideoProcessingException(
    String message, {
    this.returnCode,
    this.executionLogs,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);
}

/// Thrown when plan boundaries or durations violate domain invariants (e.g. >180s or <1s).
final class PlanValidationException extends AppException {
  final double? durationSeconds;
  final double? maxAllowedSeconds;
  final double? minAllowedSeconds;

  const PlanValidationException(
    String message, {
    this.durationSeconds,
    this.maxAllowedSeconds = 180.0,
    this.minAllowedSeconds = 1.0,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);
}

/// Thrown when target storage directory cannot be created or written to.
final class StorageAccessException extends AppException {
  final String path;

  const StorageAccessException(
    String message, {
    required this.path,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(message, cause, stackTrace);
}
