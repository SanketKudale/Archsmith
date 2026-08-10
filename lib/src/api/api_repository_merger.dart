import '../models/generation.dart';

/// Combines generated feature-level API members without duplicating endpoints.
///
/// Templates contain owned sections so a feature keeps one data source,
/// repository contract, and repository implementation as APIs are generated.
PlannedFile mergeApiFeatureFile(
  PlannedFile current,
  PlannedFile incoming, {
  bool isUpdate = false,
}) {
  var content = current.content;
  for (final section in const [
    'imports',
    'constructor-parameters',
    'fields',
    'methods',
  ]) {
    content = _mergeSection(content, incoming.content, section);
  }
  return PlannedFile(current.path, content, isUpdate: isUpdate);
}

bool isCumulativeApiFeaturePath(String path) =>
    path.endsWith('_repository.dart') ||
    path.endsWith('_repository_impl.dart') ||
    path.endsWith('_remote_data_source.dart');

String _mergeSection(String current, String incoming, String section) {
  final start = '// archsmith:repository-$section:start';
  final end = '// archsmith:repository-$section:end';
  final incomingStart = incoming.indexOf(start);
  final incomingEnd = incoming.indexOf(end);
  if (incomingStart < 0 || incomingEnd < 0) return current;

  final currentStart = current.indexOf(start);
  final currentEnd = current.indexOf(end);
  if (currentStart < 0 || currentEnd < 0) {
    throw FormatException(
      'The existing generated repository cannot be extended because its '
      'Archsmith ownership markers are missing. Regenerate it with --force '
      'once, then add further APIs normally.',
    );
  }

  final owned = current.substring(currentStart + start.length, currentEnd);
  final incomingOwned = incoming.substring(
    incomingStart + start.length,
    incomingEnd,
  );
  final additions = _newOperationBlocks(owned, incomingOwned);
  if (additions.isEmpty) {
    return current;
  }

  final insertion = owned.trim().isEmpty
      ? '\n${additions.join('\n')}\n'
      : '${owned.trimRight()}\n${additions.join('\n')}\n';
  return current.replaceRange(
    currentStart + start.length,
    currentEnd,
    insertion,
  );
}

List<String> _newOperationBlocks(String current, String incoming) {
  final starts = RegExp(
    r'// archsmith:api-operation:([a-z0-9_]+):start',
  ).allMatches(incoming);
  final additions = <String>[];
  for (final start in starts) {
    final operation = start.group(1)!;
    if (current.contains('// archsmith:api-operation:$operation:start')) {
      continue;
    }
    final endMarker = '// archsmith:api-operation:$operation:end';
    final end = incoming.indexOf(endMarker, start.end);
    if (end < 0) {
      throw FormatException(
        'Incomplete Archsmith repository marker for $operation.',
      );
    }
    final lineStart = incoming.lastIndexOf('\n', start.start) + 1;
    additions.add(
      incoming.substring(lineStart, end + endMarker.length).trimRight(),
    );
  }
  return additions;
}
