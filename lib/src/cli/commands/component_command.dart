import 'dart:io';

import '../../studio/component_registry.dart';
import '../../utils/naming_utils.dart';
import 'base_command.dart';

class ComponentCommand extends ArchsmithCommand {
  ComponentCommand(super.context) {
    argParser
      ..addOption('class', help: 'Flutter widget class name.')
      ..addOption('import', help: 'Package import for the common widget.')
      ..addOption(
        'label',
        help: 'Human-readable Studio palette label.',
      )
      ..addOption(
        'category',
        defaultsTo: 'Project',
        help: 'Studio palette category.',
      )
      ..addFlag(
        'children',
        negatable: false,
        help: 'Allow child components.',
      )
      ..addOption(
        'child-parameter',
        defaultsTo: 'child',
        allowed: const ['child', 'children'],
        help: 'Constructor parameter used for visual children.',
      )
      ..addMultiOption(
        'property',
        splitCommas: false,
        help: 'Editable property as name:type or name:select:a,b.',
      );
    addSafetyOptions();
  }

  @override
  String get name => 'component';

  @override
  String get description =>
      'Register or list project common widgets available in Studio.';

  @override
  String get invocation => 'archsmith component <add|list> [component_name]';

  @override
  Future<int> run() async {
    final arguments = argResults!.rest;
    if (arguments.isEmpty) {
      throw const FormatException('Component command requires add or list.');
    }
    final root = Directory.current.path;
    const store = StudioComponentManifestStore();
    if (arguments.first == 'list') {
      final components = store.readAll(root);
      if (components.isEmpty) {
        stdout.writeln('No project Studio components registered.');
      } else {
        for (final component in components) {
          stdout.writeln(
            '${component.type} -> ${component.dartClass} '
            '(${component.importPath})',
          );
        }
      }
      return 0;
    }
    if (arguments.first != 'add' || arguments.length < 2) {
      throw const FormatException(
        'Use archsmith component add <component_name>.',
      );
    }
    final config = readConfig(root);
    final componentName = names(arguments[1]);
    final acceptsChildren = argResults!['children'] as bool;
    final properties = (argResults!['property'] as List<String>)
        .map(_property)
        .toList(growable: false);
    final component = StudioComponentDescriptor(
      type: componentName.camelCase,
      label:
          argResults!['label'] as String? ?? _words(componentName.pascalCase),
      category: argResults!['category'] as String,
      acceptsChildren: acceptsChildren,
      properties: properties,
      dartClass: argResults!['class'] as String? ??
          '${componentName.pascalCase}Widget',
      importPath: argResults!['import'] as String? ??
          'package:${config.projectName}/shared/widgets/'
              '${componentName.snakeCase}_widget.dart',
      childParameter:
          acceptsChildren ? argResults!['child-parameter'] as String : null,
    );
    final result = await context.files.apply(
      root,
      [store.plan(root, component)],
      options,
    );
    return printResult(result);
  }

  StudioPropertyDescriptor _property(String value) {
    final parts = value.split(':');
    if (parts.length < 2 ||
        parts[0].trim().isEmpty ||
        parts[1].trim().isEmpty) {
      throw FormatException('Invalid component property: $value.');
    }
    const types = {
      'string',
      'number',
      'boolean',
      'color',
      'select',
      'binding',
    };
    final type = parts[1].trim();
    if (!types.contains(type)) {
      throw FormatException('Unsupported component property type: $type.');
    }
    final options = type == 'select' && parts.length > 2
        ? parts
            .sublist(2)
            .join(':')
            .split(',')
            .map((item) => item.trim())
            .where(
              (item) => item.isNotEmpty,
            )
            .toList(growable: false)
        : const <String>[];
    if (type == 'select' && options.isEmpty) {
      throw FormatException('Select property $value requires options.');
    }
    return StudioPropertyDescriptor(
      parts[0].trim(),
      type,
      options: options,
    );
  }

  String _words(String value) => value
      .replaceAllMapped(
        RegExp(r'(?<=[a-z0-9])(?=[A-Z])'),
        (_) => ' ',
      )
      .trim();
}
