import 'dart:io';

import '../../generators/route_registry_generator.dart';
import '../../models/generation.dart';
import '../../models/options.dart';
import 'base_command.dart';

class GenerateCommand extends ArchsmithCommand {
  GenerateCommand(super.context, this.kind) {
    addSafetyOptions(featureOption: kind != 'feature' && kind != 'widget');
    if (kind == 'page') {
      argParser.addOption(
        'route',
        help: 'Register the page path and generate navigation helpers.',
      );
    }
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
    final rawName = argResults!.rest.first;
    final feature =
        kind != 'feature' &&
            kind != 'widget' &&
            argResults!.wasParsed('feature')
        ? argResults!['feature'] as String
        : null;
    final files = context.generator.component(
      config,
      kind,
      rawName,
      feature: feature,
      withTests: options.withTests,
    );
    if (kind == 'page' && argResults!.wasParsed('route')) {
      if (config.router == RouterType.autoRoute) {
        final pageIndex = files.indexWhere(
          (file) => file.path.endsWith('_page.dart'),
        );
        if (pageIndex >= 0) {
          final page = files[pageIndex];
          files[pageIndex] = PlannedFile(
            page.path,
            "import 'package:auto_route/auto_route.dart';\n"
            "${page.content.replaceFirst('class ', '@RoutePage()\nclass ')}",
          );
        }
      }
      files.addAll(
        const RouteRegistryGenerator().register(
          root: Directory.current.path,
          config: config,
          pageName: rawName,
          routePath: argResults!['route'] as String,
          feature: feature,
        ),
      );
    }
    final result = await context.files.apply(
      Directory.current.path,
      files,
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
