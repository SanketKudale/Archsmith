import 'dart:io';

import 'package:path/path.dart' as p;

import '../configuration/archsmith_config.dart';
import '../models/generation.dart';
import '../utils/naming_utils.dart';
import 'api_common_config.dart';
import 'clean_api_feature_generator.dart';
import 'json_api_endpoint.dart';

/// Plans multiple endpoint examples as one deterministic generation unit.
class ApiBatchGenerator {
  const ApiBatchGenerator();

  List<PlannedFile> generate({
    required ArchsmithConfig config,
    required ApiCommonConfig common,
    required List<File> endpointFiles,
    String method = 'POST',
  }) {
    if (endpointFiles.isEmpty) {
      throw const FormatException('No endpoint JSON files were found.');
    }
    final sorted = [...endpointFiles]
      ..sort((left, right) => left.path.compareTo(right.path));
    final filesByPath = <String, PlannedFile>{};
    final endpoints = <_BatchEndpoint>[];
    const reader = JsonApiEndpointReader();
    const generator = CleanApiFeatureGenerator();

    for (final file in sorted) {
      final endpoint = reader.read(file.path, method: method);
      final feature = names(p.basenameWithoutExtension(file.path)).snakeCase;
      endpoints.add(_BatchEndpoint(feature, endpoint));
      for (final planned in generator.generate(
        config: config,
        common: common,
        endpoint: endpoint,
        feature: feature,
      )) {
        final existing = filesByPath[planned.path];
        if (existing == null) {
          filesByPath[planned.path] = planned;
        } else if (existing.content != planned.content) {
          throw FormatException(
            'Batch endpoints generate conflicting content for '
            '${planned.path}. Rename one JSON file or use distinct features.',
          );
        }
      }
    }

    _deduplicateSchemas(filesByPath, endpoints, config.projectName);
    filesByPath['docs/archsmith_api_summary.md'] = PlannedFile(
      'docs/archsmith_api_summary.md',
      _summary(endpoints, filesByPath.length),
    );
    return List<PlannedFile>.unmodifiable(filesByPath.values);
  }

  void _deduplicateSchemas(
    Map<String, PlannedFile> files,
    List<_BatchEndpoint> endpoints,
    String projectName,
  ) {
    final groups = <String, List<_SchemaOccurrence>>{};
    for (final item in endpoints) {
      for (final occurrence in [
        _SchemaOccurrence(
          item.feature,
          names(item.endpoint.name).snakeCase,
          'request',
          item.endpoint.request,
        ),
        _SchemaOccurrence(
          item.feature,
          names(item.endpoint.name).snakeCase,
          'response',
          item.endpoint.response,
        ),
      ]) {
        groups
            .putIfAbsent(
              '${occurrence.kind}:${_schemaKey(occurrence.schema)}',
              () => [],
            )
            .add(occurrence);
      }
    }
    for (final group in groups.values.where((items) => items.length > 1)) {
      final canonical = group.first;
      final sharedRoot =
          'lib/core/network/shared/${canonical.operation}_${canonical.kind}';
      final sharedEntityPath = '${sharedRoot}_entity.dart';
      final sharedModelPath = '${sharedRoot}_model.dart';
      final canonicalEntity = files[canonical.entityPath]!;
      final canonicalModel = files[canonical.modelPath]!;
      final canonicalEntities = _classes(canonicalEntity.content, 'Entity');
      final canonicalModels = _classes(canonicalModel.content, 'Model');
      files[sharedEntityPath] = PlannedFile(
        sharedEntityPath,
        canonicalEntity.content,
      );
      files[sharedModelPath] = PlannedFile(
        sharedModelPath,
        canonicalModel.content.replaceFirst(
          RegExp(r"import '[^']+';"),
          "import 'package:$projectName/core/network/shared/"
          "${canonical.operation}_${canonical.kind}_entity.dart';",
        ),
      );
      for (final occurrence in group) {
        files[occurrence.entityPath] = PlannedFile(
          occurrence.entityPath,
          _aliases(
            projectName,
            sharedEntityPath,
            _classes(files[occurrence.entityPath]!.content, 'Entity'),
            canonicalEntities,
          ),
        );
        files[occurrence.modelPath] = PlannedFile(
          occurrence.modelPath,
          _aliases(
            projectName,
            sharedModelPath,
            _classes(files[occurrence.modelPath]!.content, 'Model'),
            canonicalModels,
          ),
        );
      }
    }
  }

  String _schemaKey(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((left, right) => left.key.toString().compareTo(
              right.key.toString(),
            ));
      return '{${entries.map((entry) => '${entry.key}:${_schemaKey(entry.value)}').join(',')}}';
    }
    if (value is List) {
      return '[${value.isEmpty ? 'dynamic' : _schemaKey(value.first)}]';
    }
    return value == null ? 'dynamic' : value.runtimeType.toString();
  }

  List<String> _classes(String source, String suffix) => RegExp(
        'class (\\w+$suffix)',
      ).allMatches(source).map((match) => match.group(1)!).toList();

  String _aliases(
    String projectName,
    String sharedPath,
    List<String> aliases,
    List<String> canonical,
  ) {
    if (aliases.length != canonical.length) {
      throw const FormatException(
        'Matching schemas produced incompatible generated class layouts.',
      );
    }
    final importPath = sharedPath.substring('lib/'.length);
    return "import 'package:$projectName/$importPath';\n\n"
        "${List.generate(aliases.length, (index) => 'typedef ${aliases[index]} = ${canonical[index]};').join('\n')}\n";
  }

  String _summary(List<_BatchEndpoint> endpoints, int generatedFileCount) {
    final rows = endpoints
        .map(
          (item) => '| `${item.feature}` | `${item.endpoint.method}` | '
              '`${item.endpoint.path}` | `${item.endpoint.request.length}` | '
              '`${item.endpoint.response.length}` |',
        )
        .join('\n');
    return '# Archsmith API summary\n\n'
        'Generated from ${endpoints.length} endpoint example files. Shared '
        'infrastructure and identical files were emitted once.\n\n'
        '| Feature | Method | Endpoint | Request fields | Response fields |\n'
        '| --- | --- | --- | ---: | ---: |\n'
        '$rows\n\n'
        'Planned Dart/support files: $generatedFileCount.\n';
  }
}

class _BatchEndpoint {
  const _BatchEndpoint(this.feature, this.endpoint);
  final String feature;
  final JsonApiEndpoint endpoint;
}

class _SchemaOccurrence {
  const _SchemaOccurrence(
    this.feature,
    this.operation,
    this.kind,
    this.schema,
  );

  final String feature;
  final String operation;
  final String kind;
  final Map<String, Object?> schema;

  String get entityPath =>
      'lib/features/$feature/domain/entities/${operation}_${kind}_entity.dart';
  String get modelPath =>
      'lib/features/$feature/data/models/${operation}_${kind}_model.dart';
}
