import 'package:archsmith/archsmith.dart';
import 'package:test/test.dart';

void main() {
  group('architecture generation', () {
    for (final architecture in ArchitectureType.values) {
      test('plans ${architecture.value}', () {
        final files = const GenerationEngine().architecture(
          ArchsmithConfig(
            projectName: 'sample_app',
            architecture: architecture,
          ),
        );
        expect(files.map((file) => file.path), contains('lib/main.dart'));
        expect(files.map((file) => file.path), contains('archsmith.yaml'));
        expect(files.map((file) => file.path), contains('archsmith_api.yaml'));
        expect(
          files.map((file) => file.path),
          contains('lib/shared/widgets/app_component_defaults.dart'),
        );
        expect(
          files.map((file) => file.path),
          contains('lib/shared/widgets/common_widgets.dart'),
        );
      });
    }
  });

  test('runtime protection separates service, policy, checks, and UI', () {
    final files = const GenerationEngine().architecture(
      const ArchsmithConfig(
        projectName: 'secure_app',
        modules: ModuleConfig(runtimeProtection: true),
        runtimeProtectionProfile: RuntimeProtectionProfile.examination,
      ),
    );
    final paths = files.map((file) => file.path).toSet();
    expect(
      paths,
      contains('lib/core/runtime_protection/runtime_protection_service.dart'),
    );
    expect(
      paths,
      contains(
        'lib/core/runtime_protection/policies/examination_security_policy.dart',
      ),
    );
    expect(
      paths,
      contains('lib/core/runtime_protection/checks/screen_sharing_check.dart'),
    );
    expect(
      paths,
      contains(
        'lib/core/runtime_protection/presentation/security_blocking_page.dart',
      ),
    );
    expect(
      paths.any((path) => path.startsWith('lib/core/security/runtime')),
      isFalse,
    );
  });

  test('feature generation follows selected architecture', () {
    final files = const GenerationEngine().component(
      const ArchsmithConfig(projectName: 'sample_app'),
      'feature',
      'user-profile',
    );
    expect(
      files.map((file) => file.path),
      contains(
        'lib/features/user_profile/presentation/pages/user_profile_page.dart',
      ),
    );
    expect(
      files
          .singleWhere((file) => file.path.endsWith('user_profile_page.dart'))
          .content,
      contains('AppScaffold'),
    );
  });

  test('widget generation always targets the shared component folder', () {
    for (final architecture in ArchitectureType.values) {
      final files = const GenerationEngine().component(
        ArchsmithConfig(projectName: 'sample_app', architecture: architecture),
        'widget',
        'profile-card',
      );
      expect(
        files.map((file) => file.path),
        contains('lib/shared/widgets/profile_card_widget.dart'),
      );
      expect(
        files
            .singleWhere(
              (file) => file.path.endsWith('profile_card_widget.dart'),
            )
            .content,
        contains('class ProfileCardWidget extends StatelessWidget'),
      );
    }
  });
}
