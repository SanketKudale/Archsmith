import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../utils/archsmith_exception.dart';
import 'command_context.dart';
import 'commands/api_command.dart';
import 'commands/api_common_command.dart';
import 'commands/api_dir_command.dart';
import 'commands/create_command.dart';
import 'commands/doctor_command.dart';
import 'commands/generate_command.dart';
import 'commands/init_command.dart';

/// Registers Archsmith commands and maps failures to stable exit codes.
class ArchsmithRunner {
  ArchsmithRunner({CommandContext? context})
    : context = context ?? CommandContext() {
    _runner =
        CommandRunner<int>(
            'archsmith',
            'Generate maintainable Flutter architectures safely.',
          )
          ..addCommand(CreateCommand(this.context))
          ..addCommand(InitCommand(this.context))
          ..addCommand(ApiCommand(this.context))
          ..addCommand(ApiCommonCommand(this.context))
          ..addCommand(ApiDirCommand(this.context))
          ..addCommand(GenerateCommand(this.context, 'feature'))
          ..addCommand(GenerateCommand(this.context, 'page'))
          ..addCommand(GenerateCommand(this.context, 'model'))
          ..addCommand(GenerateCommand(this.context, 'repository'))
          ..addCommand(GenerateCommand(this.context, 'service'))
          ..addCommand(GenerateCommand(this.context, 'usecase'))
          ..addCommand(GenerateCommand(this.context, 'controller'))
          ..addCommand(GenerateCommand(this.context, 'widget'))
          ..addCommand(DoctorCommand(this.context));
  }

  final CommandContext context;
  late final CommandRunner<int> _runner;

  Future<int> run(List<String> arguments) async {
    try {
      return await _runner.run(arguments) ?? 0;
    } on UsageException catch (error) {
      stderr.writeln(error);
      return 64;
    } on FormatException catch (error) {
      stderr.writeln('Configuration error: ${error.message}');
      return 2;
    } on FileSystemException catch (error) {
      stderr.writeln(
        'File error: ${error.message}${error.path == null ? '' : ' (${error.path})'}',
      );
      return 2;
    } on ArchsmithException catch (error) {
      stderr.writeln(error.message);
      return error.exitCode;
    } on ProcessException catch (error) {
      stderr.writeln('Could not run ${error.executable}: ${error.message}');
      return 1;
    } on IOException catch (error) {
      stderr.writeln('Terminal I/O error: $error');
      return 1;
    }
  }
}
