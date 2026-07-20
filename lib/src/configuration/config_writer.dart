import 'dart:convert';

import '../models/generation.dart';
import 'archsmith_config.dart';

class ConfigWriter {
  const ConfigWriter();

  PlannedFile plan(ArchsmithConfig config) {
    config.validate();
    return PlannedFile('archsmith.yaml', _yaml(config.toMap()));
  }

  String _yaml(Map<String, Object?> map, [int depth = 0]) {
    final buffer = StringBuffer();
    final indent = '  ' * depth;
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is Map) {
        buffer.writeln('$indent${entry.key}:');
        buffer.write(_yaml(value.cast<String, Object?>(), depth + 1));
      } else {
        buffer.writeln('$indent${entry.key}: ${_scalar(value)}');
      }
    }
    return buffer.toString();
  }

  String _scalar(Object? value) {
    if (value is bool || value is num) return value.toString();
    return jsonEncode(value?.toString() ?? '');
  }
}
