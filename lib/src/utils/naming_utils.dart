/// Normalized snake, camel, Pascal, title, and kebab case forms of a name.
class NameVariants {
  NameVariants(String input) : words = _words(input) {
    if (words.isEmpty) throw const FormatException('Name cannot be empty.');
  }

  final List<String> words;

  String get snakeCase => words.join('_');
  String get camelCase => words.first + words.skip(1).map(_capitalized).join();
  String get pascalCase => words.map(_capitalized).join();
  String get titleCase => words.map(_capitalized).join(' ');
  String get kebabCase => words.join('-');

  static List<String> _words(String input) {
    final separated = input
        .trim()
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll(RegExp('[^A-Za-z0-9]+'), ' ');
    return separated
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part.toLowerCase())
        .toList(growable: false);
  }

  static String _capitalized(String value) =>
      value[0].toUpperCase() + value.substring(1);
}

/// Creates normalized naming variants from common input styles.
NameVariants names(String input) => NameVariants(input);
