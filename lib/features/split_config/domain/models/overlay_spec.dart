import 'dart:ui' show Color;

/// Mode controlling whether automatic part numbering labels are rendered on clips.
enum PartLabelMode {
  auto,
  always,
  never;

  String get label => switch (this) {
        PartLabelMode.auto => 'Auto',
        PartLabelMode.always => 'Always',
        PartLabelMode.never => 'Never',
      };

  String get description => switch (this) {
        PartLabelMode.auto => 'Show on multi-part videos; hide on 1 short',
        PartLabelMode.always => 'Show on every clip (including single short)',
        PartLabelMode.never => 'Never add auto part label',
      };
}

/// Per-part label override setting allowing individual parts in Plan Review to show/hide.
enum PartLabelOverride {
  useProjectDefault,
  show,
  hide;

  String get label => switch (this) {
        PartLabelOverride.useProjectDefault => 'Use project setting',
        PartLabelOverride.show => 'Show label on this part',
        PartLabelOverride.hide => 'Hide label on this part',
      };
}

/// Naming mode for single-part output exports.
enum SinglePartFileNameMode {
  keepPartSuffix,
  originalNameOnly;

  String get label => switch (this) {
        SinglePartFileNameMode.keepPartSuffix => 'Keep _part_001 suffix',
        SinglePartFileNameMode.originalNameOnly => 'Use original name only',
      };
}

/// Position of text overlay on canvas, strictly honoring YouTube Shorts safe zones.
enum OverlayPosition {
  topCenter,
  topLeft,
  topRight,
  center,
  bottomCenter,
  bottomLeft,
  bottomRight;

  // Backward compatibility aliases
  static const OverlayPosition top = OverlayPosition.topCenter;
  static const OverlayPosition bottom = OverlayPosition.bottomCenter;

  String get label => switch (this) {
        OverlayPosition.topCenter => 'Top Center',
        OverlayPosition.topLeft => 'Top Left',
        OverlayPosition.topRight => 'Top Right',
        OverlayPosition.center => 'Center',
        OverlayPosition.bottomCenter => 'Bottom Center',
        OverlayPosition.bottomLeft => 'Bottom Left',
        OverlayPosition.bottomRight => 'Bottom Right',
      };

  /// Vertical fractional offset (0.0 to 1.0) on canvas
  /// 0.14 = Top safe margin (below search/top bar)
  /// 0.50 = Middle of canvas
  /// 0.78 = Bottom safe margin (above title, sound pill, and action buttons)
  double get yOffsetFraction => switch (this) {
        OverlayPosition.topLeft ||
        OverlayPosition.topCenter ||
        OverlayPosition.topRight =>
          0.14,
        OverlayPosition.center => 0.50,
        OverlayPosition.bottomLeft ||
        OverlayPosition.bottomCenter ||
        OverlayPosition.bottomRight =>
          0.78,
      };

  /// Horizontal fractional center offset (0.0 to 1.0) on canvas
  double get xOffsetFraction => switch (this) {
        OverlayPosition.topLeft || OverlayPosition.bottomLeft => 0.10,
        OverlayPosition.topCenter ||
        OverlayPosition.center ||
        OverlayPosition.bottomCenter =>
          0.50,
        OverlayPosition.topRight || OverlayPosition.bottomRight => 0.90,
      };
}

/// Specification for text overlay / part messages on exported clips.
class OverlaySpec {
  final PartLabelMode partLabelMode;
  final String template;
  final String? allPartsMessage;
  final OverlayPosition position;
  final double fontSize;
  final int textColorValue;
  final int boxColorValue;
  final bool displayWholeClip;
  final double displayDurationSeconds;

  const OverlaySpec({
    PartLabelMode? partLabelMode,
    bool? autoLabel,
    this.template = 'Part {n}/{total}',
    this.allPartsMessage,
    this.position = OverlayPosition.topCenter,
    this.fontSize = 50.0,
    this.textColorValue = 0xFFFFFFFF,
    this.boxColorValue = 0x99000000, // ~60% black
    this.displayWholeClip = true,
    this.displayDurationSeconds = 3.0,
  }) : partLabelMode = partLabelMode ??
            (autoLabel != null
                ? (autoLabel ? PartLabelMode.auto : PartLabelMode.never)
                : PartLabelMode.auto);

  /// Backward compatibility getter for legacy boolean autoLabel check.
  bool get autoLabel => partLabelMode != PartLabelMode.never;

  Color get textColor => Color(textColorValue);
  Color get boxColor => Color(boxColorValue);

  /// Resolves the final text for a specific clip part following the strict hierarchy:
  /// 1. Specific part override (never suppressed)
  /// 2. All parts message (never suppressed)
  /// 3. Auto label template (subject to Auto/Always/Never and per-part override)
  /// 4. null (no text overlay)
  String? resolveText({
    required int partIndex,
    required int totalParts,
    required String baseName,
    String? specificPartOverride,
    PartLabelOverride perPartOverride = PartLabelOverride.useProjectDefault,
  }) {
    // 1. Specific part custom override (highest precedence)
    if (specificPartOverride != null &&
        specificPartOverride.trim().isNotEmpty) {
      return _substituteTokens(
        specificPartOverride.trim(),
        partIndex,
        totalParts,
        baseName,
      );
    }

    // 2. All parts custom message
    if (allPartsMessage != null && allPartsMessage!.trim().isNotEmpty) {
      return _substituteTokens(
        allPartsMessage!.trim(),
        partIndex,
        totalParts,
        baseName,
      );
    }

    // 3. Per-part explicit override
    if (perPartOverride == PartLabelOverride.hide) {
      return null;
    }
    if (perPartOverride == PartLabelOverride.show) {
      if (template.trim().isNotEmpty) {
        return _substituteTokens(
          template.trim(),
          partIndex,
          totalParts,
          baseName,
        );
      }
    }

    // 4. Project-level PartLabelMode resolution
    switch (partLabelMode) {
      case PartLabelMode.never:
        return null;
      case PartLabelMode.auto:
        // Auto hides the label when the entire plan has only 1 part
        if (totalParts <= 1) {
          return null;
        }
        if (template.trim().isNotEmpty) {
          return _substituteTokens(
            template.trim(),
            partIndex,
            totalParts,
            baseName,
          );
        }
      case PartLabelMode.always:
        if (template.trim().isNotEmpty) {
          return _substituteTokens(
            template.trim(),
            partIndex,
            totalParts,
            baseName,
          );
        }
    }

    return null;
  }

  static String _substituteTokens(
    String raw,
    int partIndex,
    int totalParts,
    String baseName,
  ) {
    return raw
        .replaceAll('{n}', partIndex.toString())
        .replaceAll('{total}', totalParts.toString())
        .replaceAll('{name}', baseName);
  }

  OverlaySpec copyWith({
    PartLabelMode? partLabelMode,
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
    PartLabelMode resolvedMode = partLabelMode ?? this.partLabelMode;
    if (partLabelMode == null && autoLabel != null) {
      resolvedMode = autoLabel ? PartLabelMode.auto : PartLabelMode.never;
    }

    return OverlaySpec(
      partLabelMode: resolvedMode,
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
          partLabelMode == other.partLabelMode &&
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
        partLabelMode,
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
