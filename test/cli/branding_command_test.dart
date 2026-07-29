import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:archsmith/src/cli/command_context.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('branding CLI installs and runs launcher icon generation', () async {
    final project = await Directory.systemTemp.createTemp(
      'archsmith_branding_cli_',
    );
    final sources = await Directory.systemTemp.createTemp(
      'archsmith_branding_cli_assets_',
    );
    addTearDown(() async {
      await project.delete(recursive: true);
      await sources.delete(recursive: true);
    });
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: sample_app
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    final icon = File(p.join(sources.path, 'icon.png'))
      ..writeAsBytesSync([1, 2, 3]);
    final processes = _RecordingProcessService();

    final exitCode = await ArchsmithRunner(
      context: CommandContext(processes: processes),
    ).run([
      'branding',
      '--project',
      project.path,
      '--name',
      'Acme App',
      '--icon',
      icon.path,
    ]);

    expect(exitCode, 0);
    expect(processes.calls, [
      [
        'fvm',
        'flutter',
        'pub',
        'add',
        '--dev',
        'flutter_launcher_icons',
      ],
      ['fvm', 'dart', 'run', 'flutter_launcher_icons'],
    ]);
    expect(
      File(p.join(project.path, 'assets/branding/app_icon.png')).existsSync(),
      isTrue,
    );
  });

  test('branding CLI dry run does not invoke Flutter tools', () async {
    final project = await Directory.systemTemp.createTemp(
      'archsmith_branding_cli_dry_',
    );
    addTearDown(() async {
      await project.delete(recursive: true);
    });
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: sample_app
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
    final processes = _RecordingProcessService();

    final exitCode = await ArchsmithRunner(
      context: CommandContext(processes: processes),
    ).run([
      'branding',
      '--project',
      project.path,
      '--name',
      'Preview App',
      '--dry-run',
    ]);

    expect(exitCode, 0);
    expect(processes.calls, isEmpty);
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
