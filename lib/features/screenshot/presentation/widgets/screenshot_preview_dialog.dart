import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/models/screenshot_config.dart';
import '../controllers/screenshot_controller.dart';

/// Full-screen or modal interactive screenshot viewer with pinch-to-zoom, pan, metadata,
/// share, and save-to-gallery actions.
class ScreenshotPreviewDialog extends ConsumerWidget {
  final ScreenshotItem item;

  const ScreenshotPreviewDialog({super.key, required this.item});

  static Future<void> show(BuildContext context, ScreenshotItem item) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => ScreenshotPreviewDialog(item: item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(screenshotControllerProvider);
    final controller = ref.read(screenshotControllerProvider.notifier);

    // Track reactive updates to current item (e.g. savedPath)
    final currentItem = state.capturedSessionFrames.firstWhere(
      (f) => f.id == item.id,
      orElse: () => item,
    );

    final imageFile = currentItem.tempFilePath != null
        ? File(currentItem.tempFilePath!)
        : null;
    final fileExists = imageFile != null && imageFile.existsSync();

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceXs,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentItem.outputFileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Captured at ${currentItem.formattedTime}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (fileExists)
                    IconButton(
                      icon: const Icon(
                        Icons.share_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Share Image',
                      onPressed: () {
                        Share.shareXFiles(
                          [
                            XFile(currentItem.tempFilePath!),
                          ],
                          text: currentItem.outputFileName,
                        );
                      },
                    ),
                ],
              ),
            ),

            // Zoomable Interactive Image Surface
            Expanded(
              child: fileExists
                  ? InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: Center(
                        child: Image.file(
                          imageFile,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                            child: Text(
                              'Failed to load image preview',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Image file not found on disk',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),

            // Bottom Metadata & Actions Bar
            Container(
              padding: const EdgeInsets.all(AppTokens.spaceMd),
              color: colorScheme.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Metadata Badges Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MetadataChip(
                        icon: Icons.aspect_ratio_rounded,
                        label: currentItem.width != null &&
                                currentItem.height != null
                            ? '${currentItem.width}×${currentItem.height}'
                            : 'Native Res',
                      ),
                      _MetadataChip(
                        icon: Icons.timer_outlined,
                        label: currentItem.formattedTime,
                      ),
                      if (currentItem.fileSizeBytes != null)
                        _MetadataChip(
                          icon: Icons.sd_storage_outlined,
                          label: Formatters.formatFileSize(
                            currentItem.fileSizeBytes!,
                          ),
                        ),
                      _MetadataChip(
                        icon: Icons.image_outlined,
                        label: currentItem.outputFileName.endsWith('.jpg')
                            ? 'JPEG'
                            : 'PNG',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.spaceMd),

                  // Save to Gallery Button
                  Row(
                    children: [
                      Expanded(
                        child: currentItem.isSaved
                            ? FilledButton.tonalIcon(
                                icon: const Icon(Icons.check_circle_rounded),
                                label: const Text('Saved in Gallery'),
                                onPressed: null,
                              )
                            : FilledButton.icon(
                                icon: state.isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_alt_rounded),
                                label: Text(
                                  state.isSaving
                                      ? 'Saving...'
                                      : 'Save to Gallery',
                                ),
                                onPressed: state.isSaving || !fileExists
                                    ? null
                                    : () async {
                                        final uri = await controller
                                            .saveItemToGallery(currentItem);
                                        if (context.mounted && uri != null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Saved to ${currentItem.outputFileName}',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceSm,
        vertical: AppTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: AppTokens.spaceXs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
