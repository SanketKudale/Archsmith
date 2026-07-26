import 'dart:io';

import 'base_command.dart';

class GenerateCommand extends ArchsmithCommand {
  GenerateCommand(super.context, this.kind) {
    addSafetyOptions(featureOption: kind != 'feature' && kind != 'widget');
  }
  final String kind;
  @override
  String get name => kind;
  @override
  String get description => 'Generate a $kind using archsmith.yaml.';
  @override
  String get invocation => 'archsmith $kind <${kind}_name>';

  @override
  Future<int> run() async {
    if (argResults!.rest.isEmpty) {
      stderr.writeln('A $kind name is required.');
      return 64;
    }
    final config = readConfig();
    final result = await context.files.apply(
      Directory.current.path,
      context.generator.component(
        config,
        kind,
        argResults!.rest.first,
        feature:
            kind != 'feature' &&
                kind != 'widget' &&
                argResults!.wasParsed('feature')
            ? argResults!['feature'] as String
            : null,
        withTests: options.withTests,
      ),
      options,
    );
    if (!options.dryRun &&
        !result.hasConflicts &&
        config.generation.formatAfterGeneration) {
      await runTool('fvm', ['dart', 'format', '.'], Directory.current.path);
    }
    return printResult(result);
  }
}
