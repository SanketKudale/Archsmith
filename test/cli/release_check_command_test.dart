import 'package:archsmith/archsmith.dart';
import 'package:test/test.dart';

void main() {
  test('release-check runs dry-run gates without publishing', () async {
    final processes = _RecordingProcessService();
    final runner = ArchsmithRunner(
      context: CommandContext(processes: processes),
    );

    final exitCode = await runner.run(['release-check']);

    expect(exitCode, 0);
    expect(processes.arguments, hasLength(4));
    expect(
      processes.arguments.any(
        (arguments) => arguments.join(' ') == 'dart pub publish --dry-run',
      ),
      isTrue,
    );
    expect(
      processes.arguments.any(
        (arguments) =>
            arguments.contains('publish') && !arguments.contains('--dry-run'),
      ),
      isFalse,
    );
  });

  test('release-check generated matrix covers every state strategy', () async {
    final processes = _RecordingProcessService();
    final runner = ArchsmithRunner(
      context: CommandContext(processes: processes),
    );

    final exitCode = await runner.run([
      'release-check',
      '--generated-matrix',
    ]);

    expect(exitCode, 0);
    final generated = processes.arguments
        .where((arguments) =>
            arguments.contains('tool/verify_generated_apps.dart'))
        .toList();
    expect(generated, hasLength(5));
    for (final state in ['none', 'riverpod', 'provider', 'bloc', 'getx']) {
      expect(
        generated.any(
          (arguments) =>
              arguments.contains('--state') && arguments.contains(state),
        ),
        isTrue,
      );
    }
  });
}

class _RecordingProcessService implements ProcessService {
  final arguments = <List<String>>[];

  @override
  Future<ProcessOutput> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    this.arguments.add(List.unmodifiable(arguments));
    return const ProcessOutput(
      exitCode: 0,
      stdout: '',
      stderr: '',
      duration: Duration.zero,
    );
  }
}
