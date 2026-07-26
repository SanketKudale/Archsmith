import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archsmith/archsmith.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'real browser creates and saves a Studio screen',
    () async {
      final browser = _browserExecutable();
      if (browser == null) return;
      final directory = await Directory.systemTemp.createTemp(
        'archsmith_browser_e2e_',
      );
      addTearDown(() => _deleteEventually(directory));
      final server = StudioServer(
        projectRoot: directory.path,
        config: const ArchsmithConfig(projectName: 'sample_app'),
      );
      final url = await server.start(port: 0);
      addTearDown(server.close);
      final profile = Directory(p.join(directory.path, 'browser_profile'));
      await profile.create(recursive: true);
      final process = await Process.start(
        browser,
        [
          '--headless=new',
          '--disable-gpu',
          '--no-first-run',
          '--no-default-browser-check',
          '--remote-allow-origins=*',
          '--remote-debugging-port=0',
          '--user-data-dir=${profile.path}',
          url.toString(),
        ],
        mode: ProcessStartMode.normal,
      );
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      addTearDown(() async {
        process.kill();
        try {
          await process.exitCode.timeout(const Duration(seconds: 5));
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
        }
      });

      final portFile = File(p.join(profile.path, 'DevToolsActivePort'));
      await _waitFor(() => portFile.existsSync());
      final port = int.parse(portFile.readAsLinesSync().first);
      final targets = await _json(
        Uri.parse('http://127.0.0.1:$port/json'),
      ) as List<dynamic>;
      final target = targets.cast<Map<String, dynamic>>().firstWhere(
            (item) => item['type'] == 'page',
          );
      final socket = await WebSocket.connect(
        target['webSocketDebuggerUrl'] as String,
      );
      addTearDown(socket.close);
      final iterator = StreamIterator<dynamic>(socket);
      var messageId = 0;

      Future<Object?> evaluate(String expression) async {
        final id = ++messageId;
        socket.add(
          jsonEncode({
            'id': id,
            'method': 'Runtime.evaluate',
            'params': {
              'expression': expression,
              'awaitPromise': true,
              'returnByValue': true,
            },
          }),
        );
        while (await iterator.moveNext()) {
          final message =
              jsonDecode(iterator.current.toString()) as Map<String, dynamic>;
          if (message['id'] != id) continue;
          final result = message['result'] as Map<String, dynamic>?;
          final exception = result?['exceptionDetails'];
          if (exception != null) {
            throw StateError('Browser evaluation failed: $exception');
          }
          return ((result?['result'] as Map<String, dynamic>?)?['value']);
        }
        throw StateError('Browser debugging connection closed.');
      }

      await _waitFor(() async {
        try {
          return await evaluate(
                "typeof bootstrap !== 'undefined' && "
                'Array.isArray(bootstrap?.components)',
              ) ==
              true;
        } on Object {
          return false;
        }
      });
      final status = await evaluate('''(async () => {
        addNode('text');
        document.getElementById('screenName').value = 'browser_screen';
        document.getElementById('featureName').value = 'browser';
        document.getElementById('route').value = '/browser';
        await persist(false);
        return document.getElementById('status').textContent;
      })()''');

      expect(status, contains('Saved browser_screen'));
      final schema = File(
        p.join(
          directory.path,
          '.archsmith',
          'ui',
          'browser_screen.json',
        ),
      );
      expect(schema.existsSync(), isTrue);
      expect(schema.readAsStringSync(), contains('"type": "text"'));
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

String? _browserExecutable() {
  final configured = Platform.environment['CHROME_PATH'];
  final candidates = [
    if (configured != null) configured,
    if (Platform.isWindows)
      r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    if (Platform.isWindows)
      r'C:\Program Files\Google\Chrome\Application\chrome.exe',
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ];
  for (final candidate in candidates) {
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

Future<void> _waitFor(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TimeoutException('Condition was not met.', timeout);
}

Future<Object?> _json(Uri uri) async {
  final client = HttpClient();
  try {
    final response = await (await client.getUrl(uri)).close();
    return jsonDecode(await utf8.decoder.bind(response).join());
  } finally {
    client.close(force: true);
  }
}

Future<void> _deleteEventually(Directory directory) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    try {
      if (directory.existsSync()) await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
