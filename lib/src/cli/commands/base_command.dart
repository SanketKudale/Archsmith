import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../configuration/archsmith_config.dart';
import '../../models/generation.dart';
import '../command_context.dart';

abstract class ArchsmithCommand extends Command<int> {
  ArchsmithCommand(this.context);
  final CommandContext context;

  void addSafetyOptions({bool featureOption = false}) {
    if (featureOption) {
      argParser.addOption('feature', help: 'Owning feature name.');
    }
    argParser
      ..addFlag('dry-run', negatable: false, help: 'Preview without writing.')
      ..addFlag('force', negatable: false, help: 'Overwrite conflicting files.')
      ..addFlag(
        'skip-existing',
        negatable: false,
        help: 'Skip conflicting files.',
      )
      ..addFlag('tests', defaultsTo: true, help: 'Generate tests.');
  }

  GenerationOptions get options => GenerationOptions(
    dryRun: argResults!['dry-run'] as bool,
    force: argResults!['force'] as bool,
    skipExisting: argResults!['skip-existing'] as bool,
    withTests: argResults!['tests'] as bool,
  );

  ArchsmithConfig readConfig([String? root]) => context.configReader.read(
    p.join(root ?? Directory.current.path, 'archsmith.yaml'),
  );

  int printResult(GenerationResult result) {
    for (final entry in result.entries) {
      stdout.writeln(entry);
    }
    stdout.writeln(
      '\n${result.count(GenerationAction.create)} created, '
      '${result.count(GenerationAction.update)} updated, '
      '${result.count(GenerationAction.skip)} skipped, '
      '${result.count(GenerationAction.conflict)} conflicts.',
    );
    return result.hasConflicts ? 2 : 0;
  }

  Future<bool> runTool(
    String executable,
    List<String> arguments,
    String root,
  ) async {
    final output = await context.processes.run(
      executable,
      arguments,
      workingDirectory: root,
    );
    if (output.stdout.trim().isNotEmpty) stdout.write(output.stdout);
    if (output.stderr.trim().isNotEmpty) stderr.write(output.stderr);
    return output.succeeded;
  }
}
