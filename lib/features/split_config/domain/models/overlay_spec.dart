import 'dart:ui' show Color;

/// Position of text overlay on canvas, strictly honoring YouTube Shorts safe zones.
enum OverlayPosition {
  top,
  center,
  bottom;

  String get label => switch (this) {
    OverlayPosition.top => 'Top (Safe Area)',
    OverlayPosition.center => 'Center',
    OverlayPosition.bottom => 'Bottom (Above Title)',
  };

  /// Vertical fractional offset (0.0 to 1.0) on canvas
  /// 0.14 = Top safe margin (below top bar/search)
  /// 0.50 = Middle of canvas
  /// 0.78 = Bottom safe margin (above title, sound pill, and action buttons)
  double get yOffsetFraction => switch (this) {
    OverlayPosition.top => 0.14,
    OverlayPosition.center => 0.50,
    OverlayPosition.bottom => 0.78,
  };
}

/// Specification for text overlay / part messages on exported clips.
class OverlaySpec {
  final bool autoLabel;
  final String template;
  final String? allPartsMessage;
  final OverlayPosition position;
  final double fontSize;
  final int textColorValue;
  final int boxColorValue;
  final bool displayWholeClip;
  final double displayDurationSeconds;

  const OverlaySpec({
    this.autoLabel = true,
    this.template = 'Part {n}/{total}',
    this.allPartsMessage,
    this.position = OverlayPosition.top,
    this.fontSize = 42.0,
    this.textColorValue = 0xFFFFFFFF,
    this.boxColorValue = 0x99000000, // ~60% black
    this.displayWholeClip = true,
    this.displayDurationSeconds = 3.0,
  });

  Color get textColor => Color(textColorValue);
  Color get boxColor => Color(boxColorValue);

  /// Resolves the final text for a specific clip part following the strict hierarchy:
  /// 1. Specific part override
  /// 2. All parts message
  /// 3. Auto label template (if enabled)
  /// 4. null (no text overlay)
  String? resolveText({
    required int partIndex,
    required int totalParts,
    required String baseName,
    String? specificPartOverride,
  }) {
    String? rawTemplate;

    if (specificPartOverride != null &&
        specificPartOverride.trim().isNotEmpty) {
      rawTemplate = specificPartOverride.trim();
    } else if (allPartsMessage != null && allPartsMessage!.trim().isNotEmpty) {
      rawTemplate = allPartsMessage!.trim();
    } else if (autoLabel && template.trim().isNotEmpty) {
      rawTemplate = template.trim();
    }

    if (rawTemplate == null || rawTemplate.isEmpty) {
      return null;
    }

    // Substitute tokens {n}, {total}, {name}
    return rawTemplate
        .replaceAll('{n}', partIndex.toString())
        .replaceAll('{total}', totalParts.toString())
        .replaceAll('{name}', baseName);
  }

  OverlaySpec copyWith({
    bool? autoLabel,
    String? template,
    String? allPartsMessage,
    OverlayPosition? position,
    double? fontSize,
    int? textColorValue,
    int? boxColorValue,
    bool? displayWholeClip,
    double? displayDurationSeconds,
  }) {
    return OverlaySpec(
      autoLabel: autoLabel ?? this.autoLabel,
      template: template ?? this.template,
      allPartsMessage: allPartsMessage ?? this.allPartsMessage,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      textColorValue: textColorValue ?? this.textColorValue,
      boxColorValue: boxColorValue ?? this.boxColorValue,
      displayWholeClip: displayWholeClip ?? this.displayWholeClip,
      displayDurationSeconds:
          displayDurationSeconds ?? this.displayDurationSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OverlaySpec &&
          runtimeType == other.runtimeType &&
          autoLabel == other.autoLabel &&
          template == other.template &&
          allPartsMessage == other.allPartsMessage &&
          position == other.position &&
          fontSize == other.fontSize &&
          textColorValue == other.textColorValue &&
          boxColorValue == other.boxColorValue &&
          displayWholeClip == other.displayWholeClip &&
          displayDurationSeconds == other.displayDurationSeconds;

  @override
  int get hashCode => Object.hash(
    autoLabel,
    template,
    allPartsMessage,
    position,
    fontSize,
    textColorValue,
    boxColorValue,
    displayWholeClip,
    displayDurationSeconds,
  );
}
