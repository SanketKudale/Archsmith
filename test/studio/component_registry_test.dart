import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('component CLI appends a project common widget manifest', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_component_cli_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final executable = p.join(
      Directory.current.path,
      'bin',
      'archsmith.dart',
    );
    await const LocalFileSystemService().apply(
      directory.path,
      [
        const ConfigWriter().plan(
          ArchsmithConfig(
            projectName: 'sample_app',
            generation: GenerationConfig(
              formatAfterGeneration: false,
              analyzeAfterGeneration: false,
            ),
          ),
        ),
      ],
      const GenerationOptions(),
    );
    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        executable,
        'component',
        'add',
        'profile_card',
        '--class',
        'ProfileCardWidget',
        '--children',
        '--property',
        'title:string',
        '--property',
        'tone:select:light,dark',
      ],
      workingDirectory: directory.path,
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final components =
        const StudioComponentManifestStore().readAll(directory.path);
    expect(components, hasLength(1));
    expect(components.single.type, 'profileCard');
    expect(components.single.importPath,
        'package:sample_app/shared/widgets/profile_card_widget.dart');
    expect(components.single.childParameter, 'child');
    expect(components.single.properties.last.options, ['light', 'dark']);

    final widgetResult = await Process.run(
      Platform.resolvedExecutable,
      [executable, 'widget', 'status_chip', '--no-tests'],
      workingDirectory: directory.path,
    );
    expect(widgetResult.exitCode, 0, reason: widgetResult.stderr.toString());
    expect(
      File(
        p.join(
          directory.path,
          'lib',
          'shared',
          'widgets',
          'status_chip_widget.dart',
        ),
      ).existsSync(),
      isTrue,
    );
    expect(
      const StudioComponentManifestStore()
          .readAll(directory.path)
          .map((item) => item.type),
      containsAll(['profileCard', 'statusChip']),
    );
  });

  test('custom component is validated and rendered with its shared import', () {
    const component = StudioComponentDescriptor(
      type: 'profileCard',
      label: 'Profile Card',
      category: 'Project',
      acceptsChildren: true,
      dartClass: 'ProfileCardWidget',
      importPath: 'package:sample_app/shared/widgets/profile_card_widget.dart',
      childParameter: 'child',
      properties: [
        StudioPropertyDescriptor('title', 'string'),
        StudioPropertyDescriptor('elevation', 'number'),
      ],
    );
    const registry = StudioComponentRegistry(custom: [component]);
    const schema = UiScreenSchema(
      name: 'profile',
      root: UiNode(
        id: 'profile',
        type: 'profileCard',
        properties: {'title': 'Account', 'elevation': 4},
        children: [
          UiNode(
            id: 'name',
            type: 'text',
            properties: {'text': 'Sanket'},
          ),
        ],
      ),
    );

    final files = const UiCodeGenerator().generate(
      config: ArchsmithConfig(projectName: 'sample_app'),
      schema: schema,
      actions: const [],
      components: registry,
    );
    final source = files
        .singleWhere((file) => file.path.endsWith('.archsmith.dart'))
        .content;

    expect(
      source,
      contains(
        "import 'package:sample_app/shared/widgets/profile_card_widget.dart';",
      ),
    );
    expect(
      source,
      contains(
        "ProfileCardWidget(title: 'Account', elevation: 4, child: Text(",
      ),
    );
  });

  test('manifest cannot replace centrally managed built-in components', () {
    final root = p.join(Directory.systemTemp.path, 'archsmith_manifest_guard');

    expect(
      () => const StudioComponentManifestStore().plan(
        root,
        const StudioComponentDescriptor(
          type: 'appButton',
          label: 'Replacement',
          category: 'Project',
          acceptsChildren: false,
          dartClass: 'ReplacementButton',
          importPath: 'package:sample/replacement.dart',
        ),
      ),
      throwsFormatException,
    );
  });
}
