import '../configuration/archsmith_config.dart';
import '../models/generation.dart';
import '../models/options.dart';
import '../utils/naming_utils.dart';
import 'api_code_generator.dart';
import 'api_common_config.dart';
import 'api_contract.dart';
import 'api_runtime_generator.dart';
import 'json_api_endpoint.dart';

/// Generates a complete feature-first Clean Architecture API slice.
class CleanApiFeatureGenerator {
  const CleanApiFeatureGenerator();

  List<PlannedFile> generate({
    required ArchsmithConfig config,
    required ApiCommonConfig common,
    required JsonApiEndpoint endpoint,
    required String feature,
  }) {
    if (config.network == NetworkType.none) {
      throw const FormatException(
        'JSON API generation requires Dio or HTTP networking.',
      );
    }
    final featureName = names(feature).snakeCase;
    final operation = names(endpoint.name);
    final prefix = operation.pascalCase;
    final requestClasses = _inferClasses(
      '${prefix}Request',
      endpoint.request,
    );
    final responseClasses = _inferClasses(
      '${prefix}Response',
      endpoint.response,
    );
    final root = 'lib/features/$featureName';
    final supportContract = ApiContract(
      baseUrl: common.baseUrl.replaceFirst(RegExp(r'/+$'), ''),
      headers: common.headers,
      bodyParameters: common.request,
      timeoutSeconds: common.timeoutSeconds,
      responseHandling: ApiResponseHandling(
        successKey: common.successCodePath,
        successValues: common.successCodes,
        messageKey: common.messagePath,
        codeKey: common.successCodePath,
        errorsKey: 'data',
      ),
      endpoints: const [],
    );
    return [
      ...const ApiCodeGenerator().supportFiles(supportContract),
      ...const ApiRuntimeGenerator().generate(),
      PlannedFile(
        '$root/domain/entities/${operation.snakeCase}_request_entity.dart',
        _entities(requestClasses),
      ),
      PlannedFile(
        '$root/domain/entities/${operation.snakeCase}_response_entity.dart',
        _entities(responseClasses),
      ),
      PlannedFile(
        '$root/data/models/${operation.snakeCase}_request_model.dart',
        _models(
          requestClasses,
          "../../domain/entities/${operation.snakeCase}_request_entity.dart",
          includeFromEntity: true,
        ),
      ),
      PlannedFile(
        '$root/data/models/${operation.snakeCase}_response_model.dart',
        _models(
          responseClasses,
          "../../domain/entities/${operation.snakeCase}_response_entity.dart",
        ),
      ),
      PlannedFile(
        '$root/data/datasources/${operation.snakeCase}_remote_data_source.dart',
        _dataSource(config.network, endpoint, operation, common),
      ),
      PlannedFile(
        '$root/domain/repositories/${featureName}_repository.dart',
        _repository(featureName, operation),
      ),
      PlannedFile(
        '$root/data/repositories/${featureName}_repository_impl.dart',
        _repositoryImpl(featureName, operation),
      ),
      PlannedFile(
        '$root/domain/usecases/${operation.snakeCase}_use_case.dart',
        _useCase(featureName, operation),
      ),
      PlannedFile(
        '$root/presentation/states/${operation.snakeCase}_state.dart',
        _state(operation),
      ),
      PlannedFile(
        '$root/presentation/providers/${operation.snakeCase}_notifier.dart',
        _notifier(config.stateManagement, operation),
      ),
      PlannedFile(
        'lib/core/network/providers/network_client_provider.dart',
        _networkClientProvider(config.stateManagement),
      ),
      PlannedFile(
        'lib/core/network/providers/api_request_context_provider.dart',
        _requestContextProvider(config.stateManagement),
      ),
      PlannedFile(
        'lib/core/network/providers/api_request_coordinator_provider.dart',
        _requestCoordinatorProvider(config.stateManagement),
      ),
      PlannedFile(
        'lib/core/network/providers/api_response_cache_provider.dart',
        _responseCacheProvider(config.stateManagement, common),
      ),
      PlannedFile(
        '$root/presentation/providers/${operation.snakeCase}_provider.dart',
        _operationProvider(
          config.projectName,
          featureName,
          operation,
          config.stateManagement,
        ),
      ),
    ];
  }

  List<_JsonClass> _inferClasses(
    String rootName,
    Map<String, Object?> source,
  ) {
    final classes = <_JsonClass>[];

    _JsonClass infer(String className, Map<String, Object?> object) {
      final fields = <_JsonField>[];
      for (final entry in object.entries) {
        final fieldName = names(entry.key);
        final value = entry.value;
        if (value is Map) {
          final nestedName = '$rootName${fieldName.pascalCase}';
          infer(nestedName, Map<String, Object?>.from(value));
          fields.add(
            _JsonField(entry.key, fieldName.camelCase, nestedName, false, true),
          );
        } else if (value is List) {
          if (value.isNotEmpty && value.first is Map) {
            final nestedName = '$rootName${fieldName.pascalCase}Item';
            infer(nestedName, Map<String, Object?>.from(value.first as Map));
            fields.add(
              _JsonField(
                  entry.key, fieldName.camelCase, nestedName, true, true),
            );
          } else {
            final type = value.isEmpty ? 'dynamic' : _scalarType(value.first);
            fields.add(
              _JsonField(entry.key, fieldName.camelCase, type, true, false),
            );
          }
        } else {
          fields.add(
            _JsonField(
              entry.key,
              fieldName.camelCase,
              _scalarType(value),
              false,
              false,
            ),
          );
        }
      }
      final result = _JsonClass(className, fields);
      classes.add(result);
      return result;
    }

    infer(rootName, source);
    return classes;
  }

  String _scalarType(Object? value) => switch (value) {
        String() => 'String',
        bool() => 'bool',
        int() => 'int',
        double() => 'double',
        null => 'dynamic',
        _ => 'dynamic',
      };

  String _entities(List<_JsonClass> classes) => classes.map((schema) {
        final fields = schema.fields
            .map(
                (field) => '  final ${field.dartType('Entity')} ${field.name};')
            .join('\n');
        final constructor = schema.fields
            .map((field) => '    required this.${field.name},')
            .join('\n');
        return "class ${schema.name}Entity {\n"
            "  const ${schema.name}Entity({\n$constructor\n  });\n\n"
            "$fields\n"
            "}\n";
      }).join('\n');

  String _models(
    List<_JsonClass> classes,
    String entityImport, {
    bool includeFromEntity = false,
  }) {
    return "import '$entityImport';\n\n"
        "${classes.map((schema) => _model(schema, includeFromEntity)).join('\n')}";
  }

  String _model(_JsonClass schema, bool includeFromEntity) {
    final fields = schema.fields
        .map((field) => '  final ${field.dartType('Model')} ${field.name};')
        .join('\n');
    final constructor = schema.fields
        .map((field) => '    required this.${field.name},')
        .join('\n');
    final fromJson = schema.fields
        .map(
          (field) =>
              "      ${field.name}: ${field.fromJson("json['${field.jsonName}']")},",
        )
        .join('\n');
    final toJson = schema.fields
        .map(
          (field) => "      '${field.jsonName}': ${field.toJson(field.name)},",
        )
        .join('\n');
    final toEntity = schema.fields
        .map((field) => '      ${field.name}: ${field.toEntity(field.name)},')
        .join('\n');
    final fromEntity = !includeFromEntity
        ? ''
        : "\n  factory ${schema.name}Model.fromEntity(${schema.name}Entity entity) => "
            "${schema.name}Model(\n"
            "${schema.fields.map((field) => '    ${field.name}: ${field.fromEntity('entity.${field.name}')},').join('\n')}\n"
            "  );\n";
    return "class ${schema.name}Model {\n"
        "  const ${schema.name}Model({\n$constructor\n  });\n\n"
        "$fields\n\n"
        "  factory ${schema.name}Model.fromJson(Map<String, dynamic> json) => "
        "${schema.name}Model(\n$fromJson\n  );\n"
        "$fromEntity\n"
        "  Map<String, dynamic> toJson() => {\n$toJson\n  };\n\n"
        "  ${schema.name}Entity toEntity() => ${schema.name}Entity(\n"
        "$toEntity\n"
        "  );\n"
        "}\n";
  }

  String _dataSource(
    NetworkType network,
    JsonApiEndpoint endpoint,
    NameVariants operation,
    ApiCommonConfig common,
  ) {
    final prefix = operation.pascalCase;
    final path =
        endpoint.path.startsWith('/') ? endpoint.path : '/${endpoint.path}';
    final sendsBody = endpoint.method != 'GET' && endpoint.method != 'DELETE';
    final dioParameters = sendsBody
        ? "        data: <String, Object?>{...ApiConfig.bodyParameters, ...context.bodyParameters, ...request.toJson()},\n"
        : "        queryParameters: <String, Object?>{...ApiConfig.bodyParameters, ...context.bodyParameters, ...request.toJson()},\n";
    if (network == NetworkType.dio) {
      return "import 'package:dio/dio.dart';\n"
          "import '../../../../core/network/auth/api_request_coordinator.dart';\n"
          "import '../../../../core/network/cache/api_response_cache.dart';\n"
          "import '../../../../core/network/cache/memory_api_response_cache.dart';\n"
          "import '../../../../core/network/generated/api_config.dart';\n"
          "import '../../../../core/network/generated/api_request_context.dart';\n"
          "import '../../../../core/network/generated/api_result.dart';\n"
          "import '../../../../core/network/network_client.dart';\n"
          "import '../models/${operation.snakeCase}_request_model.dart';\n"
          "import '../models/${operation.snakeCase}_response_model.dart';\n\n"
          "class ${prefix}RemoteDataSource {\n"
          "  ${prefix}RemoteDataSource(this.client, {this.context = const ApiRequestContext(), ApiRequestCoordinator? coordinator, ApiResponseCache? cache})\n"
          "      : coordinator = coordinator ?? const ApiRequestCoordinator(),\n"
          "        cache = cache ?? MemoryApiResponseCache(enabled: ${common.cacheEnabled}, timeToLive: const Duration(seconds: ${common.cacheTtlSeconds}));\n"
          "  final NetworkClient client;\n"
          "  final ApiRequestContext context;\n\n"
          "  final ApiRequestCoordinator coordinator;\n"
          "  final ApiResponseCache cache;\n\n"
          "  Future<ApiResult<${prefix}ResponseModel>> execute(${prefix}RequestModel request) async {\n"
          "    final cacheKey = '${endpoint.method}:$path:\${request.toJson()}';\n"
          "    try {\n"
          "      final response = await coordinator.execute<Response<Object?>>(\n"
          "        headers: <String, String>{...ApiConfig.headers, ...context.headers},\n"
          "        request: (headers) => client.dio.request<Object?>(\n"
          "          '\${ApiConfig.baseUrl}$path',\n"
          "$dioParameters"
          "          options: Options(method: '${endpoint.method}', headers: headers, validateStatus: (_) => true),\n"
          "        ),\n"
          "        isUnauthorized: (response) => response.statusCode == 401,\n"
          "      );\n"
          "      final statusCode = response.statusCode ?? 0;\n"
          "      coordinator.logResponse(statusCode, response.data);\n"
          "      final result = ApiResponseHandler.parse(statusCode: statusCode, body: response.data, decode: ${prefix}ResponseModel.fromJson);\n"
          "      if (result is ApiSuccess<${prefix}ResponseModel>) await cache.write(cacheKey, ApiCachedResponse(statusCode: statusCode, body: response.data, storedAt: DateTime.now()));\n"
          "      return result;\n"
          "    } on DioException catch (error) {\n"
          "      final cached = await cache.read(cacheKey);\n"
          "      if (cached != null) return ApiResponseHandler.parse(statusCode: cached.statusCode, body: cached.body, decode: ${prefix}ResponseModel.fromJson);\n"
          "      return ApiResponseHandler.failure(statusCode: error.response?.statusCode, body: error.response?.data, transportType: ApiErrorType.network, fallbackMessage: error.message);\n"
          "    } catch (error) {\n"
          "      final cached = await cache.read(cacheKey);\n"
          "      if (cached != null) return ApiResponseHandler.parse(statusCode: cached.statusCode, body: cached.body, decode: ${prefix}ResponseModel.fromJson);\n"
          "      return ApiFailure(ApiError(type: ApiErrorType.unknown, message: error.toString()));\n"
          "    }\n"
          "  }\n"
          "}\n";
    }
    final httpUri = sendsBody
        ? "Uri.parse('\${ApiConfig.baseUrl}$path')"
        : "Uri.parse('\${ApiConfig.baseUrl}$path').replace(queryParameters: <String, String>{for (final entry in <String, Object?>{...ApiConfig.bodyParameters, ...context.bodyParameters, ...payload.toJson()}.entries) entry.key: entry.value.toString()})";
    final httpBody = sendsBody
        ? "\n        ..body = jsonEncode(<String, Object?>{...ApiConfig.bodyParameters, ...context.bodyParameters, ...payload.toJson()})"
        : '';
    return "import 'dart:convert';\n"
        "import 'package:http/http.dart' as http;\n"
        "import '../../../../core/network/auth/api_request_coordinator.dart';\n"
        "import '../../../../core/network/cache/api_response_cache.dart';\n"
        "import '../../../../core/network/cache/memory_api_response_cache.dart';\n"
        "import '../../../../core/network/generated/api_config.dart';\n"
        "import '../../../../core/network/generated/api_request_context.dart';\n"
        "import '../../../../core/network/generated/api_result.dart';\n"
        "import '../../../../core/network/network_client.dart';\n"
        "import '../models/${operation.snakeCase}_request_model.dart';\n"
        "import '../models/${operation.snakeCase}_response_model.dart';\n\n"
        "class ${prefix}RemoteDataSource {\n"
        "  ${prefix}RemoteDataSource(this.client, {this.context = const ApiRequestContext(), ApiRequestCoordinator? coordinator, ApiResponseCache? cache})\n"
        "      : coordinator = coordinator ?? const ApiRequestCoordinator(),\n"
        "        cache = cache ?? MemoryApiResponseCache(enabled: ${common.cacheEnabled}, timeToLive: const Duration(seconds: ${common.cacheTtlSeconds}));\n"
        "  final NetworkClient client;\n"
        "  final ApiRequestContext context;\n\n"
        "  final ApiRequestCoordinator coordinator;\n"
        "  final ApiResponseCache cache;\n\n"
        "  Future<ApiResult<${prefix}ResponseModel>> execute(${prefix}RequestModel payload) async {\n"
        "    final uri = $httpUri;\n"
        "    final cacheKey = '${endpoint.method}:$path:\${payload.toJson()}';\n"
        "    try {\n"
        "      final response = await coordinator.execute<http.Response>(\n"
        "        headers: <String, String>{...ApiConfig.headers, ...context.headers},\n"
        "        request: (headers) async {\n"
        "          final request = http.Request('${endpoint.method}', uri)\n"
        "            ..headers.addAll(headers)$httpBody;\n"
        "          final streamed = await client.client.send(request).timeout(ApiConfig.requestTimeout);\n"
        "          return http.Response.fromStream(streamed);\n"
        "        },\n"
        "        isUnauthorized: (response) => response.statusCode == 401,\n"
        "      );\n"
        "      final body = jsonDecode(response.body);\n"
        "      coordinator.logResponse(response.statusCode, body);\n"
        "      final result = ApiResponseHandler.parse(statusCode: response.statusCode, body: body, decode: ${prefix}ResponseModel.fromJson);\n"
        "      if (result is ApiSuccess<${prefix}ResponseModel>) await cache.write(cacheKey, ApiCachedResponse(statusCode: response.statusCode, body: body, storedAt: DateTime.now()));\n"
        "      return result;\n"
        "    } catch (error) {\n"
        "      final cached = await cache.read(cacheKey);\n"
        "      if (cached != null) return ApiResponseHandler.parse(statusCode: cached.statusCode, body: cached.body, decode: ${prefix}ResponseModel.fromJson);\n"
        "      return ApiFailure(ApiError(type: ApiErrorType.network, message: error.toString()));\n"
        "    }\n"
        "  }\n"
        "}\n";
  }

  String _repository(String feature, NameVariants operation) {
    final prefix = operation.pascalCase;
    return "import '../../../../core/network/generated/api_result.dart';\n"
        "import '../entities/${operation.snakeCase}_request_entity.dart';\n"
        "import '../entities/${operation.snakeCase}_response_entity.dart';\n\n"
        "abstract interface class ${names(feature).pascalCase}Repository {\n"
        "  Future<ApiResult<${prefix}ResponseEntity>> ${operation.camelCase}(${prefix}RequestEntity request);\n"
        "}\n";
  }

  String _repositoryImpl(String feature, NameVariants operation) {
    final prefix = operation.pascalCase;
    final repository = names(feature).pascalCase;
    return "import '../../../../core/network/generated/api_result.dart';\n"
        "import '../../domain/entities/${operation.snakeCase}_request_entity.dart';\n"
        "import '../../domain/entities/${operation.snakeCase}_response_entity.dart';\n"
        "import '../../domain/repositories/${names(feature).snakeCase}_repository.dart';\n"
        "import '../datasources/${operation.snakeCase}_remote_data_source.dart';\n"
        "import '../models/${operation.snakeCase}_request_model.dart';\n\n"
        "class ${repository}RepositoryImpl implements ${repository}Repository {\n"
        "  const ${repository}RepositoryImpl(this.dataSource);\n"
        "  final ${prefix}RemoteDataSource dataSource;\n\n"
        "  @override\n"
        "  Future<ApiResult<${prefix}ResponseEntity>> ${operation.camelCase}(${prefix}RequestEntity request) async {\n"
        "    final result = await dataSource.execute(${prefix}RequestModel.fromEntity(request));\n"
        "    return switch (result) {\n"
        "      ApiSuccess(:final data, :final statusCode, :final message) => ApiSuccess(data.toEntity(), statusCode: statusCode, message: message),\n"
        "      ApiFailure(:final error) => ApiFailure(error),\n"
        "    };\n"
        "  }\n"
        "}\n";
  }

  String _useCase(String feature, NameVariants operation) {
    final prefix = operation.pascalCase;
    final repository = names(feature).pascalCase;
    return "import '../../../../core/network/generated/api_result.dart';\n"
        "import '../entities/${operation.snakeCase}_request_entity.dart';\n"
        "import '../entities/${operation.snakeCase}_response_entity.dart';\n"
        "import '../repositories/${names(feature).snakeCase}_repository.dart';\n\n"
        "class ${prefix}UseCase {\n"
        "  const ${prefix}UseCase(this.repository);\n"
        "  final ${repository}Repository repository;\n"
        "  Future<ApiResult<${prefix}ResponseEntity>> call(${prefix}RequestEntity request) => repository.${operation.camelCase}(request);\n"
        "}\n";
  }

  String _state(NameVariants operation) {
    final prefix = operation.pascalCase;
    return "import '../../../../core/network/generated/api_result.dart';\n"
        "import '../../domain/entities/${operation.snakeCase}_response_entity.dart';\n\n"
        "class ${prefix}State {\n"
        "  const ${prefix}State({this.isLoading = false, this.data, this.error, this.retryAction});\n"
        "  final bool isLoading;\n"
        "  final ${prefix}ResponseEntity? data;\n"
        "  final ApiError? error;\n"
        "  final Future<void> Function()? retryAction;\n"
        "  bool get isEmpty => !isLoading && data == null && error == null;\n"
        "  bool get hasData => data != null;\n"
        "  bool get hasError => error != null;\n"
        "  Future<void> retry() => retryAction?.call() ?? Future<void>.value();\n"
        "}\n";
  }

  String _notifier(
    StateManagementType stateManagement,
    NameVariants operation,
  ) {
    final prefix = operation.pascalCase;
    final common =
        "import '../../../../core/network/generated/api_result.dart';\n"
        "import '../../domain/entities/${operation.snakeCase}_request_entity.dart';\n"
        "import '../../domain/usecases/${operation.snakeCase}_use_case.dart';\n"
        "import '../states/${operation.snakeCase}_state.dart';\n\n";
    final body = "  ${prefix}UseCase useCase;\n"
        "  ${prefix}RequestEntity? _lastRequest;\n"
        "  Future<void> execute(${prefix}RequestEntity request) async {\n"
        "    _lastRequest = request;\n"
        "    setState(${prefix}State(isLoading: true, retryAction: retry));\n"
        "    final result = await useCase(request);\n"
        "    setState(switch (result) {\n"
        "      ApiSuccess(:final data) => ${prefix}State(data: data, retryAction: retry),\n"
        "      ApiFailure(:final error) => ${prefix}State(error: error, retryAction: retry),\n"
        "    });\n"
        "  }\n"
        "  Future<void> retry() async {\n"
        "    final request = _lastRequest;\n"
        "    if (request != null) await execute(request);\n"
        "  }\n";
    return switch (stateManagement) {
      StateManagementType.riverpod =>
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
            "$common"
            "class ${prefix}Notifier extends StateNotifier<${prefix}State> {\n"
            "  ${prefix}Notifier(this.useCase) : super(const ${prefix}State());\n"
            "$body"
            "  void setState(${prefix}State value) => state = value;\n"
            "}\n",
      StateManagementType.provider =>
        "import 'package:flutter/foundation.dart';\n"
            "$common"
            "class ${prefix}Notifier extends ChangeNotifier {\n"
            "  ${prefix}Notifier(this.useCase);\n"
            "  ${prefix}State state = const ${prefix}State();\n"
            "$body"
            "  void setState(${prefix}State value) { state = value; notifyListeners(); }\n"
            "}\n",
      StateManagementType.bloc =>
        "import 'package:flutter_bloc/flutter_bloc.dart';\n"
            "$common"
            "class ${prefix}Cubit extends Cubit<${prefix}State> {\n"
            "  ${prefix}Cubit(this.useCase) : super(const ${prefix}State());\n"
            "$body"
            "  void setState(${prefix}State value) => emit(value);\n"
            "}\n",
      StateManagementType.getx => "import 'package:get/get.dart';\n"
          "$common"
          "class ${prefix}Controller extends GetxController {\n"
          "  ${prefix}Controller(this.useCase);\n"
          "  final state = const ${prefix}State().obs;\n"
          "$body"
          "  void setState(${prefix}State value) => state.value = value;\n"
          "}\n",
      StateManagementType.none => "import 'package:flutter/foundation.dart';\n"
          "$common"
          "class ${prefix}Notifier extends ValueNotifier<${prefix}State> {\n"
          "  ${prefix}Notifier(this.useCase) : super(const ${prefix}State());\n"
          "$body"
          "  void setState(${prefix}State state) => value = state;\n"
          "}\n",
    };
  }

  String _operationProvider(
    String project,
    String feature,
    NameVariants operation,
    StateManagementType stateManagement,
  ) {
    final prefix = operation.pascalCase;
    final repository = names(feature).pascalCase;
    final coreImports = stateManagement == StateManagementType.riverpod
        ? "import 'package:$project/core/network/providers/api_request_context_provider.dart';\n"
            "import 'package:$project/core/network/providers/api_request_coordinator_provider.dart';\n"
            "import 'package:$project/core/network/providers/api_response_cache_provider.dart';\n"
            "import 'package:$project/core/network/providers/network_client_provider.dart';\n"
        : "import 'package:$project/core/network/auth/api_request_coordinator.dart';\n"
            "import 'package:$project/core/network/cache/api_response_cache.dart';\n"
            "import 'package:$project/core/network/generated/api_request_context.dart';\n"
            "import 'package:$project/core/network/network_client.dart';\n";
    final stateImport = stateManagement == StateManagementType.riverpod
        ? "import '../states/${operation.snakeCase}_state.dart';\n"
        : '';
    final imports = "$coreImports"
        "import '../../data/datasources/${operation.snakeCase}_remote_data_source.dart';\n"
        "import '../../data/repositories/${feature}_repository_impl.dart';\n"
        "import '../../domain/usecases/${operation.snakeCase}_use_case.dart';\n"
        "$stateImport"
        "import '${operation.snakeCase}_notifier.dart';\n\n";
    final dataSource =
        "${prefix}RemoteDataSource(client, context: context, coordinator: coordinator, cache: cache)";
    final notifier =
        "${prefix}Notifier(${prefix}UseCase(${repository}RepositoryImpl($dataSource)))";
    return switch (stateManagement) {
      StateManagementType.riverpod =>
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
            "$imports"
            "final ${operation.camelCase}Provider = StateNotifierProvider<${prefix}Notifier, ${prefix}State>((ref) {\n"
            "  final client = ref.watch(networkClientProvider);\n"
            "  final context = ref.watch(apiRequestContextProvider);\n"
            "  final coordinator = ref.watch(apiRequestCoordinatorProvider);\n"
            "  final cache = ref.watch(apiResponseCacheProvider);\n"
            "  return $notifier;\n"
            "});\n",
      StateManagementType.provider => "import 'package:provider/provider.dart';\n"
          "$imports"
          "final ${operation.camelCase}Provider = ChangeNotifierProxyProvider4<NetworkClient, ApiRequestContext, ApiRequestCoordinator, ApiResponseCache, ${prefix}Notifier>(\n"
          "  create: (buildContext) => ${prefix}Notifier(${prefix}UseCase(${repository}RepositoryImpl(${prefix}RemoteDataSource(buildContext.read<NetworkClient>(), context: buildContext.read<ApiRequestContext>(), coordinator: buildContext.read<ApiRequestCoordinator>(), cache: buildContext.read<ApiResponseCache>())))),\n"
          "  update: (_, client, context, coordinator, cache, previous) {\n"
          "    final useCase = ${prefix}UseCase(${repository}RepositoryImpl($dataSource));\n"
          "    if (previous == null) return ${prefix}Notifier(useCase);\n"
          "    previous.useCase = useCase;\n"
          "    return previous;\n"
          "  },\n"
          ");\n",
      StateManagementType.bloc =>
        "import 'package:flutter_bloc/flutter_bloc.dart';\n"
            "$imports"
            "final ${operation.camelCase}Provider = BlocProvider<${prefix}Cubit>(create: (buildContext) {\n"
            "  final client = buildContext.read<NetworkClient>();\n"
            "  final context = buildContext.read<ApiRequestContext>();\n"
            "  final coordinator = buildContext.read<ApiRequestCoordinator>();\n"
            "  final cache = buildContext.read<ApiResponseCache>();\n"
            "  return ${prefix}Cubit(${prefix}UseCase(${repository}RepositoryImpl($dataSource)));\n"
            "});\n",
      StateManagementType.getx => "import 'package:get/get.dart';\n"
          "$imports"
          "class ${prefix}Binding extends Bindings {\n"
          "  @override\n"
          "  void dependencies() => Get.lazyPut<${prefix}Controller>(() {\n"
          "    final client = Get.find<NetworkClient>();\n"
          "    final context = Get.find<ApiRequestContext>();\n"
          "    final coordinator = Get.find<ApiRequestCoordinator>();\n"
          "    final cache = Get.find<ApiResponseCache>();\n"
          "    return ${prefix}Controller(${prefix}UseCase(${repository}RepositoryImpl($dataSource)));\n"
          "  });\n"
          "}\n",
      StateManagementType.none => "$imports"
          "${prefix}Notifier create${prefix}Notifier(NetworkClient client, ApiRequestContext context, ApiRequestCoordinator coordinator, ApiResponseCache cache) => $notifier;\n",
    };
  }
}

class _JsonClass {
  const _JsonClass(this.name, this.fields);
  final String name;
  final List<_JsonField> fields;
}

class _JsonField {
  const _JsonField(
    this.jsonName,
    this.name,
    this.type,
    this.isList,
    this.isCustom,
  );
  final String jsonName;
  final String name;
  final String type;
  final bool isList;
  final bool isCustom;

  String dartType(String suffix) => isList
      ? 'List<${isCustom ? '$type$suffix' : type}>'
      : isCustom
          ? '$type$suffix'
          : type;

  String fromJson(String source) {
    final value = isCustom
        ? '${type}Model.fromJson(Map<String, dynamic>.from(%s as Map))'
        : switch (type) {
            'int' => '(%s as num).toInt()',
            'double' => '(%s as num).toDouble()',
            'num' => '%s as num',
            'bool' => '%s as bool',
            'String' => '%s as String',
            _ => '%s',
          };
    if (!isList) return value.replaceAll('%s', source);
    return "($source as List).map((item) => ${value.replaceAll('%s', 'item')}).toList()";
  }

  String toJson(String source) {
    if (!isCustom) return source;
    return isList
        ? '$source.map((item) => item.toJson()).toList()'
        : '$source.toJson()';
  }

  String toEntity(String source) {
    if (!isCustom) return source;
    return isList
        ? '$source.map((item) => item.toEntity()).toList()'
        : '$source.toEntity()';
  }

  String fromEntity(String source) {
    if (!isCustom) return source;
    return isList
        ? '$source.map((item) => ${type}Model.fromEntity(item)).toList()'
        : '${type}Model.fromEntity($source)';
  }
}

String _networkClientProvider(StateManagementType stateManagement) {
  const typeImport = "import '../network_client.dart';\n\n";
  return switch (stateManagement) {
    StateManagementType.riverpod =>
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
          "${typeImport}final networkClientProvider = Provider<NetworkClient>((ref) => NetworkClient());\n",
    StateManagementType.provider => "import 'package:provider/provider.dart';\n"
        "${typeImport}final networkClientProvider = Provider<NetworkClient>(create: (_) => NetworkClient());\n",
    StateManagementType.bloc =>
      "import 'package:flutter_bloc/flutter_bloc.dart';\n"
          "${typeImport}final networkClientProvider = RepositoryProvider<NetworkClient>(create: (_) => NetworkClient());\n",
    StateManagementType.getx => "import 'package:get/get.dart';\n"
        "${typeImport}class NetworkClientBinding { static void register() => Get.lazyPut<NetworkClient>(NetworkClient.new); }\n",
    StateManagementType.none =>
      "${typeImport}NetworkClient createNetworkClient() => NetworkClient();\n",
  };
}

String _requestContextProvider(StateManagementType stateManagement) {
  const typeImport = "import '../generated/api_request_context.dart';\n\n";
  return switch (stateManagement) {
    StateManagementType.riverpod =>
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
          "${typeImport}final apiRequestContextProvider = Provider<ApiRequestContext>((ref) => const ApiRequestContext());\n",
    StateManagementType.provider => "import 'package:provider/provider.dart';\n"
        "${typeImport}final apiRequestContextProvider = Provider<ApiRequestContext>(create: (_) => const ApiRequestContext());\n",
    StateManagementType.bloc =>
      "import 'package:flutter_bloc/flutter_bloc.dart';\n"
          "${typeImport}final apiRequestContextProvider = RepositoryProvider<ApiRequestContext>(create: (_) => const ApiRequestContext());\n",
    StateManagementType.getx => "import 'package:get/get.dart';\n"
        "${typeImport}class ApiRequestContextBinding { static void register() => Get.put<ApiRequestContext>(const ApiRequestContext()); }\n",
    StateManagementType.none =>
      "${typeImport}const apiRequestContext = ApiRequestContext();\n",
  };
}

String _requestCoordinatorProvider(StateManagementType stateManagement) {
  const typeImport = "import '../auth/api_request_coordinator.dart';\n\n";
  return switch (stateManagement) {
    StateManagementType.riverpod =>
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
          "${typeImport}final apiRequestCoordinatorProvider = Provider<ApiRequestCoordinator>((ref) => const ApiRequestCoordinator());\n",
    StateManagementType.provider => "import 'package:provider/provider.dart';\n"
        "${typeImport}final apiRequestCoordinatorProvider = Provider<ApiRequestCoordinator>(create: (_) => const ApiRequestCoordinator());\n",
    StateManagementType.bloc =>
      "import 'package:flutter_bloc/flutter_bloc.dart';\n"
          "${typeImport}final apiRequestCoordinatorProvider = RepositoryProvider<ApiRequestCoordinator>(create: (_) => const ApiRequestCoordinator());\n",
    StateManagementType.getx => "import 'package:get/get.dart';\n"
        "${typeImport}class ApiRequestCoordinatorBinding { static void register() => Get.put<ApiRequestCoordinator>(const ApiRequestCoordinator()); }\n",
    StateManagementType.none =>
      "${typeImport}const apiRequestCoordinator = ApiRequestCoordinator();\n",
  };
}

String _responseCacheProvider(
  StateManagementType stateManagement,
  ApiCommonConfig common,
) {
  const typeImport = "import '../cache/api_response_cache.dart';\n"
      "import '../cache/memory_api_response_cache.dart';\n\n";
  final create =
      'MemoryApiResponseCache(enabled: ${common.cacheEnabled}, timeToLive: const Duration(seconds: ${common.cacheTtlSeconds}))';
  return switch (stateManagement) {
    StateManagementType.riverpod =>
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
          "${typeImport}final apiResponseCacheProvider = Provider<ApiResponseCache>((ref) => $create);\n",
    StateManagementType.provider => "import 'package:provider/provider.dart';\n"
        "${typeImport}final apiResponseCacheProvider = Provider<ApiResponseCache>(create: (_) => $create);\n",
    StateManagementType.bloc =>
      "import 'package:flutter_bloc/flutter_bloc.dart';\n"
          "${typeImport}final apiResponseCacheProvider = RepositoryProvider<ApiResponseCache>(create: (_) => $create);\n",
    StateManagementType.getx => "import 'package:get/get.dart';\n"
        "${typeImport}class ApiResponseCacheBinding { static void register() => Get.put<ApiResponseCache>($create); }\n",
    StateManagementType.none =>
      "${typeImport}ApiResponseCache createApiResponseCache() => $create;\n",
  };
}
