import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('generates responsive Flutter code wired to a Riverpod action',
      () async {
    const action = StudioActionDescriptor(
      id: 'cusacc.accountDeactivate',
      feature: 'cusacc',
      operation: 'accountDeactivate',
      stateManagement: 'riverpod',
      target: 'accountDeactivateProvider',
      method: 'execute',
      requestType: 'AccountDeactivateRequestEntity',
      parameters: [
        StudioActionParameter(name: 'fullAccountNumber', type: 'String'),
        StudioActionParameter(name: 'closingReason', type: 'int'),
      ],
      responseFields: [
        StudioDataField(
          name: 'status',
          type: 'AccountDeactivateResponseStatusEntity',
          children: [
            StudioDataField(name: 'code', type: 'String'),
            StudioDataField(name: 'description', type: 'String'),
          ],
        ),
      ],
    );
    const schema = UiScreenSchema(
      name: 'account_deactivate',
      feature: 'cusacc',
      route: '/account-deactivate',
      root: UiNode(
        id: 'page',
        type: 'appScaffold',
        properties: {'title': 'Deactivate account'},
        children: [
          UiNode(
            id: 'content',
            type: 'column',
            properties: {'gap': 12},
            responsive: {
              'desktop': {'gap': 24},
            },
            children: [
              UiNode(
                id: 'account_number',
                type: 'appTextField',
                properties: {
                  'label': 'Account number',
                  'required': true,
                  'minLength': 6,
                },
              ),
              UiNode(
                id: 'closing_reason',
                type: 'appTextField',
                properties: {
                  'label': 'Closing reason',
                  'valueType': 'int',
                },
              ),
              UiNode(
                id: 'submit',
                type: 'appButton',
                properties: {'label': 'Deactivate'},
                action: UiActionBinding(
                  actionId: 'cusacc.accountDeactivate',
                  arguments: {
                    'fullAccountNumber': r'$account_number.value',
                    'closingReason': r'$closing_reason.value',
                  },
                  onSuccessRoute: '/done',
                ),
              ),
              UiNode(
                id: 'result',
                type: 'stateText',
                properties: {
                  'binding': 'data.status.description',
                  'fallback': 'No result',
                },
                action: UiActionBinding(
                  actionId: 'cusacc.accountDeactivate',
                  method: 'watch',
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final files = const UiCodeGenerator().generate(
      config: ArchsmithConfig(projectName: 'sample_app'),
      schema: schema,
      actions: const [action],
    );
    final generated = files
        .singleWhere((file) => file.path.endsWith('.archsmith.dart'))
        .content;

    expect(generated, contains('constraints.maxWidth >= 1024'));
    expect(generated, contains('_buildDesktop(context)'));
    expect(
      generated,
      contains('ref.read(accountDeactivateProvider.notifier).execute(request)'),
    );
    expect(
      generated,
      contains(
        'fullAccountNumber: '
        '_cusaccAccountDeactivateFullAccountNumberValue',
      ),
    );
    expect(generated, contains('int.tryParse'));
    expect(generated, contains("Account number is required."));
    expect(generated, contains('ref.read(accountDeactivateProvider).error'));
    expect(
      generated,
      contains("Navigator.of(context).pushNamed('/done')"),
    );
    expect(
      generated,
      contains(
        'ref.watch(accountDeactivateProvider)'
        '.data?.status.description',
      ),
    );
    expect(
      files.singleWhere((file) => file.path.endsWith('_page.dart')).content,
      contains('created once and is never regenerated'),
    );

    final directory = await Directory.systemTemp.createTemp(
      'archsmith_ui_code_',
    );
    addTearDown(() => directory.delete(recursive: true));
    for (final planned in files) {
      final file = File(p.join(directory.path, planned.path));
      await file.parent.create(recursive: true);
      await file.writeAsString(planned.content);
    }
    final format = await Process.run(
      Platform.resolvedExecutable,
      ['format', '--output=none', directory.path],
    );
    expect(format.exitCode, 0, reason: format.stderr.toString());
  });

  test('generates valid Dart syntax for every state manager', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_ui_states_',
    );
    addTearDown(() => directory.delete(recursive: true));
    for (final manager in StateManagementType.values) {
      final target = switch (manager) {
        StateManagementType.riverpod => 'loadProvider',
        StateManagementType.provider => 'LoadNotifier',
        StateManagementType.bloc => 'LoadCubit',
        StateManagementType.getx => 'LoadController',
        StateManagementType.none => 'LoadNotifier',
      };
      final action = StudioActionDescriptor(
        id: 'items.load',
        feature: 'items',
        operation: 'load',
        stateManagement: manager.value,
        target: target,
        method: 'execute',
        requestType: 'LoadRequestEntity',
        parameters: const [
          StudioActionParameter(name: 'query', type: 'String'),
        ],
        responseFields: const [
          StudioDataField(name: 'message', type: 'String'),
        ],
      );
      const schema = UiScreenSchema(
        name: 'items',
        root: UiNode(
          id: 'page',
          type: 'column',
          children: [
            UiNode(id: 'query', type: 'appTextField'),
            UiNode(
              id: 'load',
              type: 'appButton',
              action: UiActionBinding(
                actionId: 'items.load',
                arguments: {'query': r'$query.value'},
              ),
            ),
            UiNode(
              id: 'loading',
              type: 'appLoadingIndicator',
              action: UiActionBinding(
                actionId: 'items.load',
                method: 'watch',
              ),
            ),
            UiNode(
              id: 'message',
              type: 'stateText',
              properties: {'binding': 'data.message'},
              action: UiActionBinding(
                actionId: 'items.load',
                method: 'watch',
              ),
            ),
          ],
        ),
      );
      final files = const UiCodeGenerator().generate(
        config: ArchsmithConfig(
          projectName: 'sample_app',
          stateManagement: manager,
        ),
        schema: schema,
        actions: [action],
      );
      final variant = Directory(p.join(directory.path, manager.value));
      for (final planned in files) {
        final file = File(p.join(variant.path, planned.path));
        await file.parent.create(recursive: true);
        await file.writeAsString(planned.content);
      }
      final format = await Process.run(
        Platform.resolvedExecutable,
        ['format', '--output=none', variant.path],
      );
      expect(
        format.exitCode,
        0,
        reason: '${manager.value}: ${format.stderr}',
      );
    }
  });
}
