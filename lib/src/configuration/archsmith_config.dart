import '../models/options.dart';

/// Optional core modules selected for a generated project.
class ModuleConfig {
  const ModuleConfig({
    this.localization = true,
    this.theme = true,
    this.secureStorage = false,
    this.runtimeProtection = false,
  });

  final bool localization;
  final bool theme;
  final bool secureStorage;
  final bool runtimeProtection;
}

/// Persistent behavior applied to future generation commands.
class GenerationConfig {
  const GenerationConfig({
    this.generateTests = true,
    this.useBarrelFiles = false,
    this.formatAfterGeneration = true,
    this.analyzeAfterGeneration = true,
  });

  final bool generateTests;
  final bool useBarrelFiles;
  final bool formatAfterGeneration;
  final bool analyzeAfterGeneration;
}

/// Immutable and validated representation of `archsmith.yaml`.
class ArchsmithConfig {
  const ArchsmithConfig({
    required this.projectName,
    this.architecture = ArchitectureType.cleanFeature,
    this.stateManagement = StateManagementType.riverpod,
    this.router = RouterType.goRouter,
    this.network = NetworkType.dio,
    this.modules = const ModuleConfig(),
    this.runtimeProtectionProfile,
    this.runtimeChecks = const {},
    this.generation = const GenerationConfig(),
  });

  final String projectName;
  final ArchitectureType architecture;
  final StateManagementType stateManagement;
  final RouterType router;
  final NetworkType network;
  final ModuleConfig modules;
  final RuntimeProtectionProfile? runtimeProtectionProfile;
  final Map<String, String> runtimeChecks;
  final GenerationConfig generation;

  void validate() {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(projectName)) {
      throw const FormatException(
        'Project name must be lower_snake_case and start with a letter.',
      );
    }
    if (modules.runtimeProtection && runtimeProtectionProfile == null) {
      throw const FormatException(
        'runtime_protection.profile is required when the module is enabled.',
      );
    }
    if (!modules.runtimeProtection && runtimeProtectionProfile != null) {
      throw const FormatException(
        'Runtime protection profile requires modules.runtime_protection.',
      );
    }
  }

  Map<String, Object?> toMap() => {
    'project': {'name': projectName},
    'architecture': {'type': architecture.value},
    'state_management': {'type': stateManagement.value},
    'router': {'type': router.value},
    'network': {'type': network.value},
    'modules': {
      'localization': modules.localization,
      'theme': modules.theme,
      'secure_storage': modules.secureStorage,
      'runtime_protection': modules.runtimeProtection,
    },
    if (modules.runtimeProtection)
      'runtime_protection': {
        'profile': runtimeProtectionProfile!.value,
        'checks': runtimeChecks,
      },
    'generation': {
      'generate_tests': generation.generateTests,
      'use_barrel_files': generation.useBarrelFiles,
      'format_after_generation': generation.formatAfterGeneration,
      'analyze_after_generation': generation.analyzeAfterGeneration,
    },
  };

  factory ArchsmithConfig.fromMap(Map<Object?, Object?> map) {
    Map<Object?, Object?> section(String key) {
      final value = map[key];
      if (value is! Map) {
        throw FormatException('Missing or invalid $key section.');
      }
      return value.cast<Object?, Object?>();
    }

    T value<T>(Map<Object?, Object?> source, String key, T fallback) {
      final found = source[key];
      if (found == null) {
        return fallback;
      }
      if (found is! T) throw FormatException('$key must be a $T.');
      return found as T;
    }

    final project = section('project');
    final modules = section('modules');
    final generation = section('generation');
    final runtime = map['runtime_protection'];
    final runtimeMap = runtime is Map ? runtime.cast<Object?, Object?>() : null;
    final checks = <String, String>{};
    final rawChecks = runtimeMap?['checks'];
    if (rawChecks is Map) {
      for (final entry in rawChecks.entries) {
        checks[entry.key.toString()] = entry.value.toString();
      }
    }
    final config = ArchsmithConfig(
      projectName: value<String>(project, 'name', ''),
      architecture: enumByValue(
        ArchitectureType.values,
        value<String>(section('architecture'), 'type', 'clean_feature'),
        (item) => item.value,
      ),
      stateManagement: enumByValue(
        StateManagementType.values,
        value<String>(section('state_management'), 'type', 'riverpod'),
        (item) => item.value,
      ),
      router: enumByValue(
        RouterType.values,
        value<String>(section('router'), 'type', 'go_router'),
        (item) => item.value,
      ),
      network: enumByValue(
        NetworkType.values,
        value<String>(section('network'), 'type', 'dio'),
        (item) => item.value,
      ),
      modules: ModuleConfig(
        localization: value<bool>(modules, 'localization', true),
        theme: value<bool>(modules, 'theme', true),
        secureStorage: value<bool>(modules, 'secure_storage', false),
        runtimeProtection: value<bool>(modules, 'runtime_protection', false),
      ),
      runtimeProtectionProfile: runtimeMap == null
          ? null
          : enumByValue<RuntimeProtectionProfile>(
              RuntimeProtectionProfile.values,
              value<String>(runtimeMap, 'profile', 'standard'),
              (item) => item.value,
            ),
      runtimeChecks: Map.unmodifiable(checks),
      generation: GenerationConfig(
        generateTests: value<bool>(generation, 'generate_tests', true),
        useBarrelFiles: value<bool>(generation, 'use_barrel_files', false),
        formatAfterGeneration: value<bool>(
          generation,
          'format_after_generation',
          true,
        ),
        analyzeAfterGeneration: value<bool>(
          generation,
          'analyze_after_generation',
          true,
        ),
      ),
    );
    config.validate();
    return config;
  }
}
