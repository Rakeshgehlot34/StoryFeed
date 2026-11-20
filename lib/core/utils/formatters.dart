import 'dart:math';

/// Utility class for formatting durations, file sizes, and clip filenames.
class Formatters {
  Formatters._();

  /// Formats a [Duration] into `mm:ss` or `hh:mm:ss`.
  static String formatDuration(Duration duration) {
    if (duration.isNegative) return '00:00';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Formats fractional seconds into `mm:ss` or `hh:mm:ss`.
  static String formatSeconds(double totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    return formatDuration(
      Duration(milliseconds: (totalSeconds * 1000).round()),
    );
  }

  /// Formats fractional seconds into precise timestamp `mm:ss.mmm` or `hh:mm:ss.mmm`.
  static String formatPrecise(double totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final totalMs = (totalSeconds * 1000).round();
    final hours = totalMs ~/ 3600000;
    final minutes = (totalMs % 3600000) ~/ 60000;
    final seconds = (totalMs % 60000) ~/ 1000;
    final millis = totalMs % 1000;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final mmm = millis.toString().padLeft(3, '0');

    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss.$mmm';
    }
    return '$mm:$ss.$mmm';
  }

  /// Parses `mm:ss.mmm`, `hh:mm:ss.mmm`, or decimal seconds into double seconds.
  static double? parsePrecise(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return null;

    try {
      final parts = clean.split(':');
      if (parts.length == 1) {
        return double.tryParse(parts[0]);
      } else if (parts.length == 2) {
        final min = int.tryParse(parts[0]);
        final sec = double.tryParse(parts[1]);
        if (min != null && sec != null && sec >= 0 && sec <= 60) {
          return (min * 60) + sec;
        }
      } else if (parts.length == 3) {
        final hr = int.tryParse(parts[0]);
        final min = int.tryParse(parts[1]);
        final sec = double.tryParse(parts[2]);
        if (hr != null &&
            min != null &&
            sec != null &&
            min >= 0 &&
            min <= 60 &&
            sec >= 0 &&
            sec <= 60) {
          return (hr * 3600) + (min * 60) + sec;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Formats byte count into human-readable size string (e.g. `24.5 MB`).
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor();
    final clampedIndex = min(i, suffixes.length - 1);
    final size = bytes / pow(1024, clampedIndex);
    return '${size.toStringAsFixed(clampedIndex == 0 ? 0 : 1)} ${suffixes[clampedIndex]}';
  }

  /// Sanitizes a raw file name to prevent illegal filesystem characters.
  static String sanitizeFileName(String name) {
    var cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    // Remove trailing extension if present in base name
    if (cleaned.contains('.')) {
      cleaned = cleaned.substring(0, cleaned.lastIndexOf('.'));
    }
    return cleaned.isEmpty ? 'video' : cleaned;
  }

  /// Returns zero-padded clip filename in the required pattern:
  /// `{originalName}_part_001.mp4`, `{originalName}_part_002.mp4`, etc.
  static String formatClipFileName(
    String baseName,
    int partIndex,
    int totalParts,
  ) {
    final sanitizedBase = sanitizeFileName(baseName);
    final padLength = max(3, totalParts.toString().length);
    final paddedNumber = partIndex.toString().padLeft(padLength, '0');
    return '${sanitizedBase}_part_$paddedNumber.mp4';
  }

  /// Formats a [DateTime] into a relative string like 'Just now', '5m ago', '2h ago', or 'dd/MM/yyyy'.
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    return '$dd/$mm/${dateTime.year}';
  }
}
