import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/logger/app_logger.dart';

/// Abstract service managing on-device microphone audio recording.
abstract class AudioRecordingService {
  Future<bool> requestPermission();
  Future<bool> startRecording(String destFilePath);
  Future<bool> stopRecording();
  Future<bool> isRecording();
}

/// Production implementation connecting to native Android MediaRecorder via MethodChannel.
class PlatformAudioRecordingService implements AudioRecordingService {
  static const MethodChannel _channel = MethodChannel(
    'com.shortssplitter.shorts_splitter/audio_recorder',
  );

  bool _simulatedRecording = false;

  @override
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> startRecording(String destFilePath) async {
    try {
      if (Platform.isAndroid) {
        final success = await _channel.invokeMethod<bool>('startRecording', {
          'path': destFilePath,
        });
        return success ?? false;
      }
      _simulatedRecording = true;
      return true;
    } on PlatformException catch (e) {
      AppLogger.warning('Audio recording failed: $e');
      return false;
    } catch (_) {
      _simulatedRecording = true;
      return true;
    }
  }

  @override
  Future<bool> stopRecording() async {
    try {
      if (Platform.isAndroid) {
        final success = await _channel.invokeMethod<bool>('stopRecording');
        return success ?? true;
      }
      _simulatedRecording = false;
      return true;
    } on PlatformException catch (e) {
      AppLogger.warning('Failed to stop audio recording: $e');
      return false;
    } catch (_) {
      _simulatedRecording = false;
      return true;
    }
  }

  @override
  Future<bool> isRecording() async {
    try {
      if (Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('isRecording');
        return res ?? false;
      }
      return _simulatedRecording;
    } catch (_) {
      return _simulatedRecording;
    }
  }
}
