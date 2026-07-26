import 'dart:io';

import 'package:path/path.dart' as p;

import '../../api/api_code_generator.dart';
import '../../api/api_contract_reader.dart';
import 'base_command.dart';

class ApiCommand extends ArchsmithCommand {
  ApiCommand(super.context) {
    argParser.addOption(
      'contract',
      defaultsTo: 'archsmith_api.yaml',
      help: 'Path to the API contract relative to the project root.',
    );
    addSafetyOptions();
  }

  @override
  String get name => 'api';

  @override
  String get description =>
      'Generate typed networking code from archsmith_api.yaml.';

  @override
  String get invocation => 'archsmith api [--contract <path>]';

  @override
  Future<int> run() async {
    final root = Directory.current.path;
    final config = readConfig(root);
    final contractPath = p.normalize(
      p.join(root, argResults!['contract'] as String),
    );
    if (!p.isWithin(root, contractPath) && contractPath != root) {
      throw ArgumentError.value(
        argResults!['contract'],
        'contract',
        'Must stay within the project root',
      );
    }
    final contract = const ApiContractReader().read(contractPath);
    final files = const ApiCodeGenerator().generate(config, contract);
    final result = await context.files.apply(root, files, options);
    if (!options.dryRun &&
        !result.hasConflicts &&
        config.generation.formatAfterGeneration) {
      await runTool('fvm', [
        'dart',
        'format',
        'lib/core/network/generated',
      ], root);
    }
    return printResult(result);
  }
}
