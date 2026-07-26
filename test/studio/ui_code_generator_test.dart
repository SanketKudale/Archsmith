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
        StudioDataField(
          name: 'items',
          type: 'List<AccountDeactivateResponseItemsItemEntity>',
          isList: true,
          children: [
            StudioDataField(name: 'label', type: 'String'),
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
              UiNode(
                id: 'items',
                type: 'stateGrid',
                properties: {
                  'binding': 'data.items',
                  'itemTextPath': 'label',
                  'columns': 3,
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
    expect(generated, contains('GridView.builder'));
    expect(generated, contains('crossAxisCount: 3'));
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
        'state.data?.status.description',
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
          StudioDataField(
            name: 'items',
            type: 'List<LoadResponseItemsItemEntity>',
            isList: true,
            children: [
              StudioDataField(name: 'message', type: 'String'),
            ],
          ),
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
              id: 'items',
              type: 'stateList',
              properties: {
                'binding': 'data.items',
                'itemTextPath': 'message',
              },
              action: UiActionBinding(
                actionId: 'items.load',
                method: 'watch',
              ),
            ),
            UiNode(
              id: 'offline',
              type: 'offlineBanner',
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
      final generated = files
          .singleWhere((file) => file.path.endsWith('.archsmith.dart'))
          .content;
      if (manager == StateManagementType.none) {
        expect(generated, contains('ValueListenable<LoadState>'));
        expect(generated, contains('ValueListenableBuilder<LoadState>'));
      }
      expect(generated, contains('ListView.separated'));
      expect(generated, contains('RefreshIndicator'));
      expect(generated, contains('item.message.toString()'));
      expect(generated, contains('MaterialBanner'));
      expect(generated, contains('state.isOffline'));
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

  test('generates nested entities and object lists from structured bindings',
      () async {
    const action = StudioActionDescriptor(
      id: 'profile.update',
      feature: 'profile',
      operation: 'update',
      stateManagement: 'riverpod',
      target: 'updateProvider',
      method: 'execute',
      requestType: 'UpdateRequestEntity',
      parameters: [
        StudioActionParameter(
          name: 'profile',
          type: 'UpdateRequestProfileEntity',
          children: [
            StudioActionParameter(name: 'name', type: 'String'),
            StudioActionParameter(name: 'age', type: 'int'),
          ],
        ),
        StudioActionParameter(
          name: 'tags',
          type: 'List<String>',
          isList: true,
        ),
        StudioActionParameter(
          name: 'addresses',
          type: 'List<UpdateRequestAddressesItemEntity>',
          isList: true,
          children: [
            StudioActionParameter(name: 'city', type: 'String'),
            StudioActionParameter(name: 'postalCode', type: 'int'),
          ],
        ),
      ],
    );
    const schema = UiScreenSchema(
      name: 'profile',
      root: UiNode(
        id: 'form',
        type: 'column',
        children: [
          UiNode(id: 'name', type: 'appTextField'),
          UiNode(id: 'age', type: 'appTextField'),
          UiNode(id: 'city', type: 'appTextField'),
          UiNode(id: 'postal_code', type: 'appTextField'),
          UiNode(
            id: 'submit',
            type: 'appButton',
            action: UiActionBinding(
              actionId: 'profile.update',
              arguments: {
                'profile': {
                  'name': r'$name.value',
                  'age': r'$age.value',
                },
                'tags': ['mobile', 'customer'],
                'addresses': [
                  {
                    'city': r'$city.value',
                    'postalCode': r'$postal_code.value',
                  },
                ],
              },
            ),
          ),
        ],
      ),
    );

    final files = const UiCodeGenerator().generate(
      config: ArchsmithConfig(projectName: 'sample_app'),
      schema: schema,
      actions: const [action],
    );
    final source = files
        .singleWhere((file) => file.path.endsWith('.archsmith.dart'))
        .content;

    expect(source, contains('UpdateRequestProfileEntity('));
    expect(source, contains("tags: ['mobile', 'customer']"));
    expect(source, contains('[UpdateRequestAddressesItemEntity('));
    expect(source, contains('int.tryParse'));

    final directory = await Directory.systemTemp.createTemp(
      'archsmith_nested_ui_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'page.dart'));
    await file.writeAsString(source);
    final format = await Process.run(
      Platform.resolvedExecutable,
      ['format', '--output=none', file.path],
    );
    expect(format.exitCode, 0, reason: format.stderr.toString());
  });

  test('generates confirmed conditional flows with debounce and feedback',
      () async {
    const actions = [
      StudioActionDescriptor(
        id: 'checkout.validate',
        feature: 'checkout',
        operation: 'validate',
        stateManagement: 'riverpod',
        target: 'validateProvider',
        method: 'execute',
        requestType: 'ValidateRequestEntity',
        supportsCancellation: true,
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
        supportsCancellation: true,
        supportsOptimistic: true,
        parameters: [StudioActionParameter(name: 'id', type: 'String')],
      ),
    ];
    const schema = UiScreenSchema(
      name: 'checkout',
      root: UiNode(
        id: 'page',
        type: 'column',
        children: [
          UiNode(
            id: 'checkout_button',
            type: 'appButton',
            properties: {
              'confirmationTitle': 'Place order?',
              'confirmationMessage': 'Your payment will be submitted.',
              'debounceMs': 250,
              'cancelPrevious': true,
            },
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
                optimistic: true,
                errorMessage: 'Could not submit',
                onErrorRoute: '/failed',
              ),
            ],
          ),
        ],
      ),
    );

    final source = const UiCodeGenerator()
        .generate(
          config: ArchsmithConfig(projectName: 'sample_app'),
          schema: schema,
          actions: actions,
        )
        .first
        .content;

    expect(source, contains('_runCheckoutButtonFlow'));
    expect(source, contains('Duration(milliseconds: 250)'));
    expect(source, contains('flowGeneration != _checkoutButtonFlowGeneration'));
    expect(source, contains('showDialog<bool>'));
    expect(source, contains('validateProvider.notifier).cancel()'));
    expect(source, contains('applyOptimistic(optimisticData)'));
    expect(source, contains('if (previousSucceeded)'));
    expect(source, contains("_showActionMessage('Validated')"));
    expect(source, contains("Navigator.of(context).pushNamed('/failed')"));

    final directory = await Directory.systemTemp.createTemp(
      'archsmith_action_flow_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'page.dart'));
    await file.writeAsString(source);
    final format = await Process.run(
      Platform.resolvedExecutable,
      ['format', '--output=none', file.path],
    );
    expect(format.exitCode, 0, reason: format.stderr.toString());
  });

  test('generates tokenized localized and accessible asset presentation', () {
    const schema = UiScreenSchema(
      name: 'branding',
      root: UiNode(
        id: 'page',
        type: 'appScaffold',
        properties: {
          'title': r'$i18n.welcome',
          'padding': r'$token.spacing.content',
        },
        children: [
          UiNode(
            id: 'logo',
            type: 'imageAsset',
            properties: {
              'asset': 'assets/logo.png',
              'width': r'$token.spacing.logo',
              'semanticLabel': r'$i18n.logoLabel',
              'fit': 'contain',
            },
          ),
          UiNode(
            id: 'continue_button',
            type: 'appButton',
            properties: {
              'label': r'$i18n.continueLabel',
              'semanticLabel': r'$i18n.continueHint',
              'tooltip': r'$i18n.continueHint',
            },
          ),
        ],
      ),
    );
    const tokens = StudioDesignTokens(
      spacing: {'content': 16, 'logo': 96},
    );
    const localization = StudioLocalizationCatalog(
      locales: {
        'en': {
          'welcome': 'Welcome',
          'logoLabel': 'Company logo',
          'continueLabel': 'Continue',
          'continueHint': 'Continue to the next step',
        },
      },
    );

    final files = const UiCodeGenerator().generate(
      config: ArchsmithConfig(projectName: 'sample_app'),
      schema: schema,
      actions: const [],
      designTokens: tokens,
      localization: localization,
      assets: const ['assets/logo.png'],
    );
    final source = files
        .singleWhere((file) => file.path.endsWith('.archsmith.dart'))
        .content;

    expect(
      source,
      contains("ArchsmithLocalizations.text(context, 'welcome')"),
    );
    expect(
      source,
      contains('ArchsmithDesignTokens.spacingContent'),
    );
    expect(source, contains("Image.asset('assets/logo.png'"));
    expect(source, contains('excludeFromSemantics: false'));
    expect(source, contains('Semantics('));
    expect(source, contains('Tooltip('));
    expect(
      files.map((file) => file.path),
      containsAll([
        'lib/shared/theme/archsmith_design_tokens.dart',
        'lib/shared/localization/archsmith_localizations.dart',
      ]),
    );
  });

  test('binds typed route arguments into generated API requests', () {
    const action = StudioActionDescriptor(
      id: 'accounts.load',
      feature: 'accounts',
      operation: 'load',
      stateManagement: 'riverpod',
      target: 'loadProvider',
      method: 'execute',
      requestType: 'LoadRequestEntity',
      parameters: [
        StudioActionParameter(name: 'accountId', type: 'String'),
      ],
    );
    const schema = UiScreenSchema(
      name: 'account',
      route: '/account',
      routeArguments: [
        UiRouteArgument(name: 'accountId', type: 'String'),
      ],
      root: UiNode(
        id: 'load',
        type: 'appButton',
        action: UiActionBinding(
          actionId: 'accounts.load',
          arguments: {'accountId': r'$route.accountId'},
        ),
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
    final extension =
        files.singleWhere((file) => file.path.endsWith('_page.dart')).content;

    expect(generated, contains('required this.accountId'));
    expect(generated, contains('final String accountId'));
    expect(generated, contains('accountId: widget.accountId'));
    expect(extension, contains('accountId: accountId'));
  });
}
