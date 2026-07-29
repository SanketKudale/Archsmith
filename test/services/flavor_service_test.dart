import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('archsmith_flavors_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: sample_app
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    await Directory(p.join(project.path, 'android')).create();
  });

  tearDown(() => project.delete(recursive: true));

  test('persists multiple flavors and a production default', () async {
    const service = FlavorService();
    await service.upsert(
      project.path,
      const FlavorDefinition(
        name: 'staging',
        appName: 'Sample Staging',
        applicationId: 'com.example.sample.staging',
        dartDefines: {'API_URL': 'https://staging.example.com'},
      ),
    );
    await service.upsert(
      project.path,
      const FlavorDefinition(
        name: 'production',
        appName: 'Sample',
        applicationId: 'com.example.sample',
        dartDefines: {'API_URL': 'https://api.example.com'},
      ),
      makeDefault: true,
    );

    final config = service.read(project.path);
    expect(config.defaultFlavor, 'production');
    expect(
      config.flavors.map((flavor) => flavor.name),
      ['production', 'staging'],
    );
    final yaml =
        File(p.join(project.path, 'flavorizr.yaml')).readAsStringSync();
    expect(yaml, contains('android:flavorizrGradle'));
    expect(yaml, contains('applicationId: "com.example.sample.staging"'));
    expect(yaml, isNot(contains('flutter:main')));
    expect(
      File(p.join(project.path, 'pubspec.yaml')).readAsStringSync(),
      contains('default-flavor: production'),
    );
    final runtime = File(
      p.join(
        project.path,
        'lib/core/environment/flavor_config.dart',
      ),
    ).readAsStringSync();
    expect(runtime, contains("show appFlavor"));
    expect(runtime, contains('"API_URL": String.fromEnvironment("API_URL")'));
  });

  test('dry run does not create flavor configuration', () async {
    final result = await const FlavorService().upsert(
      project.path,
      const FlavorDefinition(
        name: 'development',
        appName: 'Sample Dev',
        applicationId: 'com.example.sample.dev',
      ),
      dryRun: true,
    );

    expect(result.paths, contains('flavorizr.yaml'));
    expect(
      File(p.join(project.path, 'flavorizr.yaml')).existsSync(),
      isFalse,
    );
  });
}
