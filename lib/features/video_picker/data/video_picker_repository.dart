import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/permission_utils.dart';
import '../../processing/domain/video_processor.dart';
import '../domain/models/picked_video.dart';

class VideoPickerRepository {
  final VideoProcessor videoProcessor;
  final ImagePicker _imagePicker;

  VideoPickerRepository({
    required this.videoProcessor,
    ImagePicker? imagePicker,
  }) : _imagePicker = imagePicker ?? ImagePicker();

  /// Picks a video from the system photo/media gallery.
  Future<PickedVideo?> pickVideoFromGallery() async {
    final hasPermission =
        await PermissionUtils.requestVideoReadPermissionIfNeeded(null);
    if (!hasPermission) {
      throw const PermissionDeniedException(
        'Permission to access videos was denied.',
        permissionName: 'Photos/Videos',
      );
    }

    try {
      final pickedFile = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return null;

      return await _createPickedVideo(pickedFile.path);
    } catch (e, st) {
      if (e is AppException) rethrow;
      AppLogger.error(
        'Failed to pick video from gallery',
        error: e,
        stackTrace: st,
      );
      throw UnsupportedVideoFormatException(
        'Could not load selected video file: $e',
      );
    }
  }

  /// Picks a video file using the system document/file picker.
  Future<PickedVideo?> pickVideoFromFileSystem() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final path = result.files.single.path;
      if (path == null) {
        throw const UnsupportedVideoFormatException(
          'Could not resolve selected file path.',
        );
      }

      return await _createPickedVideo(path);
    } catch (e, st) {
      if (e is AppException) rethrow;
      AppLogger.error(
        'Failed to pick video from file picker',
        error: e,
        stackTrace: st,
      );
      throw UnsupportedVideoFormatException(
        'Could not load selected video file: $e',
      );
    }
  }

  Future<PickedVideo> _createPickedVideo(String filePath) async {
    if (!filePath.startsWith('content://')) {
      final file = File(filePath);
      if (!await file.exists()) {
        throw StorageAccessException(
          'Selected video file not found on disk',
          path: filePath,
        );
      }
    }

    final metadata = await videoProcessor.getMetadata(filePath);
    final fileName = filePath.startsWith('content://')
        ? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4'
        : p.basename(filePath);
    final baseName = filePath.startsWith('content://')
        ? 'video_${DateTime.now().millisecondsSinceEpoch}'
        : p.basenameWithoutExtension(filePath);

    return PickedVideo(
      path: filePath,
      fileName: fileName,
      baseName: baseName,
      duration: metadata.duration,
      sizeInBytes: metadata.sizeInBytes,
      width: metadata.width,
      height: metadata.height,
      fps: metadata.fps,
    );
  }
}
