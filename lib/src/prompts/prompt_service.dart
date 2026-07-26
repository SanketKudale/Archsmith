import 'dart:io';

/// A terminal label paired with a strongly typed prompt value.
class PromptChoice<T> {
  const PromptChoice(this.label, this.value);
  final String label;
  final T value;
}

/// Testable abstraction for collecting interactive user choices.
abstract interface class PromptService {
  Future<String> askText(
    String message, {
    String? defaultValue,
    bool Function(String value)? validator,
  });
  Future<bool> askConfirmation(String message, {bool defaultValue = true});
  Future<T> askChoice<T>(String message, List<PromptChoice<T>> choices);
  Future<Set<T>> askMultipleChoices<T>(
    String message,
    List<PromptChoice<T>> choices,
  );
}

/// Standard-input and standard-output implementation of [PromptService].
class TerminalPromptService implements PromptService {
  const TerminalPromptService();

  @override
  Future<String> askText(
    String message, {
    String? defaultValue,
    bool Function(String value)? validator,
  }) async {
    while (true) {
      stdout.write(
        '? $message${defaultValue == null ? '' : ' [$defaultValue]'}: ',
      );
      final input = stdin.readLineSync()?.trim() ?? '';
      final answer = input.isEmpty ? (defaultValue ?? '') : input;
      if (validator == null || validator(answer)) return answer;
      stdout.writeln('  Invalid value. Please try again.');
    }
  }

  @override
  Future<bool> askConfirmation(
    String message, {
    bool defaultValue = true,
  }) async {
    final suffix = defaultValue ? 'Y/n' : 'y/N';
    final answer = await askText('$message ($suffix)');
    if (answer.isEmpty) return defaultValue;
    return answer.toLowerCase().startsWith('y');
  }

  @override
  Future<T> askChoice<T>(String message, List<PromptChoice<T>> choices) async {
    stdout.writeln('? $message');
    for (var index = 0; index < choices.length; index++) {
      stdout.writeln('  ${index + 1}) ${choices[index].label}');
    }
    final selected = await askText(
      'Select 1-${choices.length}',
      defaultValue: '1',
      validator: (value) {
        final number = int.tryParse(value);
        return number != null && number > 0 && number <= choices.length;
      },
    );
    return choices[int.parse(selected) - 1].value;
  }

  @override
  Future<Set<T>> askMultipleChoices<T>(
    String message,
    List<PromptChoice<T>> choices,
  ) async {
    stdout.writeln('? $message (comma-separated; empty for none)');
    for (var index = 0; index < choices.length; index++) {
      stdout.writeln('  ${index + 1}) ${choices[index].label}');
    }
    final answer = await askText('Selections');
    if (answer.isEmpty) return {};
    final indexes =
        answer.split(',').map((value) => int.tryParse(value.trim()));
    if (indexes.any(
      (value) => value == null || value < 1 || value > choices.length,
    )) {
      throw const FormatException('Invalid multiple-choice selection.');
    }
    return indexes.map((index) => choices[index! - 1].value).toSet();
  }
}
