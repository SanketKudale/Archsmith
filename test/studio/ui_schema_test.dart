import 'dart:convert';
import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('round-trips a responsive screen and validates action bindings', () {
    final schema = UiScreenSchema.fromJson({
      'version': 1,
      'name': 'account_deactivate',
      'feature': 'cusacc',
      'route': '/account-deactivate',
      'root': {
        'id': 'page',
        'type': 'appScaffold',
        'properties': {'title': 'Deactivate account'},
        'children': [
          {
            'id': 'content',
            'type': 'column',
            'responsive': {
              'desktop': {'gap': 24},
              'mobile': {'gap': 12},
            },
            'children': [
              {
                'id': 'account_number',
                'type': 'appTextField',
                'properties': {'label': 'Account number'},
              },
              {
                'id': 'submit',
                'type': 'appButton',
                'action': {
                  'action_id': 'cusacc.accountDeactivate',
                  'arguments': {
                    'fullAccountNumber': r'$account_number.value',
                  },
                },
              },
            ],
          },
        ],
      },
    });
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
      ],
    );

    expect(
      const UiSchemaValidator().validate(schema, actions: const [action]),
      isEmpty,
    );
    expect(
      UiScreenSchema.fromJson(schema.toJson()).root.children.first.id,
      'content',
    );
  });

  test('reports unknown components and missing required action arguments', () {
    final schema = UiScreenSchema(
      name: 'broken',
      root: const UiNode(
        id: 'root',
        type: 'unknown',
        action: UiActionBinding(actionId: 'feature.load'),
      ),
    );
    const action = StudioActionDescriptor(
      id: 'feature.load',
      feature: 'feature',
      operation: 'load',
      stateManagement: 'riverpod',
      target: 'loadProvider',
      method: 'execute',
      requestType: 'LoadRequestEntity',
      parameters: [StudioActionParameter(name: 'id', type: 'String')],
    );

    final issues = const UiSchemaValidator().validate(
      schema,
      actions: const [action],
    );

    expect(
        issues.map((issue) => issue.message),
        containsAll([
          'Unknown component type unknown.',
          'Missing required argument id.',
        ]));
  });

  test('watch bindings expose state without requiring request arguments', () {
    const schema = UiScreenSchema(
      name: 'loading',
      root: UiNode(
        id: 'progress',
        type: 'appLoadingIndicator',
        action: UiActionBinding(
          actionId: 'feature.load',
          method: 'watch',
        ),
      ),
    );
    const action = StudioActionDescriptor(
      id: 'feature.load',
      feature: 'feature',
      operation: 'load',
      stateManagement: 'riverpod',
      target: 'loadProvider',
      method: 'execute',
      requestType: 'LoadRequestEntity',
      parameters: [StudioActionParameter(name: 'id', type: 'String')],
    );

    expect(
      const UiSchemaValidator().validate(schema, actions: const [action]),
      isEmpty,
    );
  });

  test('reports unknown fields and incompatible action literals', () {
    const schema = UiScreenSchema(
      name: 'invalid_binding',
      root: UiNode(
        id: 'submit',
        type: 'appButton',
        action: UiActionBinding(
          actionId: 'items.load',
          arguments: {
            'count': r'$missing.value',
            'enabled': 'yes',
          },
        ),
      ),
    );
    const action = StudioActionDescriptor(
      id: 'items.load',
      feature: 'items',
      operation: 'load',
      stateManagement: 'riverpod',
      target: 'loadProvider',
      method: 'execute',
      requestType: 'LoadRequestEntity',
      parameters: [
        StudioActionParameter(name: 'count', type: 'int'),
        StudioActionParameter(name: 'enabled', type: 'bool'),
      ],
    );

    final issues = const UiSchemaValidator().validate(
      schema,
      actions: const [action],
    );

    expect(
      issues.map((issue) => issue.message),
      containsAll([
        'Unknown input field missing.',
        'Expected bool, received String.',
      ]),
    );
  });

  test('reports response bindings that are not in action metadata', () {
    const schema = UiScreenSchema(
      name: 'invalid_response',
      root: UiNode(
        id: 'message',
        type: 'stateText',
        properties: {'binding': 'data.missing'},
        action: UiActionBinding(
          actionId: 'items.load',
          method: 'watch',
        ),
      ),
    );
    const action = StudioActionDescriptor(
      id: 'items.load',
      feature: 'items',
      operation: 'load',
      stateManagement: 'riverpod',
      target: 'loadProvider',
      method: 'execute',
      requestType: 'LoadRequestEntity',
      parameters: [],
      responseFields: [
        StudioDataField(name: 'message', type: 'String'),
      ],
      state: {'data': 'data', 'error': 'error'},
    );

    final issues = const UiSchemaValidator().validate(
      schema,
      actions: const [action],
    );

    expect(
      issues.map((issue) => issue.message),
      contains('Unknown state binding data.missing.'),
    );
  });

  test('round-trips conditional multi-action flows and feedback', () {
    const schema = UiScreenSchema(
      name: 'checkout',
      root: UiNode(
        id: 'submit',
        type: 'appButton',
        action: UiActionBinding(
          actionId: 'checkout.validate',
          arguments: {'id': '42'},
          successMessage: 'Validated',
        ),
        actions: [
          UiActionBinding(
            actionId: 'checkout.submit',
            arguments: {'id': '42'},
            runWhen: 'previousSuccess',
            onErrorRoute: '/failed',
            errorMessage: 'Submission failed',
          ),
        ],
      ),
    );
    const actions = [
      StudioActionDescriptor(
        id: 'checkout.validate',
        feature: 'checkout',
        operation: 'validate',
        stateManagement: 'riverpod',
        target: 'validateProvider',
        method: 'execute',
        requestType: 'ValidateRequestEntity',
        parameters: [StudioActionParameter(name: 'id', type: 'String')],
      ),
      StudioActionDescriptor(
        id: 'checkout.submit',
        feature: 'checkout',
        operation: 'submit',
        stateManagement: 'riverpod',
        target: 'submitProvider',
        method: 'execute',
        requestType: 'SubmitRequestEntity',
        parameters: [StudioActionParameter(name: 'id', type: 'String')],
      ),
    ];

    final restored = UiScreenSchema.fromJson(schema.toJson());

    expect(restored.root.actions.single.runWhen, 'previousSuccess');
    expect(restored.root.actions.single.onErrorRoute, '/failed');
    expect(
      const UiSchemaValidator().validate(restored, actions: actions),
      isEmpty,
    );
  });

  test('reports overlapping responsive breakpoint ranges', () {
    const schema = UiScreenSchema(
      name: 'overlap',
      breakpoints: [
        UiBreakpoint(name: 'small', maxWidth: 700),
        UiBreakpoint(name: 'large', minWidth: 600),
      ],
      root: UiNode(id: 'root', type: 'column'),
    );

    expect(
      const UiSchemaValidator().validate(schema).map((issue) => issue.message),
      contains('Breakpoint ranges cannot overlap.'),
    );
  });

  test('round-trips typed route arguments', () {
    const schema = UiScreenSchema(
      name: 'account',
      route: '/account',
      routeArguments: [
        UiRouteArgument(name: 'accountId', type: 'String'),
        UiRouteArgument(name: 'tab', type: 'int', required: false),
      ],
      root: UiNode(id: 'root', type: 'column'),
    );

    final restored = UiScreenSchema.fromJson(schema.toJson());

    expect(restored.routeArguments.first.name, 'accountId');
    expect(restored.routeArguments.last.required, isFalse);
  });

  test('migrates version 1 schemas with a recoverable backup', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_ui_migration_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'screen.json'));
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'name': 'legacy',
        'root': {'id': 'root', 'type': 'column'},
      }),
    );

    final result = await const UiSchemaStore().migrate(file.path);

    expect(result.changed, isTrue);
    expect(result.fromVersion, 1);
    expect(result.toVersion, archsmithUiSchemaVersion);
    expect(File(result.backupPath!).existsSync(), isTrue);
    expect(
      (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['version'],
      archsmithUiSchemaVersion,
    );
  });
}
