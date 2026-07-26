import 'dart:io';

import 'package:archsmith/src/studio/studio_assets.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('embedded Studio JavaScript has valid syntax when Node is available',
      () async {
    try {
      final version = await Process.run('node', ['--version']);
      if (version.exitCode != 0) return;
    } on ProcessException {
      return;
    }
    final directory = await Directory.systemTemp.createTemp(
      'archsmith_studio_assets_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final script = File(p.join(directory.path, 'app.js'));
    await script.writeAsString(StudioAssets.js);

    final result = await Process.run('node', ['--check', script.path]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('editor assets include history and node movement controls', () {
    expect(StudioAssets.html, contains('id="undo"'));
    expect(StudioAssets.html, contains('id="duplicate"'));
    expect(StudioAssets.js, contains('function moveNode'));
    expect(StudioAssets.js, contains('function checkpoint'));
    expect(StudioAssets.js, contains("property.type==='binding'"));
  });
}
