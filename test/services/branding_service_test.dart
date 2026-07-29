import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late Directory sources;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('archsmith_branding_');
    sources = await Directory.systemTemp.createTemp('archsmith_assets_');
    await _writeProject(project);
  });

  tearDown(() async {
    await project.delete(recursive: true);
    await sources.delete(recursive: true);
  });

  test('updates display metadata and registers branding assets', () async {
    final logo = File(p.join(sources.path, 'logo.svg'))
      ..writeAsStringSync('<svg/>');
    final icon = File(p.join(sources.path, 'icon.png'))
      ..writeAsBytesSync([1, 2, 3, 4]);

    final result = await const BrandingService().apply(
      project.path,
      BrandingRequest(
        displayName: 'Acme Wallet',
        logoPath: logo.path,
        iconPath: icon.path,
      ),
    );

    expect(
      File(
        p.join(project.path, 'android/app/src/main/AndroidManifest.xml'),
      ).readAsStringSync(),
      contains('android:label="Acme Wallet"'),
    );
    expect(
      File(p.join(project.path, 'ios/Runner/Info.plist')).readAsStringSync(),
      contains('<string>Acme Wallet</string>'),
    );
    expect(
      File(p.join(project.path, 'web/manifest.json')).readAsStringSync(),
      contains('"name": "Acme Wallet"'),
    );
    expect(
      File(p.join(project.path, 'web/index.html')).readAsStringSync(),
      contains(
        'name="apple-mobile-web-app-title" content="Acme Wallet"',
      ),
    );
    expect(
      File(p.join(project.path, 'lib/app/app.dart')).readAsStringSync(),
      contains("title: 'Acme Wallet'"),
    );
    expect(
      File(
        p.join(project.path, 'windows/runner/Runner.rc'),
      ).readAsStringSync(),
      contains('VALUE "ProductName", "Acme Wallet" "\\0"'),
    );
    final pubspec =
        File(p.join(project.path, 'pubspec.yaml')).readAsStringSync();
    expect(pubspec, contains('- assets/branding/'));
    expect(
      pubspec,
      contains('image_path: "assets/branding/app_icon.png"'),
    );
    expect(
      File(p.join(project.path, 'assets/branding/logo.svg')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(project.path, 'assets/branding/app_icon.png'))
          .readAsBytesSync(),
      [1, 2, 3, 4],
    );
    expect(result.paths, contains('pubspec.yaml'));
  });

  test('dry run reports changes without touching the project', () async {
    final before =
        File(p.join(project.path, 'pubspec.yaml')).readAsStringSync();
    final result = await const BrandingService().apply(
      project.path,
      const BrandingRequest(displayName: 'Preview App'),
      dryRun: true,
    );

    expect(result.paths, isNotEmpty);
    expect(
      File(p.join(project.path, 'pubspec.yaml')).readAsStringSync(),
      before,
    );
    expect(
      File(
        p.join(project.path, 'android/app/src/main/AndroidManifest.xml'),
      ).readAsStringSync(),
      contains('android:label="sample_app"'),
    );
  });

  test('requires PNG input for launcher icons', () async {
    final icon = File(p.join(sources.path, 'icon.jpg'))..writeAsBytesSync([1]);
    expect(
      () => const BrandingService().apply(
        project.path,
        BrandingRequest(iconPath: icon.path),
      ),
      throwsFormatException,
    );
  });
}

Future<void> _writeProject(Directory project) async {
  Future<void> write(String relative, String content) async {
    final file = File(p.join(project.path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  await write('pubspec.yaml', '''
name: sample_app
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');
  await write('android/app/src/main/AndroidManifest.xml', '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:label="sample_app" android:icon="@mipmap/ic_launcher"/>
</manifest>
''');
  await write('ios/Runner/Info.plist', '''
<plist><dict>
  <key>CFBundleDisplayName</key>
  <string>Sample App</string>
</dict></plist>
''');
  await write('web/manifest.json', '''
{"name":"sample_app","short_name":"sample_app"}
''');
  await write('web/index.html', '''
<html><head>
<meta name="apple-mobile-web-app-title" content="sample_app">
<title>sample_app</title>
</head></html>
''');
  await write('lib/app/app.dart', '''
class App {
  final title = 'sample_app';
  Widget build() => MaterialApp(title: 'Sample App');
}
''');
  await write('windows/runner/Runner.rc', r'''
VALUE "FileDescription", "sample_app" "\0"
VALUE "ProductName", "sample_app" "\0"
''');
}
