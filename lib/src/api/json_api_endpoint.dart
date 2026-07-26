import 'dart:convert';
import 'dart:io';

import '../utils/naming_utils.dart';

/// One endpoint inferred from a backend-provided JSON example.
class JsonApiEndpoint {
  const JsonApiEndpoint({
    required this.path,
    required this.request,
    required this.response,
    this.method = 'POST',
  });

  final String path;
  final String method;
  final Map<String, Object?> request;
  final Map<String, Object?> response;

  String get name =>
      names(path.split('/').where((part) => part.isNotEmpty).last).camelCase;
}

/// Reads endpoint JSON containing `url`, `request`, and `response`.
class JsonApiEndpointReader {
  const JsonApiEndpointReader();

  JsonApiEndpoint read(String path, {String method = 'POST'}) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('API endpoint JSON was not found', path);
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw const FormatException('Endpoint JSON must contain an object.');
    }
    return fromMap(Map<String, Object?>.from(decoded), method: method);
  }

  JsonApiEndpoint fromMap(
    Map<String, Object?> map, {
    String method = 'POST',
  }) {
    final url = map['url'];
    if (url is! String || url.trim().isEmpty) {
      throw const FormatException('url must be a non-empty endpoint string.');
    }
    const supported = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};
    final normalizedMethod = method.toUpperCase();
    if (!supported.contains(normalizedMethod)) {
      throw FormatException(
        'method must be one of ${supported.join(', ')}.',
      );
    }
    return JsonApiEndpoint(
      path: url.trim(),
      method: normalizedMethod,
      request: _object(map['request'], 'request'),
      response: _object(map['response'], 'response'),
    );
  }

  Map<String, Object?> _object(Object? value, String location) {
    if (value == null) return const {};
    if (value is! Map) {
      throw FormatException('$location must contain a JSON object.');
    }
    return Map<String, Object?>.from(value);
  }
}
