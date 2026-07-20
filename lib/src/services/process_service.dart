import 'dart:async';
import 'dart:io';

class ProcessOutput {
  const ProcessOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
  });
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  bool get succeeded => exitCode == 0;
}

abstract interface class ProcessService {
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });
}

class LocalProcessService implements ProcessService {
  const LocalProcessService();

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
    );
    stopwatch.stop();
    return ProcessOutput(
      exitCode: result.exitCode,
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
      duration: stopwatch.elapsed,
    );
  }
}
