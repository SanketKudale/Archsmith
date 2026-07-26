import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'base_command.dart';

/// Runs the same non-publishing gates used before a pub.dev release.
class ReleaseCheckCommand extends ArchsmithCommand {
  ReleaseCheckCommand(super.context) {
    argParser.addFlag(
      'generated-matrix',
      negatable: false,
      help: 'Also analyze a generated Flutter application.',
    );
  }

  @override
  String get name => 'release-check';

  @override
  String get description =>
      'Run formatting, analysis, tests, package, and optional generated-app gates.';

  @override
  Future<int> run() async {
    final root = Directory.current.path;
    final failures = <String>[];
    void requireFile(String path) {
      if (!File(p.join(root, path)).existsSync()) failures.add(path);
    }

    for (final path in [
      'README.md',
      'CHANGELOG.md',
      'LICENSE',
      'pubspec.yaml'
    ]) {
      requireFile(path);
    }
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final value = loadYaml(pubspec.readAsStringSync());
      if (value is! YamlMap ||
          value['description'] == null ||
          value['repository'] == null ||
          value['issue_tracker'] == null) {
        failures.add('pubspec metadata');
      }
    }
    if (failures.isNotEmpty) {
      stderr.writeln(
        'Release metadata is incomplete: ${failures.join(', ')}',
      );
      return 2;
    }

    final checks = <(String, List<String>)>[
      (
        'format',
        [
          'dart',
          'format',
          '--output=none',
          '--set-exit-if-changed',
          'bin',
          'lib',
          'test',
          'tool',
        ],
      ),
      ('analyze', ['dart', 'analyze']),
      ('tests', ['dart', 'test']),
      ('pub dry-run', ['dart', 'pub', 'publish', '--dry-run']),
      if (argResults!['generated-matrix'] as bool)
        for (final entry in const [
          ('none', 'http'),
          ('riverpod', 'dio'),
          ('provider', 'dio'),
          ('bloc', 'http'),
          ('getx', 'dio'),
        ])
          (
            'generated Flutter app (${entry.$1}/${entry.$2})',
            [
              'dart',
              'run',
              'tool/verify_generated_apps.dart',
              '--state',
              entry.$1,
              '--network',
              entry.$2,
            ],
          ),
    ];
    for (final check in checks) {
      stdout.writeln('Checking ${check.$1}...');
      if (!await runTool('fvm', check.$2, root)) {
        stderr.writeln('Release check failed: ${check.$1}');
        return 1;
      }
    }
    stdout.writeln('Release readiness checks passed. Nothing was published.');
    return 0;
  }
}
