import 'dart:convert';
import 'dart:io';

/// Current on-disk format understood by Archsmith Studio.
const archsmithUiSchemaVersion = 1;

/// A visual screen definition used to generate responsive Flutter code.
class UiScreenSchema {
  const UiScreenSchema({
    required this.name,
    required this.root,
    this.version = archsmithUiSchemaVersion,
    this.route,
    this.feature,
    this.breakpoints = defaultUiBreakpoints,
  });

  factory UiScreenSchema.fromJson(Map<String, Object?> json) {
    final version = json['version'] ?? archsmithUiSchemaVersion;
    if (version is! int || version != archsmithUiSchemaVersion) {
      throw FormatException(
        'Unsupported UI schema version: $version. '
        'Expected $archsmithUiSchemaVersion.',
      );
    }
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('UI screen name must be a non-empty string.');
    }
    final route = json['route'];
    if (route != null && (route is! String || !route.startsWith('/'))) {
      throw const FormatException('UI route must start with /.');
    }
    final rawRoot = json['root'];
    if (rawRoot is! Map) {
      throw const FormatException('UI screen root must be an object.');
    }
    final rawBreakpoints = json['breakpoints'];
    final breakpoints = rawBreakpoints == null
        ? defaultUiBreakpoints
        : _objectList(rawBreakpoints, 'breakpoints')
            .map(UiBreakpoint.fromJson)
            .toList(growable: false);
    return UiScreenSchema(
      version: version,
      name: name.trim(),
      route: route as String?,
      feature: json['feature']?.toString(),
      breakpoints: breakpoints,
      root: UiNode.fromJson(Map<String, Object?>.from(rawRoot)),
    );
  }

  final int version;
  final String name;
  final String? route;
  final String? feature;
  final List<UiBreakpoint> breakpoints;
  final UiNode root;

  Map<String, Object?> toJson() => {
        'version': version,
        'name': name,
        if (route != null) 'route': route,
        if (feature != null) 'feature': feature,
        'breakpoints': breakpoints.map((item) => item.toJson()).toList(),
        'root': root.toJson(),
      };
}

/// One responsive width range available in the Studio preview.
class UiBreakpoint {
  const UiBreakpoint({
    required this.name,
    this.minWidth,
    this.maxWidth,
  });

  factory UiBreakpoint.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Breakpoint name must be non-empty.');
    }
    return UiBreakpoint(
      name: name.trim(),
      minWidth: _number(json['min_width'], 'min_width'),
      maxWidth: _number(json['max_width'], 'max_width'),
    );
  }

  final String name;
  final num? minWidth;
  final num? maxWidth;

  Map<String, Object?> toJson() => {
        'name': name,
        if (minWidth != null) 'min_width': minWidth,
        if (maxWidth != null) 'max_width': maxWidth,
      };
}

/// A widget node in the visual component tree.
class UiNode {
  const UiNode({
    required this.id,
    required this.type,
    this.properties = const {},
    this.responsive = const {},
    this.children = const [],
    this.action,
    this.actions = const [],
  });

  factory UiNode.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final type = json['type'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Every UI node requires a non-empty id.');
    }
    if (type is! String || type.trim().isEmpty) {
      throw FormatException('UI node $id requires a non-empty type.');
    }
    final rawChildren = json['children'];
    final rawResponsive = _map(json['responsive'], 'responsive');
    return UiNode(
      id: id.trim(),
      type: type.trim(),
      properties: Map.unmodifiable(_map(json['properties'], 'properties')),
      responsive: Map.unmodifiable({
        for (final entry in rawResponsive.entries)
          entry.key: Map<String, Object?>.unmodifiable(
            _map(entry.value, 'responsive.${entry.key}'),
          ),
      }),
      children: rawChildren == null
          ? const []
          : _objectList(rawChildren, 'children')
              .map(UiNode.fromJson)
              .toList(growable: false),
      action: json['action'] == null
          ? null
          : UiActionBinding.fromJson(
              Map<String, Object?>.from(json['action'] as Map),
            ),
      actions: json['actions'] == null
          ? const []
          : _objectList(json['actions'], 'actions')
              .map(UiActionBinding.fromJson)
              .toList(growable: false),
    );
  }

  final String id;
  final String type;
  final Map<String, Object?> properties;
  final Map<String, Map<String, Object?>> responsive;
  final List<UiNode> children;
  final UiActionBinding? action;
  final List<UiActionBinding> actions;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        if (properties.isNotEmpty) 'properties': properties,
        if (responsive.isNotEmpty) 'responsive': responsive,
        if (children.isNotEmpty)
          'children': children.map((item) => item.toJson()).toList(),
        if (action != null) 'action': action!.toJson(),
        if (actions.isNotEmpty)
          'actions': actions.map((item) => item.toJson()).toList(),
      };
}

/// A visual event binding to a generated API provider or controller.
class UiActionBinding {
  const UiActionBinding({
    required this.actionId,
    this.method = 'execute',
    this.arguments = const {},
    this.onSuccessRoute,
    this.onErrorRoute,
    this.runWhen = 'always',
    this.successMessage,
    this.errorMessage,
  });

  factory UiActionBinding.fromJson(Map<String, Object?> json) {
    final actionId = json['action_id'];
    if (actionId is! String || actionId.trim().isEmpty) {
      throw const FormatException('Action binding requires action_id.');
    }
    final successRoute = json['on_success_route'];
    if (successRoute != null &&
        (successRoute is! String || !successRoute.startsWith('/'))) {
      throw const FormatException('Success route must start with /.');
    }
    final errorRoute = json['on_error_route'];
    if (errorRoute != null &&
        (errorRoute is! String || !errorRoute.startsWith('/'))) {
      throw const FormatException('Error route must start with /.');
    }
    final runWhen = json['run_when']?.toString() ?? 'always';
    if (!const {'always', 'previousSuccess', 'previousError'}
        .contains(runWhen)) {
      throw FormatException('Unsupported action condition: $runWhen.');
    }
    return UiActionBinding(
      actionId: actionId.trim(),
      method: json['method']?.toString() ?? 'execute',
      arguments: Map.unmodifiable(_map(json['arguments'], 'arguments')),
      onSuccessRoute: successRoute as String?,
      onErrorRoute: errorRoute as String?,
      runWhen: runWhen,
      successMessage: json['success_message']?.toString(),
      errorMessage: json['error_message']?.toString(),
    );
  }

  final String actionId;
  final String method;
  final Map<String, Object?> arguments;
  final String? onSuccessRoute;
  final String? onErrorRoute;
  final String runWhen;
  final String? successMessage;
  final String? errorMessage;

  Map<String, Object?> toJson() => {
        'action_id': actionId,
        'method': method,
        if (arguments.isNotEmpty) 'arguments': arguments,
        if (onSuccessRoute != null) 'on_success_route': onSuccessRoute,
        if (onErrorRoute != null) 'on_error_route': onErrorRoute,
        if (runWhen != 'always') 'run_when': runWhen,
        if (successMessage != null) 'success_message': successMessage,
        if (errorMessage != null) 'error_message': errorMessage,
      };
}

/// Reads and writes visual screen definitions.
class UiSchemaStore {
  const UiSchemaStore();

  UiScreenSchema read(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('UI schema was not found', path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw const FormatException('UI schema must contain a JSON object.');
    }
    return UiScreenSchema.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<void> write(String path, UiScreenSchema schema) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(schema.toJson())}\n');
  }
}

const defaultUiBreakpoints = [
  UiBreakpoint(name: 'mobile', maxWidth: 599),
  UiBreakpoint(name: 'tablet', minWidth: 600, maxWidth: 1023),
  UiBreakpoint(name: 'desktop', minWidth: 1024),
];

Map<String, Object?> _map(Object? value, String location) {
  if (value == null) return const {};
  if (value is! Map) throw FormatException('$location must be an object.');
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> _objectList(Object? value, String location) {
  if (value is! List) throw FormatException('$location must be a list.');
  return value.map((item) {
    if (item is! Map) {
      throw FormatException('$location entries must be objects.');
    }
    return Map<String, Object?>.from(item);
  }).toList(growable: false);
}

num? _number(Object? value, String location) {
  if (value == null) return null;
  if (value is! num) throw FormatException('$location must be a number.');
  return value;
}
