enum GenerationAction { create, update, skip, conflict }

class PlannedFile {
  const PlannedFile(this.path, this.content, {this.isUpdate = false});
  final String path;
  final String content;
  final bool isUpdate;
}

class GenerationEntry {
  const GenerationEntry(this.path, this.action);
  final String path;
  final GenerationAction action;

  @override
  String toString() => '${action.name.toUpperCase().padRight(8)}$path';
}

class GenerationResult {
  const GenerationResult(this.entries);
  final List<GenerationEntry> entries;

  int count(GenerationAction action) =>
      entries.where((entry) => entry.action == action).length;
  bool get hasConflicts => count(GenerationAction.conflict) > 0;
}

class GenerationOptions {
  const GenerationOptions({
    this.dryRun = false,
    this.force = false,
    this.skipExisting = false,
    this.withTests = true,
  });

  final bool dryRun;
  final bool force;
  final bool skipExisting;
  final bool withTests;
}
