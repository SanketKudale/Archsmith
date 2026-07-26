import '../configuration/archsmith_config.dart';
import '../models/generation.dart';
import '../models/options.dart';
import '../utils/naming_utils.dart';
import 'action_registry.dart';
import 'component_registry.dart';
import 'ui_schema.dart';
import 'ui_validator.dart';

/// Converts a Studio schema into deterministic responsive Flutter source.
class UiCodeGenerator {
  const UiCodeGenerator();

  List<PlannedFile> generate({
    required ArchsmithConfig config,
    required UiScreenSchema schema,
    required List<StudioActionDescriptor> actions,
    StudioComponentRegistry components = const StudioComponentRegistry(),
    bool includeExtensionFile = true,
  }) {
    final issues = UiSchemaValidator(components: components).validate(
      schema,
      actions: actions,
    );
    if (issues.isNotEmpty) {
      throw FormatException(
        'Invalid UI schema:\n${issues.map((issue) => '- $issue').join('\n')}',
      );
    }

    final screen = names(schema.name);
    final feature = names(schema.feature ?? screen.snakeCase).snakeCase;
    final selectedActions = _selectedActions(schema.root, actions);
    for (final action in selectedActions) {
      if (action.stateManagement != config.stateManagement.value) {
        throw FormatException(
          'Action ${action.id} uses ${action.stateManagement}, but the '
          'project uses ${config.stateManagement.value}.',
        );
      }
    }
    final textFields = _nodes(schema.root)
        .where((node) => node.type == 'appTextField')
        .toList(growable: false);
    final renderer = _FlutterRenderer(
      config: config,
      schema: schema,
      actions: selectedActions,
      textFields: textFields,
      components: components,
    );
    final directory = _pageDirectory(config, feature);
    final files = <PlannedFile>[
      PlannedFile(
        '$directory/${screen.snakeCase}_page.archsmith.dart',
        renderer.generatedSource(screen.pascalCase),
        isUpdate: true,
      ),
    ];
    if (includeExtensionFile) {
      files.add(
        PlannedFile(
          '$directory/${screen.snakeCase}_page.dart',
          renderer.extensionSource(screen.pascalCase),
        ),
      );
    }
    return files;
  }
}

String _pageDirectory(ArchsmithConfig config, String feature) =>
    switch (config.architecture) {
      ArchitectureType.cleanFeature =>
        'lib/features/$feature/presentation/pages',
      ArchitectureType.mvvm => 'lib/features/$feature/views',
      ArchitectureType.cleanLayer => 'lib/presentation/pages',
      ArchitectureType.simpleFeature => 'lib/features/$feature/pages',
    };

class _FlutterRenderer {
  const _FlutterRenderer({
    required this.config,
    required this.schema,
    required this.actions,
    required this.textFields,
    required this.components,
  });

  final ArchsmithConfig config;
  final UiScreenSchema schema;
  final List<StudioActionDescriptor> actions;
  final List<UiNode> textFields;
  final StudioComponentRegistry components;

  String generatedSource(String classPrefix) {
    final imports = _imports();
    final invokedActions = _invokedActions().toList(growable: false);
    final callbackTypes = config.stateManagement != StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => 'typedef ${_pascal(action.id)}Action = Future<void> Function(${action.requestType} request);').join('\n')}\n\n';
    final callbackParameters = config.stateManagement !=
            StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '    required this.${_callbackName(action)},').join('\n')}\n';
    final callbackFields = config.stateManagement != StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '  final ${_pascal(action.id)}Action ${_callbackName(action)};').join('\n')}\n';
    final declaration = switch (config.stateManagement) {
      StateManagementType.riverpod =>
        'class ${classPrefix}PageView extends ConsumerStatefulWidget',
      _ => 'class ${classPrefix}PageView extends StatefulWidget',
    };
    final stateBase = switch (config.stateManagement) {
      StateManagementType.riverpod => 'ConsumerState<${classPrefix}PageView>',
      _ => 'State<${classPrefix}PageView>',
    };
    final controllerFields = textFields
        .map(
          (node) =>
              '  final _${_identifier(node.id)}Controller = TextEditingController();',
        )
        .join('\n');
    final dispose = textFields.isEmpty
        ? ''
        : '''

  @override
  void dispose() {
${textFields.map((node) => '    _${_identifier(node.id)}Controller.dispose();').join('\n')}
    super.dispose();
  }''';
    final breakpointMethods = schema.breakpoints
        .map(
          (breakpoint) => '  Widget _build${_pascal(breakpoint.name)}'
              '(BuildContext context) => '
              '${_widget(schema.root, breakpoint.name, 2)};\n',
        )
        .join('\n');
    final actionMethods = invokedActions.map(_actionMethod).join('\n');
    final validationHelper = invokedActions.any(_hasBoundInputs)
        ? '''
  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

'''
        : '';

    return '''$imports

/// Generated by Archsmith Studio. Regenerate this file; do not edit it.
$callbackTypes$declaration {
  const ${classPrefix}PageView({
$callbackParameters    super.key,
  });
$callbackFields

  @override
  State<${classPrefix}PageView> createState() => _${classPrefix}PageViewState();
}

class _${classPrefix}PageViewState extends $stateBase {
$controllerFields$dispose

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
${_breakpointSelection()}
        },
      );

$breakpointMethods
$actionMethods$validationHelper}
''';
  }

  String extensionSource(String classPrefix) {
    final invokedActions = _invokedActions().toList(growable: false);
    final callbackParameters = config.stateManagement !=
            StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '    required this.${_callbackName(action)},').join('\n')}\n';
    final callbackFields = config.stateManagement != StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '  final ${_pascal(action.id)}Action ${_callbackName(action)};').join('\n')}\n';
    final callbackArguments = config.stateManagement != StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '    ${_callbackName(action)}: ${_callbackName(action)},').join('\n')}\n';
    final constant =
        config.stateManagement == StateManagementType.none ? '' : 'const ';
    return '''
import 'package:flutter/material.dart';

import '${names(schema.name).snakeCase}_page.archsmith.dart';

/// Safe extension point. This file is created once and is never regenerated.
class ${classPrefix}Page extends StatelessWidget {
  const ${classPrefix}Page({
$callbackParameters    super.key,
  });
$callbackFields

  @override
  Widget build(BuildContext context) => $constant${classPrefix}PageView(
$callbackArguments  );
}
''';
  }

  String _imports() {
    final values = <String>{
      "import 'package:flutter/material.dart';",
      "import 'package:${config.projectName}/shared/widgets/common_widgets.dart';",
    };
    if (config.stateManagement == StateManagementType.riverpod) {
      values.add(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
      );
    } else if (actions.isNotEmpty) {
      switch (config.stateManagement) {
        case StateManagementType.riverpod:
          break;
        case StateManagementType.provider:
          values.add("import 'package:provider/provider.dart';");
        case StateManagementType.bloc:
          values.add("import 'package:flutter_bloc/flutter_bloc.dart';");
        case StateManagementType.getx:
          values.add("import 'package:get/get.dart';");
        case StateManagementType.none:
          break;
      }
    }
    for (final action in actions) {
      final operation = names(action.operation).snakeCase;
      values.add(
        "import 'package:${config.projectName}/features/${action.feature}/"
        "domain/entities/${operation}_request_entity.dart';",
      );
      if (config.stateManagement == StateManagementType.riverpod) {
        values.add(
          "import 'package:${config.projectName}/features/${action.feature}/"
          "presentation/providers/${operation}_provider.dart';",
        );
      } else if (config.stateManagement != StateManagementType.none) {
        values.add(
          "import 'package:${config.projectName}/features/${action.feature}/"
          "presentation/providers/${operation}_notifier.dart';",
        );
      }
    }
    for (final node in _nodes(schema.root)) {
      final component = components.find(node.type);
      final importPath = component?.importPath;
      if (importPath != null) {
        values.add("import '$importPath';");
      }
    }
    final sorted = values.toList()..sort();
    return sorted.join('\n');
  }

  String _breakpointSelection() {
    final ordered = schema.breakpoints.toList()
      ..sort(
        (left, right) => (right.minWidth ?? 0).compareTo(left.minWidth ?? 0),
      );
    final buffer = StringBuffer();
    for (final breakpoint in ordered) {
      final minimum = breakpoint.minWidth;
      if (minimum != null && minimum > 0) {
        buffer.writeln(
          '          if (constraints.maxWidth >= $minimum) {',
        );
        buffer.writeln(
          '            return _build${_pascal(breakpoint.name)}(context);',
        );
        buffer.writeln('          }');
      }
    }
    final fallback = ordered.lastWhere(
      (breakpoint) => breakpoint.minWidth == null || breakpoint.minWidth == 0,
      orElse: () => ordered.last,
    );
    buffer.write(
      '          return _build${_pascal(fallback.name)}(context);',
    );
    return buffer.toString();
  }

  String _widget(UiNode node, String breakpoint, int indent) {
    final properties = <String, Object?>{
      ...node.properties,
      ...?node.responsive[breakpoint],
    };
    final children = node.children
        .map((child) => _widget(child, breakpoint, indent + 2))
        .toList(growable: false);
    final child = children.isEmpty
        ? 'const SizedBox.shrink()'
        : children.length == 1
            ? children.first
            : 'Column(children: [${children.join(', ')}])';
    return switch (node.type) {
      'appScaffold' => 'AppScaffold('
          'title: ${_nullableString(properties['title'])}, '
          'padding: EdgeInsets.all(${_number(properties['padding'], 16)}), '
          'body: $child)',
      'column' => _axisWidget('Column', properties, children, indent),
      'row' => _axisWidget('Row', properties, children, indent),
      'wrap' => 'Wrap('
          'spacing: ${_number(properties['spacing'], 0)}, '
          'runSpacing: ${_number(properties['runSpacing'], 0)}, '
          'children: [${children.join(', ')}])',
      'container' => 'Container('
          '${_dimension('width', properties['width'])}'
          '${_dimension('height', properties['height'])}'
          'padding: EdgeInsets.all(${_number(properties['padding'], 0)}), '
          '${_decoration(properties)}'
          'child: $child)',
      'text' => 'Text(${_string((properties['text'] ?? 'Text').toString())}, '
          'textAlign: TextAlign.${properties['textAlign'] ?? 'left'}, '
          'style: TextStyle('
          'fontSize: ${_number(properties['fontSize'], 14)}, '
          'fontWeight: ${_fontWeight(properties['fontWeight'])}, '
          '${_colorValue('color', properties['color'])}'
          '))',
      'appTextField' => 'AppTextField('
          'controller: _${_identifier(node.id)}Controller, '
          'label: ${_nullableString(properties['label'])}, '
          'hint: ${_nullableString(properties['hint'])}, '
          'obscureText: ${properties['obscureText'] == true})',
      'appButton' => 'AppButton('
          'label: ${_string((properties['label'] ?? 'Continue').toString())}, '
          'onPressed: ${properties['enabled'] == false ? 'null' : _callback(node.action)})',
      'appLoadingIndicator' => _loadingWidget(node.action),
      'stateText' => _stateText(node, properties),
      'card' => 'Card('
          'elevation: ${_number(properties['elevation'], 1)}, '
          'child: Padding('
          'padding: EdgeInsets.all(${_number(properties['padding'], 16)}), '
          'child: $child))',
      'spacer' =>
        'SizedBox(height: ${_number(properties['size'], 16)}, width: ${_number(properties['size'], 16)})',
      _ => _customWidget(node, properties, children, child),
    };
  }

  String _customWidget(
    UiNode node,
    Map<String, Object?> properties,
    List<String> children,
    String child,
  ) {
    final component = components.find(node.type);
    if (component?.dartClass == null) return 'const SizedBox.shrink()';
    final arguments = component!.properties
        .where((property) => properties[property.name] != null)
        .map(
          (property) =>
              '${property.name}: ${_propertyValue(properties[property.name], property.type)}',
        )
        .toList();
    if (component.acceptsChildren) {
      if (component.childParameter == 'children') {
        arguments.add('children: [${children.join(', ')}]');
      } else {
        arguments.add('child: $child');
      }
    }
    return '${component.dartClass}(${arguments.join(', ')})';
  }

  String _propertyValue(Object? value, String type) {
    if (type == 'boolean') return value == true ? 'true' : 'false';
    if (type == 'number' && value is num) return value.toString();
    if (type == 'color' && value is String) {
      final color = _colorValue('color', value);
      if (color.isNotEmpty) {
        return color
            .replaceFirst('color: ', '')
            .replaceFirst(RegExp(r', $'), '');
      }
    }
    return _string(value.toString());
  }

  String _axisWidget(
    String type,
    Map<String, Object?> properties,
    List<String> children,
    int indent,
  ) {
    final gap = _number(properties['gap'], 0);
    final spaced = <String>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0 && gap != '0') {
        spaced.add(
          type == 'Row' ? 'SizedBox(width: $gap)' : 'SizedBox(height: $gap)',
        );
      }
      spaced.add(children[index]);
    }
    return '$type('
        'mainAxisAlignment: MainAxisAlignment.${properties['mainAxisAlignment'] ?? 'start'}, '
        'crossAxisAlignment: CrossAxisAlignment.${properties['crossAxisAlignment'] ?? 'center'}, '
        'children: [${spaced.join(', ')}])';
  }

  String _callback(UiActionBinding? binding) {
    if (binding == null) return 'null';
    return '_run${_pascal(binding.actionId)}';
  }

  String _loadingWidget(UiActionBinding? binding) {
    if (binding == null) return 'const AppLoadingIndicator()';
    return '${_stateExpression(binding.actionId, 'isLoading')} '
        '? const AppLoadingIndicator() : const SizedBox.shrink()';
  }

  String _stateText(UiNode node, Map<String, Object?> properties) {
    final binding = node.action;
    final fallback = _string((properties['fallback'] ?? '').toString());
    if (binding == null) return 'Text($fallback)';
    final field = properties['binding']?.toString() ?? 'error';
    return 'Text(${_stateExpression(binding.actionId, field)}'
        '?.toString() ?? $fallback)';
  }

  String _stateExpression(String actionId, String property) {
    final action = actions.singleWhere((item) => item.id == actionId);
    final state = switch (config.stateManagement) {
      StateManagementType.riverpod => 'ref.watch(${action.target}).$property',
      StateManagementType.provider =>
        'context.watch<${action.target}>().state.$property',
      StateManagementType.bloc =>
        'context.watch<${action.target}>().state.$property',
      StateManagementType.getx =>
        'Get.find<${action.target}>().state.value.$property',
      StateManagementType.none => 'null',
    };
    if (config.stateManagement == StateManagementType.none) return state;
    final base = switch (config.stateManagement) {
      StateManagementType.riverpod => 'ref.watch(${action.target})',
      StateManagementType.provider => 'context.watch<${action.target}>().state',
      StateManagementType.bloc => 'context.watch<${action.target}>().state',
      StateManagementType.getx => 'Get.find<${action.target}>().state.value',
      StateManagementType.none => 'null',
    };
    if (property.startsWith('data.')) {
      return '$base.data?.${property.substring('data.'.length)}';
    }
    if (property.startsWith('error.')) {
      return '$base.error?.${property.substring('error.'.length)}';
    }
    return '$base.$property';
  }

  String _actionMethod(StudioActionDescriptor action) {
    final binding = _nodes(schema.root)
        .map((node) => node.action)
        .whereType<UiActionBinding>()
        .firstWhere(
          (item) => item.actionId == action.id && item.method != 'watch',
        );
    final validations = StringBuffer();
    final variables = <String, String>{};
    for (final parameter in action.parameters) {
      final value = binding.arguments[parameter.name];
      final fieldId = _fieldReference(value);
      if (fieldId == null) continue;
      final matchingFields = textFields.where((node) => node.id == fieldId);
      final field = matchingFields.isEmpty ? null : matchingFields.first;
      if (field == null) continue;
      final variable =
          '_${_identifier(action.id)}${_pascal(parameter.name)}Value';
      variables[parameter.name] = variable;
      validations.write(
        _inputValidation(field, parameter, variable),
      );
    }
    final arguments = action.parameters.map((parameter) {
      final value = binding.arguments[parameter.name];
      return '      ${parameter.name}: '
          '${_argument(value, parameter.type, variable: variables[parameter.name])},';
    }).join('\n');
    final invoke = switch (config.stateManagement) {
      StateManagementType.riverpod =>
        'ref.read(${action.target}.notifier).${action.method}(request)',
      StateManagementType.provider =>
        'context.read<${action.target}>().${action.method}(request)',
      StateManagementType.bloc =>
        'context.read<${action.target}>().${action.method}(request)',
      StateManagementType.getx =>
        'Get.find<${action.target}>().${action.method}(request)',
      StateManagementType.none => 'widget.${_callbackName(action)}(request)',
    };
    final navigation = binding.onSuccessRoute == null
        ? ''
        : "\n    if (!mounted) return;"
            "\n    if (${_actionErrorExpression(action)} != null) return;"
            "\n    await Navigator.of(context).pushNamed("
            "${_string(binding.onSuccessRoute!)});";
    return '''
  Future<void> _run${_pascal(action.id)}() async {
$validations    final request = ${action.requestType}(
$arguments
    );
    await $invoke;$navigation
  }

''';
  }

  String _argument(
    Object? value,
    String type, {
    String? variable,
  }) {
    if (variable != null) return variable;
    if (value is String && value.startsWith(r'$') && value.endsWith('.value')) {
      final id = value.substring(1, value.length - '.value'.length);
      final source = '_${_identifier(id)}Controller.text';
      return switch (type) {
        'int' => 'int.parse($source)',
        'double' => 'double.parse($source)',
        'num' => 'num.parse($source)',
        'bool' => "$source.toLowerCase() == 'true'",
        _ => source,
      };
    }
    if (value is String) return _string(value);
    if (value == null) return 'null';
    return value.toString();
  }

  String _inputValidation(
    UiNode field,
    StudioActionParameter parameter,
    String variable,
  ) {
    final properties = field.properties;
    final source = '_${_identifier(field.id)}Controller.text';
    final textVariable = '${variable}Text';
    final trim = properties['trim'] != false ? '.trim()' : '';
    final label =
        (properties['label'] ?? properties['hint'] ?? field.id).toString();
    final customMessage = properties['validationMessage']?.toString();
    final buffer = StringBuffer(
      '    final $textVariable = $source$trim;\n',
    );
    void failure(String fallback) {
      buffer
        ..writeln(
          '    _showValidationError(${_string(customMessage ?? fallback)});',
        )
        ..writeln('    return;');
    }

    if (properties['required'] == true) {
      buffer.writeln('    if ($textVariable.isEmpty) {');
      failure('$label is required.');
      buffer.writeln('    }');
    }
    final minLength = properties['minLength'];
    if (minLength is num) {
      buffer.writeln('    if ($textVariable.length < $minLength) {');
      failure('$label must contain at least $minLength characters.');
      buffer.writeln('    }');
    }
    final maxLength = properties['maxLength'];
    if (maxLength is num) {
      buffer.writeln('    if ($textVariable.length > $maxLength) {');
      failure('$label cannot exceed $maxLength characters.');
      buffer.writeln('    }');
    }
    final pattern = properties['pattern'];
    if (pattern is String && pattern.isNotEmpty) {
      buffer.writeln(
        '    if (!RegExp(${_string(pattern)}).hasMatch($textVariable)) {',
      );
      failure('$label has an invalid format.');
      buffer.writeln('    }');
    }
    switch (parameter.type) {
      case 'int':
        buffer.writeln('    final $variable = int.tryParse($textVariable);');
      case 'double':
        buffer.writeln(
          '    final $variable = double.tryParse($textVariable);',
        );
      case 'num':
        buffer.writeln('    final $variable = num.tryParse($textVariable);');
      case 'bool':
        buffer.writeln(
          "    final ${variable}IsValid = $textVariable.toLowerCase() == 'true' || "
          "$textVariable.toLowerCase() == 'false';",
        );
        buffer.writeln('    if (!${variable}IsValid) {');
        failure('$label must be true or false.');
        buffer.writeln('    }');
        buffer.writeln(
          "    final $variable = $textVariable.toLowerCase() == 'true';",
        );
        return buffer.toString();
      default:
        buffer.writeln('    final $variable = $textVariable;');
        return buffer.toString();
    }
    buffer.writeln('    if ($variable == null) {');
    failure('$label must be a valid ${parameter.type}.');
    buffer.writeln('    }');
    return buffer.toString();
  }

  String _actionErrorExpression(StudioActionDescriptor action) =>
      switch (config.stateManagement) {
        StateManagementType.riverpod => 'ref.read(${action.target}).error',
        StateManagementType.provider =>
          'context.read<${action.target}>().state.error',
        StateManagementType.bloc =>
          'context.read<${action.target}>().state.error',
        StateManagementType.getx =>
          'Get.find<${action.target}>().state.value.error',
        StateManagementType.none => 'null',
      };

  bool _hasBoundInputs(StudioActionDescriptor action) {
    final bindings = _nodes(schema.root)
        .map((node) => node.action)
        .whereType<UiActionBinding>()
        .where(
          (item) => item.actionId == action.id && item.method != 'watch',
        );
    final binding = bindings.isEmpty ? null : bindings.first;
    return binding?.arguments.values.any(
          (value) => _fieldReference(value) != null,
        ) ??
        false;
  }

  String? _fieldReference(Object? value) {
    if (value is! String ||
        !value.startsWith(r'$') ||
        !value.endsWith('.value')) {
      return null;
    }
    return value.substring(1, value.length - '.value'.length);
  }

  String _decoration(Map<String, Object?> properties) {
    final color = properties['color'];
    final radius = properties['borderRadius'];
    if (color == null && radius == null) return '';
    return 'decoration: BoxDecoration('
        '${_colorValue('color', color)}'
        'borderRadius: BorderRadius.circular(${_number(radius, 0)})), ';
  }

  String _colorValue(String name, Object? value) {
    if (value is! String || value.isEmpty) return '';
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(normalized)) return '';
    return '$name: Color(0x$normalized), ';
  }

  String _dimension(String name, Object? value) =>
      value is num ? '$name: $value, ' : '';

  String _fontWeight(Object? value) => switch (value) {
        'bold' => 'FontWeight.bold',
        'medium' => 'FontWeight.w500',
        _ => 'FontWeight.normal',
      };

  String _number(Object? value, num fallback) =>
      value is num ? value.toString() : fallback.toString();

  String _nullableString(Object? value) =>
      value == null ? 'null' : _string(value.toString());

  String _string(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n')}'";

  Iterable<StudioActionDescriptor> _invokedActions() => actions.where(
        (action) => _nodes(schema.root).any(
          (node) =>
              node.action?.actionId == action.id &&
              node.action?.method != 'watch',
        ),
      );

  String _callbackName(StudioActionDescriptor action) =>
      '${_identifier(action.id)}Action';
}

List<UiNode> _nodes(UiNode root) => [
      root,
      for (final child in root.children) ..._nodes(child),
    ];

List<StudioActionDescriptor> _selectedActions(
  UiNode root,
  List<StudioActionDescriptor> actions,
) {
  final ids = _nodes(root)
      .map((node) => node.action?.actionId)
      .whereType<String>()
      .toSet();
  return actions.where((action) => ids.contains(action.id)).toList()
    ..sort((left, right) => left.id.compareTo(right.id));
}

String _identifier(String value) {
  final result = names(value).camelCase.replaceAll(
        RegExp('[^A-Za-z0-9_]'),
        '',
      );
  return result.isEmpty ? 'field' : result;
}

String _pascal(String value) => value
    .split(RegExp(r'[^A-Za-z0-9]+'))
    .where((part) => part.isNotEmpty)
    .map(
      (part) => '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join();
