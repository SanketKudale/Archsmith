import '../configuration/archsmith_config.dart';
import '../models/options.dart';
import 'process_service.dart';

/// Central mapping from project choices to pub dependencies.
class DependencyManifest {
  const DependencyManifest();

  List<String> forConfig(ArchsmithConfig config) => [
    if (config.stateManagement == StateManagementType.riverpod)
      'flutter_riverpod',
    if (config.stateManagement == StateManagementType.bloc) 'flutter_bloc',
    if (config.stateManagement == StateManagementType.provider) 'provider',
    if (config.stateManagement == StateManagementType.getx) 'get',
    if (config.router == RouterType.goRouter) 'go_router',
    if (config.router == RouterType.autoRoute) ...[
      'auto_route',
      'auto_route_generator',
      'build_runner',
    ],
    if (config.network == NetworkType.dio) 'dio',
    if (config.network == NetworkType.http) 'http',
    if (config.modules.secureStorage) 'flutter_secure_storage',
  ];
}

/// Installs dependencies selected by [DependencyManifest].
class DependencyService {
  const DependencyService(
    this.process, {
    this.manifest = const DependencyManifest(),
  });
  final ProcessService process;
  final DependencyManifest manifest;

  Future<ProcessOutput?> install(ArchsmithConfig config, String root) async {
    final dependencies = manifest.forConfig(config);
    if (dependencies.isEmpty) return null;
    return process.run('fvm', [
      'flutter',
      'pub',
      'add',
      ...dependencies,
    ], workingDirectory: root);
  }
}
