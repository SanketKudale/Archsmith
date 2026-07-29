import 'dart:io';

import '../../services/branding_service.dart';
import 'base_command.dart';

class BrandingCommand extends ArchsmithCommand {
  BrandingCommand(super.context) {
    argParser
      ..addOption('name', help: 'User-facing application name.')
      ..addOption('logo', help: 'Path to an in-app logo asset.')
      ..addOption('icon', help: 'Path to a PNG launcher icon.')
      ..addOption(
        'project',
        defaultsTo: '.',
        help: 'Flutter project directory.',
      )
      ..addFlag('dry-run', negatable: false, help: 'Preview without writing.');
  }

  @override
  String get name => 'branding';

  @override
  String get description =>
      'Update the app display name, logo asset, and launcher icons.';

  @override
  String get invocation =>
      'archsmith branding [--name <name>] [--logo <path>] [--icon <png>] '
      '[--project <path>]';

  @override
  Future<int> run() async {
    final dryRun = argResults!['dry-run'] as bool;
    final icon = argResults!['icon'] as String?;
    final root = Directory(argResults!['project'] as String).absolute.path;
    final result = await const BrandingService().apply(
      root,
      BrandingRequest(
        displayName: argResults!['name'] as String?,
        logoPath: argResults!['logo'] as String?,
        iconPath: icon,
      ),
      dryRun: dryRun,
    );
    final prefix = dryRun ? 'WOULD UPDATE' : 'UPDATE';
    for (final path in result.paths) {
      stdout.writeln('$prefix  $path');
    }
    if (icon == null || dryRun) return 0;

    if (!await runTool(
      'fvm',
      ['flutter', 'pub', 'add', '--dev', 'flutter_launcher_icons'],
      root,
    )) {
      stderr.writeln(
        'Branding files were updated, but flutter_launcher_icons '
        'could not be installed.',
      );
      return 1;
    }
    if (!await runTool(
      'fvm',
      ['dart', 'run', 'flutter_launcher_icons'],
      root,
    )) {
      stderr.writeln(
        'Branding files were updated, but launcher icons '
        'could not be generated.',
      );
      return 1;
    }
    return 0;
  }
}
