import 'dart:io';

import 'package:flutter/material.dart';

import '../../../split_config/domain/models/background_spec.dart';
import '../../../split_config/domain/models/canvas_spec.dart';
import '../../../split_config/domain/models/fit_layout.dart';
import '../../../split_config/domain/models/overlay_spec.dart';

/// Live canvas and overlay preview showing safe-area positioning and styling.
/// Powered by [FitLayout] to ensure 100% exact parity with FFmpeg export geometry.
class OverlayLivePreview extends StatelessWidget {
  final CanvasSpec canvasSpec;
  final BackgroundSpec backgroundSpec;
  final OverlaySpec overlaySpec;
  final String? previewText;
  final int sourceWidth;
  final int sourceHeight;
  final int rotationDegrees;
  final VerticalPosition verticalPosition;
  final double verticalOffsetFraction;
  final bool cropToFill;
  final VoidCallback? onPreviewTap;

  const OverlayLivePreview({
    super.key,
    required this.canvasSpec,
    required this.backgroundSpec,
    required this.overlaySpec,
    this.previewText,
    this.sourceWidth = 1920,
    this.sourceHeight = 1080,
    this.rotationDegrees = 0,
    this.verticalPosition = VerticalPosition.center,
    this.verticalOffsetFraction = 0.0,
    this.cropToFill = false,
    this.onPreviewTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final aspect = canvasSpec.aspectRatio;

    final fitLayout = FitLayout.calculate(
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      canvasWidth: canvasSpec.width,
      canvasHeight: canvasSpec.height,
      rotationDegrees: rotationDegrees,
      fitMode: cropToFill ? FitMode.cropToFill : FitMode.fit,
      verticalPosition: verticalPosition,
      verticalOffsetFraction: verticalOffsetFraction,
    );

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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPreviewTap,
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildBackground(),
                        _buildVideoPlaceholder(
                          theme,
                          colorScheme,
                          fitLayout,
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                        if (previewText != null && previewText!.isNotEmpty)
                          _buildOverlayText(),
                        if (onPreviewTap != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Preview',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
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
          errorBuilder: (context, error, stackTrace) =>
              Container(color: Colors.white),
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

  Widget _buildVideoPlaceholder(
    ThemeData theme,
    ColorScheme colorScheme,
    FitLayout layout,
    double parentWidth,
    double parentHeight,
  ) {
    final left = layout.normalizedX * parentWidth;
    final top = layout.normalizedY * parentHeight;
    final width = (layout.normalizedWidth * parentWidth).clamp(
      2.0,
      parentWidth,
    );
    final height = (layout.normalizedHeight * parentHeight).clamp(
      2.0,
      parentHeight,
    );

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24, width: 1),
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
                    size: 24,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Source Video',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 9,
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
    double alignX = 0.0;
    if (overlaySpec.position == OverlayPosition.topLeft ||
        overlaySpec.position == OverlayPosition.bottomLeft) {
      alignX = -0.84;
    } else if (overlaySpec.position == OverlayPosition.topRight ||
        overlaySpec.position == OverlayPosition.bottomRight) {
      alignX = 0.84;
    }

    final alignY = (overlaySpec.position.yOffsetFraction * 2.0) - 1.0;

    return Align(
      alignment: Alignment(alignX, alignY),
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
