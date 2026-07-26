import '../configuration/archsmith_config.dart';
import '../configuration/config_writer.dart';
import '../models/generation.dart';
import '../models/options.dart';
import '../utils/naming_utils.dart';

/// Plans architecture and component files without performing direct I/O.
class GenerationEngine {
  const GenerationEngine({this.configWriter = const ConfigWriter()});
  final ConfigWriter configWriter;

  List<PlannedFile> architecture(ArchsmithConfig config) {
    final files = <PlannedFile>[
      configWriter.plan(config),
      PlannedFile('lib/main.dart', _main(config)),
      PlannedFile('lib/app/app.dart', _app(config)),
      const PlannedFile('lib/app/bootstrap.dart', _bootstrap),
      const PlannedFile(
        'lib/app/dependency_injection.dart',
        "/// Registers application dependencies.\nFuture<void> configureDependencies() async {}\n",
      ),
      const PlannedFile('lib/core/error/app_exception.dart', _exception),
      const PlannedFile('lib/core/logging/app_logger.dart', _logger),
      const PlannedFile(
        'lib/shared/widgets/app_component_defaults.dart',
        _componentDefaults,
      ),
      const PlannedFile('lib/shared/widgets/app_scaffold.dart', _appScaffold),
      const PlannedFile('lib/shared/widgets/app_button.dart', _appButton),
      const PlannedFile(
        'lib/shared/widgets/app_text_field.dart',
        _appTextField,
      ),
      const PlannedFile(
        'lib/shared/widgets/app_loading_indicator.dart',
        _appLoadingIndicator,
      ),
      const PlannedFile(
        'lib/shared/widgets/common_widgets.dart',
        _commonWidgets,
      ),
      if (config.generation.generateTests)
        const PlannedFile('test/widget_test.dart', _widgetTest),
    ];
    files.addAll(_architectureFolders(config.architecture));
    if (config.modules.theme) {
      files.add(const PlannedFile('lib/core/theme/app_theme.dart', _theme));
    }
    if (config.modules.localization) {
      files.add(const PlannedFile('lib/core/i18n/app_strings.dart', _strings));
    }
    if (config.network != NetworkType.none) {
      files.add(
        const PlannedFile(
          'archsmith_api_common.json',
          _apiCommonConfigTemplate,
        ),
      );
      files.add(
        PlannedFile('lib/core/network/network_client.dart', _network(config)),
      );
    }
    if (config.router != RouterType.none) {
      files.add(
        PlannedFile('lib/core/router/app_router.dart', _router(config)),
      );
      files.add(
        PlannedFile(
          'lib/core/router/generated_routes.dart',
          _emptyGeneratedRoutes(config.router),
        ),
      );
    }
    if (config.modules.secureStorage) {
      files.add(
        const PlannedFile('lib/core/security/secure_store.dart', _secureStore),
      );
    }
    if (config.modules.runtimeProtection) files.addAll(_runtime(config));
    return files;
  }

  List<PlannedFile> component(
    ArchsmithConfig config,
    String kind,
    String rawName, {
    String? feature,
    bool withTests = true,
  }) {
    final name = names(rawName);
    final featureName = names(feature ?? _featureFor(rawName));
    final paths = _componentPaths(config.architecture, featureName.snakeCase);
    final folder = kind == 'widget'
        ? 'lib/shared/widgets'
        : paths[kind] ?? paths['service']!;
    final classSuffix = {
      'feature': 'Feature',
      'page': 'Page',
      'model': 'Model',
      'repository': 'Repository',
      'service': 'Service',
      'usecase': 'UseCase',
      'controller': 'Controller',
      'widget': 'Widget',
    }[kind]!;
    final files = <PlannedFile>[];
    if (kind == 'feature') {
      for (final directory in paths.values.toSet()) {
        files.add(PlannedFile('$directory/.gitkeep', ''));
      }
      final pagePath = '${paths['page']}/${featureName.snakeCase}_page.dart';
      files.add(
        PlannedFile(pagePath, _pageClass(config.projectName, featureName)),
      );
      if (withTests) {
        files.add(
          PlannedFile(
            'test/${featureName.snakeCase}/${featureName.snakeCase}_feature_test.dart',
            _componentTest(config.projectName, pagePath, featureName, 'Page'),
          ),
        );
      }
    } else {
      final filePath =
          '$folder/${name.snakeCase}_${kind == 'usecase' ? 'use_case' : kind}.dart';
      files.add(
        PlannedFile(
          filePath,
          kind == 'page'
              ? _pageClass(config.projectName, name)
              : kind == 'widget'
              ? _widgetClass(name)
              : _plainClass(name, classSuffix, kind),
        ),
      );
      if (withTests) {
        files.add(
          PlannedFile(
            'test/${featureName.snakeCase}/${name.snakeCase}_${kind}_test.dart',
            _componentTest(config.projectName, filePath, name, classSuffix),
          ),
        );
      }
    }
    return files;
  }

  String _featureFor(String name) => names(name).snakeCase;

  Map<String, String> _componentPaths(
    ArchitectureType architecture,
    String feature,
  ) {
    return switch (architecture) {
      ArchitectureType.cleanFeature => {
        'page': 'lib/features/$feature/presentation/pages',
        'controller': 'lib/features/$feature/presentation/controllers',
        'model': 'lib/features/$feature/data/models',
        'repository': 'lib/features/$feature/domain/repositories',
        'service': 'lib/features/$feature/data/datasources',
        'usecase': 'lib/features/$feature/domain/usecases',
      },
      ArchitectureType.mvvm => {
        'page': 'lib/features/$feature/views',
        'controller': 'lib/features/$feature/view_models',
        'model': 'lib/features/$feature/models',
        'repository': 'lib/features/$feature/repositories',
        'service': 'lib/features/$feature/services',
        'usecase': 'lib/features/$feature/services',
      },
      ArchitectureType.cleanLayer => {
        'page': 'lib/presentation/pages',
        'controller': 'lib/presentation/controllers',
        'model': 'lib/data/models',
        'repository': 'lib/domain/repositories',
        'service': 'lib/data/datasources',
        'usecase': 'lib/domain/usecases',
      },
      ArchitectureType.simpleFeature => {
        'page': 'lib/features/$feature/pages',
        'controller': 'lib/features/$feature/controllers',
        'model': 'lib/features/$feature/models',
        'repository': 'lib/features/$feature/services',
        'service': 'lib/features/$feature/services',
        'usecase': 'lib/features/$feature/services',
      },
    };
  }

  List<PlannedFile> _architectureFolders(ArchitectureType architecture) {
    final folders = switch (architecture) {
      ArchitectureType.cleanFeature => ['lib/features/.gitkeep'],
      ArchitectureType.cleanLayer => [
        'lib/data/.gitkeep',
        'lib/domain/.gitkeep',
        'lib/presentation/.gitkeep',
      ],
      ArchitectureType.mvvm ||
      ArchitectureType.simpleFeature => ['lib/features/.gitkeep'],
    };
    return folders.map((path) => PlannedFile(path, '')).toList();
  }

  String _main(ArchsmithConfig config) {
    final riverpod = config.stateManagement == StateManagementType.riverpod;
    return "import 'package:flutter/material.dart';\n"
        "${riverpod ? "import 'package:flutter_riverpod/flutter_riverpod.dart';\n" : ''}"
        "import 'app/app.dart';\nimport 'app/bootstrap.dart';\n\n"
        "Future<void> main() async {\n  WidgetsFlutterBinding.ensureInitialized();\n"
        "  await bootstrap();\n  runApp(${riverpod ? 'const ProviderScope(child: App())' : 'const App()'});\n}\n";
  }

  String _app(ArchsmithConfig config) {
    final gateImport = config.modules.runtimeProtection
        ? "import '../core/runtime_protection/runtime_protection_gate.dart';\n"
        : '';
    final builder = config.modules.runtimeProtection
        ? "\n    builder: (context, child) => RuntimeProtectionGate(child: child ?? const SizedBox.shrink()),"
        : '';
    if (config.router == RouterType.goRouter ||
        config.router == RouterType.autoRoute) {
      final routerConfig = config.router == RouterType.goRouter
          ? 'appRouter'
          : 'appRouter.config()';
      return "import 'package:flutter/material.dart';\nimport '../core/router/app_router.dart';\n"
          "${config.modules.theme ? "import '../core/theme/app_theme.dart';\n" : ''}$gateImport\n"
          "class App extends StatelessWidget {\n  const App({super.key});\n\n"
          "  @override\n  Widget build(BuildContext context) => MaterialApp.router(\n"
          "    title: '${names(config.projectName).titleCase}',\n"
          "    routerConfig: $routerConfig,${config.modules.theme ? '\n    theme: AppTheme.light,' : ''}$builder\n  );\n}\n";
    }
    final routeImport = config.router == RouterType.navigator
        ? "import '../core/router/generated_routes.dart';\n"
        : '';
    return "import 'package:flutter/material.dart';\n"
        "${config.modules.theme ? "import '../core/theme/app_theme.dart';\n" : ''}$routeImport$gateImport\n"
        "import '../shared/widgets/app_scaffold.dart';\n"
        "class App extends StatelessWidget {\n  const App({super.key});\n\n"
        "  @override\n  Widget build(BuildContext context) => MaterialApp(\n"
        "    title: '${names(config.projectName).titleCase}',${config.modules.theme ? '\n    theme: AppTheme.light,' : ''}\n"
        "    home: const AppScaffold(body: Center(child: Text('Welcome'))),"
        "${config.router == RouterType.navigator ? '\n    routes: generatedRoutes,' : ''}$builder\n  );\n}\n";
  }

  String _network(ArchsmithConfig config) => switch (config.network) {
    NetworkType.dio =>
      "import 'package:dio/dio.dart';\n\nclass NetworkClient {\n  NetworkClient({Dio? dio}) : dio = dio ?? Dio();\n  final Dio dio;\n}\n",
    NetworkType.http =>
      "import 'package:http/http.dart' as http;\n\nclass NetworkClient {\n  NetworkClient({http.Client? client}) : client = client ?? http.Client();\n  final http.Client client;\n}\n",
    NetworkType.none => '',
  };

  String _router(ArchsmithConfig config) => switch (config.router) {
    RouterType.goRouter =>
      "import 'package:flutter/material.dart';\nimport 'package:go_router/go_router.dart';\nimport '../../shared/widgets/app_scaffold.dart';\nimport 'generated_routes.dart';\n\nfinal appRouter = GoRouter(routes: [\n  ...generatedRoutes,\n  GoRoute(path: '/', builder: (context, state) => const AppScaffold(body: Center(child: Text('Home')))),\n]);\n",
    RouterType.autoRoute =>
      "import 'package:auto_route/auto_route.dart';\n"
      "import 'generated_routes.dart';\n"
      "// archsmith:route-imports:start\n"
      "// archsmith:route-imports:end\n\n"
      "part 'app_router.gr.dart';\n\n"
      "@AutoRouterConfig()\n"
      "class AppRouter extends RootStackRouter {\n"
      "  @override\n"
      "  List<AutoRoute> get routes => [\n"
      "    // archsmith:routes:start\n"
      "    // archsmith:routes:end\n"
      "  ];\n"
      "}\n\n"
      "final appRouter = AppRouter();\n",
    RouterType.navigator =>
      "abstract final class AppRoutes {\n  static const home = '/';\n}\n",
    RouterType.none => '',
  };

  String _emptyGeneratedRoutes(RouterType router) => switch (router) {
    RouterType.goRouter =>
      "import 'package:go_router/go_router.dart';\n\nabstract final class AppRoutes {}\nfinal generatedRoutes = <RouteBase>[];\n",
    RouterType.autoRoute =>
      "import 'package:flutter/material.dart';\n\nabstract final class AppRoutes {}\nextension GeneratedNavigation on BuildContext {}\n",
    RouterType.navigator =>
      "import 'package:flutter/material.dart';\n\nabstract final class AppRoutes {}\nfinal generatedRoutes = <String, WidgetBuilder>{};\nextension GeneratedNavigation on BuildContext {}\n",
    RouterType.none => '',
  };

  List<PlannedFile> _runtime(ArchsmithConfig config) {
    final checks = [
      'internet',
      'vpn',
      'proxy',
      'mock_location',
      'screen_capture',
      'screen_recording',
      'screen_sharing',
      'screen_mirroring',
      'external_display',
      'usb_debugging',
      'developer_mode',
      'root',
      'jailbreak',
      'emulator',
      'app_integrity',
    ];
    return [
      const PlannedFile(
        'lib/core/runtime_protection/runtime_protection.dart',
        _runtimeBarrel,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/runtime_protection_result.dart',
        _runtimeModels,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/runtime_protection_service.dart',
        _runtimeService,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/runtime_protection_adapter.dart',
        _runtimeAdapter,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/runtime_protection_config.dart',
        _runtimeConfig,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/runtime_protection_policy.dart',
        _runtimePolicy,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/security_decision.dart',
        _decision,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/runtime_protection_controller.dart',
        _runtimeController,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/runtime_protection_gate.dart',
        _runtimeGate,
      ),
      ...checks.map(
        (check) => PlannedFile(
          'lib/core/runtime_protection/checks/${check}_check.dart',
          "/// Platform adapter-backed ${check.replaceAll('_', ' ')} check marker.\nabstract interface class ${names(check).pascalCase}Check {}\n",
        ),
      ),
      ...RuntimeProtectionProfile.values.map(
        (profile) => PlannedFile(
          'lib/core/runtime_protection/policies/${profile.value}_security_policy.dart',
          _profilePolicy(profile),
        ),
      ),
      PlannedFile(
        'lib/core/runtime_protection/integration/runtime_protection_integration.dart',
        _stateIntegration(config.stateManagement),
      ),
      const PlannedFile(
        'lib/core/runtime_protection/presentation/security_blocking_page.dart',
        _blockingPage,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/presentation/security_blocking_dialog.dart',
        _blockingDialog,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/presentation/security_warning_sheet.dart',
        _warningSheet,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/presentation/secure_content_overlay.dart',
        _secureOverlay,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/presentation/sensitive_content.dart',
        _sensitiveContent,
      ),
      const PlannedFile(
        'lib/core/runtime_protection/exceptions/runtime_protection_exception.dart',
        _runtimeException,
      ),
      PlannedFile('docs/runtime_protection_setup.md', _runtimeDocs(config)),
    ];
  }

  String _pageClass(String projectName, NameVariants name) =>
      "import 'package:flutter/material.dart';\n"
      "import 'package:$projectName/shared/widgets/app_scaffold.dart';\n\n"
      "class ${name.pascalCase}Page extends StatelessWidget {\n"
      "  const ${name.pascalCase}Page({super.key});\n"
      "  @override\n"
      "  Widget build(BuildContext context) => const AppScaffold(\n"
      "    title: '${name.titleCase}',\n"
      "    body: SizedBox.shrink(),\n"
      "  );\n"
      "}\n";

  String _widgetClass(NameVariants name) =>
      "import 'package:flutter/widgets.dart';\n\n"
      "/// Reusable application widget. Customize it here and use it anywhere.\n"
      "class ${name.pascalCase}Widget extends StatelessWidget {\n"
      "  const ${name.pascalCase}Widget({super.key});\n\n"
      "  @override\n"
      "  Widget build(BuildContext context) => const SizedBox.shrink();\n"
      "}\n";

  String _plainClass(NameVariants name, String suffix, String kind) =>
      "/// Generated $kind.\nclass ${name.pascalCase}$suffix {\n  const ${name.pascalCase}$suffix();\n}\n";

  String _componentTest(
    String projectName,
    String sourcePath,
    NameVariants name,
    String suffix,
  ) {
    final importPath = sourcePath.startsWith('lib/')
        ? sourcePath.substring(4)
        : sourcePath;
    return "import 'package:$projectName/$importPath';\nimport 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('${name.titleCase} $suffix can be constructed', () {\n    expect(const ${name.pascalCase}$suffix(), isA<${name.pascalCase}$suffix>());\n  });\n}\n";
  }

  String _runtimeDocs(ArchsmithConfig config) =>
      '# Runtime protection setup\n\nProfile: `${config.runtimeProtectionProfile!.value}`.\n\nInject a platform adapter such as `runtime_guard`; no native implementation is bundled. Android and iOS entitlements/configuration depend on that adapter. Detection is heuristic, platform support varies, VPN use is not inherently malicious, and compromised clients can bypass local checks. Combine sensitive decisions with server-side attestation.\n';

  String _profilePolicy(RuntimeProtectionProfile profile) {
    final cases = switch (profile) {
      RuntimeProtectionProfile.standard => {
        'noInternet': 'blockScreen',
        'backendUnavailable': 'blockScreen',
        'screenCapture': 'warn',
        'screenRecording': 'blurContent',
      },
      RuntimeProtectionProfile.financial => {
        'noInternet': 'blockScreen',
        'vpn': 'restrict',
        'proxy': 'warn',
        'mockLocation': 'terminateSession',
        'rootedDevice': 'blockScreen',
        'jailbrokenDevice': 'blockScreen',
        'appIntegrityFailure': 'terminateSession',
        'screenRecording': 'blockScreen',
      },
      RuntimeProtectionProfile.examination => {
        'screenRecording': 'blockScreen',
        'screenSharing': 'blockScreen',
        'screenMirroring': 'blockScreen',
        'externalDisplay': 'warn',
        'emulator': 'blockScreen',
      },
      RuntimeProtectionProfile.custom => <String, String>{},
    };
    final switchCases = cases.entries
        .map(
          (entry) =>
              '        SecurityThreatType.${entry.key} => SecurityAction.${entry.value},',
        )
        .join('\n');
    return "import '../runtime_protection_policy.dart';\nimport '../security_decision.dart';\nimport '../runtime_protection_result.dart';\n\nclass ${profile.label}SecurityPolicy implements RuntimeProtectionPolicy {\n  const ${profile.label}SecurityPolicy();\n  @override\n  SecurityDecision evaluate(List<SecurityCheckResult> results) {\n    for (final result in results.where((result) => result.detected)) {\n      final action = switch (result.type) {\n$switchCases\n        _ => SecurityAction.allow,\n      };\n      if (action != SecurityAction.allow) {\n        return SecurityDecision(action, reason: result.type.name);\n      }\n    }\n    return const SecurityDecision(SecurityAction.allow);\n  }\n}\n";
  }

  String _stateIntegration(StateManagementType state) => switch (state) {
    StateManagementType.riverpod =>
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../runtime_protection_controller.dart';\nimport '../runtime_protection_service.dart';\nimport '../security_decision.dart';\nfinal runtimeProtectionServiceProvider = Provider<RuntimeProtectionService>((ref) => throw UnimplementedError('Inject a RuntimeProtectionService'));\nfinal runtimeProtectionControllerProvider = Provider<RuntimeProtectionController>((ref) => throw UnimplementedError('Inject a RuntimeProtectionPolicy'));\nfinal threatEventProvider = StreamProvider((ref) => ref.watch(runtimeProtectionServiceProvider).threatEvents);\nfinal securityDecisionProvider = Provider<SecurityDecision?>((ref) => null);\n",
    StateManagementType.bloc =>
      "import 'package:flutter_bloc/flutter_bloc.dart';\nimport '../security_decision.dart';\nsealed class RuntimeProtectionEvent { const RuntimeProtectionEvent(); }\nfinal class RuntimeProtectionStarted extends RuntimeProtectionEvent { const RuntimeProtectionStarted(); }\nclass RuntimeProtectionState { const RuntimeProtectionState({this.decision}); final SecurityDecision? decision; }\nclass RuntimeProtectionBloc extends Bloc<RuntimeProtectionEvent, RuntimeProtectionState> { RuntimeProtectionBloc() : super(const RuntimeProtectionState()) { on<RuntimeProtectionStarted>((event, emit) {}); } }\n",
    StateManagementType.provider =>
      "import 'package:flutter/foundation.dart';\nimport '../security_decision.dart';\nclass RuntimeProtectionNotifier extends ChangeNotifier { SecurityDecision? get decision => _decision; SecurityDecision? _decision; void update(SecurityDecision value) { _decision = value; notifyListeners(); } }\n",
    StateManagementType.getx =>
      "import 'package:get/get.dart';\nimport '../security_decision.dart';\nclass RuntimeProtectionController extends GetxController { final decision = Rxn<SecurityDecision>(); void updateDecision(SecurityDecision value) => decision.value = value; }\n",
    StateManagementType.none =>
      "import 'package:flutter/foundation.dart';\nimport '../security_decision.dart';\nfinal securityDecision = ValueNotifier<SecurityDecision?>(null);\n",
  };
}

const _bootstrap =
    "import 'dependency_injection.dart';\n\nFuture<void> bootstrap() => configureDependencies();\n";
const _exception =
    "class AppException implements Exception {\n  const AppException(this.message);\n  final String message;\n  @override\n  String toString() => message;\n}\n";
const _logger =
    "abstract interface class AppLogger {\n  void info(String message);\n  void warning(String message);\n  void error(String message, [Object? error, StackTrace? stackTrace]);\n}\n";
const _apiCommonConfigTemplate = '''
{
  "base_url": "https://api.example.com",
  "timeout_seconds": 30,
  "headers": {
    "Content-Type": "application/json"
  },
  "request": {},
  "cache": {
    "enabled": false,
    "ttl_seconds": 300
  },
  "response": {
    "success_code_path": "status.code",
    "success_codes": ["000000"],
    "message_path": "status.description"
  }
}
''';
const _componentDefaults =
    "import 'package:flutter/material.dart';\n\n"
    "/// Customize shared component defaults here to update the entire app.\n"
    "abstract final class AppComponentDefaults {\n"
    "  static const contentPadding = EdgeInsets.all(16);\n"
    "  static const controlBorderRadius = 12.0;\n"
    "  static const buttonHeight = 48.0;\n"
    "  static const loadingIndicatorSize = 24.0;\n"
    "  static const loadingIndicatorStrokeWidth = 3.0;\n"
    "}\n";
const _appScaffold =
    "import 'package:flutter/material.dart';\n"
    "import 'app_component_defaults.dart';\n\n"
    "/// Shared page shell used by generated screens.\n"
    "class AppScaffold extends StatelessWidget {\n"
    "  const AppScaffold({\n"
    "    required this.body,\n"
    "    this.title,\n"
    "    this.actions,\n"
    "    this.floatingActionButton,\n"
    "    this.padding = AppComponentDefaults.contentPadding,\n"
    "    super.key,\n"
    "  });\n\n"
    "  final Widget body;\n"
    "  final String? title;\n"
    "  final List<Widget>? actions;\n"
    "  final Widget? floatingActionButton;\n"
    "  final EdgeInsetsGeometry padding;\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) => Scaffold(\n"
    "    appBar: title == null ? null : AppBar(title: Text(title!), actions: actions),\n"
    "    body: SafeArea(child: Padding(padding: padding, child: body)),\n"
    "    floatingActionButton: floatingActionButton,\n"
    "  );\n"
    "}\n";
const _appButton =
    "import 'package:flutter/material.dart';\n"
    "import 'app_component_defaults.dart';\n\n"
    "/// Shared primary button. Change this widget once to update every usage.\n"
    "class AppButton extends StatelessWidget {\n"
    "  const AppButton({required this.label, required this.onPressed, super.key});\n\n"
    "  final String label;\n"
    "  final VoidCallback? onPressed;\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) => SizedBox(\n"
    "    height: AppComponentDefaults.buttonHeight,\n"
    "    child: FilledButton(\n"
    "      onPressed: onPressed,\n"
    "      style: FilledButton.styleFrom(\n"
    "        shape: RoundedRectangleBorder(\n"
    "          borderRadius: BorderRadius.circular(AppComponentDefaults.controlBorderRadius),\n"
    "        ),\n"
    "      ),\n"
    "      child: Text(label),\n"
    "    ),\n"
    "  );\n"
    "}\n";
const _appTextField =
    "import 'package:flutter/material.dart';\n"
    "import 'app_component_defaults.dart';\n\n"
    "/// Shared text field with centrally controlled decoration.\n"
    "class AppTextField extends StatelessWidget {\n"
    "  const AppTextField({\n"
    "    this.controller,\n"
    "    this.label,\n"
    "    this.hint,\n"
    "    this.onChanged,\n"
    "    this.obscureText = false,\n"
    "    super.key,\n"
    "  });\n\n"
    "  final TextEditingController? controller;\n"
    "  final String? label;\n"
    "  final String? hint;\n"
    "  final ValueChanged<String>? onChanged;\n"
    "  final bool obscureText;\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) => TextField(\n"
    "    controller: controller,\n"
    "    onChanged: onChanged,\n"
    "    obscureText: obscureText,\n"
    "    decoration: InputDecoration(\n"
    "      labelText: label,\n"
    "      hintText: hint,\n"
    "      border: OutlineInputBorder(\n"
    "        borderRadius: BorderRadius.circular(AppComponentDefaults.controlBorderRadius),\n"
    "      ),\n"
    "    ),\n"
    "  );\n"
    "}\n";
const _appLoadingIndicator =
    "import 'package:flutter/material.dart';\n"
    "import 'app_component_defaults.dart';\n\n"
    "/// Shared loading indicator with centrally controlled dimensions.\n"
    "class AppLoadingIndicator extends StatelessWidget {\n"
    "  const AppLoadingIndicator({super.key});\n\n"
    "  @override\n"
    "  Widget build(BuildContext context) => const SizedBox.square(\n"
    "    dimension: AppComponentDefaults.loadingIndicatorSize,\n"
    "    child: CircularProgressIndicator(\n"
    "      strokeWidth: AppComponentDefaults.loadingIndicatorStrokeWidth,\n"
    "    ),\n"
    "  );\n"
    "}\n";
const _commonWidgets =
    "export 'app_button.dart';\n"
    "export 'app_component_defaults.dart';\n"
    "export 'app_loading_indicator.dart';\n"
    "export 'app_scaffold.dart';\n"
    "export 'app_text_field.dart';\n";
const _theme =
    "import 'package:flutter/material.dart';\n\nabstract final class AppTheme {\n  static ThemeData get light => ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true);\n}\n";
const _strings =
    "abstract final class AppStrings {\n  static const appName = 'Application';\n}\n";
const _secureStore =
    "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\n\nclass SecureStore {\n  const SecureStore(this.storage);\n  final FlutterSecureStorage storage;\n  Future<String?> read(String key) => storage.read(key: key);\n  Future<void> write(String key, String value) => storage.write(key: key, value: value);\n}\n";
const _runtimeModels =
    "enum SecurityThreatType { noInternet, backendUnavailable, vpn, proxy, mockLocation, screenCapture, screenRecording, screenSharing, screenMirroring, externalDisplay, usbDebugging, developerMode, rootedDevice, jailbrokenDevice, emulator, appIntegrityFailure }\nenum SecurityAction { allow, warn, restrict, blurContent, blockScreen, signOut, terminateSession }\nenum DetectionConfidence { confirmed, likely, uncertain, unsupported }\nclass SecurityCheckResult {\n  const SecurityCheckResult({required this.type, required this.detected, required this.confidence, required this.platformSupported, this.details, this.checkedAt});\n  final SecurityThreatType type; final bool detected; final DetectionConfidence confidence; final bool platformSupported; final Map<String, Object?>? details; final DateTime? checkedAt;\n}\n";
const _runtimeService =
    "import 'runtime_protection_result.dart';\nabstract interface class RuntimeProtectionService {\n  Stream<SecurityCheckResult> get threatEvents;\n  Future<List<SecurityCheckResult>> runInitialChecks();\n  Future<SecurityCheckResult> check(SecurityThreatType type);\n  Future<void> startMonitoring();\n  Future<void> stopMonitoring();\n}\n";
const _runtimeAdapter =
    "import 'runtime_protection_result.dart';\nabstract interface class RuntimeProtectionAdapter {\n  Stream<SecurityCheckResult> get events;\n  Future<List<SecurityCheckResult>> runChecks();\n  Future<void> enableScreenProtection();\n  Future<void> disableScreenProtection();\n  Future<void> startMonitoring();\n  Future<void> stopMonitoring();\n}\n";
const _runtimeConfig =
    "class RuntimeProtectionConfig {\n  const RuntimeProtectionConfig({required this.profile, this.pollingInterval = const Duration(seconds: 30)});\n  final String profile; final Duration pollingInterval;\n}\nenum InternetStatus { offline, networkConnected, internetReachable, backendReachable }\n";
const _runtimePolicy =
    "import 'runtime_protection_result.dart';\nimport 'security_decision.dart';\nabstract interface class RuntimeProtectionPolicy { SecurityDecision evaluate(List<SecurityCheckResult> results); }\n";
const _decision =
    "import 'runtime_protection_result.dart';\nclass SecurityDecision { const SecurityDecision(this.action, {this.reason}); final SecurityAction action; final String? reason; }\n";
const _runtimeController =
    "import 'runtime_protection_policy.dart';\nimport 'runtime_protection_service.dart';\nimport 'security_decision.dart';\nclass RuntimeProtectionController {\n  RuntimeProtectionController(this.service, this.policy); final RuntimeProtectionService service; final RuntimeProtectionPolicy policy;\n  Future<SecurityDecision> initialize() async => policy.evaluate(await service.runInitialChecks());\n}\n";
const _runtimeGate =
    "import 'package:flutter/material.dart';\nclass RuntimeProtectionGate extends StatelessWidget { const RuntimeProtectionGate({required this.child, super.key}); final Widget child; @override Widget build(BuildContext context) => child; }\n";
const _runtimeBarrel =
    "export 'runtime_protection_adapter.dart';\nexport 'runtime_protection_config.dart';\nexport 'runtime_protection_controller.dart';\nexport 'runtime_protection_gate.dart';\nexport 'runtime_protection_policy.dart';\nexport 'runtime_protection_result.dart';\nexport 'runtime_protection_service.dart';\nexport 'security_decision.dart';\n";
const _blockingPage =
    "import 'package:flutter/material.dart';\nclass SecurityBlockingPage extends StatelessWidget { const SecurityBlockingPage({this.message = 'This action is unavailable.', super.key}); final String message; @override Widget build(BuildContext context) => Scaffold(body: Center(child: Text(message))); }\n";
const _blockingDialog =
    "import 'package:flutter/material.dart';\nFuture<void> showSecurityBlockingDialog(BuildContext context, String message) => showDialog<void>(context: context, barrierDismissible: false, builder: (_) => AlertDialog(title: const Text('Security notice'), content: Text(message)));\n";
const _warningSheet =
    "import 'package:flutter/material.dart';\nFuture<void> showSecurityWarningSheet(BuildContext context, String message) => showModalBottomSheet<void>(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Text(message)));\n";
const _secureOverlay =
    "import 'package:flutter/material.dart';\nclass SecureContentOverlay extends StatelessWidget { const SecureContentOverlay({required this.hidden, required this.child, super.key}); final bool hidden; final Widget child; @override Widget build(BuildContext context) => hidden ? const ColoredBox(color: Colors.black) : child; }\n";
const _sensitiveContent =
    "import 'package:flutter/material.dart';\nclass SensitiveContent extends StatelessWidget { const SensitiveContent({required this.child, required this.fallback, this.hidden = false, super.key}); final Widget child; final Widget fallback; final bool hidden; @override Widget build(BuildContext context) => hidden ? fallback : child; }\nabstract interface class ScreenProtectionService { Future<void> enableSecureDisplay(); Future<void> disableSecureDisplay(); Stream<bool> get captureStateChanges; Stream<bool> get mirroringStateChanges; }\n";
const _runtimeException =
    "class RuntimeProtectionException implements Exception { const RuntimeProtectionException(this.message); final String message; @override String toString() => message; }\n";
const _widgetTest =
    "import 'package:flutter_test/flutter_test.dart';\n\nvoid main() {\n  test('generated project test harness', () {\n    expect(1 + 1, 2);\n  });\n}\n";
