import 'dart:convert';
import 'dart:io';

import '../../../../core/utils/formatters.dart';

/// Domain entity representing a completed or partially-completed video split project record.
class ProjectRecord {
  final String id;
  final String videoName;
  final String baseName;
  final DateTime createdAt;
  final double totalDurationSeconds;
  final int totalShortsCount;
  final int? processedShortsCount;
  final String canvasFormat;
  final List<String> outputFilePaths;
  final String? thumbnailPath;
  final bool? isFilesAvailable;

  const ProjectRecord({
    required this.id,
    required this.videoName,
    required this.baseName,
    required this.createdAt,
    required this.totalDurationSeconds,
    required this.totalShortsCount,
    this.processedShortsCount,
    required this.canvasFormat,
    required this.outputFilePaths,
    this.thumbnailPath,
    this.isFilesAvailable,
  });

  /// The count of clips actually processed and saved to disk.
  int get actualProcessedCount =>
      processedShortsCount ?? outputFilePaths.length;

  /// True when the user processed only a subset of planned clips (e.g. 3 of 30).
  bool get isPartiallyProcessed => actualProcessedCount < totalShortsCount;

  /// Human-readable badge text describing completion status (e.g. "3/30 processed").
  String get processedBadgeText =>
      '$actualProcessedCount/$totalShortsCount processed';

  ProjectRecord copyWith({
    bool? isFilesAvailable,
    int? processedShortsCount,
    List<String>? outputFilePaths,
  }) => ProjectRecord(
    id: id,
    videoName: videoName,
    baseName: baseName,
    createdAt: createdAt,
    totalDurationSeconds: totalDurationSeconds,
    totalShortsCount: totalShortsCount,
    processedShortsCount: processedShortsCount ?? this.processedShortsCount,
    canvasFormat: canvasFormat,
    outputFilePaths: outputFilePaths ?? this.outputFilePaths,
    thumbnailPath: thumbnailPath,
    isFilesAvailable: isFilesAvailable ?? this.isFilesAvailable,
  );

  String get formattedDuration =>
      Formatters.formatSeconds(totalDurationSeconds);

  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      final hour = createdAt.hour.toString().padLeft(2, '0');
      final min = createdAt.minute.toString().padLeft(2, '0');
      return 'Today at $hour:$min';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    }
  }

  /// Checks asynchronously whether output clip files still exist on device storage.
  Future<bool> checkFilesExistAsync() async {
    if (outputFilePaths.isEmpty) return false;
    for (final path in outputFilePaths) {
      if (path.startsWith('content://')) return true;
      if (await File(path).exists()) return true;
    }
    return false;
  }

  /// Checks synchronously whether output clip files still exist on device storage (fallback).
  bool get hasValidFilesOnDisk {
    if (isFilesAvailable != null) return isFilesAvailable!;
    if (outputFilePaths.isEmpty) return false;
    for (final path in outputFilePaths) {
      if (path.startsWith('content://')) return true; // SAF URIs
      if (File(path).existsSync()) return true;
    }
    return false;
  }

  /// Total size in bytes of existing output files.
  int get totalDiskBytes {
    var total = 0;
    for (final path in outputFilePaths) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          total += f.lengthSync();
        }
      } catch (_) {}
    }
    return total;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoName': videoName,
      'baseName': baseName,
      'createdAt': createdAt.toIso8601String(),
      'totalDurationSeconds': totalDurationSeconds,
      'totalShortsCount': totalShortsCount,
      'processedShortsCount': actualProcessedCount,
      'canvasFormat': canvasFormat,
      'outputFilePaths': outputFilePaths,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory ProjectRecord.fromJson(Map<String, dynamic> map) {
    final outputFiles = List<String>.from(
      map['outputFilePaths'] as List? ?? [],
    );
    final totalClips =
        (map['totalShortsCount'] as num?)?.toInt() ?? outputFiles.length;
    final processedClips =
        (map['processedShortsCount'] as num?)?.toInt() ?? outputFiles.length;

    return ProjectRecord(
      id: map['id'] as String,
      videoName: map['videoName'] as String,
      baseName: map['baseName'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      totalDurationSeconds: (map['totalDurationSeconds'] as num).toDouble(),
      totalShortsCount: totalClips,
      processedShortsCount: processedClips,
      canvasFormat: map['canvasFormat'] as String? ?? 'Shorts 9:16',
      outputFilePaths: outputFiles,
      thumbnailPath: map['thumbnailPath'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ProjectRecord.fromJsonString(String source) =>
      ProjectRecord.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
