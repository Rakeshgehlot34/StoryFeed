import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/processing/domain/audio_graph_builder.dart';

void main() {
  group('AudioGraphBuilder Tests', () {
    test('1. atempo chain is empty for 1.0x neutral speed', () {
      final chain = AudioGraphBuilder.buildAtempoChain(1.0);
      expect(chain, isEmpty);
    });

    test(
      '2. atempo chain produces single filter for values within [0.5, 2.0]',
      () {
        final fast = AudioGraphBuilder.buildAtempoChain(1.5);
        expect(fast, equals(['atempo=1.5']));

        final slow = AudioGraphBuilder.buildAtempoChain(0.75);
        expect(slow, equals(['atempo=0.75']));
      },
    );

    test(
      '3. atempo chain cascades multiple filters for high speed (> 2.0x)',
      () {
        final speed4x = AudioGraphBuilder.buildAtempoChain(4.0);
        expect(speed4x, equals(['atempo=2.0', 'atempo=2.0']));

        final speed3x = AudioGraphBuilder.buildAtempoChain(3.0);
        expect(speed3x, equals(['atempo=2.0', 'atempo=1.5']));
      },
    );

    test(
      '4. atempo chain cascades multiple filters for low speed (< 0.5x)',
      () {
        final speedQuarter = AudioGraphBuilder.buildAtempoChain(0.25);
        expect(speedQuarter, equals(['atempo=0.5', 'atempo=0.5']));
      },
    );

    test('5. throws ArgumentError for zero or negative speed', () {
      expect(
        () => AudioGraphBuilder.buildAtempoChain(0.0),
        throwsArgumentError,
      );
      expect(
        () => AudioGraphBuilder.buildAtempoChain(-1.0),
        throwsArgumentError,
      );
    });

    test('6. buildAudioFilters handles volume, fades, speed, and reverse', () {
      final filter = AudioGraphBuilder.buildAudioFilters(
        volume: 1.5,
        speed: 2.0,
        fadeInSeconds: 1.0,
        fadeOutSeconds: 2.0,
        totalDurationSeconds: 10.0,
        reverse: true,
      );

      expect(filter, isNotNull);
      expect(filter, contains('areverse'));
      expect(filter, contains('atempo=2.0'));
      expect(filter, contains('volume=1.50'));
      expect(filter, contains('afade=t=in:st=0:d=1.000'));
      expect(filter, contains('afade=t=out:st=8.000:d=2.000'));
    });

    test('7. buildAudioFilters returns null when no filters applied', () {
      final filter = AudioGraphBuilder.buildAudioFilters();
      expect(filter, isNull);
    });

    test(
        '8. buildAudioMixFilterComplex creates two-channel volume and amix filter',
        () {
      final complex = AudioGraphBuilder.buildAudioMixFilterComplex(
        track1Tag: '0:a',
        track2Tag: '1:a',
        track1Volume: 1.0,
        track2Volume: 0.35,
        outputTag: 'aout',
      );

      expect(complex, contains('[0:a]volume=1.00[a_mix1]'));
      expect(complex, contains('[1:a]volume=0.35[a_mix2]'));
      expect(
        complex,
        contains(
          '[a_mix1][a_mix2]amix=inputs=2:duration=first:dropout_transition=2[aout]',
        ),
      );
    });
  });
}
