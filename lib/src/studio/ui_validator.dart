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
            for (final parameter
                in action.parameters.where((item) => item.required)) {
              if (!binding.arguments.containsKey(parameter.name)) {
                issues.add(
                  UiValidationIssue(
                    '$path.action.arguments',
                    'Missing required argument ${parameter.name}.',
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
