import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../logger/app_logger.dart';

/// Computes a fast, deterministic fingerprint for a video file without
/// loading the full file into memory. Uses file size, duration, and sampled
/// byte blocks (first 64KB, middle 64KB, last 64KB).
class SourceFingerprint {
  static const int _sampleChunkSize = 64 * 1024; // 64 KB

  /// Generates a SHA-256 fingerprint from the given [file] and [durationMs].
  static Future<String> computeFromFile({
    required File file,
    required int durationMs,
  }) async {
    if (!await file.exists()) {
      throw ArgumentError('Video file does not exist: ${file.path}');
    }

    final fileSize = await file.length();
    return computeFromPath(
      path: file.path,
      fileSizeBytes: fileSize,
      durationMs: durationMs,
    );
  }

  /// Generates a SHA-256 fingerprint from a path, size in bytes, and duration.
  static Future<String> computeFromPath({
    required String path,
    required int fileSizeBytes,
    required int durationMs,
  }) async {
    final sampledBytes = <int>[];

    try {
      final file = File(path);
      if (await file.exists()) {
        final raf = await file.open(mode: FileMode.read);
        try {
          if (fileSizeBytes <= _sampleChunkSize * 3) {
            // File is small: read in full
            final bytes = await raf.read(fileSizeBytes);
            sampledBytes.addAll(bytes);
          } else {
            // 1. Read first 64 KB
            await raf.setPosition(0);
            sampledBytes.addAll(await raf.read(_sampleChunkSize));

            // 2. Read middle 64 KB
            final midOffset = (fileSizeBytes ~/ 2) - (_sampleChunkSize ~/ 2);
            await raf.setPosition(midOffset);
            sampledBytes.addAll(await raf.read(_sampleChunkSize));

            // 3. Read last 64 KB
            final endOffset = fileSizeBytes - _sampleChunkSize;
            await raf.setPosition(endOffset);
            sampledBytes.addAll(await raf.read(_sampleChunkSize));
          }
        } finally {
          await raf.close();
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Direct file sample read failed ($e), falling back to path metadata',
      );
    }

    // Sample hash
    final sampleHash = sampledBytes.isNotEmpty
        ? sha256.convert(Uint8List.fromList(sampledBytes)).toString()
        : sha256.convert(utf8.encode(path)).toString();

    // Composite fingerprint
    final composite = '$fileSizeBytes:$durationMs:$sampleHash';
    return sha256.convert(utf8.encode(composite)).toString();
  }
}
