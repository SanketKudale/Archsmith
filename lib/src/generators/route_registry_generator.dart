import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../configuration/archsmith_config.dart';
import '../models/generation.dart';
import '../models/options.dart';
import '../utils/naming_utils.dart';

/// Maintains Archsmith-owned route metadata and generated navigation helpers.
class RouteRegistryGenerator {
  const RouteRegistryGenerator();

  List<PlannedFile> register({
    required String root,
    required ArchsmithConfig config,
    required String pageName,
    required String routePath,
    String? feature,
  }) {
    if (!routePath.startsWith('/')) {
      throw const FormatException('Route paths must start with /.');
    }
    if (config.router == RouterType.none) {
      throw const FormatException(
        'Route registration requires a configured router.',
      );
    }
    final page = names(pageName);
    final featureName = names(feature ?? pageName).snakeCase;
    final importPath = _pageImport(config, featureName, page.snakeCase);
    final manifestPath = p.join(root, '.archsmith', 'routes.json');
    final routes = _readManifest(manifestPath);
    final existing = routes[routePath];
    if (existing != null && existing.importPath != importPath) {
      throw FormatException(
        'Route $routePath is already registered to ${existing.className}.',
      );
    }
    routes[routePath] = _RouteEntry(
      path: routePath,
      name: page.camelCase,
      className: '${page.pascalCase}Page',
      importPath: importPath,
    );
    final sorted = routes.values.toList()
      ..sort((left, right) => left.path.compareTo(right.path));
    final files = <PlannedFile>[
      PlannedFile(
        '.archsmith/routes.json',
        '${const JsonEncoder.withIndent('  ').convert({
              'routes': sorted.map((route) => route.toJson()).toList(),
            })}\n',
        isUpdate: true,
      ),
      PlannedFile(
        'lib/core/router/generated_routes.dart',
        _registry(config, sorted),
        isUpdate: true,
      ),
    ];
    final routerPath = p.join(root, 'lib', 'core', 'router', 'app_router.dart');
    if (config.router == RouterType.goRouter && File(routerPath).existsSync()) {
      files.add(
        PlannedFile(
          'lib/core/router/app_router.dart',
          _wireGoRouter(File(routerPath).readAsStringSync()),
          isUpdate: true,
        ),
      );
    }
    if (config.router == RouterType.autoRoute &&
        File(routerPath).existsSync()) {
      files.add(
        PlannedFile(
          'lib/core/router/app_router.dart',
          _wireAutoRouter(File(routerPath).readAsStringSync(), sorted),
          isUpdate: true,
        ),
      );
    }
    return files;
  }

  Map<String, _RouteEntry> _readManifest(String path) {
    final file = File(path);
    if (!file.existsSync()) return {};
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map || decoded['routes'] is! List) {
      throw const FormatException('Invalid .archsmith/routes.json file.');
    }
    return {
      for (final value in decoded['routes'] as List)
        if (value is Map) value['path'].toString(): _RouteEntry.fromJson(value),
    };
  }

  String _pageImport(
    ArchsmithConfig config,
    String feature,
    String page,
  ) =>
      switch (config.architecture) {
        ArchitectureType.cleanFeature =>
          'package:${config.projectName}/features/$feature/presentation/pages/${page}_page.dart',
        ArchitectureType.mvvm =>
          'package:${config.projectName}/features/$feature/views/${page}_page.dart',
        ArchitectureType.cleanLayer =>
          'package:${config.projectName}/presentation/pages/${page}_page.dart',
        ArchitectureType.simpleFeature =>
          'package:${config.projectName}/features/$feature/pages/${page}_page.dart',
      };

  String _registry(ArchsmithConfig config, List<_RouteEntry> routes) {
    final imports = config.router == RouterType.autoRoute
        ? ''
        : routes.map((route) => "import '${route.importPath}';").join('\n');
    final constants = routes
        .map(
          (route) =>
              "  static const ${names(route.name).camelCase} = '${route.path}';",
        )
        .join('\n');
    final helpers = routes
        .map(
          (route) => switch (config.router) {
            RouterType.goRouter =>
              "  void goTo${names(route.name).pascalCase}() => go(AppRoutes.${names(route.name).camelCase});",
            RouterType.autoRoute =>
              "  void goTo${names(route.name).pascalCase}() => router.pushNamed(AppRoutes.${names(route.name).camelCase});",
            RouterType.navigator =>
              "  Future<T?> goTo${names(route.name).pascalCase}<T>() => Navigator.of(this).pushNamed<T>(AppRoutes.${names(route.name).camelCase});",
            RouterType.none => '',
          },
        )
        .join('\n');
    final routeEntries = routes
        .map(
          (route) => switch (config.router) {
            RouterType.goRouter =>
              "  GoRoute(path: AppRoutes.${names(route.name).camelCase}, builder: (_, __) => const ${route.className}()),",
            RouterType.navigator =>
              "  AppRoutes.${names(route.name).camelCase}: (_) => const ${route.className}(),",
            RouterType.autoRoute || RouterType.none => '',
          },
        )
        .where((line) => line.isNotEmpty)
        .join('\n');
    final routerImport = switch (config.router) {
      RouterType.goRouter => "import 'package:go_router/go_router.dart';",
      RouterType.autoRoute => "import 'package:auto_route/auto_route.dart';",
      RouterType.navigator => '',
      RouterType.none => '',
    };
    final registry = switch (config.router) {
      RouterType.goRouter =>
        'final generatedRoutes = <RouteBase>[\n$routeEntries\n];',
      RouterType.navigator =>
        'final generatedRoutes = <String, WidgetBuilder>{\n$routeEntries\n};',
      RouterType.autoRoute =>
        '// AutoRoute code generation owns page declarations; this file owns paths.',
      RouterType.none => '',
    };
    return "import 'package:flutter/material.dart';\n"
        "$routerImport\n"
        "$imports\n\n"
        "abstract final class AppRoutes {\n$constants\n}\n\n"
        "$registry\n\n"
        "extension GeneratedNavigation on BuildContext {\n$helpers\n}\n";
  }

  String _wireGoRouter(String source) {
    var result = source;
    if (!result.contains("import 'generated_routes.dart';")) {
      final lastImport = result.lastIndexOf("import ");
      final lineEnd = lastImport < 0 ? -1 : result.indexOf('\n', lastImport);
      if (lineEnd < 0) {
        throw const FormatException(
          'Could not safely add generated routes to app_router.dart.',
        );
      }
      result = result.replaceRange(
        lineEnd + 1,
        lineEnd + 1,
        "import 'generated_routes.dart';\n",
      );
    }
    if (!result.contains('...generatedRoutes')) {
      const patterns = ['GoRouter(routes: [', 'GoRouter(\n  routes: ['];
      final pattern = patterns.where(result.contains).firstOrNull;
      if (pattern == null) {
        throw const FormatException(
          'Could not find the GoRouter routes list in app_router.dart.',
        );
      }
      result = result.replaceFirst(pattern, '$pattern...generatedRoutes,');
    }
    return result;
  }

  String _wireAutoRouter(String source, List<_RouteEntry> routes) {
    const importStart = '// archsmith:route-imports:start';
    const importEnd = '// archsmith:route-imports:end';
    const routeStart = '// archsmith:routes:start';
    const routeEnd = '// archsmith:routes:end';
    if (!source.contains(importStart) ||
        !source.contains(importEnd) ||
        !source.contains(routeStart) ||
        !source.contains(routeEnd)) {
      throw const FormatException(
        'AutoRoute registration requires Archsmith route markers in '
        'app_router.dart.',
      );
    }
    final imports =
        routes.map((route) => "import '${route.importPath}';").join('\n');
    final definitions = routes
        .map(
          (route) =>
              '    AutoRoute(page: ${route.className.replaceFirst('Page', 'Route')}.page, path: AppRoutes.${names(route.name).camelCase}),',
        )
        .join('\n');
    return _between(
      _between(source, importStart, importEnd, imports),
      routeStart,
      routeEnd,
      definitions,
    );
  }

  String _between(
    String source,
    String startMarker,
    String endMarker,
    String content,
  ) {
    final start = source.indexOf(startMarker) + startMarker.length;
    final end = source.indexOf(endMarker, start);
    return source.replaceRange(start, end, '\n$content\n');
  }
}

class _RouteEntry {
  const _RouteEntry({
    required this.path,
    required this.name,
    required this.className,
    required this.importPath,
  });

  factory _RouteEntry.fromJson(Map<Object?, Object?> source) => _RouteEntry(
        path: source['path'].toString(),
        name: source['name'].toString(),
        className: source['class_name'].toString(),
        importPath: source['import'].toString(),
      );

  final String path;
  final String name;
  final String className;
  final String importPath;

  Map<String, Object?> toJson() => {
        'path': path,
        'name': name,
        'class_name': className,
        'import': importPath,
      };
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
