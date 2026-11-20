import 'dart:ui' show Color;

/// Background fill type when video does not fill the canvas canvas.
enum BackgroundType {
  solidColor,
  image,
  blur;

  String get label => switch (this) {
        BackgroundType.solidColor => 'Solid Color',
        BackgroundType.image => 'Custom Image',
        BackgroundType.blur => 'Blurred Video',
      };
}

/// Specification for background canvas fill behind scaled videos.
sealed class BackgroundSpec {
  const BackgroundSpec();

  BackgroundType get type;

  /// Default background is solid white (0xFFFFFFFF)
  static const BackgroundSpec defaultSpec = SolidColorBackgroundSpec();
}

/// Solid color background specification (defaults to white).
final class SolidColorBackgroundSpec extends BackgroundSpec {
  final int colorValue; // ARGB representation

  const SolidColorBackgroundSpec({this.colorValue = 0xFFFFFFFF});

  Color get color => Color(colorValue);

  String get hexCode {
    final hex = colorValue.toRadixString(16).padLeft(8, '0').toUpperCase();
    return '#${hex.substring(2)}'; // #RRGGBB
  }

  @override
  BackgroundType get type => BackgroundType.solidColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolidColorBackgroundSpec &&
          runtimeType == other.runtimeType &&
          colorValue == other.colorValue;

  @override
  int get hashCode => colorValue.hashCode;
}

/// Custom gallery image background specification.
final class ImageBackgroundSpec extends BackgroundSpec {
  final String imagePath;

  const ImageBackgroundSpec({required this.imagePath});

  @override
  BackgroundType get type => BackgroundType.image;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageBackgroundSpec &&
          runtimeType == other.runtimeType &&
          imagePath == other.imagePath;

  @override
  int get hashCode => imagePath.hashCode;
}

/// Blurred video background specification.
final class BlurBackgroundSpec extends BackgroundSpec {
  const BlurBackgroundSpec();

  @override
  BackgroundType get type => BackgroundType.blur;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlurBackgroundSpec && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
