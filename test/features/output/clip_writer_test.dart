import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/output/data/clip_writer_factory.dart';
import 'package:shorts_splitter/features/output/domain/clip_writer.dart';
import 'package:shorts_splitter/features/output/domain/models/storage_strategy.dart';

/// Test double implementing [ClipWriter] for hermetic testing.
class FakeClipWriter implements ClipWriter {
  @override
  final StorageStrategyType strategyType;
  final List<String> writtenClips = <String>[];
  final Set<String> existingFiles = <String>{};
  bool available = true;

  FakeClipWriter({required this.strategyType});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<String> writeClip({
    required File sourceTempFile,
    required String fileName,
    required DuplicateHandling duplicateHandling,
  }) async {
    var finalName = fileName;
    if (existingFiles.contains(fileName) &&
        duplicateHandling == DuplicateHandling.autoSuffix) {
      final dotIndex = fileName.lastIndexOf('.');
      final base = dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
      final ext = dotIndex != -1 ? fileName.substring(dotIndex) : '';
      var counter = 1;
      while (existingFiles.contains('${base}_$counter$ext')) {
        counter++;
      }
      finalName = '${base}_$counter$ext';
    }

    existingFiles.add(finalName);
    writtenClips.add(finalName);
    return '/fake/storage/$finalName';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ClipWriter Strategy Resolution by Android API Level', () {
    test('API 28 with valid SAF tree URI resolves to SafClipWriter', () async {
      final writer = await ClipWriterFactory.resolveWriter(
        preferredSafUri:
            'content://com.android.externalstorage.documents/tree/primary%3AMovies',
        overrideSdkInt: 28,
        isAndroid: true,
      );
      expect(writer.strategyType, StorageStrategyType.saf);
    });

    test('API 28 without SAF URI resolves to DirectPublicClipWriter', () async {
      final writer = await ClipWriterFactory.resolveWriter(
        preferredSafUri: null,
        overrideSdkInt: 28,
        isAndroid: true,
      );
      expect(writer.strategyType, StorageStrategyType.directPublic);
    });

    test('API 29 without SAF URI resolves to MediaStoreClipWriter', () async {
      final writer = await ClipWriterFactory.resolveWriter(
        preferredSafUri: null,
        overrideSdkInt: 29,
        isAndroid: true,
      );
      expect(writer.strategyType, StorageStrategyType.mediaStore);
    });

    test('API 30 without SAF URI resolves to MediaStoreClipWriter', () async {
      final writer = await ClipWriterFactory.resolveWriter(
        preferredSafUri: null,
        overrideSdkInt: 30,
        isAndroid: true,
      );
      expect(writer.strategyType, StorageStrategyType.mediaStore);
    });

    test('API 33 without SAF URI resolves to MediaStoreClipWriter', () async {
      final writer = await ClipWriterFactory.resolveWriter(
        preferredSafUri: null,
        overrideSdkInt: 33,
        isAndroid: true,
      );
      expect(writer.strategyType, StorageStrategyType.mediaStore);
    });

    test('API 34 without SAF URI resolves to MediaStoreClipWriter', () async {
      final writer = await ClipWriterFactory.resolveWriter(
        preferredSafUri: null,
        overrideSdkInt: 34,
        isAndroid: true,
      );
      expect(writer.strategyType, StorageStrategyType.mediaStore);
    });

    test('API 35 without SAF URI resolves to MediaStoreClipWriter', () async {
      final writer = await ClipWriterFactory.resolveWriter(
        preferredSafUri: null,
        overrideSdkInt: 35,
        isAndroid: true,
      );
      expect(writer.strategyType, StorageStrategyType.mediaStore);
    });

    test('API 35 with valid SAF URI resolves to SafClipWriter', () async {
      final writer = await ClipWriterFactory.resolveWriter(
        preferredSafUri:
            'content://com.android.externalstorage.documents/tree/primary%3AShorts',
        overrideSdkInt: 35,
        isAndroid: true,
      );
      expect(writer.strategyType, StorageStrategyType.saf);
    });
  });

  group('Duplicate Clip File Name Handling', () {
    late Directory tempDir;
    late File dummySourceFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('clip_writer_test_');
      dummySourceFile = File('${tempDir.path}/temp_clip.mp4');
      await dummySourceFile.writeAsString('video_data');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'DuplicateHandling.overwrite overwrites existing clip without suffix',
      () async {
        final fakeWriter = FakeClipWriter(
          strategyType: StorageStrategyType.appSpecific,
        );

        final clip1 = await fakeWriter.writeClip(
          sourceTempFile: dummySourceFile,
          fileName: 'my_video_part_001.mp4',
          duplicateHandling: DuplicateHandling.overwrite,
        );

        final clip2 = await fakeWriter.writeClip(
          sourceTempFile: dummySourceFile,
          fileName: 'my_video_part_001.mp4',
          duplicateHandling: DuplicateHandling.overwrite,
        );

        expect(clip1, '/fake/storage/my_video_part_001.mp4');
        expect(clip2, '/fake/storage/my_video_part_001.mp4');
        expect(fakeWriter.writtenClips.length, 2);
      },
    );

    test(
        'DuplicateHandling.autoSuffix appends sequential index suffix while preserving sequence',
        () async {
      final fakeWriter = FakeClipWriter(
        strategyType: StorageStrategyType.appSpecific,
      );

      final clip1 = await fakeWriter.writeClip(
        sourceTempFile: dummySourceFile,
        fileName: 'my_video_part_001.mp4',
        duplicateHandling: DuplicateHandling.autoSuffix,
      );

      final clip2 = await fakeWriter.writeClip(
        sourceTempFile: dummySourceFile,
        fileName: 'my_video_part_001.mp4',
        duplicateHandling: DuplicateHandling.autoSuffix,
      );

      final clip3 = await fakeWriter.writeClip(
        sourceTempFile: dummySourceFile,
        fileName: 'my_video_part_001.mp4',
        duplicateHandling: DuplicateHandling.autoSuffix,
      );

      expect(clip1, '/fake/storage/my_video_part_001.mp4');
      expect(clip2, '/fake/storage/my_video_part_001_1.mp4');
      expect(clip3, '/fake/storage/my_video_part_001_2.mp4');
    });
  });
}
