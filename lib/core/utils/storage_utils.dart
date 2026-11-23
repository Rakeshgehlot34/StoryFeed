import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logger/app_logger.dart';

/// Helper to handle scoped storage, folder fallback paths, and write testing.
class StorageUtils {
  StorageUtils._();

  static const String appFolderName = 'StoryFeed';

  /// Resolves the default persistent folder for saving clips.
  /// Uses app-specific external storage on Android (accessible across Android 10-15+ without broad permissions)
  /// and standard ApplicationDocumentsDirectory on iOS / desktop.
  static Future<Directory> getAppDefaultOutputDirectory() async {
    Directory baseDir;
    try {
      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        baseDir = extDir ?? await getApplicationDocumentsDirectory();
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      baseDir = await getApplicationDocumentsDirectory();
    }

    final targetDir = Directory(p.join(baseDir.path, appFolderName));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  /// Tests whether a given directory path is directly writable by the application.
  static Future<bool> testDirectoryWritable(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File(
        p.join(dir.path, '.probe_${DateTime.now().millisecondsSinceEpoch}.tmp'),
      );
      await testFile.writeAsString('probe', flush: true);
      if (await testFile.exists()) {
        await testFile.delete();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.warning(
        'Directory $directoryPath is not directly writable: $e',
      );
      return false;
    }
  }

  /// Removes any dangling temporary files from the target directory.
  static Future<void> cleanTempFiles(String directoryPath) async {
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) return;
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File &&
            (entity.path.endsWith('.tmp') || entity.path.contains('.probe_'))) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      AppLogger.warning('Error cleaning temp files in $directoryPath: $e');
    }
  }
}
