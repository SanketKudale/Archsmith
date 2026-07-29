import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:archsmith/src/cli/command_context.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('creates, runs, and releases a production flavor', () async {
    final project = await Directory.systemTemp.createTemp(
      'archsmith_flavor_cli_',
    );
    addTearDown(() => project.delete(recursive: true));
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: sample_app
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    await Directory(p.join(project.path, 'android')).create();
    final processes = _RecordingProcessService();
    final runner = ArchsmithRunner(
      context: CommandContext(processes: processes),
    );

    expect(
      await runner.run([
        'flavor',
        'create',
        'production',
        '--project',
        project.path,
        '--app-name',
        'Sample',
        '--application-id',
        'com.example.sample',
        '--dart-define',
        'API_URL=https://api.example.com',
        '--default',
      ]),
      0,
    );
    expect(
      await runner.run([
        'flavor',
        'run',
        'production',
        '--project',
        project.path,
        '--mode',
        'release',
        '--device',
        'pixel',
      ]),
      0,
    );
    expect(
      await runner.run([
        'flavor',
        'release',
        'production',
        '--project',
        project.path,
        '--type',
        'appbundle',
        '--obfuscate',
        '--split-debug-info',
        'build/symbols/production',
      ]),
      0,
    );

    expect(processes.calls[0], [
      'fvm',
      'flutter',
      'pub',
      'add',
      '--dev',
      'flutter_flavorizr',
    ]);
    expect(processes.calls[1], [
      'fvm',
      'dart',
      'run',
      'flutter_flavorizr',
      '-f',
    ]);
    expect(
      processes.calls[2],
      containsAll([
        'run',
        '--flavor',
        'production',
        '--release',
        '--dart-define=FLAVOR=production',
        '--dart-define=API_URL=https://api.example.com',
        'pixel',
      ]),
    );
    expect(
      processes.calls[3],
      containsAll([
        'build',
        'appbundle',
        '--flavor',
        'production',
        '--release',
        '--obfuscate',
        '--split-debug-info=build/symbols/production',
      ]),
    );
  });
}

class _RecordingProcessService implements ProcessService {
  final List<List<String>> calls = [];

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    calls.add([executable, ...arguments]);
    return const ProcessOutput(
      exitCode: 0,
      stdout: '',
      stderr: '',
      duration: Duration.zero,
    );
  }
}
