import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/generation.dart';

/// Searchable provider/controller action exposed to Archsmith Studio.
class StudioActionDescriptor {
  const StudioActionDescriptor({
    required this.id,
    required this.feature,
    required this.operation,
    required this.stateManagement,
    required this.target,
    required this.method,
    required this.requestType,
    required this.parameters,
    this.state = const {},
    this.responseFields = const [],
  });

  factory StudioActionDescriptor.fromJson(Map<String, Object?> json) {
    final rawParameters = json['parameters'];
    if (rawParameters is! List) {
      throw const FormatException('Action parameters must be a list.');
    }
    return StudioActionDescriptor(
      id: _required(json, 'id'),
      feature: _required(json, 'feature'),
      operation: _required(json, 'operation'),
      stateManagement: _required(json, 'state_management'),
      target: _required(json, 'target'),
      method: _required(json, 'method'),
      requestType: _required(json, 'request_type'),
      parameters: rawParameters
          .map(
            (item) => StudioActionParameter.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false),
      state: Map.unmodifiable(
        Map<String, Object?>.from(json['state'] as Map? ?? const {}),
      ),
      responseFields: (json['response_fields'] as List? ?? const [])
          .map(
            (item) => StudioDataField.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  final String id;
  final String feature;
  final String operation;
  final String stateManagement;
  final String target;
  final String method;
  final String requestType;
  final List<StudioActionParameter> parameters;
  final Map<String, Object?> state;
  final List<StudioDataField> responseFields;

  Map<String, Object?> toJson() => {
        'id': id,
        'feature': feature,
        'operation': operation,
        'state_management': stateManagement,
        'target': target,
        'method': method,
        'request_type': requestType,
        'parameters': parameters.map((item) => item.toJson()).toList(),
        'state': state,
        'response_fields': responseFields.map((item) => item.toJson()).toList(),
      };
}

/// One typed argument accepted by a generated action.
class StudioActionParameter {
  const StudioActionParameter({
    required this.name,
    required this.type,
    this.required = true,
    this.isList = false,
    this.children = const [],
  });

  factory StudioActionParameter.fromJson(Map<String, Object?> json) =>
      StudioActionParameter(
        name: _required(json, 'name'),
        type: _required(json, 'type'),
        required: json['required'] as bool? ?? true,
        isList: json['is_list'] as bool? ?? false,
        children: (json['children'] as List? ?? const [])
            .map(
              (item) => StudioActionParameter.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );

  final String name;
  final String type;
  final bool required;
  final bool isList;
  final List<StudioActionParameter> children;

  Map<String, Object?> toJson() => {
        'name': name,
        'type': type,
        'required': required,
        'is_list': isList,
        if (children.isNotEmpty)
          'children': children.map((item) => item.toJson()).toList(),
      };
}

/// One response field available for visual state binding.
class StudioDataField {
  const StudioDataField({
    required this.name,
    required this.type,
    this.isList = false,
    this.children = const [],
  });

  factory StudioDataField.fromJson(Map<String, Object?> json) =>
      StudioDataField(
        name: _required(json, 'name'),
        type: _required(json, 'type'),
        isList: json['is_list'] as bool? ?? false,
        children: (json['children'] as List? ?? const [])
            .map(
              (item) => StudioDataField.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );

  final String name;
  final String type;
  final bool isList;
  final List<StudioDataField> children;

  Map<String, Object?> toJson() => {
        'name': name,
        'type': type,
        'is_list': isList,
        if (children.isNotEmpty)
          'children': children.map((item) => item.toJson()).toList(),
      };
}

/// Reads generated action descriptors from `.archsmith/actions`.
class StudioActionRegistry {
  const StudioActionRegistry();

  List<StudioActionDescriptor> readAll(String projectRoot) {
    final directory = Directory(
      p.join(projectRoot, '.archsmith', 'actions'),
    );
    if (!directory.existsSync()) return const [];
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.json')
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));
    return files.map((file) {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        throw FormatException('${file.path} must contain an object.');
      }
      return StudioActionDescriptor.fromJson(
        Map<String, Object?>.from(decoded),
      );
    }).toList(growable: false);
  }

  PlannedFile plan(String filename, StudioActionDescriptor action) =>
      PlannedFile(
        '.archsmith/actions/$filename.json',
        '${const JsonEncoder.withIndent('  ').convert(action.toJson())}\n',
      );
}

String _required(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value.trim();
}
