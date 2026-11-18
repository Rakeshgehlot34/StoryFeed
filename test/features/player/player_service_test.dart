import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorts_splitter/features/player/data/player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlayerService.resetInstance();
  });

  tearDown(() {
    PlayerService.instance.stopAndRelease();
  });

  group('PlayerService invariant and lifecycle tests', () {
    test('Initializes with zero live controllers and idle state', () {
      final service = PlayerService.instance;
      expect(PlayerService.liveControllersCount, 0);
      expect(service.isPlaying, isFalse);
      expect(service.isInitialized, isFalse);
      expect(service.controller, isNull);
      expect(service.position, Duration.zero);
    });

    test('stopAndRelease safely resets all playback state', () async {
      final service = PlayerService.instance;
      await service.stopAndRelease();

      expect(PlayerService.liveControllersCount, 0);
      expect(service.controller, isNull);
      expect(service.currentPath, isNull);
      expect(service.isPlaying, isFalse);
    });

    test('Re-instantiates fresh instance cleanly after dispose', () {
      final initialService = PlayerService.instance;
      initialService.dispose();

      expect(initialService.isDisposed, isTrue);

      final freshService = PlayerService.instance;
      expect(freshService.isDisposed, isFalse);
      expect(PlayerService.liveControllersCount, 0);
    });
  });
}
