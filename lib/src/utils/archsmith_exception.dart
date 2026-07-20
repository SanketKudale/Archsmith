/// User-facing failure with a predictable command exit code.
class ArchsmithException implements Exception {
  const ArchsmithException(this.message, {this.exitCode = 1});

  final String message;
  final int exitCode;

  @override
  String toString() => message;
}
