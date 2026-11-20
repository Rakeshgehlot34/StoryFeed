import '../../../../core/utils/formatters.dart';

/// Represents an exported, sequentially numbered video clip saved on the device.
class ExportedClip {
  final String path;
  final String fileName;
  final int partIndex;
  final int totalParts;
  final Duration duration;
  final int sizeInBytes;
  final DateTime createdAt;

  const ExportedClip({
    required this.path,
    required this.fileName,
    required this.partIndex,
    required this.totalParts,
    required this.duration,
    required this.sizeInBytes,
    required this.createdAt,
  });

  String get formattedDuration => Formatters.formatDuration(duration);
  String get formattedSize => Formatters.formatFileSize(sizeInBytes);

  Map<String, dynamic> toJson() => {
        'path': path,
        'fileName': fileName,
        'partIndex': partIndex,
        'totalParts': totalParts,
        'durationMs': duration.inMilliseconds,
        'sizeInBytes': sizeInBytes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExportedClip.fromJson(Map<String, dynamic> json) => ExportedClip(
        path: json['path'] as String,
        fileName: json['fileName'] as String,
        partIndex: json['partIndex'] as int,
        totalParts: json['totalParts'] as int,
        duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
        sizeInBytes: json['sizeInBytes'] as int? ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
