import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shorts_splitter/features/output/data/writers/direct_directory_clip_writer.dart';
import 'package:shorts_splitter/features/output/domain/clip_writer.dart';
import 'package:shorts_splitter/features/output/domain/models/storage_strategy.dart';
import 'package:shorts_splitter/features/output/domain/safe_clip_replacer.dart';

class _FakeWriter implements ClipWriter {
  @override
  final StorageStrategyType strategyType;
  final Directory targetDir;
  final List<String> writtenFiles = [];

  _FakeWriter({required this.strategyType, required this.targetDir});

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> writeClip({
    required File sourceTempFile,
    required String fileName,
    required DuplicateHandling duplicateHandling,
  }) async {
    final dest = File('${targetDir.path}/$fileName');
    await sourceTempFile.copy(dest.path);
    writtenFiles.add(dest.path);
    return dest.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory testDir;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp('replacer_test_');
  });

  tearDown(() async {
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  test('DirectDirectoryClipWriter writes clip directly to target directory',
      () async {
    final writer = DirectDirectoryClipWriter(testDir);
    final src = File('${testDir.path}/src.mp4')
      ..writeAsStringSync('dummy content');

    final res = await writer.writeClip(
      sourceTempFile: src,
      fileName: 'clip_001.mp4',
      duplicateHandling: DuplicateHandling.overwrite,
    );

    expect(File(res).existsSync(), isTrue);
    expect(File(res).readAsStringSync(), 'dummy content');
  });

  test('SafeClipReplacer replace strategy atomically replaces old file',
      () async {
    final oldFile = File('${testDir.path}/part_001.mp4')
      ..writeAsStringSync('old clip');
    final newTemp = File('${testDir.path}/new_temp.mp4')
      ..writeAsStringSync('new 9:16 short');

    final writer = _FakeWriter(
      strategyType: StorageStrategyType.appSpecific,
      targetDir: testDir,
    );

    final result = await SafeClipReplacer.replace(
      newTempClipFile: newTemp,
      existingPathOrUri: oldFile.path,
      targetFileName: 'part_001.mp4',
      clipWriter: writer,
      replaceStrategy: ReplaceStrategy.replace,
    );

    expect(result.isSuccess, isTrue);
    expect(File(result.finalPathOrUri).existsSync(), isTrue);
    expect(File(result.finalPathOrUri).readAsStringSync(), 'new 9:16 short');
  });

  test(
      'SafeClipReplacer keepBoth strategy writes _short.mp4 and keeps original',
      () async {
    final oldFile = File('${testDir.path}/part_001.mp4')
      ..writeAsStringSync('old clip');
    final newTemp = File('${testDir.path}/new_temp.mp4')
      ..writeAsStringSync('new 9:16 short');

    final writer = _FakeWriter(
      strategyType: StorageStrategyType.appSpecific,
      targetDir: testDir,
    );

    final result = await SafeClipReplacer.replace(
      newTempClipFile: newTemp,
      existingPathOrUri: oldFile.path,
      targetFileName: 'part_001.mp4',
      clipWriter: writer,
      replaceStrategy: ReplaceStrategy.keepBoth,
    );

    expect(result.isSuccess, isTrue);
    expect(result.finalPathOrUri.endsWith('part_001_short.mp4'), isTrue);
    expect(oldFile.existsSync(), isTrue);
    expect(oldFile.readAsStringSync(), 'old clip');
    expect(File(result.finalPathOrUri).readAsStringSync(), 'new 9:16 short');
  });
}
