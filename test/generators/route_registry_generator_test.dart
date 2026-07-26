import 'dart:convert';
import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('registers GoRouter pages without removing custom router code',
      () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_routes_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final router = File(
      p.join(directory.path, 'lib', 'core', 'router', 'app_router.dart'),
    );
    await router.parent.create(recursive: true);
    await router.writeAsString(
      "import 'package:go_router/go_router.dart';\n"
      "// Keep this custom redirect.\n"
      "final appRouter = GoRouter(routes: []);\n",
    );
    const config = ArchsmithConfig(projectName: 'sample_app');
    final files = const RouteRegistryGenerator().register(
      root: directory.path,
      config: config,
      pageName: 'account_deactivate',
      routePath: '/account-deactivate',
      feature: 'accounts',
      routeArguments: const [
        UiRouteArgument(name: 'accountId', type: 'String'),
        UiRouteArgument(name: 'reasonCode', type: 'int', required: false),
      ],
    );
    final result = await const LocalFileSystemService().apply(
      directory.path,
      files,
      const GenerationOptions(),
    );

    expect(result.hasConflicts, isFalse);
    expect(
        router.readAsStringSync(), contains('// Keep this custom redirect.'));
    expect(router.readAsStringSync(), contains('...generatedRoutes'));
    final manifest = jsonDecode(
      File(p.join(directory.path, '.archsmith', 'routes.json'))
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    final route = (manifest['routes'] as List).single as Map<String, dynamic>;
    expect(route['path'], '/account-deactivate');
    final registry = File(
      p.join(
        directory.path,
        'lib',
        'core',
        'router',
        'generated_routes.dart',
      ),
    ).readAsStringSync();
    expect(registry, contains('goToAccountDeactivate'));
    expect(registry, contains('AccountDeactivatePage'));
    expect(registry, contains('class AccountDeactivateRouteArgs'));
    expect(registry, contains('required String accountId'));
    expect(registry, contains('extra: AccountDeactivateRouteArgs'));
    expect(registry, contains('accountId: args.accountId'));
    expect(
      (route['arguments'] as List).length,
      2,
    );
  });

  test('rejects duplicate paths owned by another page', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_route_duplicate_',
    );
    addTearDown(() => directory.delete(recursive: true));
    const generator = RouteRegistryGenerator();
    const config = ArchsmithConfig(
      projectName: 'sample_app',
      router: RouterType.navigator,
    );
    final first = generator.register(
      root: directory.path,
      config: config,
      pageName: 'first',
      routePath: '/same',
    );
    await const LocalFileSystemService().apply(
      directory.path,
      first,
      const GenerationOptions(),
    );

    expect(
      () => generator.register(
        root: directory.path,
        config: config,
        pageName: 'second',
        routePath: '/same',
      ),
      throwsFormatException,
    );
  });

  test('updates Archsmith AutoRoute markers', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_auto_routes_',
    );
    addTearDown(() => directory.delete(recursive: true));
    const config = ArchsmithConfig(
      projectName: 'sample_app',
      router: RouterType.autoRoute,
    );
    final routerPlan =
        const GenerationEngine().architecture(config).singleWhere(
              (file) => file.path == 'lib/core/router/app_router.dart',
            );
    await const LocalFileSystemService().apply(
      directory.path,
      [routerPlan],
      const GenerationOptions(),
    );

    final files = const RouteRegistryGenerator().register(
      root: directory.path,
      config: config,
      pageName: 'account_deactivate',
      routePath: '/account-deactivate',
      feature: 'accounts',
    );
    await const LocalFileSystemService().apply(
      directory.path,
      files,
      const GenerationOptions(),
    );
    final router = File(
      p.join(directory.path, 'lib', 'core', 'router', 'app_router.dart'),
    ).readAsStringSync();

    expect(router, contains('account_deactivate_page.dart'));
    expect(
      router,
      contains(
        'AutoRoute(page: AccountDeactivateRoute.page, '
        'path: AppRoutes.accountDeactivate)',
      ),
    );
  });
}
