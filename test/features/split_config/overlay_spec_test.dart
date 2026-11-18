import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/split_config/domain/models/overlay_spec.dart';

void main() {
  group('OverlaySpec Message Resolution Hierarchy Tests', () {
    const baseName = 'epic_travel';

    test('1. Specific part override takes highest precedence', () {
      const spec = OverlaySpec(
        autoLabel: true,
        template: 'Part {n}/{total}',
        allPartsMessage: 'All Parts Intro: {name}',
      );

      final message = spec.resolveText(
        partIndex: 1,
        totalParts: 4,
        baseName: baseName,
        specificPartOverride: 'Finale - Part {n}',
      );

      expect(message, equals('Finale - Part 1'));
    });

    test(
      '2. All parts message takes precedence when no part override exists',
      () {
        const spec = OverlaySpec(
          autoLabel: true,
          template: 'Part {n}/{total}',
          allPartsMessage: 'Watch Till End! #{n} of {total}',
        );

        final message = spec.resolveText(
          partIndex: 2,
          totalParts: 5,
          baseName: baseName,
        );

        expect(message, equals('Watch Till End! #2 of 5'));
      },
    );

    test('3. Auto label template takes precedence when no overrides exist', () {
      const spec = OverlaySpec(
        autoLabel: true,
        template: 'Episode {n}/{total} - {name}',
      );

      final message = spec.resolveText(
        partIndex: 3,
        totalParts: 6,
        baseName: baseName,
      );

      expect(message, equals('Episode 3/6 - epic_travel'));
    });

    test('4. Returns null when auto label is disabled and no messages set', () {
      const spec = OverlaySpec(autoLabel: false, allPartsMessage: null);

      final message = spec.resolveText(
        partIndex: 1,
        totalParts: 3,
        baseName: baseName,
      );

      expect(message, isNull);
    });

    test(
      'Token replacement handles multiple occurrences of {n}, {total}, {name}',
      () {
        const spec = OverlaySpec(
          autoLabel: true,
          template: '[{name}] Part {n} of {total} ({n}/{total})',
        );

        final message = spec.resolveText(
          partIndex: 1,
          totalParts: 2,
          baseName: 'vlog',
        );

        expect(message, equals('[vlog] Part 1 of 2 (1/2)'));
      },
    );
  });
}
