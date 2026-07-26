/// A typed API description loaded from `archsmith_api.yaml`.
class ApiContract {
  const ApiContract({
    required this.baseUrl,
    required this.endpoints,
    this.headers = const {},
    this.queryParameters = const {},
    this.bodyParameters = const {},
    this.responseHandling = const ApiResponseHandling(),
    this.timeoutSeconds = 30,
    this.models = const [],
  });

  final String baseUrl;
  final Map<String, String> headers;
  final Map<String, Object?> queryParameters;
  final Map<String, Object?> bodyParameters;
  final ApiResponseHandling responseHandling;
  final int timeoutSeconds;
  final List<ApiModel> models;
  final List<ApiEndpoint> endpoints;
}

/// Rules used to distinguish successful and failed backend envelopes.
class ApiResponseHandling {
  const ApiResponseHandling({
    this.dataKey,
    this.successKey,
    this.successValues = const [true],
    this.errorKey,
    this.errorValues = const [true],
    this.messageKey = 'message',
    this.codeKey = 'code',
    this.errorsKey = 'errors',
    this.successStatusCodes = const [],
  });

  final String? dataKey;
  final String? successKey;
  final List<Object?> successValues;
  final String? errorKey;
  final List<Object?> errorValues;
  final String messageKey;
  final String codeKey;
  final String errorsKey;
  final List<int> successStatusCodes;
}

/// A JSON object represented as a generated Dart class.
class ApiModel {
  const ApiModel({required this.name, required this.fields});

  final String name;
  final List<ApiField> fields;
}

/// A typed field used by models and endpoint parameters.
class ApiField {
  const ApiField({
    required this.name,
    required this.type,
    this.required = true,
  });

  final String name;
  final String type;
  final bool required;
}

/// One HTTP operation from the API contract.
class ApiEndpoint {
  const ApiEndpoint({
    required this.name,
    required this.method,
    required this.path,
    required this.response,
    this.headers = const {},
    this.pathParameters = const [],
    this.queryParameters = const [],
    this.request,
  });

  final String name;
  final String method;
  final String path;
  final Map<String, String> headers;
  final List<ApiField> pathParameters;
  final List<ApiField> queryParameters;
  final ApiModel? request;
  final ApiModel response;
}
