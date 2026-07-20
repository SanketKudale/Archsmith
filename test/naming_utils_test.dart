import 'package:archsmith/archsmith.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes common naming styles', () {
    for (final input in [
      'user-profile',
      'user_profile',
      'UserProfile',
      'user profile',
    ]) {
      final value = names(input);
      expect(value.snakeCase, 'user_profile');
      expect(value.camelCase, 'userProfile');
      expect(value.pascalCase, 'UserProfile');
      expect(value.titleCase, 'User Profile');
    }
  });
}
