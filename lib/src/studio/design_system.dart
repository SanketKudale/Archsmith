import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/generation.dart';

/// Central visual values shared by Studio-generated screens.
class StudioDesignTokens {
  const StudioDesignTokens({
    this.colors = const {
      'primary': '#6750A4',
      'surface': '#FFFBFE',
      'error': '#B3261E',
      'onPrimary': '#FFFFFF',
    },
    this.spacing = const {
      'xs': 4,
      'sm': 8,
      'md': 16,
      'lg': 24,
      'xl': 32,
    },
    this.radii = const {'sm': 8, 'md': 12, 'lg': 20},
    this.fontSizes = const {'body': 14, 'title': 20, 'headline': 28},
  });

  factory StudioDesignTokens.fromJson(Map<String, Object?> json) {
    const defaults = StudioDesignTokens();
    return StudioDesignTokens(
      colors: json['colors'] == null
          ? defaults.colors
          : _stringMap(json['colors'], 'colors'),
      spacing: json['spacing'] == null
          ? defaults.spacing
          : _numberMap(json['spacing'], 'spacing'),
      radii: json['radii'] == null
          ? defaults.radii
          : _numberMap(json['radii'], 'radii'),
      fontSizes: json['font_sizes'] == null
          ? defaults.fontSizes
          : _numberMap(json['font_sizes'], 'font_sizes'),
    );
  }

  final Map<String, String> colors;
  final Map<String, num> spacing;
  final Map<String, num> radii;
  final Map<String, num> fontSizes;

  Map<String, Object?> toJson() => {
        'colors': colors,
        'spacing': spacing,
        'radii': radii,
        'font_sizes': fontSizes,
      };

  String dartSource() {
    final values = <String>[];
    for (final entry in colors.entries) {
      values.add(
        '  static const ${identifier('colors.${entry.key}')} = '
        'Color(${_color(entry.value)});',
      );
    }
    for (final group in [
      ('spacing', spacing),
      ('radii', radii),
      ('fontSizes', fontSizes),
    ]) {
      for (final entry in group.$2.entries) {
        values.add(
          '  static const double ${identifier('${group.$1}.${entry.key}')} = '
          '${entry.value.toDouble()};',
        );
      }
    }
    return '''import 'package:flutter/material.dart';

/// Generated from .archsmith/design_tokens.json.
abstract final class ArchsmithDesignTokens {
${values.join('\n')}
}
''';
  }

  static String identifier(String reference) {
    final parts = reference
        .split('.')
        .expand((part) => part.split(RegExp(r'[^A-Za-z0-9]+')))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'token';
    final value = parts.first.toLowerCase() +
        parts
            .skip(1)
            .map(
              (part) => '${part[0].toUpperCase()}${part.substring(1)}',
            )
            .join();
    return RegExp(r'^[0-9]').hasMatch(value) ? 'token$value' : value;
  }
}

class StudioDesignTokenStore {
  const StudioDesignTokenStore();

  StudioDesignTokens read(String root) {
    final file = File(p.join(root, '.archsmith', 'design_tokens.json'));
    if (!file.existsSync()) return const StudioDesignTokens();
    final value = jsonDecode(file.readAsStringSync());
    if (value is! Map) {
      throw const FormatException('Design tokens must be a JSON object.');
    }
    return StudioDesignTokens.fromJson(Map<String, Object?>.from(value));
  }

  PlannedFile plan(StudioDesignTokens tokens) => PlannedFile(
        '.archsmith/design_tokens.json',
        '${const JsonEncoder.withIndent('  ').convert(tokens.toJson())}\n',
        isUpdate: true,
      );
}

/// Locale-key catalog used by the visual string picker.
class StudioLocalizationCatalog {
  const StudioLocalizationCatalog({
    this.defaultLocale = 'en',
    this.locales = const {
      'en': {
        'appName': 'Application',
        'continueLabel': 'Continue',
        'retryLabel': 'Retry',
      },
    },
  });

  factory StudioLocalizationCatalog.fromJson(Map<String, Object?> json) {
    final rawLocales = json['locales'];
    if (rawLocales is! Map) {
      throw const FormatException('Localization locales must be an object.');
    }
    return StudioLocalizationCatalog(
      defaultLocale: json['default_locale']?.toString() ?? 'en',
      locales: {
        for (final entry in rawLocales.entries)
          entry.key.toString(): _stringMap(
            entry.value,
            'locales.${entry.key}',
          ),
      },
    );
  }

  final String defaultLocale;
  final Map<String, Map<String, String>> locales;

  Iterable<String> get keys =>
      locales.values.expand((locale) => locale.keys).toSet().toList()..sort();

  Map<String, Object?> toJson() => {
        'default_locale': defaultLocale,
        'locales': locales,
      };

  String dartSource() {
    final localeEntries = locales.entries.map((locale) {
      final strings = locale.value.entries.map(
        (entry) => '${_dartString(entry.key)}: ${_dartString(entry.value)}',
      );
      return '${_dartString(locale.key)}: <String, String>{'
          '${strings.join(', ')}}';
    });
    return '''import 'package:flutter/widgets.dart';

/// Generated from .archsmith/localization.json.
abstract final class ArchsmithLocalizations {
  static const defaultLocale = ${_dartString(defaultLocale)};
  static const values = <String, Map<String, String>>{
    ${localeEntries.join(',\n    ')}
  };

  static String text(BuildContext context, String key) {
    final locale = Localizations.localeOf(context).languageCode;
    return values[locale]?[key] ??
        values[defaultLocale]?[key] ??
        key;
  }
}
''';
  }
}

class StudioLocalizationStore {
  const StudioLocalizationStore();

  StudioLocalizationCatalog read(String root) {
    final file = File(p.join(root, '.archsmith', 'localization.json'));
    if (!file.existsSync()) return const StudioLocalizationCatalog();
    final value = jsonDecode(file.readAsStringSync());
    if (value is! Map) {
      throw const FormatException('Localization must be a JSON object.');
    }
    return StudioLocalizationCatalog.fromJson(
      Map<String, Object?>.from(value),
    );
  }

  PlannedFile plan(StudioLocalizationCatalog catalog) => PlannedFile(
        '.archsmith/localization.json',
        '${const JsonEncoder.withIndent('  ').convert(catalog.toJson())}\n',
        isUpdate: true,
      );
}

/// Finds image files already present in the Flutter project's assets folder.
class StudioAssetRegistry {
  const StudioAssetRegistry();

  List<String> readAll(String root) {
    final directory = Directory(p.join(root, 'assets'));
    if (!directory.existsSync()) return const [];
    const supported = {'.png', '.jpg', '.jpeg', '.webp', '.gif'};
    final assets = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where(
            (file) => supported.contains(p.extension(file.path).toLowerCase()))
        .map(
          (file) =>
              p.relative(file.path, from: root).replaceAll(p.separator, '/'),
        )
        .toList()
      ..sort();
    return assets;
  }
}

Map<String, String> _stringMap(Object? value, String location) {
  if (value is! Map) throw FormatException('$location must be an object.');
  return Map.unmodifiable({
    for (final entry in value.entries)
      entry.key.toString(): entry.value.toString(),
  });
}

Map<String, num> _numberMap(Object? value, String location) {
  if (value is! Map) throw FormatException('$location must be an object.');
  return Map.unmodifiable({
    for (final entry in value.entries)
      entry.key.toString(): entry.value is num
          ? entry.value as num
          : throw FormatException('$location.${entry.key} must be a number.'),
  });
}

String _color(String value) {
  final hex = value.replaceFirst('#', '').toUpperCase();
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  if (normalized.length != 8 || int.tryParse(normalized, radix: 16) == null) {
    throw FormatException('Invalid design-token color: $value.');
  }
  return '0x$normalized';
}

String _dartString(String value) =>
    "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n')}'";
