import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class FlavorDefinition {
  const FlavorDefinition({
    required this.name,
    required this.appName,
    required this.applicationId,
    this.iconPath,
    this.dartDefines = const {},
  });

  final String name;
  final String appName;
  final String applicationId;
  final String? iconPath;
  final Map<String, String> dartDefines;

  Map<String, Object?> toJson() => {
        'name': name,
        'app_name': appName,
        'application_id': applicationId,
        if (iconPath != null) 'icon': iconPath,
        'dart_defines': dartDefines,
      };

  factory FlavorDefinition.fromJson(Map<String, Object?> json) =>
      FlavorDefinition(
        name: json['name']! as String,
        appName: json['app_name']! as String,
        applicationId: json['application_id']! as String,
        iconPath: json['icon'] as String?,
        dartDefines: Map<String, String>.from(
          (json['dart_defines'] as Map?) ?? const {},
        ),
      );
}

class FlavorConfig {
  const FlavorConfig({
    this.defaultFlavor,
    this.flavors = const [],
  });

  final String? defaultFlavor;
  final List<FlavorDefinition> flavors;

  FlavorDefinition flavor(String name) => flavors.firstWhere(
        (flavor) => flavor.name == name,
        orElse: () => throw FormatException(
          'Unknown flavor "$name". Create it first.',
        ),
      );

  Map<String, Object?> toJson() => {
        if (defaultFlavor != null) 'default_flavor': defaultFlavor,
        'flavors': flavors.map((flavor) => flavor.toJson()).toList(),
      };

  factory FlavorConfig.fromJson(Map<String, Object?> json) => FlavorConfig(
        defaultFlavor: json['default_flavor'] as String?,
        flavors: ((json['flavors'] as List?) ?? const [])
            .map(
              (value) => FlavorDefinition.fromJson(
                Map<String, Object?>.from(value as Map),
              ),
            )
            .toList(growable: false),
      );
}

class FlavorUpdateResult {
  const FlavorUpdateResult({
    required this.config,
    required this.paths,
  });

  final FlavorConfig config;
  final List<String> paths;
}

/// Persists flavor definitions and produces flutter_flavorizr input.
class FlavorService {
  const FlavorService();

  FlavorConfig read(String root) {
    final file = File(_configPath(root));
    if (!file.existsSync()) {
      throw FileSystemException(
        'Flavor configuration was not found. Run flavor create first.',
        file.path,
      );
    }
    return FlavorConfig.fromJson(
      Map<String, Object?>.from(jsonDecode(file.readAsStringSync()) as Map),
    );
  }

  Future<FlavorUpdateResult> upsert(
    String root,
    FlavorDefinition definition, {
    bool makeDefault = false,
    String? sourceIconPath,
    bool dryRun = false,
  }) async {
    _validate(definition);
    final projectRoot = p.normalize(p.absolute(root));
    _validateFlutterProject(projectRoot);
    File? sourceIcon;
    if (sourceIconPath != null) {
      sourceIcon = File(p.normalize(p.absolute(sourceIconPath)));
      if (!sourceIcon.existsSync()) {
        throw FileSystemException('Flavor icon was not found', sourceIcon.path);
      }
      if (p.extension(sourceIcon.path).toLowerCase() != '.png') {
        throw const FormatException('Flavor icon must be a PNG file.');
      }
    }
    final configFile = File(_configPath(projectRoot));
    final current =
        configFile.existsSync() ? read(projectRoot) : const FlavorConfig();
    final flavors = [
      for (final flavor in current.flavors)
        if (flavor.name != definition.name) flavor,
      definition,
    ]..sort((left, right) => left.name.compareTo(right.name));
    final updated = FlavorConfig(
      defaultFlavor: makeDefault ? definition.name : current.defaultFlavor,
      flavors: List.unmodifiable(flavors),
    );
    final paths = <String>[
      '.archsmith/flavors.json',
      'flavorizr.yaml',
      'lib/core/environment/flavor_config.dart',
    ];
    if (sourceIconPath != null) {
      paths.add('assets/branding/flavors/${definition.name}.png');
    }
    if (makeDefault) {
      paths.add('pubspec.yaml');
    }
    if (dryRun) {
      return FlavorUpdateResult(config: updated, paths: paths);
    }

    await configFile.parent.create(recursive: true);
    await configFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(updated.toJson())}\n',
    );
    await File(p.join(projectRoot, 'flavorizr.yaml')).writeAsString(
      _flavorizrYaml(projectRoot, updated),
    );
    final runtimeFile = File(
      p.join(
        projectRoot,
        'lib',
        'core',
        'environment',
        'flavor_config.dart',
      ),
    );
    await runtimeFile.parent.create(recursive: true);
    await runtimeFile.writeAsString(_runtimeConfig(updated));
    if (sourceIcon != null) {
      final target = File(
        p.join(
          projectRoot,
          'assets',
          'branding',
          'flavors',
          '${definition.name}.png',
        ),
      );
      await target.parent.create(recursive: true);
      await sourceIcon.copy(target.path);
    }
    if (makeDefault) {
      final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
      await pubspec.writeAsString(
        _setDefaultFlavor(pubspec.readAsStringSync(), definition.name),
      );
    }
    return FlavorUpdateResult(config: updated, paths: paths);
  }

  Future<FlavorUpdateResult> sync(
    String root, {
    bool dryRun = false,
  }) async {
    final projectRoot = p.normalize(p.absolute(root));
    _validateFlutterProject(projectRoot);
    final config = read(projectRoot);
    const paths = [
      'flavorizr.yaml',
      'lib/core/environment/flavor_config.dart',
    ];
    if (!dryRun) {
      await File(p.join(projectRoot, 'flavorizr.yaml')).writeAsString(
        _flavorizrYaml(projectRoot, config),
      );
      final runtimeFile = File(
        p.join(
          projectRoot,
          'lib',
          'core',
          'environment',
          'flavor_config.dart',
        ),
      );
      await runtimeFile.parent.create(recursive: true);
      await runtimeFile.writeAsString(_runtimeConfig(config));
    }
    return FlavorUpdateResult(config: config, paths: paths);
  }

  String _configPath(String root) =>
      p.join(p.normalize(p.absolute(root)), '.archsmith', 'flavors.json');

  void _validateFlutterProject(String root) {
    final pubspec = File(p.join(root, 'pubspec.yaml'));
    if (!pubspec.existsSync() ||
        !RegExp(r'^flutter:\s*$', multiLine: true)
            .hasMatch(pubspec.readAsStringSync())) {
      throw FileSystemException(
        'Flavor management requires a Flutter project',
        pubspec.path,
      );
    }
  }

  void _validate(FlavorDefinition definition) {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(definition.name)) {
      throw const FormatException(
        'Flavor name must be lower_snake_case and start with a letter.',
      );
    }
    if (definition.appName.trim().isEmpty) {
      throw const FormatException('Flavor app name cannot be empty.');
    }
    if (!RegExp(
      r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$',
    ).hasMatch(definition.applicationId)) {
      throw const FormatException(
        'Application ID must look like com.example.app.',
      );
    }
    for (final key in definition.dartDefines.keys) {
      if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(key)) {
        throw FormatException(
          'Dart define "$key" must use UPPER_SNAKE_CASE.',
        );
      }
    }
  }

  String _flavorizrYaml(String root, FlavorConfig config) {
    final instructions = <String>[
      if (Directory(p.join(root, 'android')).existsSync()) ...[
        'android:androidManifest',
        'android:flavorizrGradle',
        'android:buildGradle',
        'android:icons',
      ],
      if (Platform.isMacOS && Directory(p.join(root, 'ios')).existsSync()) ...[
        'ios:podfile',
        'ios:xcconfig',
        'ios:buildTargets',
        'ios:schema',
        'ios:icons',
        'ios:plist',
      ],
      if (Platform.isMacOS &&
          Directory(p.join(root, 'macos')).existsSync()) ...[
        'macos:podfile',
        'macos:xcconfig',
        'macos:configs',
        'macos:buildTargets',
        'macos:schema',
        'macos:icons',
        'macos:plist',
      ],
      'ide:config',
    ];
    final buffer = StringBuffer('instructions:\n');
    for (final instruction in instructions) {
      buffer.writeln('  - $instruction');
    }
    buffer.writeln('flavors:');
    for (final flavor in config.flavors) {
      final icon = flavor.iconPath;
      buffer
        ..writeln('  ${flavor.name}:')
        ..writeln('    app:')
        ..writeln('      name: ${jsonEncode(flavor.appName)}')
        ..writeln('    android:')
        ..writeln(
          '      applicationId: ${jsonEncode(flavor.applicationId)}',
        );
      if (icon != null) buffer.writeln('      icon: ${jsonEncode(icon)}');
      buffer
        ..writeln('    ios:')
        ..writeln('      bundleId: ${jsonEncode(flavor.applicationId)}');
      if (icon != null) buffer.writeln('      icon: ${jsonEncode(icon)}');
      buffer
        ..writeln('    macos:')
        ..writeln('      bundleId: ${jsonEncode(flavor.applicationId)}');
      if (icon != null) buffer.writeln('      icon: ${jsonEncode(icon)}');
    }
    return buffer.toString();
  }

  String _runtimeConfig(FlavorConfig config) {
    final keys = config.flavors
        .expand((flavor) => flavor.dartDefines.keys)
        .toSet()
        .toList()
      ..sort();
    final fallback = config.defaultFlavor ?? config.flavors.first.name;
    return "import 'package:flutter/services.dart' show appFlavor;\n\n"
        "abstract final class FlavorConfig {\n"
        "  static String get name => appFlavor ?? const String.fromEnvironment('FLAVOR', defaultValue: ${jsonEncode(fallback)});\n"
        "  static const values = <String, String>{\n"
        "${keys.map((key) => "    ${jsonEncode(key)}: String.fromEnvironment(${jsonEncode(key)}),").join('\n')}\n"
        "  };\n"
        "  static String? value(String key) { final result = values[key]; return result == null || result.isEmpty ? null : result; }\n"
        "}\n";
  }

  String _setDefaultFlavor(String content, String flavor) {
    final newline = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(RegExp(r'\r?\n'));
    final flutter = lines.indexWhere((line) => line.trim() == 'flutter:');
    if (flutter < 0) return content;
    var end = lines.length;
    for (var index = flutter + 1; index < lines.length; index++) {
      final line = lines[index];
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
        end = index;
        break;
      }
    }
    final existing = lines.indexWhere(
      (line) => line.trimLeft().startsWith('default-flavor:'),
      flutter + 1,
    );
    if (existing >= 0 && existing < end) {
      lines[existing] = '  default-flavor: $flavor';
    } else {
      lines.insert(flutter + 1, '  default-flavor: $flavor');
    }
    return lines.join(newline);
  }
}
