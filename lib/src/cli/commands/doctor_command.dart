import 'dart:io';

import 'package:path/path.dart' as p;

import 'base_command.dart';

class DoctorCommand extends ArchsmithCommand {
  DoctorCommand(super.context);
  @override
  String get name => 'doctor';
  @override
  String get description => 'Check the local Flutter development environment.';

  @override
  Future<int> run() async {
    stdout.writeln('Archsmith doctor\n');
    var failed = false;
    Future<void> tool(
      String label,
      String executable,
      List<String> args,
    ) async {
      try {
        final result = await context.processes.run(executable, args);
        final line = result.stdout.trim().split('\n').firstOrNull?.trim() ?? '';
        stdout.writeln(
          '${result.succeeded ? '[OK]' : '[FAIL]'} $label${line.isEmpty ? '' : ': $line'}',
        );
        failed |= !result.succeeded;
      } on ProcessException catch (error) {
        stdout.writeln('[FAIL] $label: ${error.message}');
        failed = true;
      }
    }

    await tool('Dart', 'fvm', ['dart', '--version']);
    await tool('Flutter', 'fvm', ['flutter', '--version']);
    await tool('Flutter toolchains', 'fvm', ['flutter', 'doctor']);
    await tool('Java', 'java', ['-version']);
    if (Platform.isMacOS) await tool('Xcode', 'xcodebuild', ['-version']);
    final pubspec = File(p.join(Directory.current.path, 'pubspec.yaml'));
    stdout.writeln('${pubspec.existsSync() ? '[OK]' : '[WARN]'} pubspec.yaml');
    final configFile = File(p.join(Directory.current.path, 'archsmith.yaml'));
    if (configFile.existsSync()) {
      try {
        final config = readConfig();
        stdout.writeln('[OK] archsmith.yaml (${config.architecture.label})');
        if (config.modules.runtimeProtection) {
          stdout.writeln(
            '[WARN] Runtime checks are heuristic; verify native adapter setup and server-side attestation.',
          );
        }
      } on Object catch (error) {
        stdout.writeln('[FAIL] archsmith.yaml: $error');
        failed = true;
      }
    } else {
      stdout.writeln('[WARN] archsmith.yaml not found');
    }
    return failed ? 1 : 0;
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
