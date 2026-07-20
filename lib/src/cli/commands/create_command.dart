import 'dart:io';

import 'package:path/path.dart' as p;

import '../../configuration/archsmith_config.dart';
import '../../models/generation.dart';
import '../../models/options.dart';
import '../../prompts/prompt_service.dart';
import '../../utils/naming_utils.dart';
import 'base_command.dart';

class CreateCommand extends ArchsmithCommand {
  CreateCommand(super.context) {
    argParser
      ..addOption(
        'architecture',
        allowed: ArchitectureType.values.map((e) => e.value),
      )
      ..addOption(
        'state',
        allowed: StateManagementType.values.map((e) => e.value),
      )
      ..addOption('router', allowed: RouterType.values.map((e) => e.value))
      ..addOption('network', allowed: NetworkType.values.map((e) => e.value))
      ..addFlag('localization', defaultsTo: true)
      ..addFlag('theme', defaultsTo: true)
      ..addFlag('secure-storage', negatable: false)
      ..addFlag(
        'interactive',
        defaultsTo: true,
        help: 'Prompt for choices not supplied as flags.',
      )
      ..addOption(
        'runtime-protection',
        allowed: RuntimeProtectionProfile.values.map((e) => e.value),
      )
      ..addFlag('starter-auth', negatable: false);
    addSafetyOptions();
  }

  @override
  String get name => 'create';
  @override
  String get description =>
      'Create a Flutter project and initialize Archsmith.';
  @override
  String get invocation => 'archsmith create [project_name]';

  @override
  Future<int> run() async {
    stdout.writeln('Welcome to Archsmith\n');
    final interactive = argResults!['interactive'] as bool && stdin.hasTerminal;
    var projectName = argResults!.rest.firstOrNull;
    projectName ??= interactive
        ? await context.prompts.askText(
            'Enter project name',
            validator: (value) => RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value),
          )
        : null;
    if (projectName == null) {
      stderr.writeln('A project name is required in non-interactive mode.');
      return 64;
    }
    projectName = names(projectName).snakeCase;
    final config = await _config(projectName, interactive);
    final target = p.join(Directory.current.path, projectName);
    if (Directory(target).existsSync()) {
      stderr.writeln('Target already exists: $target');
      return 2;
    }
    if (options.dryRun) {
      stdout.writeln('CREATE $target (Flutter project)');
      final result = await context.files.apply(
        target,
        context.generator.architecture(config),
        options,
      );
      return printResult(result);
    }
    stdout.writeln('Creating Flutter project...');
    if (!await runTool('fvm', [
      'flutter',
      'create',
      '--project-name',
      projectName,
      target,
    ], Directory.current.path)) {
      return 1;
    }
    final result = await context.files.apply(
      target,
      context.generator.architecture(config),
      const GenerationOptions(force: true),
    );
    final dependencies = await context.dependencies.install(config, target);
    if (dependencies != null && !dependencies.succeeded) {
      stderr.writeln(dependencies.stderr);
      return 1;
    }
    if (argResults!['starter-auth'] as bool) {
      await context.files.apply(
        target,
        context.generator.component(config, 'feature', 'authentication'),
        const GenerationOptions(),
      );
    }
    await runTool('fvm', ['dart', 'format', '.'], target);
    if (!await runTool('fvm', ['flutter', 'analyze'], target)) {
      return 1;
    }
    stdout.writeln('\nProject generated successfully at $target');
    return printResult(result);
  }

  Future<ArchsmithConfig> _config(String name, bool interactive) async {
    Future<T> choice<T extends Enum>(
      String key,
      String message,
      List<T> values,
      String Function(T) value,
      String Function(T) label,
      T fallback,
    ) async {
      final supplied = argResults![key] as String?;
      if (supplied != null) {
        return values.firstWhere((e) => value(e) == supplied);
      }
      if (!interactive) return fallback;
      return context.prompts.askChoice(
        message,
        values.map((e) => PromptChoice(label(e), e)).toList(),
      );
    }

    final architecture = await choice(
      'architecture',
      'Select architecture',
      ArchitectureType.values,
      (e) => e.value,
      (e) => e.label,
      ArchitectureType.cleanFeature,
    );
    final state = await choice(
      'state',
      'Select state management',
      StateManagementType.values,
      (e) => e.value,
      (e) => e.label,
      StateManagementType.riverpod,
    );
    final router = await choice(
      'router',
      'Select router',
      RouterType.values,
      (e) => e.value,
      (e) => e.label,
      RouterType.goRouter,
    );
    final network = await choice(
      'network',
      'Select networking',
      NetworkType.values,
      (e) => e.value,
      (e) => e.label,
      NetworkType.dio,
    );
    final localization = interactive && !argResults!.wasParsed('localization')
        ? await context.prompts.askConfirmation('Enable localization?')
        : argResults!['localization'] as bool;
    final theme = interactive && !argResults!.wasParsed('theme')
        ? await context.prompts.askConfirmation('Enable theme system?')
        : argResults!['theme'] as bool;
    final secureStorage =
        interactive && !argResults!.wasParsed('secure-storage')
        ? await context.prompts.askConfirmation(
            'Enable secure storage?',
            defaultValue: false,
          )
        : argResults!['secure-storage'] as bool;
    var runtimeValue = argResults!['runtime-protection'] as String?;
    if (interactive &&
        runtimeValue == null &&
        await context.prompts.askConfirmation(
          'Enable runtime protection?',
          defaultValue: false,
        )) {
      final selected = await context.prompts.askChoice(
        'Select runtime protection profile',
        RuntimeProtectionProfile.values
            .map((e) => PromptChoice(e.label, e))
            .toList(),
      );
      runtimeValue = selected.value;
    }
    final profile = runtimeValue == null
        ? null
        : RuntimeProtectionProfile.values.firstWhere(
            (e) => e.value == runtimeValue,
          );
    var runtimeChecks = _profileChecks(profile);
    if (profile == RuntimeProtectionProfile.custom && interactive) {
      final checks = [
        'internet',
        'backend_reachability',
        'vpn',
        'proxy',
        'mock_location',
        'screen_capture',
        'screen_recording',
        'screen_sharing',
        'screen_mirroring',
        'external_display',
        'usb_debugging',
        'developer_mode',
        'root',
        'jailbreak',
        'emulator',
        'app_integrity',
      ];
      final selected = await context.prompts.askMultipleChoices(
        'Select runtime checks',
        checks
            .map((check) => PromptChoice(check.replaceAll('_', ' '), check))
            .toList(),
      );
      final configured = <String, String>{};
      const actions = [
        'allow',
        'warn',
        'restrict',
        'blur_content',
        'block_screen',
        'sign_out',
        'terminate_session',
      ];
      for (final check in selected) {
        configured[check] = await context.prompts.askChoice(
          'Action for ${check.replaceAll('_', ' ')}',
          actions
              .map(
                (action) => PromptChoice(action.replaceAll('_', ' '), action),
              )
              .toList(),
        );
      }
      runtimeChecks = configured;
    }
    return ArchsmithConfig(
      projectName: name,
      architecture: architecture,
      stateManagement: state,
      router: router,
      network: network,
      modules: ModuleConfig(
        localization: localization,
        theme: theme,
        secureStorage: secureStorage,
        runtimeProtection: profile != null,
      ),
      runtimeProtectionProfile: profile,
      runtimeChecks: runtimeChecks,
      generation: GenerationConfig(generateTests: options.withTests),
    );
  }
}

Map<String, String> _profileChecks(RuntimeProtectionProfile? profile) {
  if (profile == null) return const {};
  if (profile == RuntimeProtectionProfile.custom) return const {};
  final standard = <String, String>{
    'internet': 'block_screen',
    'backend_reachability': 'block_screen',
    'screen_capture': 'warn',
    'screen_recording': 'blur_content',
  };
  if (profile == RuntimeProtectionProfile.standard) return standard;
  if (profile == RuntimeProtectionProfile.examination) {
    return {
      'internet': 'block_screen',
      'screen_recording': 'block_screen',
      'screen_sharing': 'block_screen',
      'screen_mirroring': 'block_screen',
      'external_display': 'warn',
      'usb_debugging': 'warn',
      'developer_mode': 'warn',
      'emulator': 'block_screen',
    };
  }
  return {
    ...standard,
    'vpn': 'warn',
    'proxy': 'warn',
    'mock_location': 'terminate_session',
    'root': 'block_screen',
    'jailbreak': 'block_screen',
    'usb_debugging': 'warn',
    'developer_mode': 'warn',
    'app_integrity': 'terminate_session',
    'emulator': 'warn',
  };
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
