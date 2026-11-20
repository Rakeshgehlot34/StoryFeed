import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/split_config/domain/models/overlay_spec.dart';

void main() {
  group('OverlaySpec & PartLabelMode Unit Tests', () {
    const defaultSpec = OverlaySpec(
      partLabelMode: PartLabelMode.auto,
      template: 'Part {n}/{total}',
    );

    test('1. PartLabelMode.auto: suppresses auto label for 1-part plan', () {
      final text = defaultSpec.resolveText(
        partIndex: 1,
        totalParts: 1,
        baseName: 'MyShort',
      );
      expect(text, isNull);
    });

    test('2. PartLabelMode.auto: generates label for multi-part plan', () {
      final text = defaultSpec.resolveText(
        partIndex: 2,
        totalParts: 5,
        baseName: 'MyShort',
      );
      expect(text, equals('Part 2/5'));
    });

    test('3. PartLabelMode.always: generates label even for 1-part plan', () {
      const alwaysSpec = OverlaySpec(
        partLabelMode: PartLabelMode.always,
        template: 'Part {n}/{total}',
      );
      final text = alwaysSpec.resolveText(
        partIndex: 1,
        totalParts: 1,
        baseName: 'MyShort',
      );
      expect(text, equals('Part 1/1'));
    });

    test('4. PartLabelMode.never: never generates auto label', () {
      const neverSpec = OverlaySpec(
        partLabelMode: PartLabelMode.never,
        template: 'Part {n}/{total}',
      );
      expect(
        neverSpec.resolveText(partIndex: 1, totalParts: 1, baseName: 'MyShort'),
        isNull,
      );
      expect(
        neverSpec.resolveText(partIndex: 1, totalParts: 5, baseName: 'MyShort'),
        isNull,
      );
    });

    test('5. Precedence: specificPartOverride overrides everything', () {
      const spec = OverlaySpec(
        partLabelMode: PartLabelMode.never, // Even with never
        template: 'Part {n}/{total}',
      );
      final text = spec.resolveText(
        partIndex: 1,
        totalParts: 1,
        specificPartOverride: 'Custom intro for part 1',
        baseName: 'MyShort',
      );
      expect(text, equals('Custom intro for part 1'));
    });

    test('6. Precedence: all-parts custom message overrides auto label', () {
      const spec = OverlaySpec(
        partLabelMode: PartLabelMode.auto,
        template: 'Part {n}/{total}',
        allPartsMessage: 'Subscribe for Part {n}',
      );
      final text = spec.resolveText(
        partIndex: 3,
        totalParts: 4,
        baseName: 'MyShort',
      );
      expect(text, equals('Subscribe for Part 3'));
    });

    test(
      '7. PartLabelOverride.show forces label on single part under auto',
      () {
        final text = defaultSpec.resolveText(
          partIndex: 1,
          totalParts: 1,
          perPartOverride: PartLabelOverride.show,
          baseName: 'MyShort',
        );
        expect(text, equals('Part 1/1'));
      },
    );

    test('8. PartLabelOverride.hide suppresses label on multi-part plan', () {
      final text = defaultSpec.resolveText(
        partIndex: 2,
        totalParts: 5,
        perPartOverride: PartLabelOverride.hide,
        baseName: 'MyShort',
      );
      expect(text, isNull);
    });

    test('9. Token replacements: {n}, {total}, {name}', () {
      const spec = OverlaySpec(
        partLabelMode: PartLabelMode.always,
        template: '{name} - Clip {n} of {total}',
      );
      final text = spec.resolveText(
        partIndex: 2,
        totalParts: 3,
        baseName: 'Vlog2026',
      );
      expect(text, equals('Vlog2026 - Clip 2 of 3'));
    });

    test('10. Backward compatibility with autoLabel boolean parameter', () {
      const legacyTrue = OverlaySpec(autoLabel: true);
      expect(legacyTrue.partLabelMode, equals(PartLabelMode.auto));
      expect(legacyTrue.autoLabel, isTrue);

      const legacyFalse = OverlaySpec(autoLabel: false);
      expect(legacyFalse.partLabelMode, equals(PartLabelMode.never));
      expect(legacyFalse.autoLabel, isFalse);
    });
  });
}
