import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('design tokens and localization generate deterministic Dart helpers',
      () {
    const tokens = StudioDesignTokens(
      colors: {'brand': '#123456'},
      spacing: {'content': 18},
      radii: {'control': 10},
      fontSizes: {'body': 15},
    );
    const catalog = StudioLocalizationCatalog(
      defaultLocale: 'en',
      locales: {
        'en': {'welcome': 'Welcome'},
        'hi': {'welcome': 'स्वागत'},
      },
    );

    expect(
      tokens.dartSource(),
      contains('static const colorsBrand = Color(0xFF123456)'),
    );
    expect(
      tokens.dartSource(),
      contains('static const double spacingContent = 18.0'),
    );
    expect(
      catalog.dartSource(),
      contains("values[defaultLocale]?[key]"),
    );
  });

  test('asset registry returns supported project images only', () async {
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_assets_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final images = Directory(p.join(directory.path, 'assets', 'images'));
    await images.create(recursive: true);
    await File(p.join(images.path, 'logo.png')).writeAsBytes([1, 2, 3]);
    await File(p.join(images.path, 'notes.txt')).writeAsString('ignore');

    expect(
      const StudioAssetRegistry().readAll(directory.path),
      ['assets/images/logo.png'],
    );
  });

  test('validates image semantics and unknown shared references', () {
    const schema = UiScreenSchema(
      name: 'branding',
      root: UiNode(
        id: 'content',
        type: 'column',
        children: [
          UiNode(
            id: 'logo',
            type: 'imageAsset',
            properties: {
              'asset': 'assets/logo.png',
              'semanticLabel': r'$i18n.missing',
              'width': r'$token.spacing.missing',
            },
          ),
        ],
      ),
    );

    final messages = const UiSchemaValidator().validate(schema,
        assets: const ['assets/logo.png']).map((issue) => issue.message);

    expect(messages, contains('Unknown localization key missing.'));
    expect(messages, contains('Unknown design token spacing.missing.'));
  });
}
