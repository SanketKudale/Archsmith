import 'dart:convert';
import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('serves metadata, saves schemas, and protects extension pages',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_studio_server_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final server = StudioServer(
      projectRoot: directory.path,
      config: const ArchsmithConfig(projectName: 'sample_app'),
    );
    await const LocalFileSystemService().apply(
      directory.path,
      [
        const StudioComponentManifestStore().plan(
          directory.path,
          const StudioComponentDescriptor(
            type: 'projectBanner',
            label: 'Project Banner',
            category: 'Project',
            acceptsChildren: false,
            dartClass: 'ProjectBanner',
            importPath: 'package:sample_app/shared/widgets/project_banner.dart',
          ),
        ),
      ],
      const GenerationOptions(),
    );
    final asset = File(p.join(directory.path, 'assets', 'logo.png'));
    await asset.parent.create(recursive: true);
    await asset.writeAsBytes([137, 80, 78, 71]);
    final url = await server.start(port: 0);
    addTearDown(server.close);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    final bootstrap = await _request(client, url.resolve('/api/bootstrap'));
    expect(bootstrap.statusCode, HttpStatus.ok);
    final metadata = jsonDecode(bootstrap.body) as Map<String, dynamic>;
    expect(metadata['project'], 'sample_app');
    expect(metadata['components'], isNotEmpty);
    expect(
      (metadata['components'] as List)
          .map((item) => (item as Map<String, dynamic>)['type']),
      contains('projectBanner'),
    );
    expect(metadata['actions'], isEmpty);
    expect(metadata['templates'], isEmpty);
    expect(metadata['design_tokens'], isA<Map<String, dynamic>>());
    expect(metadata['localization'], isA<Map<String, dynamic>>());
    expect(metadata['assets'], contains('assets/logo.png'));

    final savedTokens = await _request(
      client,
      url.resolve('/api/design-tokens'),
      method: 'POST',
      body: jsonEncode({
        'colors': {'brand': '#123456'},
        'spacing': {'content': 16},
        'radii': {'control': 12},
        'font_sizes': {'body': 14},
      }),
    );
    expect(savedTokens.statusCode, HttpStatus.ok);
    expect(
      File(
        p.join(directory.path, '.archsmith', 'design_tokens.json'),
      ).existsSync(),
      isTrue,
    );

    final schema = {
      'version': 1,
      'name': 'home',
      'feature': 'home',
      'route': '/home',
      'root': {
        'id': 'page',
        'type': 'appScaffold',
        'properties': {'title': 'Home'},
        'children': [
          {
            'id': 'welcome',
            'type': 'text',
            'properties': {'text': 'Welcome'},
          },
        ],
      },
    };
    final generated = await _request(
      client,
      url.resolve('/api/generate'),
      method: 'POST',
      body: jsonEncode(schema),
    );
    expect(generated.statusCode, HttpStatus.ok, reason: generated.body);
    final source = File(
      p.join(directory.path, '.archsmith', 'ui', 'home.json'),
    );
    final generatedPage = File(
      p.join(
        directory.path,
        'lib',
        'features',
        'home',
        'presentation',
        'pages',
        'home_page.archsmith.dart',
      ),
    );
    final extensionPage = File(
      p.join(
        directory.path,
        'lib',
        'features',
        'home',
        'presentation',
        'pages',
        'home_page.dart',
      ),
    );
    expect(source.existsSync(), isTrue);
    expect(generatedPage.readAsStringSync(), contains('_buildDesktop'));
    expect(extensionPage.existsSync(), isTrue);

    await extensionPage.writeAsString('// developer customization\n');
    final regenerated = await _request(
      client,
      url.resolve('/api/generate'),
      method: 'POST',
      body: jsonEncode(schema),
    );
    expect(regenerated.statusCode, HttpStatus.ok, reason: regenerated.body);
    expect(
      extensionPage.readAsStringSync(),
      '// developer customization\n',
    );

    final templateSchema = {...schema, 'name': 'dashboard_template'};
    final savedTemplate = await _request(
      client,
      url.resolve('/api/templates'),
      method: 'POST',
      body: jsonEncode(templateSchema),
    );
    expect(savedTemplate.statusCode, HttpStatus.ok);
    final loadedTemplate = await _request(
      client,
      url.resolve('/api/templates/dashboard_template'),
    );
    expect(loadedTemplate.statusCode, HttpStatus.ok);
    expect(
      (jsonDecode(loadedTemplate.body) as Map<String, dynamic>)['name'],
      'dashboard_template',
    );

    final deleted = await _request(
      client,
      url.resolve('/api/screens/home'),
      method: 'DELETE',
    );
    expect(deleted.statusCode, HttpStatus.ok);
    expect(source.existsSync(), isFalse);
    expect(generatedPage.existsSync(), isTrue);
  });
}

Future<({int statusCode, String body})> _request(
  HttpClient client,
  Uri uri, {
  String method = 'GET',
  String? body,
}) async {
  final request = await client.openUrl(method, uri);
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(body);
  }
  final response = await request.close();
  return (
    statusCode: response.statusCode,
    body: await utf8.decoder.bind(response).join(),
  );
}
