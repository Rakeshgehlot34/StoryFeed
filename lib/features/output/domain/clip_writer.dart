import 'dart:io';

import 'models/storage_strategy.dart';

/// Contract for destination clip writing strategies selected dynamically at runtime.
abstract class ClipWriter {
  /// The runtime storage strategy implemented by this writer.
  StorageStrategyType get strategyType;

  /// Checks if this strategy is supported, authorized, and physically writable.
  Future<bool> isAvailable();

  /// Copies an encoded temporary video file into the target destination.
  ///
  /// Must strictly preserve the sequential filename `{originalName}_part_{NNN}.mp4`,
  /// respect the [duplicateHandling] rule, verify that the copied output is non-empty,
  /// and return the resulting absolute path or content URI.
  Future<String> writeClip({
    required File sourceTempFile,
    required String fileName,
    required DuplicateHandling duplicateHandling,
  });
}
