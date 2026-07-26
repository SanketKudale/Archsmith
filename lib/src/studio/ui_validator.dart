import 'action_registry.dart';
import 'component_registry.dart';
import 'design_system.dart';
import 'ui_schema.dart';

/// One validation message associated with a screen or node.
class UiValidationIssue {
  const UiValidationIssue(this.path, this.message);
  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Validates component types, IDs, breakpoints, and action bindings.
class UiSchemaValidator {
  const UiSchemaValidator({
    this.components = const StudioComponentRegistry(),
  });

  final StudioComponentRegistry components;

  List<UiValidationIssue> validate(
    UiScreenSchema schema, {
    Iterable<StudioActionDescriptor> actions = const [],
    StudioDesignTokens designTokens = const StudioDesignTokens(),
    StudioLocalizationCatalog localization = const StudioLocalizationCatalog(),
    Iterable<String> assets = const [],
  }) {
    final issues = <UiValidationIssue>[];
    final ids = <String>{};
    final breakpointNames = <String>{};
    for (final breakpoint in schema.breakpoints) {
      if (!breakpointNames.add(breakpoint.name)) {
        issues.add(
          UiValidationIssue(
            'breakpoints.${breakpoint.name}',
            'Breakpoint names must be unique.',
          ),
        );
      }
      if (breakpoint.minWidth != null &&
          breakpoint.maxWidth != null &&
          breakpoint.minWidth! > breakpoint.maxWidth!) {
        issues.add(
          UiValidationIssue(
            'breakpoints.${breakpoint.name}',
            'min_width cannot exceed max_width.',
          ),
        );
      }
      if ((breakpoint.minWidth ?? 0) < 0 || (breakpoint.maxWidth ?? 0) < 0) {
        issues.add(
          UiValidationIssue(
            'breakpoints.${breakpoint.name}',
            'Breakpoint widths cannot be negative.',
          ),
        );
      }
    }
    final orderedBreakpoints = schema.breakpoints.toList()
      ..sort(
        (left, right) => (left.minWidth ?? 0).compareTo(right.minWidth ?? 0),
      );
    for (var index = 1; index < orderedBreakpoints.length; index++) {
      final previous = orderedBreakpoints[index - 1];
      final current = orderedBreakpoints[index];
      if (previous.maxWidth == null ||
          previous.maxWidth! >= (current.minWidth ?? 0)) {
        issues.add(
          UiValidationIssue(
            'breakpoints.${current.name}',
            'Breakpoint ranges cannot overlap.',
          ),
        );
      }
    }
    final actionsById = {for (final action in actions) action.id: action};
    final assetSet = assets.toSet();
    final localizationKeys = localization.keys.toSet();
    final tokenKeys = <String>{
      ...designTokens.colors.keys.map((key) => 'colors.$key'),
      ...designTokens.spacing.keys.map((key) => 'spacing.$key'),
      ...designTokens.radii.keys.map((key) => 'radii.$key'),
      ...designTokens.fontSizes.keys.map((key) => 'fontSizes.$key'),
    };
    final nodesById = <String, UiNode>{};

    void collect(UiNode node) {
      nodesById[node.id] = node;
      for (final child in node.children) {
        collect(child);
      }
    }

    collect(schema.root);

    void validateParameter(
      StudioActionParameter parameter,
      Object? value,
      String path,
    ) {
      if (value == null) {
        if (parameter.required) {
          issues.add(
            UiValidationIssue(path, 'Missing required value.'),
          );
        }
        return;
      }
      if (parameter.isList) {
        if (value is! List) {
          issues.add(
            UiValidationIssue(path, 'Expected ${parameter.type}.'),
          );
          return;
        }
        final itemType = _listItemType(parameter.type);
        for (var index = 0; index < value.length; index++) {
          final itemPath = '$path[$index]';
          final Object? item = value[index];
          if (parameter.children.isEmpty) {
            if (!_literalMatches(item, itemType)) {
              issues.add(
                UiValidationIssue(
                  itemPath,
                  'Expected $itemType, received '
                  '${item?.runtimeType ?? 'null'}.',
                ),
              );
            }
          } else if (item is! Map) {
            issues.add(
              UiValidationIssue(itemPath, 'Expected a structured object.'),
            );
          } else {
            final object = Map<String, Object?>.from(item);
            for (final child in parameter.children) {
              validateParameter(
                child,
                object[child.name],
                '$itemPath.${child.name}',
              );
            }
          }
        }
        return;
      }
      if (parameter.children.isNotEmpty) {
        if (value is! Map) {
          issues.add(
            UiValidationIssue(path, 'Expected a structured object.'),
          );
          return;
        }
        final object = Map<String, Object?>.from(value);
        for (final child in parameter.children) {
          validateParameter(
            child,
            object[child.name],
            '$path.${child.name}',
          );
        }
        return;
      }
      final fieldId = _fieldReference(value);
      if (fieldId != null) {
        final field = nodesById[fieldId];
        if (field == null) {
          issues.add(
            UiValidationIssue(path, 'Unknown input field $fieldId.'),
          );
        } else if (field.type != 'appTextField') {
          issues.add(
            UiValidationIssue(path, '$fieldId is not an appTextField.'),
          );
        } else if (!_isPrimitive(parameter.type)) {
          issues.add(
            UiValidationIssue(
              path,
              '${parameter.type} cannot bind to a text field.',
            ),
          );
        }
      } else if (!_literalMatches(value, parameter.type)) {
        issues.add(
          UiValidationIssue(
            path,
            'Expected ${parameter.type}, received '
            '${value.runtimeType}.',
          ),
        );
      }
    }

    void visit(UiNode node, String path) {
      if (!ids.add(node.id)) {
        issues
            .add(UiValidationIssue(path, 'Node id ${node.id} is duplicated.'));
      }
      final component = components.find(node.type);
      if (component == null) {
        issues.add(
          UiValidationIssue(path, 'Unknown component type ${node.type}.'),
        );
      } else if (!component.acceptsChildren && node.children.isNotEmpty) {
        issues.add(
          UiValidationIssue(path, '${node.type} cannot contain children.'),
        );
      }
      void validateReference(
        Object? value,
        String propertyPath, [
        String? propertyType,
      ]) {
        if (value is String && value.startsWith(r'$token.')) {
          final key = value.substring(r'$token.'.length);
          if (!tokenKeys.contains(key)) {
            issues.add(
              UiValidationIssue(propertyPath, 'Unknown design token $key.'),
            );
          } else if (propertyType == 'color' && !key.startsWith('colors.')) {
            issues.add(
              UiValidationIssue(
                propertyPath,
                'Color properties require a colors token.',
              ),
            );
          } else if (propertyType == 'number' && key.startsWith('colors.')) {
            issues.add(
              UiValidationIssue(
                propertyPath,
                'Numeric properties cannot use a colors token.',
              ),
            );
          }
        }
        if (value is String && value.startsWith(r'$i18n.')) {
          final key = value.substring(r'$i18n.'.length);
          if (!localizationKeys.contains(key)) {
            issues.add(
              UiValidationIssue(propertyPath, 'Unknown localization key $key.'),
            );
          }
        }
      }

      for (final entry in node.properties.entries) {
        final propertyType = _propertyType(component, entry.key);
        validateReference(
          entry.value,
          '$path.properties.${entry.key}',
          propertyType,
        );
      }
      for (final responsive in node.responsive.entries) {
        for (final entry in responsive.value.entries) {
          final propertyType = _propertyType(component, entry.key);
          validateReference(
            entry.value,
            '$path.responsive.${responsive.key}.${entry.key}',
            propertyType,
          );
        }
      }
      if (node.type == 'imageAsset') {
        final asset = node.properties['asset']?.toString() ?? '';
        if (asset.isEmpty || !assetSet.contains(asset)) {
          issues.add(
            UiValidationIssue(
              '$path.properties.asset',
              'Select an existing project image asset.',
            ),
          );
        }
        final decorative = node.properties['decorative'] == true;
        final semanticLabel =
            node.properties['semanticLabel']?.toString() ?? '';
        if (!decorative && semanticLabel.isEmpty) {
          issues.add(
            UiValidationIssue(
              '$path.properties.semanticLabel',
              'Non-decorative images require a semantic label.',
            ),
          );
        }
      }
      if (node.type == 'appButton' &&
          ((node.properties['label'] ?? component?.defaults['label'])
                  ?.toString()
                  .trim()
                  .isEmpty ??
              true) &&
          (node.properties['semanticLabel']?.toString().trim().isEmpty ??
              true)) {
        issues.add(
          UiValidationIssue(
            path,
            'Buttons require visible text or a semantic label.',
          ),
        );
      }
      for (final breakpoint in node.responsive.keys) {
        if (!breakpointNames.contains(breakpoint)) {
          issues.add(
            UiValidationIssue(
              '$path.responsive.$breakpoint',
              'Unknown breakpoint.',
            ),
          );
        }
      }
      final binding = node.action;
      if ((node.type == 'stateList' || node.type == 'stateGrid') &&
          binding == null) {
        issues.add(
          UiValidationIssue(path, '${node.type} requires an API action.'),
        );
      }
      if (binding != null) {
        final action = actionsById[binding.actionId];
        if (action == null) {
          issues.add(
            UiValidationIssue(
              '$path.action',
              'Unknown action ${binding.actionId}.',
            ),
          );
        } else {
          if (node.type == 'stateText') {
            final stateBinding =
                node.properties['binding']?.toString() ?? 'error';
            final available = <String>{
              ...action.state.keys,
              ..._responsePaths(action.responseFields),
            };
            if (!available.contains(stateBinding)) {
              issues.add(
                UiValidationIssue(
                  '$path.properties.binding',
                  'Unknown state binding $stateBinding.',
                ),
              );
            }
          }
          if (node.type == 'stateList' || node.type == 'stateGrid') {
            final listPath = node.properties['binding']?.toString() ?? '';
            final listField = _findResponseField(
              action.responseFields,
              listPath,
            );
            if (listField == null || !listField.isList) {
              issues.add(
                UiValidationIssue(
                  '$path.properties.binding',
                  'Select a list-valued response binding.',
                ),
              );
            } else {
              final itemPath =
                  node.properties['itemTextPath']?.toString() ?? '';
              final itemPaths = _responseItemPaths(listField.children).toSet();
              if (itemPath.isNotEmpty && !itemPaths.contains(itemPath)) {
                issues.add(
                  UiValidationIssue(
                    '$path.properties.itemTextPath',
                    'Unknown list item binding $itemPath.',
                  ),
                );
              }
            }
          }
          if (binding.method != 'watch') {
            for (final parameter in action.parameters) {
              if (!binding.arguments.containsKey(parameter.name)) {
                if (parameter.required) {
                  issues.add(
                    UiValidationIssue(
                      '$path.action.arguments',
                      'Missing required argument ${parameter.name}.',
                    ),
                  );
                }
                continue;
              }
              validateParameter(
                parameter,
                binding.arguments[parameter.name],
                '$path.action.arguments.${parameter.name}',
              );
            }
          }
        }
      }
      for (var actionIndex = 0;
          actionIndex < node.actions.length;
          actionIndex++) {
        final flowBinding = node.actions[actionIndex];
        final actionPath = '$path.actions[$actionIndex]';
        final action = actionsById[flowBinding.actionId];
        if (action == null) {
          issues.add(
            UiValidationIssue(
              actionPath,
              'Unknown action ${flowBinding.actionId}.',
            ),
          );
          continue;
        }
        if (flowBinding.method == 'watch') {
          issues.add(
            UiValidationIssue(
              actionPath,
              'Flow steps must invoke an action, not watch it.',
            ),
          );
          continue;
        }
        for (final parameter in action.parameters) {
          if (!flowBinding.arguments.containsKey(parameter.name)) {
            if (parameter.required) {
              issues.add(
                UiValidationIssue(
                  '$actionPath.arguments',
                  'Missing required argument ${parameter.name}.',
                ),
              );
            }
            continue;
          }
          validateParameter(
            parameter,
            flowBinding.arguments[parameter.name],
            '$actionPath.arguments.${parameter.name}',
          );
        }
      }
      for (var index = 0; index < node.children.length; index++) {
        visit(node.children[index], '$path.children[$index]');
      }
    }

    visit(schema.root, 'root');
    return List.unmodifiable(issues);
  }
}

String? _fieldReference(Object? value) {
  if (value is! String ||
      !value.startsWith(r'$') ||
      !value.endsWith('.value')) {
    return null;
  }
  return value.substring(1, value.length - '.value'.length);
}

bool _isPrimitive(String type) =>
    const {'String', 'int', 'double', 'num', 'bool', 'dynamic'}.contains(type);

String? _propertyType(
  StudioComponentDescriptor? component,
  String name,
) {
  if (component == null) return null;
  for (final property in component.properties) {
    if (property.name == name) return property.type;
  }
  return null;
}

bool _literalMatches(Object? value, String type) {
  if (value == null) return false;
  return switch (type) {
    'String' => value is String,
    'int' => value is int,
    'double' => value is num,
    'num' => value is num,
    'bool' => value is bool,
    'dynamic' => true,
    _ => false,
  };
}

String _listItemType(String type) {
  if (type.startsWith('List<') && type.endsWith('>')) {
    return type.substring(5, type.length - 1);
  }
  return 'dynamic';
}

Iterable<String> _responsePaths(
  Iterable<StudioDataField> fields, [
  String prefix = 'data',
]) sync* {
  for (final field in fields) {
    final path = '$prefix.${field.name}';
    if (field.isList || field.children.isEmpty) {
      yield path;
    } else {
      yield* _responsePaths(field.children, path);
    }
  }
}

StudioDataField? _findResponseField(
  Iterable<StudioDataField> fields,
  String path, [
  String prefix = 'data',
]) {
  for (final field in fields) {
    final current = '$prefix.${field.name}';
    if (current == path) return field;
    final nested = _findResponseField(field.children, path, current);
    if (nested != null) return nested;
  }
  return null;
}

Iterable<String> _responseItemPaths(
  Iterable<StudioDataField> fields, [
  String prefix = '',
]) sync* {
  for (final field in fields) {
    final path = prefix.isEmpty ? field.name : '$prefix.${field.name}';
    if (field.isList || field.children.isEmpty) {
      yield path;
    } else {
      yield* _responseItemPaths(field.children, path);
    }
  }
}
