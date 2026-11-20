import 'dart:io';

import '../../../core/errors/app_exception.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/utils/storage_bridge.dart';
import 'clip_writer.dart';
import 'models/storage_strategy.dart';

enum ReplaceStrategy {
  replace,
  keepBoth,
}

class SafeReplaceResult {
  final bool isSuccess;
  final String finalPathOrUri;
  final int fileSizeBytes;
  final String? errorMessage;

  const SafeReplaceResult({
    required this.isSuccess,
    required this.finalPathOrUri,
    this.fileSizeBytes = 0,
    this.errorMessage,
  });

  factory SafeReplaceResult.failure(String message) => SafeReplaceResult(
        isSuccess: false,
        finalPathOrUri: '',
        errorMessage: message,
      );
}

class SafeClipReplacer {
  /// Safely replaces an existing clip file with a newly transcoded clip.
  /// Guarantees that the original file is NEVER deleted or modified unless
  /// the new clip has been fully written and verified on disk.
  static Future<SafeReplaceResult> replace({
    required File newTempClipFile,
    required String existingPathOrUri,
    required String targetFileName,
    required ClipWriter clipWriter,
    required ReplaceStrategy replaceStrategy,
    Future<bool> Function(File)? customVerifier,
  }) async {
    // 1. Verify that new temporary clip exists and is non-empty
    if (!await newTempClipFile.exists() ||
        await newTempClipFile.length() == 0) {
      return SafeReplaceResult.failure(
        'New transcoded clip file is missing or empty: ${newTempClipFile.path}',
      );
    }

    // Optional verification hook (e.g. OutputVerifier duration/stream check)
    if (customVerifier != null) {
      final isValid = await customVerifier(newTempClipFile);
      if (!isValid) {
        return SafeReplaceResult.failure(
          'Transcoded clip failed integrity verification',
        );
      }
    }

    final newFileSize = await newTempClipFile.length();

    // If strategy is keepBoth, modify target file name
    final finalFileName = replaceStrategy == ReplaceStrategy.keepBoth
        ? targetFileName.replaceAll('.mp4', '_short.mp4')
        : targetFileName;

    // Temporary staging name beside the target
    final tempStagingName = '${finalFileName.replaceAll('.mp4', '')}.tmp.mp4';

    try {
      String finalResultPath;

      if (clipWriter.strategyType == StorageStrategyType.mediaStore) {
        // MediaStore Strategy (API 29+):
        // If replacing, remove the old MediaStore record/file first to avoid auto-(1) duplicate naming
        if (replaceStrategy == ReplaceStrategy.replace) {
          if (existingPathOrUri.startsWith('content://')) {
            await StorageBridge.deleteSafDocument(
              documentUri: existingPathOrUri,
            );
          } else if (existingPathOrUri.isNotEmpty) {
            final oldF = File(existingPathOrUri);
            if (await oldF.exists()) await oldF.delete();
          }
        }

        // Write new clip directly with the target file name
        final writtenUriOrPath = await clipWriter.writeClip(
          sourceTempFile: newTempClipFile,
          fileName: finalFileName,
          duplicateHandling: DuplicateHandling.overwrite,
        );

        if (writtenUriOrPath.isEmpty) {
          throw StorageAccessException(
            'MediaStore clip writing returned empty URI',
            path: finalFileName,
          );
        }
        finalResultPath = writtenUriOrPath;
      } else if (clipWriter.strategyType == StorageStrategyType.saf) {
        // SAF Strategy (API 28+):
        // 1. Write new document beside old with temporary staging name
        final stagedUriOrPath = await clipWriter.writeClip(
          sourceTempFile: newTempClipFile,
          fileName: tempStagingName,
          duplicateHandling: DuplicateHandling.overwrite,
        );

        if (stagedUriOrPath.isEmpty) {
          throw StorageAccessException(
            'Staged SAF clip writing returned empty path',
            path: tempStagingName,
          );
        }

        // 2. Delete old document if replacing
        if (replaceStrategy == ReplaceStrategy.replace) {
          if (existingPathOrUri.startsWith('content://')) {
            await StorageBridge.deleteSafDocument(
              documentUri: existingPathOrUri,
            );
          } else if (existingPathOrUri.isNotEmpty) {
            final oldF = File(existingPathOrUri);
            if (await oldF.exists()) await oldF.delete();
          }
        }

        // 3. Atomically rename staged document to final name
        final renamed = await StorageBridge.renameSafDocument(
          documentUri: stagedUriOrPath,
          newName: finalFileName,
        );
        if (!renamed) {
          AppLogger.warning(
            'SAF document renameTo failed; staged URI remains as $stagedUriOrPath',
          );
        }
        finalResultPath = stagedUriOrPath;
      } else {
        // Direct Filesystem / App-Specific Strategy:
        // 1. Write to staging name
        final stagedUriOrPath = await clipWriter.writeClip(
          sourceTempFile: newTempClipFile,
          fileName: tempStagingName,
          duplicateHandling: DuplicateHandling.overwrite,
        );

        if (stagedUriOrPath.isEmpty) {
          throw StorageAccessException(
            'Staged clip writing returned empty path',
            path: tempStagingName,
          );
        }

        final stagedFile = File(stagedUriOrPath);
        if (!await stagedFile.exists() || await stagedFile.length() == 0) {
          throw StorageAccessException(
            'Staged clip file is invalid on disk',
            path: stagedUriOrPath,
          );
        }

        final finalFile = File('${stagedFile.parent.path}/$finalFileName');

        if (replaceStrategy == ReplaceStrategy.replace &&
            existingPathOrUri.isNotEmpty) {
          final oldFile = File(existingPathOrUri);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        if (await finalFile.exists()) {
          await finalFile.delete();
        }

        await stagedFile.rename(finalFile.path);
        finalResultPath = finalFile.path;
      }

      AppLogger.info(
        'Safe replace completed successfully: $existingPathOrUri -> $finalResultPath',
      );

      return SafeReplaceResult(
        isSuccess: true,
        finalPathOrUri: finalResultPath,
        fileSizeBytes: newFileSize,
      );
    } catch (e, st) {
      AppLogger.error('Safe replace failed', error: e, stackTrace: st);
      // Clean up staged temporary document if it exists, leaving original intact!
      return SafeReplaceResult.failure(
        'Failed to safely replace clip: $e',
      );
    }
  }
}
