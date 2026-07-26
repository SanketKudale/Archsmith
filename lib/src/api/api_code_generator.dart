import '../configuration/archsmith_config.dart';
import '../models/generation.dart';
import '../models/options.dart';
import '../utils/naming_utils.dart';
import 'api_contract.dart';

/// Generates typed models and a callable API client from an API contract.
class ApiCodeGenerator {
  const ApiCodeGenerator();

  List<PlannedFile> generate(ArchsmithConfig config, ApiContract contract) {
    if (config.network == NetworkType.none) {
      throw const FormatException(
        'API generation requires Dio or HTTP networking in archsmith.yaml.',
      );
    }
    _validateTypes(contract);
    return [
      PlannedFile(
        'lib/core/network/generated/api_config.dart',
        _config(contract),
      ),
      PlannedFile(
        'lib/core/network/generated/api_models.dart',
        _models(contract.models),
      ),
      const PlannedFile(
        'lib/core/network/generated/api_request_context.dart',
        _requestContext,
      ),
      const PlannedFile(
        'lib/core/network/generated/api_result.dart',
        _apiResult,
      ),
      PlannedFile(
        'lib/core/network/generated/api_client.dart',
        _client(config, contract),
      ),
      const PlannedFile(
        'lib/core/network/generated/generated_api.dart',
        _barrel,
      ),
    ];
  }

  String _config(ApiContract contract) =>
      "abstract final class ApiConfig {\n"
      "  static const baseUrl = '${_escape(contract.baseUrl)}';\n"
      "  static const requestTimeout = Duration(seconds: ${contract.timeoutSeconds});\n"
      "  static const headers = <String, String>{${_mapEntries(contract.headers)}};\n"
      "  static const queryParameters = <String, Object?>{${_objectMapEntries(contract.queryParameters)}};\n"
      "  static const bodyParameters = <String, Object?>{${_objectMapEntries(contract.bodyParameters)}};\n"
      "  static String? get dataKey => ${_nullableString(contract.responseHandling.dataKey)};\n"
      "  static String? get successKey => ${_nullableString(contract.responseHandling.successKey)};\n"
      "  static const successValues = <Object?>[${contract.responseHandling.successValues.map(_literal).join(',')}];\n"
      "  static String? get errorKey => ${_nullableString(contract.responseHandling.errorKey)};\n"
      "  static const errorValues = <Object?>[${contract.responseHandling.errorValues.map(_literal).join(',')}];\n"
      "  static const messageKey = '${_escape(contract.responseHandling.messageKey)}';\n"
      "  static const codeKey = '${_escape(contract.responseHandling.codeKey)}';\n"
      "  static const errorsKey = '${_escape(contract.responseHandling.errorsKey)}';\n"
      "  static const successStatusCodes = <int>[${contract.responseHandling.successStatusCodes.join(',')}];\n"
      "}\n";

  String _models(List<ApiModel> models) {
    if (models.isEmpty) {
      return '// No API models are defined yet.\n';
    }
    return '${models.map(_model).join('\n')}\n';
  }

  String _model(ApiModel model) {
    final className = names(model.name).pascalCase;
    final constructor = model.fields
        .map(
          (field) =>
              '    ${field.required ? 'required ' : ''}this.${names(field.name).camelCase},',
        )
        .join('\n');
    final declarations = model.fields
        .map(
          (field) =>
              '  final ${_dartType(field)} ${names(field.name).camelCase};',
        )
        .join('\n');
    final fromJson = model.fields
        .map(
          (field) =>
              "      ${names(field.name).camelCase}: ${_fromJson(field, "json['${_escape(field.name)}']")},",
        )
        .join('\n');
    final toJson = model.fields
        .map(
          (field) =>
              "      '${_escape(field.name)}': ${_toJson(field, names(field.name).camelCase)},",
        )
        .join('\n');
    return "class $className {\n"
        "  const $className({\n$constructor\n  });\n\n"
        "$declarations\n\n"
        "  factory $className.fromJson(Map<String, dynamic> json) => $className(\n"
        "$fromJson\n"
        "  );\n\n"
        "  Map<String, dynamic> toJson() => <String, dynamic>{\n"
        "$toJson\n"
        "  };\n"
        "}\n";
  }

  String _client(ArchsmithConfig config, ApiContract contract) {
    final imports = config.network == NetworkType.dio
        ? "import 'package:dio/dio.dart';\n"
        : "import 'dart:async';\n"
              "import 'dart:convert';\n"
              "import 'dart:io';\n\n"
              "import 'package:http/http.dart' as http;\n";
    final methods = contract.endpoints
        .map(
          (endpoint) => config.network == NetworkType.dio
              ? _dioMethod(endpoint, contract)
              : _httpMethod(endpoint, contract),
        )
        .join('\n');
    final helper = config.network == NetworkType.http
        ? "  Map<String, String> _stringQuery(Map<String, Object?> values) => {\n"
              "    for (final entry in values.entries)\n"
              "      if (entry.value != null)\n"
              "        entry.key: entry.value is List\n"
              "            ? (entry.value as List).join(',')\n"
              "            : entry.value.toString(),\n"
              "  };\n\n"
        : '';
    final constructor = config.network == NetworkType.dio
        ? "  GeneratedApiClient(\n"
              "    this.client, {\n"
              "    this.context = const ApiRequestContext(),\n"
              "  }) {\n"
              "    client.dio.options.connectTimeout ??= ApiConfig.requestTimeout;\n"
              "  }\n\n"
        : "  const GeneratedApiClient(\n"
              "    this.client, {\n"
              "    this.context = const ApiRequestContext(),\n"
              "  });\n\n";
    return "$imports"
        "import '../network_client.dart';\n"
        "import 'api_config.dart';\n"
        "import 'api_models.dart';\n\n"
        "import 'api_request_context.dart';\n"
        "import 'api_result.dart';\n\n"
        "class GeneratedApiClient {\n"
        "$constructor"
        "  final NetworkClient client;\n\n"
        "  final ApiRequestContext context;\n\n"
        "$helper"
        "$methods"
        "}\n";
  }

  String _dioMethod(ApiEndpoint endpoint, ApiContract contract) {
    final response = names(endpoint.response.name).pascalCase;
    final signature = _signature(endpoint);
    final path = _resolvedPath(endpoint);
    final sendsBody =
        endpoint.request != null ||
        (contract.bodyParameters.isNotEmpty && endpoint.method != 'GET');
    final requestBody = endpoint.request == null ? '' : '...payload.toJson(),';
    final body = !sendsBody
        ? ''
        : "\n        data: <String, Object?>{"
              "...ApiConfig.bodyParameters,"
              "...context.bodyParameters,"
              "$requestBody"
              "...overrides.bodyParameters},";
    return "  Future<ApiResult<$response>> ${names(endpoint.name).camelCase}({\n"
        "$signature"
        "    ApiRequestContext overrides = const ApiRequestContext(),\n"
        "  }) async {\n"
        "    final path = $path;\n"
        "    try {\n"
        "      final response = await client.dio.request<Object?>(\n"
        "        '\${ApiConfig.baseUrl}\$path',$body\n"
        "        queryParameters: <String, Object?>{\n"
        "          ...ApiConfig.queryParameters,\n"
        "          ...context.queryParameters,\n"
        "          ${_parameterMap(endpoint.queryParameters)}\n"
        "          ...overrides.queryParameters,\n"
        "        },\n"
        "        options: Options(\n"
        "          method: '${endpoint.method}',\n"
        "          sendTimeout: ApiConfig.requestTimeout,\n"
        "          receiveTimeout: ApiConfig.requestTimeout,\n"
        "          headers: <String, String>{\n"
        "            ...ApiConfig.headers,\n"
        "            ...context.headers,\n"
        "            ${_mapEntries(endpoint.headers)}\n"
        "            ...overrides.headers,\n"
        "          },\n"
        "          validateStatus: (_) => true,\n"
        "        ),\n"
        "      );\n"
        "      return ApiResponseHandler.parse<$response>(\n"
        "        statusCode: response.statusCode ?? 0,\n"
        "        body: response.data,\n"
        "        decode: $response.fromJson,\n"
        "      );\n"
        "    } on DioException catch (error) {\n"
        "      final type = switch (error.type) {\n"
        "        DioExceptionType.connectionTimeout ||\n"
        "        DioExceptionType.sendTimeout ||\n"
        "        DioExceptionType.receiveTimeout => ApiErrorType.timeout,\n"
        "        DioExceptionType.cancel => ApiErrorType.cancelled,\n"
        "        _ => ApiErrorType.network,\n"
        "      };\n"
        "      return ApiResponseHandler.failure<$response>(\n"
        "        statusCode: error.response?.statusCode,\n"
        "        body: error.response?.data,\n"
        "        transportType: type,\n"
        "        fallbackMessage: error.message,\n"
        "      );\n"
        "    } catch (error) {\n"
        "      return ApiFailure(ApiError(\n"
        "        type: ApiErrorType.unknown,\n"
        "        message: error.toString(),\n"
        "      ));\n"
        "    }\n"
        "  }\n\n";
  }

  String _httpMethod(ApiEndpoint endpoint, ApiContract contract) {
    final responseType = names(endpoint.response.name).pascalCase;
    final signature = _signature(endpoint);
    final path = _resolvedPath(endpoint);
    final sendsBody =
        endpoint.request != null ||
        (contract.bodyParameters.isNotEmpty && endpoint.method != 'GET');
    final requestBody = endpoint.request == null ? '' : '...payload.toJson(),';
    final body = !sendsBody
        ? ''
        : "\n      request.body = jsonEncode(<String, Object?>{"
              "...ApiConfig.bodyParameters,"
              "...context.bodyParameters,"
              "$requestBody"
              "...overrides.bodyParameters});";
    return "  Future<ApiResult<$responseType>> ${names(endpoint.name).camelCase}({\n"
        "$signature"
        "    ApiRequestContext overrides = const ApiRequestContext(),\n"
        "  }) async {\n"
        "    final path = $path;\n"
        "    try {\n"
        "      final uri = Uri.parse('\${ApiConfig.baseUrl}\$path').replace(\n"
        "        queryParameters: _stringQuery(<String, Object?>{\n"
        "          ...ApiConfig.queryParameters,\n"
        "          ...context.queryParameters,\n"
        "          ${_parameterMap(endpoint.queryParameters)}\n"
        "          ...overrides.queryParameters,\n"
        "        }),\n"
        "      );\n"
        "      final request = http.Request('${endpoint.method}', uri)\n"
        "        ..headers.addAll(<String, String>{\n"
        "          ...ApiConfig.headers,\n"
        "          ...context.headers,\n"
        "          ${_mapEntries(endpoint.headers)}\n"
        "          ...overrides.headers,\n"
        "        });$body\n"
        "      final streamed = await client.client.send(request).timeout(ApiConfig.requestTimeout);\n"
        "      final response = await http.Response.fromStream(streamed).timeout(ApiConfig.requestTimeout);\n"
        "      final Object? body = response.body.isEmpty ? null : jsonDecode(response.body);\n"
        "      return ApiResponseHandler.parse<$responseType>(\n"
        "        statusCode: response.statusCode,\n"
        "        body: body,\n"
        "        decode: $responseType.fromJson,\n"
        "      );\n"
        "    } on TimeoutException catch (error) {\n"
        "      return ApiFailure(ApiError(type: ApiErrorType.timeout, message: error.message ?? 'Request timed out.'));\n"
        "    } on SocketException catch (error) {\n"
        "      return ApiFailure(ApiError(type: ApiErrorType.network, message: error.message));\n"
        "    } on http.ClientException catch (error) {\n"
        "      return ApiFailure(ApiError(type: ApiErrorType.network, message: error.message));\n"
        "    } on FormatException catch (error) {\n"
        "      return ApiFailure(ApiError(type: ApiErrorType.parsing, message: error.message));\n"
        "    } catch (error) {\n"
        "      return ApiFailure(ApiError(type: ApiErrorType.unknown, message: error.toString()));\n"
        "    }\n"
        "  }\n\n";
  }

  String _signature(ApiEndpoint endpoint) {
    final fields = [...endpoint.pathParameters, ...endpoint.queryParameters];
    final parameters = fields
        .map(
          (field) =>
              '    ${field.required ? 'required ' : ''}${_dartType(field)} ${names(field.name).camelCase},\n',
        )
        .join();
    final request = endpoint.request == null
        ? ''
        : '    required ${names(endpoint.request!.name).pascalCase} payload,\n';
    return '$parameters$request';
  }

  String _resolvedPath(ApiEndpoint endpoint) {
    var path = "'${_escape(endpoint.path)}'";
    for (final parameter in endpoint.pathParameters) {
      final name = names(parameter.name).camelCase;
      path = path.replaceAll(
        '{${parameter.name}}',
        "\${Uri.encodeComponent($name.toString())}",
      );
    }
    return path;
  }

  String _parameterMap(List<ApiField> fields) => fields.map((field) {
    final name = names(field.name).camelCase;
    return "${field.required ? '' : 'if ($name != null) '}"
        "'${_escape(field.name)}': $name,";
  }).join();

  String _dartType(ApiField field) {
    final normalized = _type(field.type);
    return field.required ? normalized : '$normalized?';
  }

  String _type(String raw) {
    final type = raw.trim();
    if (type.endsWith('[]')) {
      return 'List<${_type(type.substring(0, type.length - 2))}>';
    }
    return switch (type.toLowerCase()) {
      'string' => 'String',
      'int' || 'integer' => 'int',
      'double' => 'double',
      'num' || 'number' => 'num',
      'bool' || 'boolean' => 'bool',
      'datetime' || 'date_time' => 'DateTime',
      'dynamic' || 'object' => 'dynamic',
      _ => names(type).pascalCase,
    };
  }

  String _fromJson(ApiField field, String source) {
    final converted = _readValue(field.type, source);
    return field.required ? converted : '$source == null ? null : $converted';
  }

  String _readValue(String rawType, String source) {
    final type = rawType.trim();
    if (type.endsWith('[]')) {
      final inner = type.substring(0, type.length - 2);
      return "($source as List).map((item) => ${_readValue(inner, 'item')}).toList()";
    }
    return switch (type.toLowerCase()) {
      'string' => '$source as String',
      'int' || 'integer' => '($source as num).toInt()',
      'double' => '($source as num).toDouble()',
      'num' || 'number' => '$source as num',
      'bool' || 'boolean' => '$source as bool',
      'datetime' || 'date_time' => 'DateTime.parse($source as String)',
      'dynamic' || 'object' => source,
      _ =>
        '${names(type).pascalCase}.fromJson(Map<String, dynamic>.from($source as Map))',
    };
  }

  String _toJson(ApiField field, String source) {
    final nullableSource = field.required ? source : '$source?';
    final type = field.type.trim();
    if (type.endsWith('[]')) {
      final inner = type.substring(0, type.length - 2);
      if (_isScalar(inner)) return source;
      return '$nullableSource.map((item) => item.toJson()).toList()';
    }
    if (_isDate(type)) return '$nullableSource.toIso8601String()';
    if (_isScalar(type)) return source;
    return '$nullableSource.toJson()';
  }

  bool _isDate(String type) =>
      type.toLowerCase() == 'datetime' || type.toLowerCase() == 'date_time';

  bool _isScalar(String type) => const {
    'string',
    'int',
    'integer',
    'double',
    'num',
    'number',
    'bool',
    'boolean',
    'dynamic',
    'object',
  }.contains(type.toLowerCase());

  void _validateTypes(ApiContract contract) {
    final known = contract.models
        .map((model) => names(model.name).pascalCase.toLowerCase())
        .toSet();
    for (final model in contract.models) {
      for (final field in model.fields) {
        var type = field.type;
        if (type.endsWith('[]')) type = type.substring(0, type.length - 2);
        if (!_isScalar(type) &&
            !_isDate(type) &&
            !known.contains(names(type).pascalCase.toLowerCase())) {
          throw FormatException(
            'Unknown API type "${field.type}" in ${model.name}.${field.name}.',
          );
        }
      }
    }
  }

  String _mapEntries(Map<String, String> values) => values.entries
      .map((entry) => "'${_escape(entry.key)}': '${_escape(entry.value)}',")
      .join();

  String _objectMapEntries(Map<String, Object?> values) => values.entries
      .map((entry) => "'${_escape(entry.key)}': ${_literal(entry.value)},")
      .join();

  String _literal(Object? value) {
    if (value == null) return 'null';
    if (value is bool || value is num) return value.toString();
    if (value is String) return "'${_escape(value)}'";
    if (value is List) {
      return '<Object?>[${value.map(_literal).join(',')}]';
    }
    if (value is Map) {
      final values = value.map((key, value) => MapEntry(key.toString(), value));
      return '<String, Object?>{${_objectMapEntries(values)}}';
    }
    throw FormatException('Unsupported common API value: $value.');
  }

  String _nullableString(String? value) =>
      value == null ? 'null' : "'${_escape(value)}'";

  String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll(r'$', r'\$');
}

const _requestContext =
    "class ApiRequestContext {\n"
    "  const ApiRequestContext({\n"
    "    this.headers = const {},\n"
    "    this.queryParameters = const {},\n"
    "    this.bodyParameters = const {},\n"
    "  });\n\n"
    "  final Map<String, String> headers;\n"
    "  final Map<String, Object?> queryParameters;\n"
    "  final Map<String, Object?> bodyParameters;\n"
    "}\n";

const _apiResult =
    "import 'api_config.dart';\n\n"
    "sealed class ApiResult<T> {\n"
    "  const ApiResult();\n"
    "  bool get isSuccess => this is ApiSuccess<T>;\n"
    "  bool get isFailure => this is ApiFailure<T>;\n"
    "}\n\n"
    "final class ApiSuccess<T> extends ApiResult<T> {\n"
    "  const ApiSuccess(this.data, {required this.statusCode, this.message});\n"
    "  final T data;\n"
    "  final int statusCode;\n"
    "  final String? message;\n"
    "}\n\n"
    "final class ApiFailure<T> extends ApiResult<T> {\n"
    "  const ApiFailure(this.error);\n"
    "  final ApiError error;\n"
    "}\n\n"
    "enum ApiErrorType {\n"
    "  network,\n"
    "  timeout,\n"
    "  cancelled,\n"
    "  redirection,\n"
    "  client,\n"
    "  badRequest,\n"
    "  unauthorized,\n"
    "  forbidden,\n"
    "  notFound,\n"
    "  conflict,\n"
    "  validation,\n"
    "  rateLimited,\n"
    "  server,\n"
    "  backend,\n"
    "  parsing,\n"
    "  unknown,\n"
    "}\n\n"
    "class ApiError {\n"
    "  const ApiError({\n"
    "    required this.type,\n"
    "    required this.message,\n"
    "    this.statusCode,\n"
    "    this.code,\n"
    "    this.details,\n"
    "  });\n"
    "  final ApiErrorType type;\n"
    "  final String message;\n"
    "  final int? statusCode;\n"
    "  final String? code;\n"
    "  final Object? details;\n"
    "}\n\n"
    "abstract final class ApiResponseHandler {\n"
    "  static ApiResult<T> parse<T>({\n"
    "    required int statusCode,\n"
    "    required Object? body,\n"
    "    required T Function(Map<String, dynamic>) decode,\n"
    "  }) {\n"
    "    final map = body is Map ? Map<String, dynamic>.from(body) : null;\n"
    "    if (!_isSuccessStatus(statusCode)) {\n"
    "      return failure<T>(statusCode: statusCode, body: body);\n"
    "    }\n"
    "    final errorKey = ApiConfig.errorKey;\n"
    "    if (errorKey != null &&\n"
    "        map != null &&\n"
    "        ApiConfig.errorValues.contains(map[errorKey])) {\n"
    "      return failure<T>(\n"
    "        statusCode: statusCode,\n"
    "        body: body,\n"
    "        transportType: ApiErrorType.backend,\n"
    "        fallbackMessage: 'The backend reported an error.',\n"
    "      );\n"
    "    }\n"
    "    final successKey = ApiConfig.successKey;\n"
    "    if (successKey != null &&\n"
    "        map != null &&\n"
    "        !ApiConfig.successValues.contains(map[successKey])) {\n"
    "      return failure<T>(\n"
    "        statusCode: statusCode,\n"
    "        body: body,\n"
    "        transportType: ApiErrorType.backend,\n"
    "        fallbackMessage: 'The backend reported that the request failed.',\n"
    "      );\n"
    "    }\n"
    "    try {\n"
    "      final payload = ApiConfig.dataKey == null ? map : map?[ApiConfig.dataKey];\n"
    "      if (payload is! Map) {\n"
    "        return ApiFailure(ApiError(\n"
    "          type: ApiErrorType.parsing,\n"
    "          statusCode: statusCode,\n"
    "          message: 'Expected a JSON object in the success response.',\n"
    "          details: body,\n"
    "        ));\n"
    "      }\n"
    "      return ApiSuccess(\n"
    "        decode(Map<String, dynamic>.from(payload)),\n"
    "        statusCode: statusCode,\n"
    "        message: map?[ApiConfig.messageKey]?.toString(),\n"
    "      );\n"
    "    } catch (error) {\n"
    "      return ApiFailure(ApiError(\n"
    "        type: ApiErrorType.parsing,\n"
    "        statusCode: statusCode,\n"
    "        message: 'Could not parse the success response: \$error',\n"
    "        details: body,\n"
    "      ));\n"
    "    }\n"
    "  }\n\n"
    "  static ApiFailure<T> failure<T>({\n"
    "    int? statusCode,\n"
    "    Object? body,\n"
    "    ApiErrorType? transportType,\n"
    "    String? fallbackMessage,\n"
    "  }) {\n"
    "    final map = body is Map ? Map<String, dynamic>.from(body) : null;\n"
    "    return ApiFailure(ApiError(\n"
    "      type: transportType ?? _typeForStatus(statusCode),\n"
    "      statusCode: statusCode,\n"
    "      code: map?[ApiConfig.codeKey]?.toString(),\n"
    "      message: map?[ApiConfig.messageKey]?.toString() ??\n"
    "          fallbackMessage ??\n"
    "          _messageForStatus(statusCode),\n"
    "      details: map?[ApiConfig.errorsKey] ?? body,\n"
    "    ));\n"
    "  }\n\n"
    "  static bool _isSuccessStatus(int statusCode) =>\n"
    "      ApiConfig.successStatusCodes.isEmpty\n"
    "          ? statusCode >= 200 && statusCode < 300\n"
    "          : ApiConfig.successStatusCodes.contains(statusCode);\n\n"
    "  static ApiErrorType _typeForStatus(int? statusCode) => switch (statusCode) {\n"
    "    400 => ApiErrorType.badRequest,\n"
    "    401 => ApiErrorType.unauthorized,\n"
    "    403 => ApiErrorType.forbidden,\n"
    "    404 => ApiErrorType.notFound,\n"
    "    408 => ApiErrorType.timeout,\n"
    "    409 => ApiErrorType.conflict,\n"
    "    422 => ApiErrorType.validation,\n"
    "    429 => ApiErrorType.rateLimited,\n"
    "    _ when statusCode != null && statusCode >= 300 && statusCode < 400 => ApiErrorType.redirection,\n"
    "    _ when statusCode != null && statusCode >= 400 && statusCode < 500 => ApiErrorType.client,\n"
    "    _ when statusCode != null && statusCode >= 500 => ApiErrorType.server,\n"
    "    _ => ApiErrorType.unknown,\n"
    "  };\n\n"
    "  static String _messageForStatus(int? statusCode) => switch (statusCode) {\n"
    "    400 => 'The request was invalid.',\n"
    "    401 => 'Authentication is required.',\n"
    "    403 => 'You do not have permission for this action.',\n"
    "    404 => 'The requested resource was not found.',\n"
    "    408 => 'The request timed out.',\n"
    "    409 => 'The request conflicts with the current state.',\n"
    "    422 => 'One or more fields are invalid.',\n"
    "    429 => 'Too many requests. Please try again later.',\n"
    "    _ when statusCode != null && statusCode >= 300 && statusCode < 400 => 'The server redirected the request unexpectedly.',\n"
    "    _ when statusCode != null && statusCode >= 400 && statusCode < 500 => 'The request could not be accepted.',\n"
    "    _ when statusCode != null && statusCode >= 500 => 'The server could not complete the request.',\n"
    "    _ => 'The request could not be completed.',\n"
    "  };\n"
    "}\n";

const _barrel =
    "export 'api_client.dart';\n"
    "export 'api_config.dart';\n"
    "export 'api_models.dart';\n"
    "export 'api_request_context.dart';\n"
    "export 'api_result.dart';\n";
