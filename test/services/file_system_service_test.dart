import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('archsmith_fs_'),
  );
  tearDown(() => directory.delete(recursive: true));

  test('dry run reports create without writing', () async {
    final result = await const LocalFileSystemService().apply(
      directory.path,
      const [PlannedFile('lib/new.dart', 'content')],
      const GenerationOptions(dryRun: true),
    );
    expect(result.count(GenerationAction.create), 1);
    expect(File(p.join(directory.path, 'lib/new.dart')).existsSync(), isFalse);
  });

  test('protects, skips, forces, and becomes idempotent', () async {
    final file = File(p.join(directory.path, 'value.txt'))
      ..writeAsStringSync('old');
    const service = LocalFileSystemService();
    final conflict = await service.apply(directory.path, const [
      PlannedFile('value.txt', 'new'),
    ], const GenerationOptions());
    expect(conflict.hasConflicts, isTrue);
    expect(file.readAsStringSync(), 'old');
    final skipped = await service.apply(directory.path, const [
      PlannedFile('value.txt', 'new'),
    ], const GenerationOptions(skipExisting: true));
    expect(skipped.count(GenerationAction.skip), 1);
    await service.apply(directory.path, const [
      PlannedFile('value.txt', 'new'),
    ], const GenerationOptions(force: true));
    final repeated = await service.apply(directory.path, const [
      PlannedFile('value.txt', 'new'),
    ], const GenerationOptions());
    expect(repeated.count(GenerationAction.skip), 1);
  });

  test('rejects paths outside root', () async {
    expect(
      () => const LocalFileSystemService().apply(directory.path, const [
        PlannedFile('../escape.txt', 'no'),
      ], const GenerationOptions()),
      throwsArgumentError,
    );
  });

  test('allows explicit generated-file updates without global force', () async {
    final file = File(p.join(directory.path, 'generated.txt'))
      ..writeAsStringSync('old');
    final result = await const LocalFileSystemService().apply(
      directory.path,
      const [
        PlannedFile('generated.txt', 'new', isUpdate: true),
      ],
      const GenerationOptions(),
    );
    expect(result.count(GenerationAction.update), 1);
    expect(file.readAsStringSync(), 'new');
  });
}
