import 'dart:io';

import 'package:path/path.dart' as p;

import '../../generators/route_registry_generator.dart';
import '../../models/generation.dart';
import '../../models/options.dart';
import '../../studio/action_registry.dart';
import '../../studio/component_registry.dart';
import '../../studio/design_system.dart';
import '../../studio/ui_code_generator.dart';
import '../../studio/ui_schema.dart';
import '../../studio/ui_validator.dart';
import 'base_command.dart';

class UiCommand extends ArchsmithCommand {
  UiCommand(super.context) {
    addSafetyOptions();
  }

  @override
  String get name => 'ui';

  @override
  String get description =>
      'Validate or generate Flutter code from a Studio UI schema.';

  @override
  String get invocation => 'archsmith ui <validate|generate> <screen.json>';

  @override
  Future<int> run() async {
    final arguments = argResults!.rest;
    if (arguments.length < 2) {
      throw const FormatException(
        'UI command requires validate|generate and a schema path.',
      );
    }
    final operation = arguments[0];
    if (operation != 'validate' && operation != 'generate') {
      throw FormatException('Unsupported UI operation: $operation.');
    }
    final root = Directory.current.path;
    final path = p.normalize(
      p.isAbsolute(arguments[1]) ? arguments[1] : p.join(root, arguments[1]),
    );
    final schema = const UiSchemaStore().read(path);
    final actions = const StudioActionRegistry().readAll(root);
    final components = StudioComponentRegistry(
      custom: const StudioComponentManifestStore().readAll(root),
    );
    final designTokens = const StudioDesignTokenStore().read(root);
    final localization = const StudioLocalizationStore().read(root);
    final assets = const StudioAssetRegistry().readAll(root);
    final issues = UiSchemaValidator(components: components).validate(
      schema,
      actions: actions,
      designTokens: designTokens,
      localization: localization,
      assets: assets,
    );
    if (issues.isNotEmpty) {
      for (final issue in issues) {
        stderr.writeln(issue);
      }
      return 2;
    }
    if (operation == 'validate') {
      stdout.writeln('Valid UI schema: ${schema.name}');
      return 0;
    }

    final config = readConfig(root);
    final generated = <PlannedFile>[
      ...const UiCodeGenerator().generate(
        config: config,
        schema: schema,
        actions: actions,
        components: components,
        designTokens: designTokens,
        localization: localization,
        assets: assets,
      ),
      if (schema.route != null && config.router != RouterType.none)
        ...const RouteRegistryGenerator().register(
          root: root,
          config: config,
          pageName: schema.name,
          routePath: schema.route!,
          feature: schema.feature,
        ),
    ];
    final files = generated.where((file) {
      if (file.path.endsWith('.archsmith.dart')) return true;
      return !context.files.fileExists(p.join(root, file.path));
    });
    final result = await context.files.apply(root, files, options);
    if (!options.dryRun &&
        !result.hasConflicts &&
        config.generation.formatAfterGeneration) {
      await runTool(
        'fvm',
        ['dart', 'format', 'lib/features'],
        root,
      );
    }
    return printResult(result);
  }
}
