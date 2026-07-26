import 'package:archsmith/archsmith.dart';
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
}
