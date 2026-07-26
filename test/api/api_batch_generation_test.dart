import 'dart:convert';
import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('batch generation emits shared infrastructure once and a summary',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_api_batch_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final first = await _endpoint(
      directory,
      'close_account.json',
      'accountDeactivate',
    );
    final second = await _endpoint(
      directory,
      'account_status.json',
      'accountStatus',
    );

    final files = const ApiBatchGenerator().generate(
      config: ArchsmithConfig(projectName: 'sample_app'),
      common: ApiCommonConfig(baseUrl: 'https://api.example.com'),
      endpointFiles: [second, first],
    );
    final paths = files.map((file) => file.path);

    expect(
      paths.where((path) => path.endsWith('api_config.dart')).length,
      1,
    );
    expect(
      paths,
      contains(
        'lib/features/close_account/domain/usecases/'
        'account_deactivate_use_case.dart',
      ),
    );
    expect(
      paths,
      contains(
        'lib/features/account_status/domain/usecases/'
        'account_status_use_case.dart',
      ),
    );
    expect(
      paths,
      contains(
        'lib/core/network/shared/account_status_request_model.dart',
      ),
    );
    expect(
      files
          .singleWhere(
            (file) =>
                file.path ==
                'lib/features/close_account/data/models/'
                    'account_deactivate_request_model.dart',
          )
          .content,
      contains('typedef AccountDeactivateRequestModel'),
    );
    final summary = files
        .singleWhere(
          (file) => file.path == 'docs/archsmith_api_summary.md',
        )
        .content;
    expect(summary, contains('Generated from 2 endpoint example files'));
    expect(summary, contains('`accountDeactivate`'));
    expect(summary, contains('`accountStatus`'));
  });

  test('api-dir CLI supports external endpoint directories', () async {
    final project = await Directory.systemTemp.createTemp(
      'archsmith_api_dir_project_',
    );
    final contracts = await Directory.systemTemp.createTemp(
      'archsmith_api_dir_contracts_',
    );
    final repository = Directory.current;
    addTearDown(() async {
      await project.delete(recursive: true);
      await contracts.delete(recursive: true);
    });
    await const LocalFileSystemService().apply(
      project.path,
      [
        const ConfigWriter().plan(
          const ArchsmithConfig(projectName: 'sample_app'),
        ),
      ],
      const GenerationOptions(),
    );
    await const ApiCommonConfigStore().write(
      p.join(project.path, 'archsmith_api_common.json'),
      const ApiCommonConfig(baseUrl: 'https://api.example.com'),
    );
    await _endpoint(contracts, 'profile.json', 'profile');

    final result = await Process.run(
        Platform.resolvedExecutable,
        [
          p.join(repository.path, 'bin', 'archsmith.dart'),
          'api-dir',
          contracts.path,
          '--dry-run',
        ],
        workingDirectory: project.path);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(Directory(p.join(project.path, 'lib')).existsSync(), isFalse);
  });
}

Future<File> _endpoint(
  Directory directory,
  String filename,
  String url,
) async {
  final file = File(p.join(directory.path, filename));
  await file.writeAsString(
    jsonEncode({
      'url': url,
      'request': {'id': 1},
      'response': {
        'status': {'code': '000000'},
        'data': {'id': 1},
      },
    }),
  );
  return file;
}
