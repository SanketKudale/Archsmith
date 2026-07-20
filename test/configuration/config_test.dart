import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('configuration round trips through YAML', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_config_',
    );
    addTearDown(() => directory.delete(recursive: true));
    const config = ArchsmithConfig(
      projectName: 'bank_app',
      modules: ModuleConfig(runtimeProtection: true, secureStorage: true),
      runtimeProtectionProfile: RuntimeProtectionProfile.financial,
      runtimeChecks: {'vpn': 'warn', 'root': 'block_screen'},
    );
    await const LocalFileSystemService().apply(directory.path, [
      const ConfigWriter().plan(config),
    ], const GenerationOptions());

    final restored = const ConfigReader().read(
      p.join(directory.path, 'archsmith.yaml'),
    );
    expect(restored.projectName, 'bank_app');
    expect(
      restored.runtimeProtectionProfile,
      RuntimeProtectionProfile.financial,
    );
    expect(restored.runtimeChecks['root'], 'block_screen');
  });

  test('runtime profile requires enabled module', () {
    const config = ArchsmithConfig(
      projectName: 'bad_app',
      runtimeProtectionProfile: RuntimeProtectionProfile.standard,
    );
    expect(config.validate, throwsFormatException);
  });
}
