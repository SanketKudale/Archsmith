import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/generation.dart';

/// Applies generated files with overwrite and dry-run protection.
abstract interface class FileSystemService {
  bool fileExists(String path);
  String readFile(String path);
  Future<GenerationResult> apply(
    String root,
    Iterable<PlannedFile> files,
    GenerationOptions options,
  );
}

/// Local-disk implementation of [FileSystemService].
class LocalFileSystemService implements FileSystemService {
  const LocalFileSystemService();

  @override
  bool fileExists(String path) => File(path).existsSync();

  @override
  String readFile(String path) => File(path).readAsStringSync();

  @override
  Future<GenerationResult> apply(
    String root,
    Iterable<PlannedFile> files,
    GenerationOptions options,
  ) async {
    final rootPath = p.normalize(p.absolute(root));
    final entries = <GenerationEntry>[];
    for (final planned in files) {
      final target = p.normalize(p.join(rootPath, planned.path));
      if (!p.isWithin(rootPath, target)) {
        throw ArgumentError.value(planned.path, 'path', 'Escapes project root');
      }
      final file = File(target);
      final exists = file.existsSync();
      if (exists && file.readAsStringSync() == planned.content) {
        entries.add(GenerationEntry(planned.path, GenerationAction.skip));
        continue;
      }
      if (exists && !options.force) {
        entries.add(
          GenerationEntry(
            planned.path,
            options.skipExisting
                ? GenerationAction.skip
                : GenerationAction.conflict,
          ),
        );
        continue;
      }
      final action = exists || planned.isUpdate
          ? GenerationAction.update
          : GenerationAction.create;
      entries.add(GenerationEntry(planned.path, action));
      if (!options.dryRun) {
        await file.parent.create(recursive: true);
        await file.writeAsString(planned.content);
      }
    }
    return GenerationResult(List.unmodifiable(entries));
  }
}
