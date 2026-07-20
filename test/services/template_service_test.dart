import 'package:archsmith/archsmith.dart';
import 'package:test/test.dart';

void main() {
  test('renders all supported name variants', () {
    final output = const TemplateService().render(
      '{{name.snakeCase}} {{name.camelCase}} {{name.pascalCase}} {{name.titleCase}}',
      {'name': 'User-Profile'},
    );
    expect(output, 'user_profile userProfile UserProfile User Profile');
  });

  test('fails on unresolved variables', () {
    expect(
      () => const TemplateService().render('{{missing}}', const {}),
      throwsFormatException,
    );
  });
}
