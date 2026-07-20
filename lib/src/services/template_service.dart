import 'dart:io';

import '../utils/naming_utils.dart';

class TemplateService {
  const TemplateService();

  String render(String template, Map<String, String> variables) {
    var output = template;
    for (final entry in variables.entries) {
      final value = names(entry.value);
      final replacements = {
        '{{${entry.key}}}': entry.value,
        '{{${entry.key}.snakeCase}}': value.snakeCase,
        '{{${entry.key}.camelCase}}': value.camelCase,
        '{{${entry.key}.pascalCase}}': value.pascalCase,
        '{{${entry.key}.titleCase}}': value.titleCase,
      };
      for (final replacement in replacements.entries) {
        output = output.replaceAll(replacement.key, replacement.value);
      }
    }
    final unresolved = RegExp(r'\{\{[^}]+\}\}').firstMatch(output);
    if (unresolved != null) {
      throw FormatException(
        'Unresolved template variable: ${unresolved.group(0)}',
      );
    }
    return output;
  }

  String renderFile(String path, Map<String, String> variables) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Template not found', path);
    }
    return render(file.readAsStringSync(), variables);
  }
}
