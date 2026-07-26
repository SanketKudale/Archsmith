import 'action_registry.dart';
import 'component_registry.dart';
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
    }
    final actionsById = {for (final action in actions) action.id: action};
    final nodesById = <String, UiNode>{};

    void collect(UiNode node) {
      nodesById[node.id] = node;
      for (final child in node.children) {
        collect(child);
      }
    }

    collect(schema.root);

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
              final value = binding.arguments[parameter.name];
              final fieldId = _fieldReference(value);
              if (fieldId != null) {
                final field = nodesById[fieldId];
                if (field == null) {
                  issues.add(
                    UiValidationIssue(
                      '$path.action.arguments.${parameter.name}',
                      'Unknown input field $fieldId.',
                    ),
                  );
                } else if (field.type != 'appTextField') {
                  issues.add(
                    UiValidationIssue(
                      '$path.action.arguments.${parameter.name}',
                      '$fieldId is not an appTextField.',
                    ),
                  );
                } else if (!_isPrimitive(parameter.type)) {
                  issues.add(
                    UiValidationIssue(
                      '$path.action.arguments.${parameter.name}',
                      '${parameter.type} requires structured entity mapping.',
                    ),
                  );
                }
              } else if (!_literalMatches(value, parameter.type)) {
                issues.add(
                  UiValidationIssue(
                    '$path.action.arguments.${parameter.name}',
                    'Expected ${parameter.type}, received '
                        '${value?.runtimeType ?? 'null'}.',
                  ),
                );
              }
            }
          }
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
