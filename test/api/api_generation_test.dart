import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  const reader = ApiContractReader();

  final contractMap = <String, Object?>{
    'base_url': 'https://api.example.com',
    'timeout_seconds': 20,
    'headers': {'Content-Type': 'application/json'},
    'common': {
      'headers': {'X-Platform': 'mobile'},
      'query_parameters': {'locale': 'en'},
      'body_parameters': {'device_type': 'mobile'},
    },
    'response_handling': {
      'data_key': 'data',
      'success_key': 'success',
      'success_values': [true, 1],
      'error_key': 'has_error',
      'error_values': [true],
      'message_key': 'message',
      'code_key': 'error_code',
      'errors_key': 'errors',
      'success_status_codes': [200, 201],
    },
    'models': {
      'User': {
        'fields': {
          'id': 'int',
          'display_name': {'type': 'string', 'required': false},
        },
      },
    },
    'endpoints': [
      {
        'name': 'login',
        'method': 'post',
        'path': '/users/{user_id}/login',
        'headers': {'X-Client': 'mobile'},
        'path_parameters': {'user_id': 'int'},
        'query_parameters': {
          'verbose': {'type': 'bool', 'required': false},
        },
        'request': {
          'model': 'LoginRequest',
          'fields': {'email': 'string', 'password': 'string'},
        },
        'response': {
          'model': 'LoginResponse',
          'fields': {
            'access_token': 'string',
            'user': 'User',
            'roles': 'string[]',
          },
        },
      },
    ],
  };

  test('reads headers, parameters, request, response, and shared models', () {
    final contract = reader.fromMap(contractMap);

    expect(contract.baseUrl, 'https://api.example.com');
    expect(contract.timeoutSeconds, 20);
    expect(contract.headers['X-Platform'], 'mobile');
    expect(contract.queryParameters['locale'], 'en');
    expect(contract.bodyParameters['device_type'], 'mobile');
    expect(contract.responseHandling.dataKey, 'data');
    expect(contract.responseHandling.successKey, 'success');
    expect(contract.responseHandling.successValues, [true, 1]);
    expect(contract.responseHandling.errorKey, 'has_error');
    expect(contract.models.map((model) => model.name), [
      'User',
      'LoginRequest',
      'LoginResponse',
    ]);
    final endpoint = contract.endpoints.single;
    expect(endpoint.method, 'POST');
    expect(endpoint.pathParameters.single.name, 'user_id');
    expect(endpoint.queryParameters.single.required, isFalse);
    expect(endpoint.request!.fields, hasLength(2));
    expect(endpoint.response.fields, hasLength(3));
  });

  test('generates typed Dio code', () {
    final files = const ApiCodeGenerator().generate(
      const ArchsmithConfig(
        projectName: 'sample_app',
        network: NetworkType.dio,
      ),
      reader.fromMap(contractMap),
    );

    expect(
      files.map((file) => file.path),
      contains('lib/core/network/generated/api_client.dart'),
    );
    expect(
      files.map((file) => file.path),
      contains('lib/core/network/generated/api_result.dart'),
    );
    final models = files
        .singleWhere((file) => file.path.endsWith('api_models.dart'))
        .content;
    expect(models, contains('class LoginRequest'));
    expect(models, contains('final User user;'));
    expect(models, contains('final List<String> roles;'));
    final client = files
        .singleWhere((file) => file.path.endsWith('api_client.dart'))
        .content;
    expect(client, contains('Future<ApiResult<LoginResponse>> login'));
    expect(client, contains("method: 'POST'"));
    expect(client, contains('payload.toJson()'));
    expect(client, contains('Uri.encodeComponent(userId.toString())'));
    expect(client, contains('...context.headers'));
    expect(client, contains('ApiResponseHandler.parse<LoginResponse>'));
    final result = files
        .singleWhere((file) => file.path.endsWith('api_result.dart'))
        .content;
    expect(result, contains('ApiErrorType.unauthorized'));
    expect(result, contains('ApiErrorType.validation'));
    expect(result, contains('ApiErrorType.rateLimited'));
    expect(result, contains('ApiErrorType.server'));
  });

  test('generates an HTTP request implementation for HTTP projects', () {
    final files = const ApiCodeGenerator().generate(
      const ArchsmithConfig(
        projectName: 'sample_app',
        network: NetworkType.http,
      ),
      reader.fromMap(contractMap),
    );
    final client = files
        .singleWhere((file) => file.path.endsWith('api_client.dart'))
        .content;

    expect(client, contains("http.Request('POST', uri)"));
    expect(client, contains('jsonEncode(<String, Object?>'));
    expect(client, contains('client.client.send(request)'));
  });

  test('generated Dart files are syntactically valid', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_api_syntax_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final contract = reader.fromMap(contractMap);
    final generated = <PlannedFile>[
      ...const ApiCodeGenerator().generate(
        const ArchsmithConfig(
          projectName: 'sample_app',
          network: NetworkType.dio,
        ),
        contract,
      ),
      ...const ApiCodeGenerator()
          .generate(
            const ArchsmithConfig(
              projectName: 'sample_app',
              network: NetworkType.http,
            ),
            contract,
          )
          .map(
            (file) => PlannedFile(
              p.join('http', p.basename(file.path)),
              file.content,
            ),
          ),
    ];
    for (final planned in generated) {
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

    final supportDirectory = Directory(p.join(directory.path, 'support'));
    await supportDirectory.create();
    for (final planned in generated.where(
      (file) =>
          !file.path.contains('http') &&
          !file.path.endsWith('api_client.dart') &&
          !file.path.endsWith('generated_api.dart'),
    )) {
      await File(
        p.join(supportDirectory.path, p.basename(planned.path)),
      ).writeAsString(planned.content);
    }
    final analysis = await Process.run(Platform.resolvedExecutable, [
      'analyze',
      supportDirectory.path,
    ]);
    expect(analysis.exitCode, 0, reason: analysis.stdout.toString());
  });

  test('rejects endpoint placeholders without matching parameters', () {
    final invalid = Map<String, Object?>.from(contractMap)
      ..['endpoints'] = [
        {
          'name': 'user',
          'method': 'GET',
          'path': '/users/{id}',
          'response': {
            'fields': {'id': 'int'},
          },
        },
      ];

    expect(() => reader.fromMap(invalid), throwsFormatException);
  });
}
