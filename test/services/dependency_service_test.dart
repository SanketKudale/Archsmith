import 'package:archsmith/archsmith.dart';
import 'package:test/test.dart';

void main() {
  test('selects dependencies centrally from configuration', () {
    const config = ArchsmithConfig(
      projectName: 'example_app',
      modules: ModuleConfig(secureStorage: true, runtimeProtection: true),
      runtimeProtectionProfile: RuntimeProtectionProfile.standard,
    );
    final dependencies = const DependencyManifest().forConfig(config);
    expect(
      dependencies,
      containsAll([
        'flutter_riverpod',
        'go_router',
        'dio',
        'flutter_secure_storage',
      ]),
    );
    expect(dependencies, isNot(contains('runtime_guard')));
  });

  test('selects GetX dependency', () {
    const config = ArchsmithConfig(
      projectName: 'example_app',
      stateManagement: StateManagementType.getx,
    );
    expect(const DependencyManifest().forConfig(config), contains('get'));
  });
}
