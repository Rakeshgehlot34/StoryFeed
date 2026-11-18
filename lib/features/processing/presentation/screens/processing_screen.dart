import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/services/app_messenger.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../controllers/processing_controller.dart';
import '../../domain/models/processing_progress.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final progress = ref.read(processingControllerProvider);
      if (!progress.isProcessing &&
          progress.status == ProcessingStatus.completed) {
        if (mounted) context.go(AppRoutes.results);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _minimizeToBackground(BuildContext context) {
    AppMessenger.showInfo(
      context,
      'Exporting continues in the background. You can browse the app freely.',
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<bool> _onWillPop() async {
    final progress = ref.read(processingControllerProvider);
    if (!progress.isProcessing) return true;

    final shouldCancel = await ConfirmDialog.show(
      context: context,
      title: 'Cancel Video Split?',
      message: 'Video processing is in progress. Cancelling will stop encoding and delete partial files.',
      confirmLabel: 'Cancel Split',
      cancelLabel: 'Keep Processing',
      isDestructive: true,
    );

    if (shouldCancel) {
      await ref.read(processingControllerProvider.notifier).cancel();
      return true;
    }
    return false;
  }

  String _formatElapsed() {
    final s = _stopwatch.elapsed.inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(double progress) {
    if (progress <= 0.05) return 'Estimating...';
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final totalEstimatedMs = elapsedMs / progress;
    final remainingMs = (totalEstimatedMs - elapsedMs)
        .clamp(0, 3600000)
        .toInt();
    final remSec = remainingMs ~/ 1000;
    final m = remSec ~/ 60;
    final s = remSec % 60;
    return '~${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(processingControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<ProcessingProgress>(processingControllerProvider, (prev, next) {
      if (next.status == ProcessingStatus.completed && mounted) {
        context.go(AppRoutes.results);
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (progress.isProcessing) {
          _minimizeToBackground(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exporting Shorts'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: progress.isProcessing ? 'Run in Background' : 'Back',
            onPressed: () {
              if (progress.isProcessing) {
                _minimizeToBackground(context);
              } else {
                context.pop();
              }
            },
          ),
          actions: [
            if (progress.isProcessing)
              TextButton.icon(
                icon: const Icon(Icons.picture_in_picture_alt_rounded),
                label: const Text('Background'),
                onPressed: () => _minimizeToBackground(context),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            children: [
              _buildProgressCard(colorScheme, progress),
              const SizedBox(height: AppTokens.spaceLg),
              _buildClipStatusCard(colorScheme, progress),
              const SizedBox(height: AppTokens.spaceLg),
              _buildNotificationNote(colorScheme),
              const SizedBox(height: AppTokens.spaceXl),
              _buildActionButtons(colorScheme, progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    ColorScheme colorScheme,
    ProcessingProgress progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceXl),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppTokens.borderRadiusXl,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          ProgressRing(
            progress: progress.overallProgress,
            size: 150,
            statusText: progress.totalClips > 0
                ? 'Clip ${progress.currentClipIndex} of ${progress.totalClips}'
                : 'Preparing...',
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeStat('Elapsed', _formatElapsed()),
              _buildTimeStat(
                'Remaining',
                _formatRemaining(progress.overallProgress),
              ),
              if (progress.fps > 0)
                _buildTimeStat(
                  'Speed',
                  '${progress.fps.toStringAsFixed(0)} FPS',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildClipStatusCard(
    ColorScheme colorScheme,
    ProcessingProgress progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppTokens.borderRadiusLg,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie_creation_outlined, size: 18),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  progress.currentClipName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          LinearProgressIndicator(
            value: progress.currentClipProgress > 0
                ? progress.currentClipProgress
                : null,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationNote(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppTokens.borderRadiusMd,
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18),
          SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(
              'You can leave this screen. Export continues in the background.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    ColorScheme colorScheme,
    ProcessingProgress progress,
  ) {
    if (progress.isProcessing) {
      return Column(
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
            ),
            icon: const Icon(Icons.picture_in_picture_alt_rounded),
            label: const Text('Minimize / Continue in App'),
            onPressed: () => _minimizeToBackground(context),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
              minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel Split'),
            onPressed: () async {
              final shouldCancel = await _onWillPop();
              if (shouldCancel && mounted) context.pop();
            },
          ),
        ],
      );
    }

    if (progress.hasError || progress.isCancelled) {
      return FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTokens.minTouchTarget),
        ),
        onPressed: () => context.pop(),
        child: const Text('Return to Settings'),
      );
    }

    return const SizedBox.shrink();
  }
}
