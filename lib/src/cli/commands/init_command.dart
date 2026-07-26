import 'dart:io';

import 'package:path/path.dart' as p;

import '../../configuration/archsmith_config.dart';
import 'base_command.dart';

class InitCommand extends ArchsmithCommand {
  InitCommand(super.context) {
    addSafetyOptions();
  }
  @override
  String get name => 'init';
  @override
  String get description =>
      'Initialize architecture in an existing Flutter project.';

  @override
  Future<int> run() async {
    final root = Directory.current.path;
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync() ||
        !pubspec.readAsStringSync().contains('flutter:')) {
      stderr.writeln('Current directory is not a Flutter project.');
      return 2;
    }
    final projectName = RegExp(
          r'^name:\s*([^\s]+)',
          multiLine: true,
        ).firstMatch(pubspec.readAsStringSync())?.group(1) ??
        p.basename(root);
    final config = ArchsmithConfig(projectName: projectName);
    final result = await context.files.apply(
      root,
      context.generator.architecture(config),
      options,
    );
    if (!options.dryRun && !result.hasConflicts) {
      final installed = await context.dependencies.install(config, root);
      if (installed != null && !installed.succeeded) return 1;
      await runTool('fvm', ['dart', 'format', '.'], root);
    }
    return printResult(result);
  }
}
