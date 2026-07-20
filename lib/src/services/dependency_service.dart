import '../configuration/archsmith_config.dart';
import '../models/options.dart';
import 'process_service.dart';

class DependencyManifest {
  const DependencyManifest();

  List<String> forConfig(ArchsmithConfig config) => [
    if (config.stateManagement == StateManagementType.riverpod)
      'flutter_riverpod',
    if (config.stateManagement == StateManagementType.bloc) 'flutter_bloc',
    if (config.stateManagement == StateManagementType.provider) 'provider',
    if (config.router == RouterType.goRouter) 'go_router',
    if (config.router == RouterType.autoRoute) 'auto_route',
    if (config.network == NetworkType.dio) 'dio',
    if (config.network == NetworkType.http) 'http',
    if (config.modules.secureStorage) 'flutter_secure_storage',
  ];
}

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
