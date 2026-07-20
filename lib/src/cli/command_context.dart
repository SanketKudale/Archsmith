import '../configuration/config_reader.dart';
import '../generators/generation_engine.dart';
import '../prompts/prompt_service.dart';
import '../services/dependency_service.dart';
import '../services/file_system_service.dart';
import '../services/process_service.dart';

class CommandContext {
  CommandContext({
    PromptService? prompts,
    FileSystemService? files,
    ProcessService? processes,
    GenerationEngine? generator,
    ConfigReader? configReader,
  }) : prompts = prompts ?? const TerminalPromptService(),
       files = files ?? const LocalFileSystemService(),
       processes = processes ?? const LocalProcessService(),
       generator = generator ?? const GenerationEngine(),
       configReader = configReader ?? const ConfigReader();

  final PromptService prompts;
  final FileSystemService files;
  final ProcessService processes;
  final GenerationEngine generator;
  final ConfigReader configReader;

  DependencyService get dependencies => DependencyService(processes);
}
