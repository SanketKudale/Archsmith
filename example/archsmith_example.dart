import 'package:archsmith/archsmith.dart';

void main() {
  const config = ArchsmithConfig(projectName: 'example_app');
  final plan = const GenerationEngine().architecture(config);
  for (final file in plan) {
    print('CREATE ${file.path}');
  }
}
