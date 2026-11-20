import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
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
      message:
          'Video processing is in progress. Cancelling will stop encoding and delete partial files.',
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

  String _formatElapsed(ProcessingProgress progress) {
    final d = progress.elapsed > Duration.zero
        ? progress.elapsed
        : _stopwatch.elapsed;
    return Formatters.formatDuration(d);
  }

  String _formatRemaining(ProcessingProgress progress) {
    if (progress.status == ProcessingStatus.completed) return 'Done';
    if (progress.eta != null && progress.eta! > Duration.zero) {
      return '~${Formatters.formatDuration(progress.eta!)}';
    }
    if (progress.overallProgress > 0.005) {
      final elapsedMs = progress.elapsed.inMilliseconds > 0
          ? progress.elapsed.inMilliseconds
          : _stopwatch.elapsedMilliseconds;
      if (elapsedMs > 1500) {
        final remainingMs =
            ((elapsedMs / progress.overallProgress) - elapsedMs).round();
        if (remainingMs > 0 && remainingMs < 86400000) {
          return '~${Formatters.formatDuration(Duration(milliseconds: remainingMs))}';
        }
      }
    }
    return 'Estimating...';
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
              _buildTimeStat('Elapsed', _formatElapsed(progress)),
              _buildTimeStat(
                'Remaining',
                _formatRemaining(progress),
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
    final clipPercent =
        (progress.currentClipProgress * 100).clamp(0, 100).toInt();

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.movie_creation_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  Text(
                    progress.totalClips > 0
                        ? 'Clip ${progress.currentClipIndex} of ${progress.totalClips}'
                        : 'Current Clip',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$clipPercent%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            progress.currentClipName.isNotEmpty
                ? progress.currentClipName
                : 'Processing...',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTokens.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.currentClipProgress > 0
                  ? progress.currentClipProgress
                  : (progress.isProcessing ? null : 0.0),
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
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
