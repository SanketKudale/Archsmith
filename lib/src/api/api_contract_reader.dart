import 'dart:io';

import 'package:yaml/yaml.dart';

import 'api_contract.dart';

/// Parses and validates an Archsmith API contract.
class ApiContractReader {
  const ApiContractReader();

  ApiContract read(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('archsmith_api.yaml was not found', path);
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throw const FormatException(
        'archsmith_api.yaml must contain a YAML map.',
      );
    }
    return fromMap(_stringMap(document));
  }

  ApiContract fromMap(Map<String, Object?> map) {
    final baseUrl = _requiredString(map, 'base_url');
    final timeoutSeconds = map['timeout_seconds'] ?? 30;
    if (timeoutSeconds is! int || timeoutSeconds <= 0) {
      throw const FormatException(
        'timeout_seconds must be a positive integer.',
      );
    }
    final common = map['common'] == null
        ? const <String, Object?>{}
        : _map(map['common'], 'common');
    final models = <ApiModel>[];
    final modelNames = <String>{};

    final rawModels = map['models'];
    if (rawModels != null) {
      for (final entry in _map(rawModels, 'models').entries) {
        final model = _model(entry.key, entry.value, 'models.${entry.key}');
        _addModel(models, modelNames, model);
      }
    }

    final rawEndpoints = map['endpoints'];
    if (rawEndpoints is! List || rawEndpoints.isEmpty) {
      throw const FormatException('endpoints must be a non-empty YAML list.');
    }
    final endpoints = <ApiEndpoint>[];
    final endpointNames = <String>{};
    for (var index = 0; index < rawEndpoints.length; index++) {
      final source = _map(rawEndpoints[index], 'endpoints[$index]');
      final name = _requiredString(source, 'name');
      if (!endpointNames.add(name)) {
        throw FormatException('Duplicate endpoint name: $name.');
      }
      final request = source['request'] == null
          ? null
          : _payload(source['request'], '${name}Request', '$name.request');
      final response = _payload(
        source['response'],
        '${name}Response',
        '$name.response',
      );
      if (request != null && request.fields.isNotEmpty) {
        _addModel(models, modelNames, request);
      }
      if (response.fields.isNotEmpty) {
        _addModel(models, modelNames, response);
      }
      if (request != null &&
          request.fields.isEmpty &&
          !modelNames.contains(request.name)) {
        throw FormatException(
          '$name.request must define fields or reference a model declared '
          'under models.',
        );
      }
      if (response.fields.isEmpty && !modelNames.contains(response.name)) {
        throw FormatException(
          '$name.response must define fields or reference a model declared '
          'under models.',
        );
      }
      final method = _requiredString(source, 'method').toUpperCase();
      const methods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};
      if (!methods.contains(method)) {
        throw FormatException(
          '$name.method must be one of ${methods.join(', ')}.',
        );
      }
      final endpoint = ApiEndpoint(
        name: name,
        method: method,
        path: _requiredString(source, 'path'),
        headers: _strings(source['headers'], '$name.headers'),
        pathParameters: _fields(
          source['path_parameters'],
          '$name.path_parameters',
        ),
        queryParameters: _fields(
          source['query_parameters'],
          '$name.query_parameters',
        ),
        request: request,
        response: response,
      );
      _validatePathParameters(endpoint);
      endpoints.add(endpoint);
    }
    return ApiContract(
      baseUrl: baseUrl,
      headers: {
        ..._strings(map['headers'], 'headers'),
        ..._strings(common['headers'], 'common.headers'),
      },
      queryParameters: _jsonMap(
        common['query_parameters'],
        'common.query_parameters',
      ),
      bodyParameters: _jsonMap(
        common['body_parameters'],
        'common.body_parameters',
      ),
      responseHandling: _responseHandling(map['response_handling']),
      timeoutSeconds: timeoutSeconds,
      models: List.unmodifiable(models),
      endpoints: List.unmodifiable(endpoints),
    );
  }

  ApiResponseHandling _responseHandling(Object? value) {
    if (value == null) return const ApiResponseHandling();
    final source = _map(value, 'response_handling');
    final rawStatuses = source['success_status_codes'];
    final statuses = rawStatuses == null
        ? const <int>[]
        : _intList(rawStatuses, 'response_handling.success_status_codes');
    return ApiResponseHandling(
      dataKey: _optionalString(source, 'data_key'),
      successKey: _optionalString(source, 'success_key'),
      successValues: _jsonList(
        source['success_values'],
        'response_handling.success_values',
        const [true],
      ),
      errorKey: _optionalString(source, 'error_key'),
      errorValues: _jsonList(
        source['error_values'],
        'response_handling.error_values',
        const [true],
      ),
      messageKey: _optionalString(source, 'message_key') ?? 'message',
      codeKey: _optionalString(source, 'code_key') ?? 'code',
      errorsKey: _optionalString(source, 'errors_key') ?? 'errors',
      successStatusCodes: statuses,
    );
  }

  ApiModel _payload(Object? value, String fallbackName, String location) {
    final source = _map(value, location);
    final name = source['model']?.toString() ?? fallbackName;
    return ApiModel(
      name: name,
      fields: _fields(source['fields'], '$location.fields'),
    );
  }

  ApiModel _model(String name, Object? value, String location) {
    final source = _map(value, location);
    return ApiModel(
      name: name,
      fields: _fields(source['fields'], '$location.fields'),
    );
  }

  List<ApiField> _fields(Object? value, String location) {
    if (value == null) return const [];
    final source = _map(value, location);
    return source.entries
        .map((entry) {
          if (entry.value is String) {
            return ApiField(name: entry.key, type: entry.value! as String);
          }
          final details = _map(entry.value, '$location.${entry.key}');
          return ApiField(
            name: entry.key,
            type: _requiredString(details, 'type'),
            required: details['required'] is bool
                ? details['required']! as bool
                : true,
          );
        })
        .toList(growable: false);
  }

  void _addModel(List<ApiModel> models, Set<String> names, ApiModel model) {
    if (!names.add(model.name)) {
      throw FormatException('Duplicate API model name: ${model.name}.');
    }
    models.add(model);
  }

  void _validatePathParameters(ApiEndpoint endpoint) {
    final declared = endpoint.pathParameters.map((field) => field.name).toSet();
    final used = RegExp(
      r'\{([^}]+)\}',
    ).allMatches(endpoint.path).map((match) => match.group(1)!).toSet();
    if (declared.difference(used).isNotEmpty ||
        used.difference(declared).isNotEmpty) {
      throw FormatException(
        '${endpoint.name}.path_parameters must exactly match placeholders '
        'in ${endpoint.path}.',
      );
    }
    if (endpoint.pathParameters.any((field) => !field.required)) {
      throw FormatException(
        '${endpoint.name}.path_parameters cannot be optional.',
      );
    }
  }

  Map<String, String> _strings(Object? value, String location) {
    if (value == null) return const {};
    return _map(
      value,
      location,
    ).map((key, value) => MapEntry(key, value.toString()));
  }

  Map<String, Object?> _jsonMap(Object? value, String location) {
    if (value == null) return const {};
    return _map(
      value,
      location,
    ).map((key, value) => MapEntry(key, _jsonValue(value, '$location.$key')));
  }

  Object? _jsonValue(Object? value, String location) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is YamlMap || value is Map) {
      return _map(
        value,
        location,
      ).map((key, value) => MapEntry(key, _jsonValue(value, '$location.$key')));
    }
    if (value is List) {
      return value
          .asMap()
          .entries
          .map((entry) => _jsonValue(entry.value, '$location[${entry.key}]'))
          .toList(growable: false);
    }
    throw FormatException('$location must be JSON-compatible.');
  }

  List<int> _intList(Object? value, String location) {
    if (value is! List ||
        value.any((item) => item is! int || item < 100 || item > 599)) {
      throw FormatException(
        '$location must be a list of valid HTTP status codes.',
      );
    }
    return List<int>.unmodifiable(value.cast<int>());
  }

  List<Object?> _jsonList(
    Object? value,
    String location,
    List<Object?> fallback,
  ) {
    if (value == null) return fallback;
    if (value is! List || value.isEmpty) {
      throw FormatException('$location must be a non-empty YAML list.');
    }
    return List<Object?>.unmodifiable(
      value.asMap().entries.map(
        (entry) => _jsonValue(entry.value, '$location[${entry.key}]'),
      ),
    );
  }

  Map<String, Object?> _map(Object? value, String location) {
    if (value is YamlMap) return _stringMap(value);
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    throw FormatException('$location must be a YAML map.');
  }

  String _requiredString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value.trim();
  }

  String? _optionalString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value.trim();
  }

  Map<String, Object?> _stringMap(YamlMap map) =>
      map.map((key, value) => MapEntry(key.toString(), value));
}
