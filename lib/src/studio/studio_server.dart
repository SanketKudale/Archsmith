import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../configuration/archsmith_config.dart';
import '../generators/route_registry_generator.dart';
import '../models/generation.dart';
import '../models/options.dart';
import '../services/file_system_service.dart';
import 'action_registry.dart';
import 'component_registry.dart';
import 'studio_assets.dart';
import 'ui_code_generator.dart';
import 'ui_schema.dart';
import 'ui_validator.dart';

/// Local HTTP server that hosts the drag-and-drop Archsmith Studio.
class StudioServer {
  StudioServer({
    required this.projectRoot,
    required this.config,
    FileSystemService fileSystem = const LocalFileSystemService(),
  }) : _fileSystem = fileSystem;

  final String projectRoot;
  final ArchsmithConfig config;
  final FileSystemService _fileSystem;
  HttpServer? _server;

  Uri? get url {
    final server = _server;
    if (server == null) return null;
    return Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
    );
  }

  Future<Uri> start({
    InternetAddress? address,
    int port = 7331,
  }) async {
    if (_server != null) {
      throw StateError('Archsmith Studio is already running.');
    }
    final server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    _server = server;
    unawaited(_serve(server));
    return url!;
  }

  Future<void> close() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handleSafely(request));
    }
  }

  Future<void> _handleSafely(HttpRequest request) async {
    try {
      await _handle(request);
    } on FormatException catch (error) {
      await _json(
        request.response,
        HttpStatus.badRequest,
        {'error': error.message},
      );
    } on FileSystemException catch (error) {
      await _json(
        request.response,
        HttpStatus.internalServerError,
        {'error': error.message},
      );
    } catch (error) {
      await _json(
        request.response,
        HttpStatus.internalServerError,
        {'error': error.toString()},
      );
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    if (request.method == 'GET' && path == '/') {
      return _text(request.response, 'text/html', StudioAssets.html);
    }
    if (request.method == 'GET' && path == '/styles.css') {
      return _text(request.response, 'text/css', StudioAssets.css);
    }
    if (request.method == 'GET' && path == '/app.js') {
      return _text(
        request.response,
        'application/javascript',
        StudioAssets.js,
      );
    }
    if (request.method == 'GET' && path == '/api/bootstrap') {
      final components = _components();
      return _json(request.response, HttpStatus.ok, {
        'components': components.toJson(),
        'actions': _actions().map((action) => action.toJson()).toList(),
        'breakpoints':
            defaultUiBreakpoints.map((item) => item.toJson()).toList(),
        'screens': _screenNames(),
        'project': config.projectName,
        'state_management': config.stateManagement.value,
      });
    }
    if (request.method == 'GET' && path.startsWith('/api/screens/')) {
      final name = Uri.decodeComponent(path.substring('/api/screens/'.length));
      final schema = const UiSchemaStore().read(_screenPath(name));
      return _json(request.response, HttpStatus.ok, schema.toJson());
    }
    if (request.method == 'POST' &&
        (path == '/api/screens' || path == '/api/generate')) {
      final schema = await _readSchema(request);
      final actions = _actions();
      final components = _components();
      final issues = UiSchemaValidator(components: components).validate(
        schema,
        actions: actions,
      );
      if (issues.isNotEmpty) {
        throw FormatException(
            issues.map((issue) => issue.toString()).join('\n'));
      }
      await const UiSchemaStore().write(_screenPath(schema.name), schema);
      if (path == '/api/screens') {
        return _json(request.response, HttpStatus.ok, {
          'message': 'Saved ${schema.name}',
          'schema': _relative(_screenPath(schema.name)),
        });
      }
      final wrapperPath = _wrapperPath(schema);
      final files = <PlannedFile>[
        ...const UiCodeGenerator().generate(
          config: config,
          schema: schema,
          actions: actions,
          components: components,
          includeExtensionFile: !File(wrapperPath).existsSync(),
        ),
        if (schema.route != null && config.router != RouterType.none)
          ...const RouteRegistryGenerator().register(
            root: projectRoot,
            config: config,
            pageName: schema.name,
            routePath: schema.route!,
            feature: schema.feature,
          ),
      ];
      final result = await _fileSystem.apply(
        projectRoot,
        files,
        const GenerationOptions(),
      );
      if (result.hasConflicts) {
        throw const FormatException(
          'Generation found a protected file conflict.',
        );
      }
      return _json(request.response, HttpStatus.ok, {
        'message': 'Generated ${schema.name} page',
        'files': result.entries
            .map(
              (entry) => {
                'path': entry.path,
                'action': entry.action.name,
              },
            )
            .toList(),
      });
    }
    await _json(
      request.response,
      HttpStatus.notFound,
      {'error': 'Not found'},
    );
  }

  List<StudioActionDescriptor> _actions() =>
      const StudioActionRegistry().readAll(projectRoot);

  StudioComponentRegistry _components() => StudioComponentRegistry(
        custom: const StudioComponentManifestStore().readAll(projectRoot),
      );

  Future<UiScreenSchema> _readSchema(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Request body must contain a JSON object.');
    }
    return UiScreenSchema.fromJson(Map<String, Object?>.from(decoded));
  }

  List<String> _screenNames() {
    final directory = Directory(p.join(projectRoot, '.archsmith', 'ui'));
    if (!directory.existsSync()) return const [];
    final names = directory
        .listSync()
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.json')
        .map((file) => p.basenameWithoutExtension(file.path))
        .toList()
      ..sort();
    return names;
  }

  String _screenPath(String name) {
    final safeName = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (safeName.isEmpty) {
      throw const FormatException(
          'Screen name must contain letters or digits.');
    }
    return p.join(projectRoot, '.archsmith', 'ui', '$safeName.json');
  }

  String _wrapperPath(UiScreenSchema schema) {
    final feature = (schema.feature ?? schema.name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    final screen =
        schema.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    final directory = switch (config.architecture) {
      ArchitectureType.cleanFeature =>
        p.join('lib', 'features', feature, 'presentation', 'pages'),
      ArchitectureType.mvvm => p.join('lib', 'features', feature, 'views'),
      ArchitectureType.cleanLayer => p.join('lib', 'presentation', 'pages'),
      ArchitectureType.simpleFeature =>
        p.join('lib', 'features', feature, 'pages'),
    };
    return p.join(projectRoot, directory, '${screen}_page.dart');
  }

  String _relative(String path) => p.relative(path, from: projectRoot);

  Future<void> _text(
    HttpResponse response,
    String contentType,
    String content,
  ) async {
    response
      ..statusCode = HttpStatus.ok
      ..headers
          .set(HttpHeaders.contentTypeHeader, '$contentType; charset=utf-8')
      ..write(content);
    await response.close();
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Object value,
  ) async {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(value));
    await response.close();
  }
}
