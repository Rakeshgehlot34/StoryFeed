import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/core/errors/app_exception.dart';
import 'package:shorts_splitter/features/editor/domain/models/edit_project.dart';

void main() {
  group('EditProject Domain Model', () {
    const baseProject = EditProject(
      id: 'proj_1',
      title: 'Summer_Vacation_edited',
      sourceVideoPath: '/path/to/vacation.mp4',
      sourceVideoName: 'vacation.mp4',
      sourceDurationSeconds: 60.0,
      sourceWidth: 1920,
      sourceHeight: 1080,
      trim: TrimConfig(startSeconds: 10.0, endSeconds: 20.0), // 10s duration
    );

    test('calculates activeTrimDuration and outputDuration correctly', () {
      expect(baseProject.activeTrimDuration, 10.0);
      expect(baseProject.outputDuration, 10.0);

      final spedUp = baseProject.copyWith(speed: const SpeedSpec(speed: 2.0));
      expect(spedUp.outputDuration, 5.0);

      final slowedDown = baseProject.copyWith(
        speed: const SpeedSpec(speed: 0.5),
      );
      expect(slowedDown.outputDuration, 20.0);
    });

    test(
      'serializes to and from JSON preserving all nested configurations',
      () {
        final complexProject = baseProject.copyWith(
          transform: const TransformSpec(
            cropX: 100,
            cropY: 50,
            cropWidth: 800,
            cropHeight: 800,
            rotationDegrees: 90,
            hflip: true,
            vflip: false,
          ),
          canvas: const CanvasConfig(
            aspectRatio: TargetAspectRatio.vertical916,
            fitMode: CanvasFitMode.fitWithBlur,
            backgroundColorHex: 0xFF112233,
          ),
          speed: const SpeedSpec(speed: 1.5, preservePitch: true),
          color: const ColorFilterSpec(
            brightness: 0.1,
            contrast: 1.2,
            saturation: 1.3,
            preset: ColorFilterPreset.vibrant,
          ),
          fade: const FadeSpec(
            fadeInSeconds: 1.0,
            fadeOutSeconds: 1.5,
            fadeAudio: true,
          ),
          watermark: const WatermarkSpec(
            imagePath: '/logo.png',
            position: OverlayPosition.topLeft,
            opacity: 0.7,
            scale: 0.2,
          ),
          textOverlay: const TextOverlaySpec(
            text: 'Exclusive Clip',
            position: OverlayPosition.bottomRight,
            fontSize: 32,
          ),
          reverse: false,
        );

        final json = complexProject.toJson();
        final restored = EditProject.fromJson(json);

        expect(restored.id, complexProject.id);
        expect(restored.title, complexProject.title);
        expect(restored.transform.rotationDegrees, 90);
        expect(restored.transform.hflip, isTrue);
        expect(restored.canvas.aspectRatio, TargetAspectRatio.vertical916);
        expect(restored.canvas.fitMode, CanvasFitMode.fitWithBlur);
        expect(restored.speed.speed, 1.5);
        expect(restored.color.preset, ColorFilterPreset.vibrant);
        expect(restored.fade.fadeInSeconds, 1.0);
        expect(restored.watermark?.imagePath, '/logo.png');
        expect(restored.textOverlay?.text, 'Exclusive Clip');
      },
    );

    test('reverse invariant: allows reverse when clip duration <= 15s', () {
      final shortTrim = baseProject.copyWith(
        trim: const TrimConfig(startSeconds: 0.0, endSeconds: 14.5),
        reverse: true,
      );

      expect(shortTrim.isReverseAllowed, isTrue);
      expect(() => shortTrim.validate(), returnsNormally);
    });

    test(
        'reverse invariant: throws PlanValidationException when reverse requested on > 15s clip',
        () {
      final longTrim = baseProject.copyWith(
        trim: const TrimConfig(startSeconds: 0.0, endSeconds: 25.0),
        reverse: true,
      );

      expect(longTrim.isReverseAllowed, isFalse);
      expect(
        () => longTrim.validate(),
        throwsA(isA<PlanValidationException>()),
      );
    });

    test('throws PlanValidationException on trim duration < 0.5s', () {
      final tinyTrim = baseProject.copyWith(
        trim: const TrimConfig(startSeconds: 10.0, endSeconds: 10.2),
      );

      expect(
        () => tinyTrim.validate(),
        throwsA(isA<PlanValidationException>()),
      );
    });
  });
}
