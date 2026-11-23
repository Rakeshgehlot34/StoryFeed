import 'dart:io';

import '../../../core/utils/storage_bridge.dart';
import 'models/storage_strategy.dart';

enum OutputFolderLayout {
  singleRoot,
  multiSubfolder,
}

class ResolvedFolderTarget {
  final OutputFolderLayout layout;
  final String folderName;
  final String destinationLocation; // URI for SAF or directory path
  final String? relativePath; // For MediaStore API 29+

  const ResolvedFolderTarget({
    required this.layout,
    required this.folderName,
    required this.destinationLocation,
    this.relativePath,
  });
}

class FolderLayoutResolver {
  static const int maxFolderNameLength = 64;

  /// Sanitizes folder name removing illegal characters, trailing dots/spaces,
  /// and capping length.
  static String sanitizeFolderName(String rawName) {
    var sanitized = rawName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Strip trailing dots or spaces
    while (sanitized.endsWith('.') || sanitized.endsWith(' ')) {
      sanitized = sanitized.substring(0, sanitized.length - 1).trim();
    }

    if (sanitized.isEmpty) {
      sanitized = 'StoryFeed_Video';
    }

    if (sanitized.length > maxFolderNameLength) {
      sanitized = sanitized.substring(0, maxFolderNameLength).trim();
    }

    return sanitized;
  }

  /// Resolves the layout decision based on total planned parts.
  /// Always organizes split clips into their dedicated subfolder:
  /// Movies/StoryFeed/[foldername]/[all_split video]
  static OutputFolderLayout decideLayout(int totalPartsCount) {
    return OutputFolderLayout.multiSubfolder;
  }

  /// Prepares or retrieves the target destination for a project.
  /// If [existingFolderUri] is provided and non-empty, reuses it.
  /// Otherwise, creates a collision-safe subfolder if multi-part.
  static Future<ResolvedFolderTarget> resolveTarget({
    required int totalPartsCount,
    required String baseName,
    required StorageStrategyType strategyType,
    required String rootSaveLocation,
    String? existingFolderUri,
    List<String> existingFolderNames = const [],
  }) async {
    final layout = decideLayout(totalPartsCount);

    if (layout == OutputFolderLayout.singleRoot) {
      return ResolvedFolderTarget(
        layout: layout,
        folderName: '',
        destinationLocation: rootSaveLocation,
        relativePath: 'Movies/StoryFeed',
      );
    }

    // Reuse existing folder URI if already assigned to this project
    if (existingFolderUri != null && existingFolderUri.isNotEmpty) {
      return ResolvedFolderTarget(
        layout: layout,
        folderName: sanitizeFolderName(baseName),
        destinationLocation: existingFolderUri,
        relativePath: 'Movies/StoryFeed/${sanitizeFolderName(baseName)}',
      );
    }

    // Generate collision-safe folder name
    final baseSanitized = sanitizeFolderName(baseName);
    var targetFolderName = baseSanitized;
    var suffix = 2;
    while (existingFolderNames.contains(targetFolderName)) {
      targetFolderName = '$baseSanitized ($suffix)';
      suffix++;
    }

    String destinationLocation;
    String? relativePath;

    switch (strategyType) {
      case StorageStrategyType.saf:
        destinationLocation = await StorageBridge.createSafDirectory(
          treeUri: rootSaveLocation,
          dirName: targetFolderName,
        );
        break;

      case StorageStrategyType.mediaStore:
        final base = rootSaveLocation.startsWith('/storage/emulated/0')
            ? rootSaveLocation
            : (Platform.isAndroid
                ? '/storage/emulated/0/Movies/StoryFeed'
                : rootSaveLocation);
        destinationLocation = '$base/$targetFolderName';
        relativePath = 'Movies/StoryFeed/$targetFolderName';
        break;

      case StorageStrategyType.directPublic:
      case StorageStrategyType.appSpecific:
        final base = (strategyType == StorageStrategyType.directPublic &&
                !rootSaveLocation.startsWith('/storage/emulated/0') &&
                Platform.isAndroid)
            ? '/storage/emulated/0/Movies/StoryFeed'
            : rootSaveLocation;
        final dir = Directory('$base/$targetFolderName');
        if (!await dir.exists()) {
          try {
            await dir.create(recursive: true);
          } catch (_) {}
        }
        destinationLocation = dir.path;
        break;
    }

    return ResolvedFolderTarget(
      layout: layout,
      folderName: targetFolderName,
      destinationLocation: destinationLocation,
      relativePath: relativePath,
    );
  }
}
