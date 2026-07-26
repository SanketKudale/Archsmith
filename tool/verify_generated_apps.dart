import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> arguments) async {
  final stateValue = _option(arguments, '--state') ?? 'riverpod';
  final networkValue = _option(arguments, '--network') ?? 'dio';
  final keep = arguments.contains('--keep');
  final state = StateManagementType.values.firstWhere(
    (value) => value.value == stateValue,
    orElse: () => throw FormatException('Unknown state manager: $stateValue'),
  );
  final network = NetworkType.values.firstWhere(
    (value) => value.value == networkValue,
    orElse: () => throw FormatException('Unknown network: $networkValue'),
  );
  final flutter = Platform.environment['ARCHSMITH_FLUTTER_BIN'] ?? 'flutter';
  final workspace = await Directory.systemTemp.createTemp(
    'archsmith_generated_${state.value}_${network.value}_',
  );
  final app = Directory(p.join(workspace.path, 'generated_app'));
  try {
    await _run(
      flutter,
      [
        'create',
        '--empty',
        '--project-name',
        'generated_app',
        app.path,
      ],
      workspace.path,
    );
    final config = ArchsmithConfig(
      projectName: 'generated_app',
      stateManagement: state,
      router: RouterType.navigator,
      network: network,
      generation: const GenerationConfig(generateTests: false),
    );
    const files = LocalFileSystemService();
    await files.apply(
      app.path,
      const GenerationEngine().architecture(config),
      const GenerationOptions(force: true),
    );
    final dependencies = const DependencyManifest().forConfig(config);
    if (dependencies.isNotEmpty) {
      await _run(
        flutter,
        ['pub', 'add', ...dependencies],
        app.path,
      );
    }
    final endpoint = const JsonApiEndpointReader().fromMap(
      {
        'url': '/accounts',
        'request': {'accountId': 'A-100'},
        'response': {
          'status': {'code': '000000', 'description': 'SUCCESS'},
          'items': [
            {'label': 'Primary account'},
          ],
        },
      },
      method: 'GET',
    );
    await files.apply(
      app.path,
      const CleanApiFeatureGenerator().generate(
        config: config,
        common: const ApiCommonConfig(
          baseUrl: 'https://api.example.com',
          cacheEnabled: true,
        ),
        endpoint: endpoint,
        feature: 'accounts',
      ),
      const GenerationOptions(force: true),
    );
    final actions = const StudioActionRegistry().readAll(app.path);
    final action = actions.single;
    const schema = UiScreenSchema(
      name: 'accounts',
      feature: 'accounts',
      route: '/accounts',
      routeArguments: [
        UiRouteArgument(name: 'accountId', type: 'String'),
      ],
      root: UiNode(
        id: 'page',
        type: 'appScaffold',
        properties: {'title': 'Accounts'},
        children: [
          UiNode(
            id: 'load',
            type: 'appButton',
            action: UiActionBinding(
              actionId: 'accounts.accounts',
              arguments: {'accountId': r'$route.accountId'},
            ),
          ),
          UiNode(
            id: 'offline',
            type: 'offlineBanner',
            action: UiActionBinding(
              actionId: 'accounts.accounts',
              method: 'watch',
            ),
          ),
          UiNode(
            id: 'items',
            type: 'stateList',
            properties: {
              'binding': 'data.items',
              'itemTextPath': 'label',
            },
            action: UiActionBinding(
              actionId: 'accounts.accounts',
              method: 'watch',
            ),
          ),
        ],
      ),
    );
    await files.apply(
      app.path,
      const UiCodeGenerator().generate(
        config: config,
        schema: schema,
        actions: [action],
      ),
      const GenerationOptions(force: true),
    );
    await files.apply(
      app.path,
      const RouteRegistryGenerator().register(
        root: app.path,
        config: config,
        pageName: schema.name,
        routePath: '/accounts',
        feature: 'accounts',
        routeArguments: schema.routeArguments,
      ),
      const GenerationOptions(force: true),
    );
    // Flutter releases ship different lint bundles. Compatibility verification
    // keeps analyzer errors and warnings fatal while allowing version-specific
    // informational style suggestions.
    await _run(flutter, ['analyze', '--no-fatal-infos'], app.path);
    stdout.writeln(
      'Generated app passed: ${state.value}/${network.value}',
    );
  } finally {
    if (keep) {
      stdout.writeln('Kept generated app at ${app.path}');
    } else if (workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  }
}

String? _option(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  return index < 0 || index + 1 >= arguments.length
      ? null
      : arguments[index + 1];
}

Future<void> _run(
  String executable,
  List<String> arguments,
  String workingDirectory,
) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'Command failed with exit code $exitCode.',
      exitCode,
    );
  }
}
