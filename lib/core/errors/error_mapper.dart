import 'app_exception.dart';

/// Centralized mapper that converts technical exceptions into user-friendly messages.
class ErrorMapper {
  ErrorMapper._();

  /// Maps any caught exception or error to a clean, actionable UI message.
  static String mapToUserMessage(Object error) {
    return switch (error) {
      PermissionDeniedException(:final message, :final isPermanentlyDenied) =>
        isPermanentlyDenied
            ? '$message Please enable video and storage permissions in system settings.'
            : message,
      UnsupportedVideoFormatException(:final message) =>
        'Unable to process this video format: $message',
      InsufficientStorageException(
        :final requiredBytes,
        :final availableBytes,
      ) =>
        'Insufficient storage space. Need ${_formatBytes(requiredBytes)}, but only ${_formatBytes(availableBytes)} available.',
      OperationCancelledException(:final message) => message,
      VideoProcessingException(:final message) =>
        'Video processing failed: $message',
      PlanValidationException(:final message) => message,
      StorageAccessException(:final message, :final path) =>
        '$message (Path: $path)',
      _ => 'An unexpected error occurred: ${error.toString()}',
    };
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
