import 'dart:io';

import 'package:yaml/yaml.dart';

import 'archsmith_config.dart';

class ConfigReader {
  const ConfigReader();

  ArchsmithConfig read(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('archsmith.yaml was not found', path);
    }
    final document = loadYaml(file.readAsStringSync());
    if (document is! YamlMap) {
      throw const FormatException('archsmith.yaml must contain a YAML map.');
    }
    return ArchsmithConfig.fromMap(_plain(document) as Map<Object?, Object?>);
  }

  Object? _plain(Object? value) {
    if (value is YamlMap) {
      return {
        for (final entry in value.entries) entry.key: _plain(entry.value),
      };
    }
    if (value is YamlList) return value.map(_plain).toList();
    return value;
  }
}
