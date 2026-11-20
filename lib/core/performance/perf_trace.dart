import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logger/app_logger.dart';

/// Enum defining discrete execution stages of clip generation.
enum PerfStage {
  sourcePrep('Source Preparation'),
  probe('Stream Probing'),
  ffmpegRun('FFmpeg Execution'),
  destCopy('Destination Storage Copy'),
  verification('Output Verification'),
  cleanup('Temp File Cleanup');

  final String label;
  const PerfStage(this.label);
}

/// Trace record for a single processed clip.
class ClipPerfRecord {
  final int clipIndex;
  final int totalClips;
  final double clipDurationSeconds;
  final Map<PerfStage, int> stageDurationsMs = {};
  String encoder = 'unknown';
  double? ffmpegSpeedMultiplier;
  int? freeRamMb;
  String thermalStatus = 'normal';
  int outputSizeBytes = 0;
  bool isSuccess = false;
  String? errorMessage;
  int totalTimeMs = 0;

  ClipPerfRecord({
    required this.clipIndex,
    required this.totalClips,
    required this.clipDurationSeconds,
  });

  void recordStage(PerfStage stage, int durationMs) {
    stageDurationsMs[stage] = durationMs;
  }

  int getStage(PerfStage stage) => stageDurationsMs[stage] ?? 0;
}

/// Debug and release safe performance telemetry and diagnostic tracing service.
/// Collects strictly technical performance metrics (timings, encoder, speed, RAM, thermal)
/// with zero personally identifiable data.
class PerfTrace {
  static final PerfTrace instance = PerfTrace._internal();
  PerfTrace._internal();

  String? _activeJobId;
  String? _jobType;
  String? _sourceFileName;
  int _totalClips = 0;
  DateTime? _jobStartTime;
  DateTime? _jobEndTime;

  final List<ClipPerfRecord> _clipRecords = [];
  ClipPerfRecord? _currentClip;

  List<ClipPerfRecord> get clipRecords => List.unmodifiable(_clipRecords);
  bool get hasActiveJob => _activeJobId != null;

  /// Starts tracking a new batch export or single-pass operation.
  void startJob({
    required String jobId,
    required String jobType,
    required String sourceFileName,
    required int totalClips,
  }) {
    _activeJobId = jobId;
    _jobType = jobType;
    _sourceFileName = p.basename(sourceFileName);
    _totalClips = totalClips;
    _jobStartTime = DateTime.now();
    _jobEndTime = null;
    _clipRecords.clear();
    _currentClip = null;

    AppLogger.info(
      'PerfTrace: Job started ($jobType, $totalClips clips, source: $_sourceFileName)',
    );
  }

  /// Begins timing a specific clip in the batch.
  void startClip(int clipIndex, double clipDurationSeconds) {
    _currentClip = ClipPerfRecord(
      clipIndex: clipIndex,
      totalClips: _totalClips,
      clipDurationSeconds: clipDurationSeconds,
    );
  }

  /// Times a synchronous or asynchronous execution stage.
  Future<T> measureStage<T>(
    PerfStage stage,
    Future<T> Function() action,
  ) async {
    final sw = Stopwatch()..start();
    try {
      final result = await action();
      sw.stop();
      _currentClip?.recordStage(stage, sw.elapsedMilliseconds);
      return result;
    } catch (e) {
      sw.stop();
      _currentClip?.recordStage(stage, sw.elapsedMilliseconds);
      rethrow;
    }
  }

  /// Manually logs duration for an external stage.
  void recordStageTime(PerfStage stage, int durationMs) {
    _currentClip?.recordStage(stage, durationMs);
  }

  /// Records hardware/software encoder used (e.g. h264_mediacodec, libx264).
  void recordEncoder(String encoder) {
    _currentClip?.encoder = encoder;
  }

  /// Records speed multiplier (e.g. 2.4x realtime).
  void recordSpeed(double speedMultiplier) {
    _currentClip?.ffmpegSpeedMultiplier = speedMultiplier;
  }

  /// Records system memory and thermal state at capture time.
  void recordSystemHealth({int? freeRamMb, String? thermalStatus}) {
    if (freeRamMb != null) _currentClip?.freeRamMb = freeRamMb;
    if (thermalStatus != null) _currentClip?.thermalStatus = thermalStatus;
  }

  /// Completes the timing for the current clip.
  void finishClip({
    required bool isSuccess,
    int outputSizeBytes = 0,
    String? errorMessage,
  }) {
    if (_currentClip != null) {
      _currentClip!.isSuccess = isSuccess;
      _currentClip!.outputSizeBytes = outputSizeBytes;
      _currentClip!.errorMessage = errorMessage;

      // Compute total clip execution time from stage sums
      int sum = 0;
      for (final v in _currentClip!.stageDurationsMs.values) {
        sum += v;
      }
      _currentClip!.totalTimeMs = sum;

      // If speed was not reported by FFmpeg stats, compute from ffmpegRun duration:
      if (_currentClip!.ffmpegSpeedMultiplier == null &&
          _currentClip!.clipDurationSeconds > 0) {
        final ffmpegMs = _currentClip!.getStage(PerfStage.ffmpegRun);
        if (ffmpegMs > 0) {
          _currentClip!.ffmpegSpeedMultiplier =
              (_currentClip!.clipDurationSeconds * 1000) / ffmpegMs;
        }
      }

      _clipRecords.add(_currentClip!);
      AppLogger.info(
        'PerfTrace: Clip ${_currentClip!.clipIndex}/$_totalClips finished in ${_currentClip!.totalTimeMs}ms (FFmpeg: ${_currentClip!.getStage(PerfStage.ffmpegRun)}ms, Speed: ${_currentClip!.ffmpegSpeedMultiplier?.toStringAsFixed(2)}x, Success: $isSuccess)',
      );
      _currentClip = null;
    }
  }

  /// Finishes the overall job session and auto-generates report.
  Future<File?> finishJob() async {
    _jobEndTime = DateTime.now();
    AppLogger.info(
      'PerfTrace: Job finished ($_activeJobId). Generated ${_clipRecords.length} records.',
    );
    return saveReportToFile();
  }

  /// Compiles a human-readable diagnostics markdown report.
  String generateReport() {
    final buffer = StringBuffer();
    final totalDuration = _jobStartTime != null && _jobEndTime != null
        ? _jobEndTime!.difference(_jobStartTime!).inMilliseconds
        : 0;

    buffer.writeln('# ShortsSplitter Performance Diagnostics Report');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Job ID: ${_activeJobId ?? 'N/A'}');
    buffer.writeln('Job Type: ${_jobType ?? 'N/A'}');
    buffer.writeln('Source: ${_sourceFileName ?? 'N/A'}');
    buffer.writeln(
      'Total Wall-Clock Time: ${(totalDuration / 1000).toStringAsFixed(2)}s',
    );
    buffer.writeln(
      'Clips Total: $_totalClips | Processed: ${_clipRecords.length}',
    );
    buffer.writeln();

    if (_clipRecords.isEmpty) {
      buffer.writeln('No clip performance records available.');
      return buffer.toString();
    }

    // Summary Statistics
    int totalPrepMs = 0;
    int totalProbeMs = 0;
    int totalFfmpegMs = 0;
    int totalCopyMs = 0;
    int totalVerifyMs = 0;
    int totalCleanupMs = 0;
    double totalSpeedSum = 0;
    int speedCount = 0;

    for (final c in _clipRecords) {
      totalPrepMs += c.getStage(PerfStage.sourcePrep);
      totalProbeMs += c.getStage(PerfStage.probe);
      totalFfmpegMs += c.getStage(PerfStage.ffmpegRun);
      totalCopyMs += c.getStage(PerfStage.destCopy);
      totalVerifyMs += c.getStage(PerfStage.verification);
      totalCleanupMs += c.getStage(PerfStage.cleanup);
      if (c.ffmpegSpeedMultiplier != null) {
        totalSpeedSum += c.ffmpegSpeedMultiplier!;
        speedCount++;
      }
    }

    final avgSpeed = speedCount > 0 ? (totalSpeedSum / speedCount) : 0.0;
    final totalAllStages = totalPrepMs +
        totalProbeMs +
        totalFfmpegMs +
        totalCopyMs +
        totalVerifyMs +
        totalCleanupMs;

    buffer.writeln('## Stage Breakdown (Cumulative)');
    buffer.writeln('| Stage | Total Time | Share (%) |');
    buffer.writeln('| :--- | :--- | :--- |');
    buffer.writeln(
      '| 1. Source Preparation | ${totalPrepMs}ms | ${_calcPercent(totalPrepMs, totalAllStages)}% |',
    );
    buffer.writeln(
      '| 2. Stream Probing | ${totalProbeMs}ms | ${_calcPercent(totalProbeMs, totalAllStages)}% |',
    );
    buffer.writeln(
      '| 3. FFmpeg Execution | ${totalFfmpegMs}ms | ${_calcPercent(totalFfmpegMs, totalAllStages)}% |',
    );
    buffer.writeln(
      '| 4. Destination Storage Copy | ${totalCopyMs}ms | ${_calcPercent(totalCopyMs, totalAllStages)}% |',
    );
    buffer.writeln(
      '| 5. Output Verification | ${totalVerifyMs}ms | ${_calcPercent(totalVerifyMs, totalAllStages)}% |',
    );
    buffer.writeln(
      '| 6. Temp Cleanup | ${totalCleanupMs}ms | ${_calcPercent(totalCleanupMs, totalAllStages)}% |',
    );
    buffer.writeln(
      '| **Total Processing Time** | **${totalAllStages}ms** | **100.0%** |',
    );
    buffer.writeln();
    buffer.writeln(
      '**Average Transcode Speed:** ${avgSpeed.toStringAsFixed(2)}x realtime',
    );
    buffer.writeln();

    buffer.writeln('## Per-Clip Metrics');
    buffer.writeln(
      '| Clip # | Length (s) | Total (ms) | FFmpeg (ms) | Speed | Copy (ms) | Encoder | Size (KB) | Result |',
    );
    buffer.writeln(
      '| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |',
    );

    for (final c in _clipRecords) {
      final sizeKb = (c.outputSizeBytes / 1024).round();
      final speedStr = c.ffmpegSpeedMultiplier != null
          ? '${c.ffmpegSpeedMultiplier!.toStringAsFixed(2)}x'
          : 'N/A';
      final statusStr = c.isSuccess ? 'PASS' : 'FAIL';
      buffer.writeln(
        '| ${c.clipIndex} | ${c.clipDurationSeconds.toStringAsFixed(1)}s | ${c.totalTimeMs}ms | ${c.getStage(PerfStage.ffmpegRun)}ms | $speedStr | ${c.getStage(PerfStage.destCopy)}ms | ${c.encoder} | ${sizeKb}KB | $statusStr |',
      );
    }

    return buffer.toString();
  }

  static String _calcPercent(int part, int total) {
    if (total <= 0) return '0.0';
    return ((part / total) * 100).toStringAsFixed(1);
  }

  /// Writes report to the application logs folder.
  Future<File?> saveReportToFile() async {
    try {
      Directory logDir;
      try {
        final docDir = await getApplicationDocumentsDirectory();
        logDir = Directory(p.join(docDir.path, 'logs'));
      } catch (_) {
        logDir = Directory(
          p.join(Directory.systemTemp.path, 'shortssplitter_logs'),
        );
      }

      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File(
        p.join(logDir.path, 'perf_report_${_activeJobId ?? ts}.md'),
      );
      await file.writeAsString(generateReport());
      AppLogger.info('PerfTrace: Report saved to ${file.path}');
      return file;
    } catch (e) {
      AppLogger.warning('PerfTrace: Failed to save report: $e');
      return null;
    }
  }

  /// Opens the system share sheet with the generated report file.
  Future<void> shareDiagnostics(BuildContext context) async {
    final file = await saveReportToFile();
    if (file == null || !await file.exists()) {
      AppLogger.warning('PerfTrace: Cannot share null/nonexistent report file');
      return;
    }
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'ShortsSplitter Performance Diagnostics',
      text: 'Performance trace diagnostics from ShortsSplitter.',
    );
  }
}
