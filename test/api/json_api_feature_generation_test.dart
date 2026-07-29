import 'dart:convert';
import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const endpointMap = <String, Object?>{
    'url': 'accountDeactivate',
    'request': {
      'fullAccountNumber': '0471-0621998-001-3000-000',
      'closingReason': 1,
    },
    'response': {
      'status': {'code': '000000', 'description': 'SUCCESS'},
      'data': {
        'statusCode': 0,
        'statusMessage': 'OPERATION SUCCESSFUL',
      },
    },
  };

  test('reads backend endpoint-only JSON shape', () {
    final endpoint = const JsonApiEndpointReader().fromMap(endpointMap);

    expect(endpoint.path, 'accountDeactivate');
    expect(endpoint.name, 'accountDeactivate');
    expect(endpoint.method, 'POST');
    expect(endpoint.request['closingReason'], 1);
  });

  test('generates every Clean Architecture API layer', () {
    final endpoint = const JsonApiEndpointReader().fromMap(endpointMap);
    final files = const CleanApiFeatureGenerator().generate(
      config: ArchsmithConfig(projectName: 'sample_app'),
      common: ApiCommonConfig(
        baseUrl: 'https://api.example.com/',
        headers: {'Content-Type': 'application/json'},
        request: {'channel': 'MOBILE'},
      ),
      endpoint: endpoint,
      feature: 'cusacc',
    );
    final paths = files.map((file) => file.path).toSet();

    expect(
      paths,
      containsAll({
        'lib/features/cusacc/data/datasources/account_deactivate_remote_data_source.dart',
        'lib/features/cusacc/data/models/account_deactivate_request_model.dart',
        'lib/features/cusacc/data/models/account_deactivate_response_model.dart',
        'lib/features/cusacc/data/repositories/cusacc_repository_impl.dart',
        'lib/features/cusacc/domain/entities/account_deactivate_request_entity.dart',
        'lib/features/cusacc/domain/entities/account_deactivate_response_entity.dart',
        'lib/features/cusacc/domain/repositories/cusacc_repository.dart',
        'lib/features/cusacc/domain/usecases/account_deactivate_use_case.dart',
        'lib/features/cusacc/presentation/states/account_deactivate_state.dart',
        'lib/features/cusacc/presentation/providers/account_deactivate_provider.dart',
        'lib/core/network/auth/api_request_coordinator.dart',
        'lib/core/network/cache/api_response_cache.dart',
        'lib/core/network/cache/memory_api_response_cache.dart',
      }),
    );
    expect(
      paths,
      isNot(
        contains(
          'lib/features/cusacc/presentation/providers/account_deactivate_data_source_provider.dart',
        ),
      ),
    );
    final responseModel = files
        .singleWhere(
          (file) => file.path.endsWith(
            'account_deactivate_response_model.dart',
          ),
        )
        .content;
    expect(
      responseModel,
      contains('class AccountDeactivateResponseStatusModel'),
    );
    expect(
      responseModel,
      contains('class AccountDeactivateResponseDataModel'),
    );
    expect(responseModel, contains('class AccountDeactivateResponseModel'));
    final config = files
        .singleWhere((file) => file.path.endsWith('api_config.dart'))
        .content;
    expect(config, contains("baseUrl = 'https://api.example.com'"));
    expect(config, contains("'channel': 'MOBILE'"));
    expect(config, contains("successKey => 'status.code'"));
    final state = files
        .singleWhere(
          (file) => file.path.endsWith('account_deactivate_state.dart'),
        )
        .content;
    expect(state, contains('bool get isEmpty'));
    expect(state, contains('Future<void> retry()'));
    final dataSource = files
        .singleWhere(
          (file) =>
              file.path.endsWith('account_deactivate_remote_data_source.dart'),
        )
        .content;
    expect(dataSource, contains('coordinator.execute'));
    expect(dataSource, contains('cache.read(cacheKey)'));
  });

  test('generates dependency injection for every state manager', () {
    final endpoint = const JsonApiEndpointReader().fromMap(endpointMap);
    for (final stateManagement in StateManagementType.values) {
      final files = const CleanApiFeatureGenerator().generate(
        config: ArchsmithConfig(
          projectName: 'sample_app',
          stateManagement: stateManagement,
        ),
        common: const ApiCommonConfig(baseUrl: 'https://api.example.com'),
        endpoint: endpoint,
        feature: 'cusacc',
      );
      final provider = files
          .singleWhere(
            (file) => file.path.endsWith('account_deactivate_provider.dart'),
          )
          .content;
      expect(provider, isNotEmpty, reason: stateManagement.value);
      expect(
        provider,
        contains('CusaccRepositoryImpl'),
        reason: stateManagement.value,
      );
      expect(
        files
            .where(
              (file) =>
                  file.path.contains('/presentation/providers/') &&
                  file.path.startsWith('lib/features/'),
            )
            .map((file) => file.path),
        [
          'lib/features/cusacc/presentation/providers/account_deactivate_notifier.dart',
          'lib/features/cusacc/presentation/providers/account_deactivate_provider.dart',
        ],
        reason: stateManagement.value,
      );
      expect(
        files.map((file) => file.path),
        contains(
          'lib/core/network/providers/api_request_coordinator_provider.dart',
        ),
      );
    }
  });

  test('all state-manager variants generate valid Dart syntax', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_state_variants_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final endpoint = const JsonApiEndpointReader().fromMap(endpointMap);
    for (final stateManagement in StateManagementType.values) {
      final variant = Directory(
        p.join(directory.path, stateManagement.value),
      );
      final files = const CleanApiFeatureGenerator().generate(
        config: ArchsmithConfig(
          projectName: 'sample_app',
          stateManagement: stateManagement,
        ),
        common: const ApiCommonConfig(baseUrl: 'https://api.example.com'),
        endpoint: endpoint,
        feature: 'cusacc',
      );
      for (final planned in files.where(
        (file) => file.path.endsWith('.dart'),
      )) {
        final file = File(p.join(variant.path, planned.path));
        await file.parent.create(recursive: true);
        await file.writeAsString(planned.content);
      }
      final result = await Process.run(Platform.resolvedExecutable, [
        'format',
        '--output=none',
        variant.path,
      ]);
      expect(
        result.exitCode,
        0,
        reason: '${stateManagement.value}: ${result.stderr}',
      );
    }
  });

  test('generated feature Dart files are syntactically valid', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_json_api_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final files = const CleanApiFeatureGenerator().generate(
      config: ArchsmithConfig(projectName: 'sample_app'),
      common: ApiCommonConfig(baseUrl: 'https://api.example.com'),
      endpoint: const JsonApiEndpointReader().fromMap(endpointMap),
      feature: 'cusacc',
    );
    for (final planned in files) {
      final file = File(p.join(directory.path, planned.path));
      await file.parent.create(recursive: true);
      await file.writeAsString(planned.content);
    }

    final result = await Process.run(Platform.resolvedExecutable, [
      'format',
      '--output=none',
      directory.path,
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    await _writeAnalyzerStubs(directory);
    final get = await Process.run(
      Platform.resolvedExecutable,
      ['pub', 'get'],
      workingDirectory: directory.path,
    );
    expect(get.exitCode, 0, reason: get.stderr.toString());
    final analysis = await Process.run(
      Platform.resolvedExecutable,
      ['analyze'],
      workingDirectory: directory.path,
    );
    expect(analysis.exitCode, 0, reason: analysis.stdout.toString());
  });

  test('common configuration can append headers and request values', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_common_api_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'archsmith_api_common.json');
    const store = ApiCommonConfigStore();
    const initial = ApiCommonConfig(baseUrl: 'https://api.example.com');
    await store.write(path, initial);
    final current = store.read(path);
    await store.write(
      path,
      current.copyWith(
        headers: {...current.headers, 'X-Channel': 'MOBILE'},
        request: {...current.request, 'deviceId': 'abc'},
      ),
    );

    final restored = store.read(path);
    expect(restored.headers['X-Channel'], 'MOBILE');
    expect(restored.request['deviceId'], 'abc');
  });

  test('api-common CLI creates and appends shared values', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_common_cli_',
    );
    final previous = Directory.current;
    addTearDown(() {
      Directory.current = previous;
      return directory.delete(recursive: true);
    });
    Directory.current = directory;
    final runner = ArchsmithRunner();

    expect(
      await runner.run([
        'api-common',
        'base-url',
        'https://api.example.com',
      ]),
      0,
    );
    expect(
      await runner.run(['api-common', 'header', 'X-Channel', 'MOBILE']),
      0,
    );
    expect(
      await runner.run(['api-common', 'request', 'retryCount', '3']),
      0,
    );
    expect(await runner.run(['api-common', 'success-code', '"00"']), 0);
    expect(
      await runner.run(['api-common', 'add-success-code', '"000000"']),
      0,
    );
    expect(
      await runner.run([
        'api-common',
        'success-code-path',
        'meta.resultCode',
      ]),
      0,
    );
    expect(
      await runner.run(['api-common', 'message-path', 'meta.message']),
      0,
    );
    expect(await runner.run(['api-common', 'cache-enabled', 'true']), 0);
    expect(await runner.run(['api-common', 'cache-ttl', '900']), 0);

    final config = const ApiCommonConfigStore().read(
      p.join(directory.path, 'archsmith_api_common.json'),
    );
    expect(config.headers['X-Channel'], 'MOBILE');
    expect(config.request['retryCount'], 3);
    expect(config.successCodes, ['00', '000000']);
    expect(config.successCodePath, 'meta.resultCode');
    expect(config.messagePath, 'meta.message');
    expect(config.cacheEnabled, isTrue);
    expect(config.cacheTtlSeconds, 900);
  });

  test('api CLI accepts endpoint JSON and derives the feature', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_json_cli_',
    );
    final previous = Directory.current;
    addTearDown(() {
      Directory.current = previous;
      return directory.delete(recursive: true);
    });
    await const LocalFileSystemService().apply(
        directory.path,
        [
          const ConfigWriter().plan(
            const ArchsmithConfig(projectName: 'sample_app'),
          ),
        ],
        const GenerationOptions());
    await const ApiCommonConfigStore().write(
      p.join(directory.path, 'archsmith_api_common.json'),
      const ApiCommonConfig(baseUrl: 'https://api.example.com'),
    );
    final endpoint = File(p.join(directory.path, 'cusacc.json'));
    await endpoint.writeAsString(
      const JsonEncoder.withIndent('  ').convert(endpointMap),
    );
    Directory.current = directory;

    final exitCode = await ArchsmithRunner().run([
      'api',
      endpoint.path,
      '--dry-run',
    ]);

    expect(exitCode, 0);
    expect(
      Directory(p.join(directory.path, 'lib', 'features')).existsSync(),
      isFalse,
    );
  });
}

Future<void> _writeAnalyzerStubs(Directory project) async {
  final dio = Directory(p.join(project.path, '.stubs', 'dio'));
  final riverpod = Directory(p.join(project.path, '.stubs', 'riverpod'));
  await Directory(p.join(dio.path, 'lib')).create(recursive: true);
  await Directory(p.join(riverpod.path, 'lib')).create(recursive: true);
  await File(p.join(dio.path, 'pubspec.yaml')).writeAsString('''
name: dio
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
  await File(p.join(dio.path, 'lib', 'dio.dart')).writeAsString('''
class Dio {
  Future<Response<T>> request<T>(
    String path, {
    Object? data,
    Map<String, Object?>? queryParameters,
    Options? options,
  }) async => Response<T>();
}
class Response<T> {
  T? data;
  int? statusCode;
}
class DioException implements Exception {
  Response<Object?>? response;
  String? message;
}
class Options {
  Options({
    String? method,
    Map<String, String>? headers,
    bool Function(int?)? validateStatus,
  });
}
''');
  await File(p.join(riverpod.path, 'pubspec.yaml')).writeAsString('''
name: flutter_riverpod
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
  await File(
    p.join(riverpod.path, 'lib', 'flutter_riverpod.dart'),
  ).writeAsString('''
abstract class ProviderListenable<T> {}
class Ref {
  T watch<T>(ProviderListenable<T> provider) => throw UnimplementedError();
}
class Provider<T> extends ProviderListenable<T> {
  Provider(T Function(Ref) create);
}
class StateNotifier<T> {
  StateNotifier(this.state);
  T state;
}
class StateNotifierProvider<N extends StateNotifier<S>, S>
    extends ProviderListenable<S> {
  StateNotifierProvider(N Function(Ref) create);
}
''');
  final networkClient = File(
    p.join(project.path, 'lib', 'core', 'network', 'network_client.dart'),
  );
  await networkClient.parent.create(recursive: true);
  await networkClient.writeAsString('''
import 'package:dio/dio.dart';
class NetworkClient {
  NetworkClient();
  final Dio dio = Dio();
}
''');
  await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: sample_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  dio:
    path: ${dio.path.replaceAll(r'\', '/')}
  flutter_riverpod:
    path: ${riverpod.path.replaceAll(r'\', '/')}
''');
}
