import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Branding values to apply to an existing Flutter project.
class BrandingRequest {
  const BrandingRequest({
    this.displayName,
    this.logoPath,
    this.iconPath,
  });

  final String? displayName;
  final String? logoPath;
  final String? iconPath;

  bool get isEmpty =>
      displayName == null && logoPath == null && iconPath == null;
}

/// Files affected by a branding update.
class BrandingResult {
  const BrandingResult(this.paths);

  final List<String> paths;
}

/// Updates Flutter display metadata and branding assets.
class BrandingService {
  const BrandingService();

  Future<BrandingResult> apply(
    String root,
    BrandingRequest request, {
    bool dryRun = false,
  }) async {
    if (request.isEmpty) {
      throw const FormatException(
        'Provide at least one of --name, --logo, or --icon.',
      );
    }
    final projectRoot = p.normalize(p.absolute(root));
    final pubspecPath = p.join(projectRoot, 'pubspec.yaml');
    final pubspec = File(pubspecPath);
    if (!pubspec.existsSync() ||
        !RegExp(r'^flutter:\s*$', multiLine: true)
            .hasMatch(pubspec.readAsStringSync())) {
      throw FileSystemException(
        'Branding requires a Flutter project with pubspec.yaml',
        pubspecPath,
      );
    }

    final name = request.displayName?.trim();
    if (request.displayName != null && (name == null || name.isEmpty)) {
      throw const FormatException('App name cannot be empty.');
    }
    final logo = _sourceFile(request.logoPath, 'logo');
    final icon = _sourceFile(request.iconPath, 'icon', pngOnly: true);
    final updates = <String, String>{};

    if (name != null) {
      _planTextUpdate(
        updates,
        projectRoot,
        'lib/app/app.dart',
        (content) => content.replaceFirst(
          RegExp(r"title:\s*'([^'\\]|\\.)*'"),
          "title: '${_dartString(name)}'",
        ),
      );
      _planTextUpdate(
        updates,
        projectRoot,
        'android/app/src/main/AndroidManifest.xml',
        (content) => content.replaceFirst(
          RegExp(r'android:label="[^"]*"'),
          'android:label="${_xml(name)}"',
        ),
      );
      for (final path in const [
        'ios/Runner/Info.plist',
        'macos/Runner/Info.plist',
      ]) {
        _planTextUpdate(
          updates,
          projectRoot,
          path,
          (content) => _updatePlistName(content, name),
        );
      }
      _planTextUpdate(
        updates,
        projectRoot,
        'web/manifest.json',
        (content) => _updateWebManifest(content, name),
      );
      _planTextUpdate(
        updates,
        projectRoot,
        'web/index.html',
        (content) => _updateWebIndex(content, name),
      );
      _planTextUpdate(
        updates,
        projectRoot,
        'windows/runner/Runner.rc',
        (content) => _updateWindowsMetadata(content, name),
      );
      _planTextUpdate(
        updates,
        projectRoot,
        'linux/runner/my_application.cc',
        (content) => content.replaceAll(
          RegExp(r'gtk_window_set_title\(window,\s*"[^"]*"\);'),
          'gtk_window_set_title(window, "${_cString(name)}");',
        ),
      );
    }

    var updatedPubspec = pubspec.readAsStringSync();
    if (logo != null || icon != null) {
      updatedPubspec = _ensureBrandingAsset(updatedPubspec);
    }
    if (icon != null) {
      updatedPubspec = _upsertLauncherIconConfig(updatedPubspec);
    }
    if (updatedPubspec != pubspec.readAsStringSync()) {
      updates[pubspecPath] = updatedPubspec;
    }

    final changed = <String>[
      for (final path in updates.keys) p.relative(path, from: projectRoot),
    ];
    if (logo != null) {
      changed.add(
        'assets/branding/logo${p.extension(logo.path).toLowerCase()}',
      );
    }
    if (icon != null) changed.add('assets/branding/app_icon.png');

    if (!dryRun) {
      for (final entry in updates.entries) {
        await File(entry.key).writeAsString(entry.value);
      }
      if (logo != null) {
        await _copy(
          logo,
          p.join(
            projectRoot,
            'assets',
            'branding',
            'logo${p.extension(logo.path).toLowerCase()}',
          ),
        );
      }
      if (icon != null) {
        await _copy(
          icon,
          p.join(projectRoot, 'assets', 'branding', 'app_icon.png'),
        );
      }
    }
    return BrandingResult(List.unmodifiable(changed));
  }

  File? _sourceFile(String? path, String label, {bool pngOnly = false}) {
    if (path == null) return null;
    final file = File(p.normalize(p.absolute(path)));
    if (!file.existsSync()) {
      throw FileSystemException('$label file was not found', file.path);
    }
    if (pngOnly && p.extension(file.path).toLowerCase() != '.png') {
      throw const FormatException('Launcher icon must be a PNG file.');
    }
    return file;
  }

  void _planTextUpdate(
    Map<String, String> updates,
    String root,
    String relativePath,
    String Function(String content) transform,
  ) {
    final path = p.join(root, relativePath);
    final file = File(path);
    if (!file.existsSync()) return;
    final current = file.readAsStringSync();
    final updated = transform(current);
    if (updated != current) updates[path] = updated;
  }

  Future<void> _copy(File source, String targetPath) async {
    if (p.equals(p.normalize(source.absolute.path), p.normalize(targetPath))) {
      return;
    }
    final target = File(targetPath);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
  }

  String _updatePlistName(String content, String name) {
    final value = _xml(name);
    final displayName = RegExp(
      r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
    );
    if (displayName.hasMatch(content)) {
      return content.replaceFirstMapped(
        displayName,
        (match) => '${match[1]}$value${match[2]}',
      );
    }
    return content.replaceFirst(
      '</dict>',
      '\t<key>CFBundleDisplayName</key>\n\t<string>$value</string>\n</dict>',
    );
  }

  String _updateWebManifest(String content, String name) {
    final decoded = jsonDecode(content);
    if (decoded is! Map) return content;
    final manifest = Map<String, Object?>.from(decoded);
    manifest['name'] = name;
    manifest['short_name'] = name;
    return '${const JsonEncoder.withIndent('    ').convert(manifest)}\n';
  }

  String _updateWebIndex(String content, String name) {
    final escaped = _html(name);
    final result = content.replaceFirst(
      RegExp(r'<title>.*?</title>', dotAll: true),
      '<title>$escaped</title>',
    );
    return result.replaceFirstMapped(
      RegExp(
        r'(<meta\s+name="apple-mobile-web-app-title"\s+content=")[^"]*(")',
      ),
      (match) => '${match[1]}$escaped${match[2]}',
    );
  }

  String _updateWindowsMetadata(String content, String name) {
    final escaped = _rcString(name);
    return content.replaceAllMapped(
      RegExp(
        r'VALUE "(FileDescription|ProductName)", "[^"]*" "\\0"',
      ),
      (match) => 'VALUE "${match[1]}", "$escaped" "${r'\0'}"',
    );
  }

  String _ensureBrandingAsset(String content) {
    if (RegExp(
      r'^\s*-\s+assets/branding/\s*$',
      multiLine: true,
    ).hasMatch(content)) {
      return content;
    }
    final newline = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(RegExp(r'\r?\n'));
    final flutter = lines.indexWhere((line) => line.trim() == 'flutter:');
    if (flutter < 0) return content;
    var sectionEnd = lines.length;
    for (var index = flutter + 1; index < lines.length; index++) {
      final line = lines[index];
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
        sectionEnd = index;
        break;
      }
    }
    final assets = lines.indexWhere(
      (line) => line.trim() == 'assets:',
      flutter + 1,
    );
    if (assets >= 0 && assets < sectionEnd) {
      lines.insert(assets + 1, '    - assets/branding/');
    } else {
      lines.insertAll(flutter + 1, [
        '  assets:',
        '    - assets/branding/',
      ]);
    }
    return lines.join(newline);
  }

  String _upsertLauncherIconConfig(String content) {
    final newline = content.contains('\r\n') ? '\r\n' : '\n';
    final lines = content.split(RegExp(r'\r?\n'));
    final start = lines.indexWhere(
      (line) => line.trim() == 'flutter_launcher_icons:',
    );
    if (start >= 0 && !lines[start].startsWith(' ')) {
      var end = lines.length;
      for (var index = start + 1; index < lines.length; index++) {
        final line = lines[index];
        if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
          end = index;
          break;
        }
      }
      lines.removeRange(start, end);
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    lines.addAll(const [
      '',
      'flutter_launcher_icons:',
      '  image_path: "assets/branding/app_icon.png"',
      '  android: true',
      '  ios: true',
      '  remove_alpha_ios: true',
      '  web:',
      '    generate: true',
      '  windows:',
      '    generate: true',
      '  macos:',
      '    generate: true',
      '',
    ]);
    return lines.join(newline);
  }

  String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _html(String value) => _xml(value);
  String _dartString(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$');
  String _cString(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  String _rcString(String value) => _cString(value);
}
