import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../../core/logger/app_logger.dart';

const String _prefKeyResumeWhenReturning =
    'shorts_splitter_resume_playback_on_return';

/// Global PlayerService provider ensuring strictly ONE VideoPlayerController is active in memory.
final playerServiceProvider = ChangeNotifierProvider<PlayerService>((ref) {
  final service = PlayerService.instance;
  return service;
});

/// Centralized media playback coordinator enforcing single-controller invariants,
/// lifecycle hooks (AppLifecycleState & RouteAware), and audio/video surface synchronization.
class PlayerService extends ChangeNotifier {
  PlayerService._() {
    _initLifecycleObserver();
    _loadPreferences();
  }

  static PlayerService _instance = PlayerService._();

  static PlayerService get instance {
    if (_instance._isDisposed) {
      _instance = PlayerService._();
    }
    return _instance;
  }

  @visibleForTesting
  static void resetInstance() {
    _instance = PlayerService._();
  }

  bool _isDisposed = false;
  bool get isDisposed => _isDisposed;

  /// Live controller counter used to enforce single-controller invariant.
  static int _liveControllersCount = 0;
  static int get liveControllersCount => _liveControllersCount;

  VideoPlayerController? _controller;
  VideoPlayerController? get controller => _controller;

  String? _currentPath;
  String? get currentPath => _currentPath;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _wasPlayingBeforeAppPause = false;
  bool _resumeWhenReturning = false;
  bool get resumeWhenReturning => _resumeWhenReturning;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  double _playbackSpeed = 1.0;
  double get playbackSpeed => _playbackSpeed;

  int _initToken = 0;
  AppLifecycleListener? _lifecycleListener;

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _resumeWhenReturning =
          prefs.getBool(_prefKeyResumeWhenReturning) ?? false;
    } catch (_) {}
  }

  Future<void> setResumeWhenReturning(bool value) async {
    _resumeWhenReturning = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyResumeWhenReturning, value);
    } catch (_) {}
  }

  void _initLifecycleObserver() {
    _lifecycleListener = AppLifecycleListener(
      onPause: _handleAppPause,
      onInactive: _handleAppPause,
      onHide: _handleAppPause,
      onResume: _handleAppResume,
    );
  }

  void _handleAppPause() {
    if (_controller != null && _isPlaying) {
      _wasPlayingBeforeAppPause = true;
      pause();
    } else {
      _wasPlayingBeforeAppPause = false;
    }
  }

  void _handleAppResume() {
    if (_wasPlayingBeforeAppPause &&
        _resumeWhenReturning &&
        _controller != null) {
      play();
    }
    _wasPlayingBeforeAppPause = false;
  }

  /// Opens a new video path, strictly releasing and disposing any existing controller first.
  Future<VideoPlayerController?> openVideo({
    required String path,
    bool autoPlay = false,
    Duration? seekToPosition,
  }) async {
    final token = ++_initToken;

    // Dispose existing controller first to uphold invariant
    await stopAndRelease();

    _currentPath = path;
    _isInitialized = false;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();

    final VideoPlayerController newController;
    if (path.startsWith('content://')) {
      newController = VideoPlayerController.contentUri(Uri.parse(path));
    } else {
      final file = File(path);
      if (!file.existsSync()) {
        AppLogger.warning('Cannot open video: file does not exist at $path');
        return null;
      }
      newController = VideoPlayerController.file(file);
    }

    _liveControllersCount++;
    assert(
      _liveControllersCount <= 1,
      'Invariant violated: More than 1 live VideoPlayerController detected ($_liveControllersCount)',
    );
    AppLogger.debug(
      'Created VideoPlayerController. Live count: $_liveControllersCount',
    );

    try {
      await newController.initialize();

      // Check if another request superseded this initialization
      if (token != _initToken) {
        await _disposeRawController(newController);
        return null;
      }

      await newController.setPlaybackSpeed(_playbackSpeed);

      if (seekToPosition != null && seekToPosition > Duration.zero) {
        await newController.seekTo(seekToPosition);
      }

      _controller = newController;
      _isInitialized = true;
      _duration = newController.value.duration;
      _position = newController.value.position;

      newController.addListener(_onControllerUpdate);

      if (autoPlay) {
        await newController.play();
        _isPlaying = true;
      }

      notifyListeners();
      return newController;
    } catch (e, st) {
      AppLogger.error(
        'Failed to initialize video player for $path: $e',
        stackTrace: st,
      );
      await _disposeRawController(newController);
      _controller = null;
      _isInitialized = false;
      notifyListeners();
      return null;
    }
  }

  void _onControllerUpdate() {
    final c = _controller;
    if (c == null) return;

    final newIsPlaying = c.value.isPlaying;
    final newPosition = c.value.position;
    final newDuration = c.value.duration;

    if (newIsPlaying != _isPlaying ||
        newPosition != _position ||
        newDuration != _duration) {
      _isPlaying = newIsPlaying;
      _position = newPosition;
      _duration = newDuration;
      notifyListeners();
    }
  }

  Future<void> play() async {
    final c = _controller;
    if (c != null && _isInitialized && !c.value.isPlaying) {
      await c.play();
      _isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    final c = _controller;
    if (c != null && c.value.isPlaying) {
      await c.pause();
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration pos, {bool pauseAudioDuringSeek = false}) async {
    final c = _controller;
    if (c != null && _isInitialized) {
      if (pauseAudioDuringSeek && c.value.isPlaying) {
        await c.pause();
        _isPlaying = false;
      }
      await c.seekTo(pos);
      _position = pos;
      notifyListeners();
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    final c = _controller;
    if (c != null && _isInitialized) {
      await c.setPlaybackSpeed(speed);
      notifyListeners();
    }
  }

  /// Called when a route is covered or popped: immediately pauses playback.
  void onRouteCoveredOrPopped() {
    pause();
  }

  /// Stops playback, removes listeners, and disposes the current controller.
  Future<void> stopAndRelease() async {
    final c = _controller;
    _controller = null;
    _currentPath = null;
    _isInitialized = false;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;

    if (c != null) {
      await _disposeRawController(c);
    }
    notifyListeners();
  }

  Future<void> _disposeRawController(
    VideoPlayerController controllerToDispose,
  ) async {
    try {
      controllerToDispose.removeListener(_onControllerUpdate);
      if (controllerToDispose.value.isPlaying) {
        await controllerToDispose.pause();
      }
      await controllerToDispose.dispose();
    } catch (e) {
      AppLogger.warning('Error while disposing VideoPlayerController: $e');
    } finally {
      _liveControllersCount = (_liveControllersCount - 1).clamp(0, 99);
      AppLogger.debug(
        'Disposed VideoPlayerController. Live count: $_liveControllersCount',
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _lifecycleListener?.dispose();
    stopAndRelease();
    super.dispose();
  }
}
