import 'dart:io';

import 'package:path/path.dart' as p;

import '../../api/api_batch_generator.dart';
import '../../api/api_common_config.dart';
import 'base_command.dart';

class ApiDirCommand extends ArchsmithCommand {
  ApiDirCommand(super.context) {
    argParser
      ..addOption(
        'common',
        defaultsTo: 'archsmith_api_common.json',
        help: 'Shared API configuration path.',
      )
      ..addOption(
        'method',
        defaultsTo: 'POST',
        allowed: const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
      )
      ..addFlag(
        'recursive',
        defaultsTo: true,
        help: 'Read JSON files in nested directories.',
      );
    addSafetyOptions();
  }

  @override
  String get name => 'api-dir';

  @override
  String get description =>
      'Generate API features for every endpoint JSON file in a directory.';

  @override
  String get invocation => 'archsmith api-dir <json-directory>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      stderr.writeln('A JSON directory is required.');
      return 64;
    }
    final root = Directory.current.path;
    final input = p.normalize(
      p.isAbsolute(argResults!.rest.first)
          ? argResults!.rest.first
          : p.join(root, argResults!.rest.first),
    );
    final directory = Directory(input);
    if (!directory.existsSync()) {
      throw FileSystemException('API JSON directory was not found', input);
    }
    final commonPath = p.normalize(
      p.join(root, argResults!['common'] as String),
    );
    if (!p.isWithin(root, commonPath)) {
      throw ArgumentError.value(
        commonPath,
        'common',
        'Must stay within the project root',
      );
    }
    final recursive = argResults!['recursive'] as bool;
    final endpointFiles = directory
        .listSync(recursive: recursive)
        .whereType<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList();
    final files = const ApiBatchGenerator().generate(
      config: readConfig(root),
      common: ApiCommonConfigStore().read(commonPath),
      endpointFiles: endpointFiles,
      method: argResults!['method'] as String,
    );
    final result = await context.files.apply(root, files, options);
    if (!options.dryRun &&
        !result.hasConflicts &&
        readConfig(root).generation.formatAfterGeneration) {
      await runTool('fvm', ['dart', 'format', 'lib'], root);
    }
    return printResult(result);
  }
}
