import '../configuration/archsmith_config.dart';
import '../models/generation.dart';
import '../models/options.dart';
import '../utils/naming_utils.dart';
import 'action_registry.dart';
import 'component_registry.dart';
import 'design_system.dart';
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
    StudioDesignTokens designTokens = const StudioDesignTokens(),
    StudioLocalizationCatalog localization = const StudioLocalizationCatalog(),
    Iterable<String> assets = const [],
    bool includeExtensionFile = true,
  }) {
    final issues = UiSchemaValidator(components: components).validate(
      schema,
      actions: actions,
      designTokens: designTokens,
      localization: localization,
      assets: assets,
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
      designTokens: designTokens,
      localization: localization,
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
    if (_containsReference(schema.root, r'$token.')) {
      files.add(
        PlannedFile(
          'lib/shared/theme/archsmith_design_tokens.dart',
          designTokens.dartSource(),
          isUpdate: true,
        ),
      );
    }
    if (_containsReference(schema.root, r'$i18n.')) {
      files.add(
        PlannedFile(
          'lib/shared/localization/archsmith_localizations.dart',
          localization.dartSource(),
          isUpdate: true,
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
    required this.designTokens,
    required this.localization,
  });

  final ArchsmithConfig config;
  final UiScreenSchema schema;
  final List<StudioActionDescriptor> actions;
  final List<UiNode> textFields;
  final StudioComponentRegistry components;
  final StudioDesignTokens designTokens;
  final StudioLocalizationCatalog localization;

  String generatedSource(String classPrefix) {
    final imports = _imports();
    final invokedActions = _invokedActions().toList(growable: false);
    final callbackTypes = config.stateManagement != StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => 'typedef ${_pascal(action.id)}Action = Future<void> Function(${action.requestType} request);').join('\n')}\n\n';
    final callbackParameters = config.stateManagement !=
            StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '    this.${_callbackName(action)},').join('\n')}\n';
    final stateParameters = config.stateManagement != StateManagementType.none
        ? ''
        : '${actions.map((action) => '    this.${_stateCallbackName(action)},').join('\n')}\n';
    final callbackFields = config.stateManagement != StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '  final ${_pascal(action.id)}Action? ${_callbackName(action)};').join('\n')}\n';
    final stateFields = config.stateManagement != StateManagementType.none
        ? ''
        : '${actions.map((action) => '  final ValueListenable<${_stateType(action)}>? ${_stateCallbackName(action)};').join('\n')}\n';
    final routeParameters = schema.routeArguments
        .map(
          (argument) =>
              '    ${argument.required ? 'required ' : ''}this.${argument.name},',
        )
        .join('\n');
    final routeFields = schema.routeArguments
        .map(
          (argument) =>
              '  final ${argument.type}${argument.required ? '' : '?'} ${argument.name};',
        )
        .join('\n');
    final declaration = switch (config.stateManagement) {
      StateManagementType.riverpod =>
        'class ${classPrefix}PageView extends ConsumerStatefulWidget',
      _ => 'class ${classPrefix}PageView extends StatefulWidget',
    };
    final stateBase = switch (config.stateManagement) {
      StateManagementType.riverpod => 'ConsumerState<${classPrefix}PageView>',
      _ => 'State<${classPrefix}PageView>',
    };
    final stateReturnType = switch (config.stateManagement) {
      StateManagementType.riverpod => 'ConsumerState<${classPrefix}PageView>',
      _ => 'State<${classPrefix}PageView>',
    };
    final controllerFields = textFields
        .map(
          (node) =>
              '  final _${_identifier(node.id)}Controller = TextEditingController();',
        )
        .join('\n');
    final fallbackStateFields =
        config.stateManagement != StateManagementType.none
            ? ''
            : actions
                .map(
                  (action) =>
                      '  final _${_stateCallbackName(action)}Fallback = '
                      'ValueNotifier<${_stateType(action)}>('
                      'const ${_stateType(action)}());',
                )
                .join('\n');
    final flowFields = _flowNodes()
        .map(
          (node) => '  int _${_identifier(node.id)}FlowGeneration = 0;',
        )
        .join('\n');
    final dispose = textFields.isEmpty && fallbackStateFields.isEmpty
        ? ''
        : '''

  @override
  void dispose() {
${textFields.map((node) => '    _${_identifier(node.id)}Controller.dispose();').join('\n')}
${config.stateManagement == StateManagementType.none ? actions.map((action) => '    _${_stateCallbackName(action)}Fallback.dispose();').join('\n') : ''}
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
    final flowMethods = _flowNodes().map(_actionFlowMethod).join('\n');
    final validationHelper = invokedActions.any(_hasBoundInputs)
        ? '''
  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

'''
        : '';
    final actionMessageHelper = _nodes(schema.root).expand(_bindings).any(
            (binding) =>
                binding.successMessage != null || binding.errorMessage != null)
        ? '''
  void _showActionMessage(String message) {
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
$callbackParameters$stateParameters$routeParameters
    super.key,
  });
$callbackFields$stateFields$routeFields

  @override
  $stateReturnType createState() => _${classPrefix}PageViewState();
}

class _${classPrefix}PageViewState extends $stateBase {
$controllerFields
$fallbackStateFields
$flowFields$dispose

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
${_breakpointSelection()}
        },
      );

$breakpointMethods
$actionMethods$flowMethods$validationHelper$actionMessageHelper}
''';
  }

  String extensionSource(String classPrefix) {
    final invokedActions = _invokedActions().toList(growable: false);
    final callbackParameters = config.stateManagement !=
            StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '    this.${_callbackName(action)},').join('\n')}\n';
    final stateParameters = config.stateManagement != StateManagementType.none
        ? ''
        : '${actions.map((action) => '    this.${_stateCallbackName(action)},').join('\n')}\n';
    final callbackFields = config.stateManagement != StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '  final ${_pascal(action.id)}Action? ${_callbackName(action)};').join('\n')}\n';
    final stateFields = config.stateManagement != StateManagementType.none
        ? ''
        : '${actions.map((action) => '  final ValueListenable<${_stateType(action)}>? ${_stateCallbackName(action)};').join('\n')}\n';
    final callbackArguments = config.stateManagement != StateManagementType.none
        ? ''
        : '${invokedActions.map((action) => '    ${_callbackName(action)}: ${_callbackName(action)},').join('\n')}\n';
    final stateArguments = config.stateManagement != StateManagementType.none
        ? ''
        : '${actions.map((action) => '    ${_stateCallbackName(action)}: ${_stateCallbackName(action)},').join('\n')}\n';
    final routeParameters = schema.routeArguments
        .map(
          (argument) =>
              '    ${argument.required ? 'required ' : ''}this.${argument.name},',
        )
        .join('\n');
    final routeFields = schema.routeArguments
        .map(
          (argument) =>
              '  final ${argument.type}${argument.required ? '' : '?'} ${argument.name};',
        )
        .join('\n');
    final routeArguments = schema.routeArguments
        .map((argument) => '    ${argument.name}: ${argument.name},')
        .join('\n');
    final frameworkImports = config.stateManagement != StateManagementType.none
        ? ''
        : "import 'package:flutter/foundation.dart';\n"
            '${actions.map((action) => "import 'package:${config.projectName}/features/${action.feature}/presentation/states/${names(action.operation).snakeCase}_state.dart';").join('\n')}\n';
    return '''
import 'package:flutter/material.dart';
$frameworkImports

import '${names(schema.name).snakeCase}_page.archsmith.dart';

/// Safe extension point. This file is created once and is never regenerated.
class ${classPrefix}Page extends StatelessWidget {
  const ${classPrefix}Page({
$callbackParameters$stateParameters$routeParameters
    super.key,
  });
$callbackFields$stateFields$routeFields

  @override
  Widget build(BuildContext context) => ${classPrefix}PageView(
$callbackArguments$stateArguments$routeArguments  );
}
''';
  }

  String _imports() {
    final values = <String>{
      "import 'package:flutter/material.dart';",
      "import 'package:${config.projectName}/shared/widgets/common_widgets.dart';",
    };
    if (config.stateManagement == StateManagementType.none &&
        actions.isNotEmpty) {
      values.add("import 'package:flutter/foundation.dart';");
    }
    if (_containsReference(schema.root, r'$token.')) {
      values.add(
        "import 'package:${config.projectName}/shared/theme/archsmith_design_tokens.dart';",
      );
    }
    if (_containsReference(schema.root, r'$i18n.')) {
      values.add(
        "import 'package:${config.projectName}/shared/localization/archsmith_localizations.dart';",
      );
    }
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
      } else {
        values.add(
          "import 'package:${config.projectName}/features/${action.feature}/"
          "presentation/states/${operation}_state.dart';",
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
          'title: ${_localized(properties['title'], nullable: true)}, '
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
      'text' => 'Text(${_localized(properties['text'] ?? 'Text')}, '
          'textAlign: TextAlign.${properties['textAlign'] ?? 'left'}, '
          'style: TextStyle('
          'fontSize: ${_number(properties['fontSize'], 14)}, '
          'fontWeight: ${_fontWeight(properties['fontWeight'])}, '
          '${_colorValue('color', properties['color'])}'
          '))',
      'appTextField' => 'AppTextField('
          'controller: _${_identifier(node.id)}Controller, '
          'label: ${_localized(properties['label'], nullable: true)}, '
          'hint: ${_localized(properties['hint'], nullable: true)}, '
          'obscureText: ${properties['obscureText'] == true})',
      'appButton' => _button(node, properties),
      'imageAsset' => _imageAsset(properties),
      'appLoadingIndicator' => _loadingWidget(node.action),
      'offlineBanner' => _offlineBanner(node, properties),
      'stateText' => _stateText(node, properties),
      'stateList' => _stateCollection(node, properties, isGrid: false),
      'stateGrid' => _stateCollection(node, properties, isGrid: true),
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

  String _callback(UiNode node) {
    final executable = _executableBindings(node);
    if (executable.isEmpty) return 'null';
    if (_needsFlow(node)) return '_run${_pascal(node.id)}Flow';
    return '_run${_pascal(executable.single.actionId)}';
  }

  String _button(UiNode node, Map<String, Object?> properties) {
    final label = _localized(properties['label'] ?? 'Continue');
    final callback = properties['enabled'] == false ? 'null' : _callback(node);
    var widget = 'AppButton(label: $label, onPressed: $callback)';
    final tooltip = properties['tooltip'];
    if (tooltip != null && tooltip.toString().isNotEmpty) {
      widget = 'Tooltip(message: ${_localized(tooltip)}, child: $widget)';
    }
    final semantics = properties['semanticLabel'];
    if (semantics != null && semantics.toString().isNotEmpty) {
      widget = 'Semantics(label: ${_localized(semantics)}, '
          'button: true, child: $widget)';
    }
    return widget;
  }

  String _imageAsset(Map<String, Object?> properties) {
    final asset = properties['asset']?.toString() ?? '';
    if (asset.isEmpty) return 'const SizedBox.shrink()';
    final decorative = properties['decorative'] == true;
    final semantics = properties['semanticLabel'];
    return 'Image.asset(${_string(asset)}, '
        '${_dimension('width', properties['width'])}'
        '${_dimension('height', properties['height'])}'
        'fit: BoxFit.${properties['fit'] ?? 'contain'}, '
        'excludeFromSemantics: $decorative, '
        'semanticLabel: ${decorative ? 'null' : _localized(semantics, nullable: true)})';
  }

  String _loadingWidget(UiActionBinding? binding) {
    if (binding == null) return 'const AppLoadingIndicator()';
    final action = actions.singleWhere((item) => item.id == binding.actionId);
    return _stateBuilder(
      action,
      'return state.isLoading ? const AppLoadingIndicator() : '
      'const SizedBox.shrink();',
    );
  }

  String _offlineBanner(
    UiNode node,
    Map<String, Object?> properties,
  ) {
    final binding = node.action;
    if (binding == null) {
      return 'const SizedBox.shrink()';
    }
    final action = actions.singleWhere((item) => item.id == binding.actionId);
    final message = _localized(
      properties['message'] ?? 'You are offline. Showing saved data.',
    );
    final retry = properties['showRetry'] == false
        ? 'const SizedBox.shrink()'
        : 'TextButton(onPressed: state.retry, child: Text('
            '${_localized(properties['retryLabel'] ?? 'Retry')}))';
    return _stateBuilder(
        action,
        'if (!state.isOffline) return const SizedBox.shrink(); '
        'return MaterialBanner(content: Text($message), actions: [$retry]); ');
  }

  String _stateText(UiNode node, Map<String, Object?> properties) {
    final binding = node.action;
    final fallback = _string((properties['fallback'] ?? '').toString());
    if (binding == null) return 'Text($fallback)';
    final field = properties['binding']?.toString() ?? 'error';
    final action = actions.singleWhere((item) => item.id == binding.actionId);
    return _stateBuilder(
      action,
      'return Text(${_propertyFromState('state', field)}'
      '?.toString() ?? $fallback);',
    );
  }

  String _stateCollection(
    UiNode node,
    Map<String, Object?> properties, {
    required bool isGrid,
  }) {
    final binding = node.action;
    final listPath = properties['binding']?.toString() ?? '';
    if (binding == null || listPath.isEmpty) {
      return 'const SizedBox.shrink()';
    }
    final action = actions.singleWhere((item) => item.id == binding.actionId);
    final listExpression = _propertyFromState('state', listPath);
    final itemPath = properties['itemTextPath']?.toString() ?? '';
    final itemExpression = itemPath.isEmpty ? 'item' : 'item.$itemPath';
    final emptyText = _string(
      (properties['emptyText'] ?? 'No items').toString(),
    );
    final errorText = _string(
      (properties['errorText'] ?? 'Could not load items').toString(),
    );
    final shrinkWrap = properties['shrinkWrap'] != false;
    final refreshable = properties['refreshable'] != false;
    final physics = refreshable
        ? 'const AlwaysScrollableScrollPhysics()'
        : shrinkWrap
            ? 'const NeverScrollableScrollPhysics()'
            : 'null';
    final collection = isGrid
        ? 'GridView.builder('
            'shrinkWrap: $shrinkWrap, '
            'physics: $physics, '
            'gridDelegate: SliverGridDelegateWithFixedCrossAxisCount('
            'crossAxisCount: ${_integer(properties['columns'], 2)}, '
            'crossAxisSpacing: ${_number(properties['spacing'], 0)}, '
            'mainAxisSpacing: ${_number(properties['spacing'], 0)}, '
            'childAspectRatio: ${_number(properties['childAspectRatio'], 1)}), '
            'itemCount: items.length, '
            'itemBuilder: (context, index) { '
            'final item = items[index]; '
            'return Card(child: Center(child: Text($itemExpression.toString()))); '
            '})'
        : 'ListView.separated('
            'shrinkWrap: $shrinkWrap, '
            'physics: $physics, '
            'itemCount: items.length, '
            'separatorBuilder: (context, index) => SizedBox(height: ${_number(properties['separator'], 0)}), '
            'itemBuilder: (context, index) { '
            'final item = items[index]; '
            'return Text($itemExpression.toString()); '
            '})';
    final presented = refreshable
        ? 'RefreshIndicator(onRefresh: state.retry, child: $collection)'
        : collection;
    final paginated = node.actions.isEmpty
        ? presented
        : 'Column(mainAxisSize: MainAxisSize.min, children: ['
            '$presented, '
            'AppButton(label: ${_localized(properties['paginationLabel'] ?? 'Load more')}, '
            'onPressed: ${_callback(node)})])';
    return _stateBuilder(
        action,
        'final items = $listExpression ?? const []; '
        'if (state.isLoading && items.isEmpty) return const AppLoadingIndicator(); '
        'if (state.error != null && items.isEmpty) return Text($errorText); '
        'if (items.isEmpty) return Text($emptyText); '
        'return $paginated; ');
  }

  String _stateBuilder(
    StudioActionDescriptor action,
    String body,
  ) {
    if (config.stateManagement == StateManagementType.none) {
      return 'ValueListenableBuilder<${_stateType(action)}>('
          'valueListenable: ${_stateListenable(action)}, '
          'builder: (context, state, _) { $body })';
    }
    final builder = 'Builder(builder: (context) { '
        'final state = ${_watchedState(action)}; '
        '$body })';
    return config.stateManagement == StateManagementType.getx
        ? 'Obx(() => $builder)'
        : builder;
  }

  String _watchedState(StudioActionDescriptor action) =>
      switch (config.stateManagement) {
        StateManagementType.riverpod => 'ref.watch(${action.target})',
        StateManagementType.provider =>
          'context.watch<${action.target}>().state',
        StateManagementType.bloc => 'context.watch<${action.target}>().state',
        StateManagementType.getx => 'Get.find<${action.target}>().state.value',
        StateManagementType.none => '${_stateListenable(action)}.value',
      };

  String _propertyFromState(String base, String property) {
    if (property.startsWith('data.')) {
      return '$base.data?.${property.substring('data.'.length)}';
    }
    if (property.startsWith('error.')) {
      return '$base.error?.${property.substring('error.'.length)}';
    }
    return '$base.$property';
  }

  String _actionMethod(StudioActionDescriptor action) {
    final binding = _nodes(schema.root).expand(_bindings).firstWhere(
          (item) => item.actionId == action.id && item.method != 'watch',
        );
    final validations = StringBuffer();
    final variables = <String, String>{};
    final parameterValues = _parameterValues(
      action.parameters,
      binding.arguments,
    );
    for (final parameterValue in parameterValues) {
      final parameter = parameterValue.parameter;
      final value = parameterValue.value;
      final fieldId = _fieldReference(value);
      if (fieldId == null) continue;
      final matchingFields = textFields.where((node) => node.id == fieldId);
      final field = matchingFields.isEmpty ? null : matchingFields.first;
      if (field == null) continue;
      final variable = '_${_identifier(action.id)}'
          '${_pascal(parameterValue.path)}Value';
      variables[parameterValue.path] = variable;
      validations.write(
        _inputValidation(field, parameter, variable),
      );
    }
    final arguments = action.parameters.map((parameter) {
      final value = binding.arguments[parameter.name];
      return '      ${parameter.name}: '
          '${_parameterExpression(parameter, value, parameter.name, variables)},';
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
      StateManagementType.none =>
        '(widget.${_callbackName(action)}?.call(request) ?? Future<void>.value())',
    };
    final optimistic = binding.optimistic && action.supportsOptimistic
        ? _optimisticInvocation(action)
        : '';
    final resultHandling = StringBuffer()
      ..writeln('    if (!mounted) return;')
      ..writeln('    final actionError = ${_actionErrorExpression(action)};')
      ..writeln('    if (actionError != null) {');
    if (binding.errorMessage != null) {
      resultHandling.writeln(
        '      _showActionMessage(${_string(binding.errorMessage!)});',
      );
    }
    if (binding.onErrorRoute != null) {
      resultHandling.writeln(
        '      await Navigator.of(context).pushNamed('
        '${_string(binding.onErrorRoute!)});',
      );
    }
    resultHandling
      ..writeln('      return;')
      ..writeln('    }');
    if (binding.successMessage != null) {
      resultHandling.writeln(
        '    _showActionMessage(${_string(binding.successMessage!)});',
      );
    }
    if (binding.onSuccessRoute != null) {
      resultHandling.writeln(
        '    await Navigator.of(context).pushNamed('
        '${_string(binding.onSuccessRoute!)});',
      );
    }
    return '''
  Future<void> _run${_pascal(action.id)}() async {
$validations    final request = ${action.requestType}(
$arguments
    );
$optimistic
    await $invoke;
$resultHandling
  }

''';
  }

  String _actionFlowMethod(UiNode node) {
    final bindings = _executableBindings(node);
    final properties = node.properties;
    final generation = '_${_identifier(node.id)}FlowGeneration';
    final cancelPrevious = properties['cancelPrevious'] != false;
    final debounce = properties['debounceMs'] is num
        ? (properties['debounceMs'] as num).toInt()
        : 0;
    final buffer = StringBuffer(
      '  Future<void> _run${_pascal(node.id)}Flow() async {\n',
    );
    buffer.writeln('    final flowGeneration = ++$generation;');
    if (cancelPrevious) {
      for (final actionId
          in bindings.map((binding) => binding.actionId).toSet()) {
        final action = actions.singleWhere((item) => item.id == actionId);
        final cancellation = _actionCancellation(action);
        if (cancellation != null) buffer.writeln('    $cancellation;');
      }
    }
    if (debounce > 0) {
      buffer.writeln(
        '    await Future<void>.delayed('
        'const Duration(milliseconds: $debounce));',
      );
    }
    if (cancelPrevious) {
      buffer.writeln(
        '    if (!mounted || flowGeneration != $generation) return;',
      );
    }
    final confirmation = properties['confirmationMessage']?.toString() ?? '';
    if (confirmation.isNotEmpty) {
      final title =
          (properties['confirmationTitle'] ?? 'Please confirm').toString();
      buffer
        ..writeln('    final confirmed = await showDialog<bool>(')
        ..writeln('      context: context,')
        ..writeln('      builder: (context) => AlertDialog(')
        ..writeln('        title: Text(${_string(title)}),')
        ..writeln('        content: Text(${_string(confirmation)}),')
        ..writeln('        actions: [')
        ..writeln(
          "          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),",
        )
        ..writeln(
          "          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),",
        )
        ..writeln('        ],')
        ..writeln('      ),')
        ..writeln('    );')
        ..writeln('    if (confirmed != true || !mounted) return;');
    }
    buffer.writeln('    var previousSucceeded = true;');
    for (final binding in bindings) {
      final action = actions.singleWhere(
        (item) => item.id == binding.actionId,
      );
      final condition = switch (binding.runWhen) {
        'previousSuccess' => 'previousSucceeded',
        'previousError' => '!previousSucceeded',
        _ => 'true',
      };
      buffer
        ..writeln('    if ($condition) {')
        ..writeln('      await _run${_pascal(action.id)}();');
      if (cancelPrevious) {
        buffer.writeln(
          '      if (!mounted || flowGeneration != $generation) return;',
        );
      }
      buffer
        ..writeln(
          '      previousSucceeded = '
          '${_actionErrorExpression(action)} == null;',
        )
        ..writeln('    }');
    }
    buffer
      ..writeln('  }')
      ..writeln();
    return buffer.toString();
  }

  String _argument(
    Object? value,
    String type, {
    String? variable,
  }) {
    if (variable != null) return variable;
    if (value is String && value.startsWith(r'$route.')) {
      return 'widget.${value.substring(r'$route.'.length)}';
    }
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

  String _parameterExpression(
    StudioActionParameter parameter,
    Object? value,
    String path,
    Map<String, String> variables,
  ) {
    if (parameter.isList) {
      if (value is! List) return 'const []';
      final itemType = _listItemType(parameter.type);
      final items = <String>[];
      for (var index = 0; index < value.length; index++) {
        final item = value[index];
        final itemPath = '$path.$index';
        if (parameter.children.isEmpty) {
          items.add(_argument(item, itemType));
        } else {
          final object = item is Map
              ? Map<String, Object?>.from(item)
              : const <String, Object?>{};
          items.add(
            _entityExpression(
              itemType,
              parameter.children,
              object,
              itemPath,
              variables,
            ),
          );
        }
      }
      return '[${items.join(', ')}]';
    }
    if (parameter.children.isNotEmpty) {
      final object = value is Map
          ? Map<String, Object?>.from(value)
          : const <String, Object?>{};
      return _entityExpression(
        parameter.type,
        parameter.children,
        object,
        path,
        variables,
      );
    }
    return _argument(
      value,
      parameter.type,
      variable: variables[path],
    );
  }

  String _entityExpression(
    String type,
    List<StudioActionParameter> children,
    Map<String, Object?> values,
    String path,
    Map<String, String> variables,
  ) {
    final arguments = children.map(
      (child) => '${child.name}: ${_parameterExpression(
        child,
        values[child.name],
        '$path.${child.name}',
        variables,
      )}',
    );
    return '$type(${arguments.join(', ')})';
  }

  List<_ParameterValue> _parameterValues(
    List<StudioActionParameter> parameters,
    Map<String, Object?> values, [
    String prefix = '',
  ]) {
    final result = <_ParameterValue>[];
    for (final parameter in parameters) {
      final path =
          prefix.isEmpty ? parameter.name : '$prefix.${parameter.name}';
      final value = values[parameter.name];
      if (parameter.isList) {
        if (value is List && parameter.children.isNotEmpty) {
          for (var index = 0; index < value.length; index++) {
            final item = value[index];
            if (item is Map) {
              result.addAll(
                _parameterValues(
                  parameter.children,
                  Map<String, Object?>.from(item),
                  '$path.$index',
                ),
              );
            }
          }
        }
      } else if (parameter.children.isNotEmpty && value is Map) {
        result.addAll(
          _parameterValues(
            parameter.children,
            Map<String, Object?>.from(value),
            path,
          ),
        );
      } else {
        result.add(_ParameterValue(parameter, value, path));
      }
    }
    return result;
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
        StateManagementType.none => '${_stateListenable(action)}.value.error',
      };

  String? _actionCancellation(StudioActionDescriptor action) =>
      !action.supportsCancellation
          ? null
          : switch (config.stateManagement) {
              StateManagementType.riverpod =>
                'ref.read(${action.target}.notifier).cancel()',
              StateManagementType.provider =>
                'context.read<${action.target}>().cancel()',
              StateManagementType.bloc =>
                'context.read<${action.target}>().cancel()',
              StateManagementType.getx =>
                'Get.find<${action.target}>().cancel()',
              StateManagementType.none => null,
            };

  String _optimisticInvocation(StudioActionDescriptor action) {
    if (config.stateManagement == StateManagementType.none) return '';
    final state = switch (config.stateManagement) {
      StateManagementType.riverpod => 'ref.read(${action.target})',
      StateManagementType.provider => 'context.read<${action.target}>().state',
      StateManagementType.bloc => 'context.read<${action.target}>().state',
      StateManagementType.getx => 'Get.find<${action.target}>().state.value',
      StateManagementType.none => '',
    };
    final notifier = switch (config.stateManagement) {
      StateManagementType.riverpod => 'ref.read(${action.target}.notifier)',
      StateManagementType.provider => 'context.read<${action.target}>()',
      StateManagementType.bloc => 'context.read<${action.target}>()',
      StateManagementType.getx => 'Get.find<${action.target}>()',
      StateManagementType.none => '',
    };
    return '    final optimisticData = $state.data;\n'
        '    if (optimisticData != null) {\n'
        '      $notifier.applyOptimistic(optimisticData);\n'
        '    }';
  }

  bool _hasBoundInputs(StudioActionDescriptor action) {
    final bindings = _nodes(schema.root).expand(_bindings).where(
          (item) => item.actionId == action.id && item.method != 'watch',
        );
    final binding = bindings.isEmpty ? null : bindings.first;
    return binding?.arguments.values.any(
          _containsFieldReference,
        ) ??
        false;
  }

  bool _containsFieldReference(Object? value) {
    if (_fieldReference(value) != null) return true;
    if (value is List) return value.any(_containsFieldReference);
    if (value is Map) return value.values.any(_containsFieldReference);
    return false;
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
    final token = _tokenExpression(value);
    if (token != null) return '$name: $token, ';
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(normalized)) return '';
    return '$name: Color(0x$normalized), ';
  }

  String _dimension(String name, Object? value) {
    final token = _tokenExpression(value);
    if (token != null) return '$name: $token, ';
    return value is num ? '$name: $value, ' : '';
  }

  String _fontWeight(Object? value) => switch (value) {
        'bold' => 'FontWeight.bold',
        'medium' => 'FontWeight.w500',
        _ => 'FontWeight.normal',
      };

  String _number(Object? value, num fallback) =>
      _tokenExpression(value) ??
      (value is num ? value.toString() : fallback.toString());

  int _integer(Object? value, int fallback) =>
      value is num && value > 0 ? value.toInt() : fallback;

  String _localized(Object? value, {bool nullable = false}) {
    if (value == null) return nullable ? 'null' : "''";
    final text = value.toString();
    if (text.startsWith(r'$i18n.') && text.length > r'$i18n.'.length) {
      return 'ArchsmithLocalizations.text(context, '
          '${_string(text.substring(r'$i18n.'.length))})';
    }
    return _string(text);
  }

  String? _tokenExpression(Object? value) {
    if (value is! String ||
        !value.startsWith(r'$token.') ||
        value.length == r'$token.'.length) {
      return null;
    }
    return 'ArchsmithDesignTokens.'
        '${StudioDesignTokens.identifier(value.substring(r'$token.'.length))}';
  }

  String _string(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n')}'";

  Iterable<StudioActionDescriptor> _invokedActions() => actions.where(
        (action) => _nodes(schema.root).any(
          (node) => _bindings(node).any(
            (binding) =>
                binding.actionId == action.id && binding.method != 'watch',
          ),
        ),
      );

  Iterable<UiActionBinding> _bindings(UiNode node) sync* {
    if (node.action != null) yield node.action!;
    yield* node.actions;
  }

  List<UiActionBinding> _executableBindings(UiNode node) => _bindings(node)
      .where((binding) => binding.method != 'watch')
      .toList(growable: false);

  bool _needsFlow(UiNode node) {
    final bindings = _executableBindings(node);
    return bindings.length > 1 ||
        node.actions.isNotEmpty ||
        (node.properties['confirmationMessage']?.toString().isNotEmpty ??
            false) ||
        (node.properties['debounceMs'] is num &&
            (node.properties['debounceMs'] as num) > 0);
  }

  Iterable<UiNode> _flowNodes() =>
      _nodes(schema.root).where((node) => _needsFlow(node));

  String _callbackName(StudioActionDescriptor action) =>
      '${_identifier(action.id)}Action';

  String _stateCallbackName(StudioActionDescriptor action) =>
      '${_identifier(action.id)}State';

  String _stateListenable(StudioActionDescriptor action) =>
      '(widget.${_stateCallbackName(action)} ?? '
      '_${_stateCallbackName(action)}Fallback)';

  String _stateType(StudioActionDescriptor action) =>
      '${names(action.operation).pascalCase}State';
}

List<UiNode> _nodes(UiNode root) => [
      root,
      for (final child in root.children) ..._nodes(child),
    ];

bool _containsReference(UiNode root, String prefix) => _nodes(root).any(
      (node) =>
          _valueContainsReference(node.properties, prefix) ||
          _valueContainsReference(node.responsive, prefix) ||
          _valueContainsReference(node.action?.arguments, prefix) ||
          node.actions.any(
            (binding) => _valueContainsReference(binding.arguments, prefix),
          ),
    );

bool _valueContainsReference(Object? value, String prefix) {
  if (value is String) return value.startsWith(prefix);
  if (value is Map) {
    return value.values.any((item) => _valueContainsReference(item, prefix));
  }
  if (value is Iterable) {
    return value.any((item) => _valueContainsReference(item, prefix));
  }
  return false;
}

List<StudioActionDescriptor> _selectedActions(
  UiNode root,
  List<StudioActionDescriptor> actions,
) {
  final ids = _nodes(root)
      .expand(
        (node) => [
          if (node.action != null) node.action!.actionId,
          ...node.actions.map((binding) => binding.actionId),
        ],
      )
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

String _listItemType(String type) {
  if (type.startsWith('List<') && type.endsWith('>')) {
    return type.substring(5, type.length - 1);
  }
  return 'dynamic';
}

class _ParameterValue {
  const _ParameterValue(this.parameter, this.value, this.path);

  final StudioActionParameter parameter;
  final Object? value;
  final String path;
}
