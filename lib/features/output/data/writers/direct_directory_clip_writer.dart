import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/logger/app_logger.dart';
import '../../domain/clip_writer.dart';
import '../../domain/models/storage_strategy.dart';

/// Writer that saves clips directly into a specific local filesystem directory.
/// Used for intermediate transcode stages before atomic replacement or user-selected storage.
class DirectDirectoryClipWriter implements ClipWriter {
  final Directory directory;

  const DirectDirectoryClipWriter(this.directory);

  @override
  StorageStrategyType get strategyType => StorageStrategyType.appSpecific;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> writeClip({
    required File sourceTempFile,
    required String fileName,
    required DuplicateHandling duplicateHandling,
  }) async {
    if (!await sourceTempFile.exists() || await sourceTempFile.length() == 0) {
      throw Exception(
        'Source temp file is missing or empty: ${sourceTempFile.path}',
      );
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final destPath = p.join(directory.path, fileName);
    final destFile = File(destPath);
    if (await destFile.exists()) {
      await destFile.delete();
    }

    await sourceTempFile.copy(destPath);
    AppLogger.info(
      'DirectDirectoryClipWriter: wrote intermediate clip to $destPath',
    );
    return destPath;
  }
}
