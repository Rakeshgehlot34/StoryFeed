import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../split_config/domain/models/overlay_spec.dart';

/// Renders styled text overlays into crisp, transparent PNGs using Flutter's native 2D canvas.
/// Guarantees universal Unicode, emoji, and script support without host font dependencies.
class OverlayRenderer {
  OverlayRenderer._();

  /// Renders [text] onto a transparent canvas of size [width] x [height] and writes PNG to [outputPath].
  static Future<String> renderToPngFile({
    required String text,
    required int width,
    required int height,
    required OverlaySpec overlaySpec,
    required String outputPath,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final paragraphStyle = ui.ParagraphStyle(
      textAlign: ui.TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      maxLines: 3,
    );

    final textStyle = ui.TextStyle(
      color: overlaySpec.textColor,
      fontSize: overlaySpec.fontSize,
      fontWeight: ui.FontWeight.bold,
      shadows: const [
        ui.Shadow(
          color: ui.Color(0x80000000),
          offset: ui.Offset(2, 2),
          blurRadius: 4,
        ),
      ],
    );

    final builder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(text);

    final maxTextWidth = width * 0.82;
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxTextWidth));

    final textWidth = paragraph.maxIntrinsicWidth;
    final textHeight = paragraph.height;

    // Background pill/box padding
    const horizontalPadding = 24.0;
    const verticalPadding = 12.0;

    // Calculate vertical position honoring safe areas
    final targetY = (height * overlaySpec.position.yOffsetFraction).clamp(
      verticalPadding + 16.0,
      height - textHeight - verticalPadding - 16.0,
    );

    // Calculate horizontal position honoring alignment presets
    double targetX;
    if (overlaySpec.position == OverlayPosition.topLeft ||
        overlaySpec.position == OverlayPosition.bottomLeft) {
      targetX = horizontalPadding + 16.0;
    } else if (overlaySpec.position == OverlayPosition.topRight ||
        overlaySpec.position == OverlayPosition.bottomRight) {
      targetX = width - textWidth - horizontalPadding - 16.0;
    } else {
      // topCenter, center, bottomCenter
      targetX = (width - textWidth) / 2.0;
    }

    final boxRect = ui.Rect.fromLTWH(
      targetX - horizontalPadding,
      targetY - verticalPadding,
      textWidth + (horizontalPadding * 2),
      textHeight + (verticalPadding * 2),
    );

    // Draw background rounded box
    final boxPaint = ui.Paint()
      ..color = overlaySpec.boxColor
      ..style = ui.PaintingStyle.fill;

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(boxRect, const ui.Radius.circular(16)),
      boxPaint,
    );

    // Draw paragraph
    canvas.drawParagraph(paragraph, ui.Offset(targetX, targetY));

    // Convert picture to image and encode to PNG
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw StateError('Failed to encode overlay image to PNG byte data.');
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final file = File(outputPath);
    await file.writeAsBytes(pngBytes, flush: true);

    return outputPath;
  }
}
