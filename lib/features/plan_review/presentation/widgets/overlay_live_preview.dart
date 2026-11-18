import 'dart:io';

import 'package:flutter/material.dart';

import '../../../split_config/domain/models/background_spec.dart';
import '../../../split_config/domain/models/canvas_spec.dart';
import '../../../split_config/domain/models/overlay_spec.dart';

/// Live canvas and overlay preview showing safe-area positioning and styling.
class OverlayLivePreview extends StatelessWidget {
  final CanvasSpec canvasSpec;
  final BackgroundSpec backgroundSpec;
  final OverlaySpec overlaySpec;
  final String? previewText;

  const OverlayLivePreview({
    super.key,
    required this.canvasSpec,
    required this.backgroundSpec,
    required this.overlaySpec,
    this.previewText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final aspect = canvasSpec.aspectRatio;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        child: AspectRatio(
          aspectRatio: aspect,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildBackground(),
                _buildVideoPlaceholder(theme, colorScheme),
                if (previewText != null && previewText!.isNotEmpty)
                  _buildOverlayText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    switch (backgroundSpec) {
      case SolidColorBackgroundSpec(:final color):
        return Container(color: color);
      case ImageBackgroundSpec(:final imagePath):
        return Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(color: Colors.white),
        );
      case BlurBackgroundSpec():
        return Container(
          color: Colors.grey.shade800,
          child: const Center(
            child: Icon(Icons.blur_on_rounded, color: Colors.white54, size: 36),
          ),
        );
    }
  }

  Widget _buildVideoPlaceholder(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Container(
        width: 140,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Source Video',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayText() {
    return Align(
      alignment: Alignment(
        0.0,
        (overlaySpec.position.yOffsetFraction * 2.0) - 1.0,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: overlaySpec.boxColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          previewText!,
          style: TextStyle(
            color: overlaySpec.textColor,
            fontSize: (overlaySpec.fontSize * 0.28).clamp(9.0, 16.0),
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
