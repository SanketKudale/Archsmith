import 'dart:convert';
import 'dart:io';

/// Project-wide API values shared by every JSON endpoint contract.
class ApiCommonConfig {
  const ApiCommonConfig({
    required this.baseUrl,
    this.headers = const {},
    this.request = const {},
    this.timeoutSeconds = 30,
    this.successCodePath = 'status.code',
    this.successCodes = const ['000000'],
    this.messagePath = 'status.description',
    this.cacheEnabled = false,
    this.cacheTtlSeconds = 300,
  });

  final String baseUrl;
  final Map<String, String> headers;
  final Map<String, Object?> request;
  final int timeoutSeconds;
  final String successCodePath;
  final List<Object?> successCodes;
  final String messagePath;
  final bool cacheEnabled;
  final int cacheTtlSeconds;

  ApiCommonConfig copyWith({
    String? baseUrl,
    Map<String, String>? headers,
    Map<String, Object?>? request,
    int? timeoutSeconds,
    String? successCodePath,
    List<Object?>? successCodes,
    String? messagePath,
    bool? cacheEnabled,
    int? cacheTtlSeconds,
  }) =>
      ApiCommonConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        headers: headers ?? this.headers,
        request: request ?? this.request,
        timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
        successCodePath: successCodePath ?? this.successCodePath,
        successCodes: successCodes ?? this.successCodes,
        messagePath: messagePath ?? this.messagePath,
        cacheEnabled: cacheEnabled ?? this.cacheEnabled,
        cacheTtlSeconds: cacheTtlSeconds ?? this.cacheTtlSeconds,
      );

  Map<String, Object?> toJson() => {
        'base_url': baseUrl,
        'timeout_seconds': timeoutSeconds,
        'headers': headers,
        'request': request,
        'cache': {
          'enabled': cacheEnabled,
          'ttl_seconds': cacheTtlSeconds,
        },
        'response': {
          'success_code_path': successCodePath,
          'success_codes': successCodes,
          'message_path': messagePath,
        },
      };
}

/// Reads and writes `archsmith_api_common.json`.
class ApiCommonConfigStore {
  const ApiCommonConfigStore();

  ApiCommonConfig read(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException(
        'archsmith_api_common.json was not found. '
        'Run archsmith api-common base-url <url> first.',
        path,
      );
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) {
      throw const FormatException(
        'archsmith_api_common.json must contain a JSON object.',
      );
    }
    return fromMap(Map<String, Object?>.from(decoded));
  }

  ApiCommonConfig fromMap(Map<String, Object?> map) {
    final baseUrl = map['base_url'];
    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      throw const FormatException('base_url must be a non-empty string.');
    }
    final timeout = map['timeout_seconds'] ?? 30;
    if (timeout is! int || timeout <= 0) {
      throw const FormatException(
          'timeout_seconds must be a positive integer.');
    }
    final response = _map(map['response'], 'response');
    final cache = _map(map['cache'], 'cache');
    final cacheTtl = cache['ttl_seconds'] ?? 300;
    if (cacheTtl is! int || cacheTtl <= 0) {
      throw const FormatException(
        'cache.ttl_seconds must be a positive integer.',
      );
    }
    final successCodes = response['success_codes'] ?? const ['000000'];
    if (successCodes is! List || successCodes.isEmpty) {
      throw const FormatException('response.success_codes must be a list.');
    }
    return ApiCommonConfig(
      baseUrl: baseUrl.trim(),
      headers: _map(
        map['headers'],
        'headers',
      ).map((key, value) => MapEntry(key, value.toString())),
      request: _map(map['request'], 'request'),
      timeoutSeconds: timeout,
      successCodePath:
          response['success_code_path']?.toString() ?? 'status.code',
      successCodes: List<Object?>.unmodifiable(successCodes),
      messagePath: response['message_path']?.toString() ?? 'status.description',
      cacheEnabled: cache['enabled'] is bool ? cache['enabled'] as bool : false,
      cacheTtlSeconds: cacheTtl,
    );
  }

  Future<void> write(String path, ApiCommonConfig config) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(config.toJson())}\n');
  }

  Map<String, Object?> _map(Object? value, String location) {
    if (value == null) return const {};
    if (value is! Map) throw FormatException('$location must be an object.');
    return Map<String, Object?>.from(value);
  }
}
