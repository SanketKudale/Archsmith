import 'dart:io';

import 'package:path/path.dart' as p;

import '../../api/api_code_generator.dart';
import '../../api/api_common_config.dart';
import '../../api/api_contract_reader.dart';
import '../../api/clean_api_feature_generator.dart';
import '../../api/json_api_endpoint.dart';
import '../../models/generation.dart';
import '../../utils/naming_utils.dart';
import 'base_command.dart';

class ApiCommand extends ArchsmithCommand {
  ApiCommand(super.context) {
    argParser.addOption(
      'contract',
      defaultsTo: 'archsmith_api.yaml',
      help: 'Legacy YAML contract path.',
    );
    argParser
      ..addOption('feature', help: 'Owning feature for endpoint JSON.')
      ..addOption(
        'common',
        defaultsTo: 'archsmith_api_common.json',
        help: 'Shared API configuration path.',
      )
      ..addOption(
        'method',
        defaultsTo: 'POST',
        allowed: const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
      );
    addSafetyOptions();
  }

  @override
  String get name => 'api';

  @override
  String get description =>
      'Generate a Clean Architecture API feature from endpoint JSON.';

  @override
  String get invocation => 'archsmith api [endpoint.json]';

  @override
  Future<int> run() async {
    final root = Directory.current.path;
    final config = readConfig(root);
    final endpointPath = argResults!.rest.firstOrNull;
    late final List<PlannedFile> files;
    late final String formatTarget;
    if (endpointPath != null) {
      final resolvedEndpoint = p.normalize(
        p.isAbsolute(endpointPath) ? endpointPath : p.join(root, endpointPath),
      );
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
      final endpoint = const JsonApiEndpointReader().read(
        resolvedEndpoint,
        method: argResults!['method'] as String,
      );
      final common = const ApiCommonConfigStore().read(commonPath);
      final feature = argResults!['feature'] as String? ??
          names(p.basenameWithoutExtension(resolvedEndpoint)).snakeCase;
      files = const CleanApiFeatureGenerator().generate(
        config: config,
        common: common,
        endpoint: endpoint,
        feature: feature,
      );
      formatTarget = 'lib/features/${names(feature).snakeCase}';
    } else {
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
      files = const ApiCodeGenerator().generate(config, contract);
      formatTarget = 'lib/core/network/generated';
    }
    final result = await context.files.apply(root, files, options);
    if (!options.dryRun &&
        !result.hasConflicts &&
        config.generation.formatAfterGeneration) {
      await runTool(
          'fvm',
          [
            'dart',
            'format',
            'lib/core/network/generated',
            formatTarget,
          ],
          root);
    }
    return printResult(result);
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
