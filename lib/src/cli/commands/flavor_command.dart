import 'dart:io';

import '../../services/flavor_service.dart';
import 'base_command.dart';

class FlavorCommand extends ArchsmithCommand {
  FlavorCommand(super.context) {
    argParser
      ..addOption('app-name', help: 'Display name for the flavor.')
      ..addOption(
        'application-id',
        help: 'Android application ID and Apple bundle ID.',
      )
      ..addOption('icon', help: 'Optional PNG icon for this flavor.')
      ..addMultiOption(
        'dart-define',
        help: 'Compile-time KEY=VALUE for this flavor.',
        splitCommas: false,
      )
      ..addFlag(
        'default',
        negatable: false,
        help: 'Make this the default Flutter flavor.',
      )
      ..addFlag(
        'generate',
        defaultsTo: true,
        help: 'Generate native flavor projects after create.',
      )
      ..addOption(
        'project',
        defaultsTo: '.',
        help: 'Flutter project directory.',
      )
      ..addOption(
        'mode',
        defaultsTo: 'debug',
        allowed: const ['debug', 'profile', 'release'],
      )
      ..addOption('device', abbr: 'd', help: 'Flutter device ID.')
      ..addOption('entrypoint', abbr: 't', help: 'Dart entrypoint.')
      ..addOption(
        'type',
        defaultsTo: 'appbundle',
        allowed: const [
          'apk',
          'appbundle',
          'ios',
          'ipa',
          'web',
          'windows',
          'macos',
          'linux',
        ],
        help: 'Flutter build artifact type.',
      )
      ..addFlag(
        'obfuscate',
        negatable: false,
        help: 'Obfuscate a release build.',
      )
      ..addOption(
        'split-debug-info',
        help: 'Directory for release symbol files.',
      )
      ..addFlag('dry-run', negatable: false, help: 'Preview without writing.');
  }

  @override
  String get name => 'flavor';

  @override
  String get description =>
      'Create, sync, run, and build Flutter flavor variants.';

  @override
  String get invocation =>
      'archsmith flavor <create|sync|run|build|release> [flavor]';

  @override
  Future<int> run() async {
    final positional = argResults!.rest;
    if (positional.isEmpty) {
      stderr.writeln(
        'Use flavor create <name>, sync, run <name>, '
        'build <name>, or release <name>.',
      );
      return 64;
    }
    final operation = positional.first;
    final root = Directory(argResults!['project'] as String).absolute.path;
    final dryRun = argResults!['dry-run'] as bool;
    if (operation == 'sync') {
      final result = await const FlavorService().sync(
        root,
        dryRun: dryRun,
      );
      final prefix = dryRun ? 'WOULD UPDATE' : 'UPDATE';
      for (final path in result.paths) {
        stdout.writeln('$prefix  $path');
      }
      if (dryRun) return 0;
      return _generateNative(root);
    }
    if (positional.length < 2) {
      stderr.writeln('flavor $operation requires a flavor name.');
      return 64;
    }
    final name = positional[1];
    switch (operation) {
      case 'create':
        return _create(root, name, dryRun);
      case 'run':
        return _runFlavor(root, name, dryRun);
      case 'build':
        return _buildFlavor(root, name, dryRun, release: false);
      case 'release':
        return _buildFlavor(root, name, dryRun, release: true);
      default:
        return _unsupported(operation);
    }
  }

  Future<int> _create(String root, String name, bool dryRun) async {
    final service = const FlavorService();
    FlavorDefinition? existing;
    try {
      existing = service.read(root).flavor(name);
    } on FileSystemException {
      // The first flavor creates the configuration.
    } on FormatException {
      // A new flavor is added to the existing configuration.
    }
    final appName = argResults!['app-name'] as String? ?? existing?.appName;
    final applicationId =
        argResults!['application-id'] as String? ?? existing?.applicationId;
    if (appName == null || applicationId == null) {
      stderr.writeln(
        'New flavors require --app-name and --application-id.',
      );
      return 64;
    }
    final sourceIcon = argResults!['icon'] as String?;
    final iconPath = sourceIcon == null
        ? existing?.iconPath
        : 'assets/branding/flavors/$name.png';
    final defines = {
      ...?existing?.dartDefines,
      ..._dartDefines(argResults!['dart-define'] as List<String>),
    };
    final result = await service.upsert(
      root,
      FlavorDefinition(
        name: name,
        appName: appName,
        applicationId: applicationId,
        iconPath: iconPath,
        dartDefines: defines,
      ),
      makeDefault: argResults!['default'] as bool,
      sourceIconPath: sourceIcon,
      dryRun: dryRun,
    );
    final prefix = dryRun ? 'WOULD UPDATE' : 'UPDATE';
    for (final path in result.paths) {
      stdout.writeln('$prefix  $path');
    }
    if (dryRun || !(argResults!['generate'] as bool)) return 0;
    return _generateNative(root);
  }

  Future<int> _generateNative(String root) async {
    if (!await runTool(
      'fvm',
      ['flutter', 'pub', 'add', '--dev', 'flutter_flavorizr'],
      root,
    )) {
      return 1;
    }
    return await runTool(
      'fvm',
      ['dart', 'run', 'flutter_flavorizr', '-f'],
      root,
    )
        ? 0
        : 1;
  }

  Future<int> _runFlavor(String root, String name, bool dryRun) async {
    final flavor = const FlavorService().read(root).flavor(name);
    final arguments = <String>[
      'flutter',
      'run',
      '--flavor',
      name,
      '--${argResults!['mode']}',
      ..._defineArguments(flavor),
      if (argResults!['device'] case final String device) ...['-d', device],
      if (argResults!['entrypoint'] case final String target) ...[
        '-t',
        target,
      ],
    ];
    return _executeOrPreview(root, arguments, dryRun);
  }

  Future<int> _buildFlavor(
    String root,
    String name,
    bool dryRun, {
    required bool release,
  }) async {
    final flavor = const FlavorService().read(root).flavor(name);
    final mode = release ? 'release' : argResults!['mode'] as String;
    final arguments = <String>[
      'flutter',
      'build',
      argResults!['type'] as String,
      '--flavor',
      name,
      '--$mode',
      ..._defineArguments(flavor),
      if (argResults!['entrypoint'] case final String target) ...[
        '-t',
        target,
      ],
      if (release && argResults!['obfuscate'] as bool) '--obfuscate',
      if (release && (argResults!['split-debug-info'] as String?) != null)
        '--split-debug-info=${argResults!['split-debug-info']}',
    ];
    return _executeOrPreview(root, arguments, dryRun);
  }

  Future<int> _executeOrPreview(
    String root,
    List<String> arguments,
    bool dryRun,
  ) async {
    if (dryRun) {
      stdout.writeln('WOULD RUN  fvm ${arguments.join(' ')}');
      return 0;
    }
    return await runTool('fvm', arguments, root) ? 0 : 1;
  }

  Map<String, String> _dartDefines(List<String> values) {
    final result = <String, String>{};
    for (final value in values) {
      final separator = value.indexOf('=');
      if (separator < 1) {
        throw FormatException('Invalid --dart-define "$value". Use KEY=VALUE.');
      }
      result[value.substring(0, separator)] = value.substring(separator + 1);
    }
    return result;
  }

  List<String> _defineArguments(FlavorDefinition flavor) => [
        '--dart-define=FLAVOR=${flavor.name}',
        for (final entry in flavor.dartDefines.entries)
          '--dart-define=${entry.key}=${entry.value}',
      ];

  int _unsupported(String operation) {
    stderr.writeln('Unsupported flavor operation: $operation.');
    return 64;
  }
}
