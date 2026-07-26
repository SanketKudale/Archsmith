import 'dart:async';
import 'dart:io';

import '../../studio/studio_server.dart';
import 'base_command.dart';

class StudioCommand extends ArchsmithCommand {
  StudioCommand(super.context) {
    argParser
      ..addOption(
        'port',
        defaultsTo: '7331',
        help: 'Local Studio HTTP port.',
      )
      ..addFlag(
        'open',
        defaultsTo: true,
        help: 'Open Studio in the default browser.',
      );
  }

  @override
  String get name => 'studio';

  @override
  String get description =>
      'Open the local responsive drag-and-drop UI builder.';

  @override
  Future<int> run() async {
    final root = Directory.current.path;
    final port = int.tryParse(argResults!['port'] as String);
    if (port == null || port < 0 || port > 65535) {
      throw const FormatException('Studio port must be between 0 and 65535.');
    }
    final server = StudioServer(
      projectRoot: root,
      config: readConfig(root),
      fileSystem: context.files,
    );
    final url = await server.start(port: port);
    stdout.writeln('Archsmith Studio: $url');
    stdout.writeln('Press Ctrl+C to stop.');
    if (argResults!['open'] as bool) {
      await _openBrowser(url);
    }
    final stopped = Completer<void>();
    late final StreamSubscription<ProcessSignal> subscription;
    subscription = ProcessSignal.sigint.watch().listen((_) {
      if (!stopped.isCompleted) stopped.complete();
    });
    await stopped.future;
    await subscription.cancel();
    await server.close();
    return 0;
  }

  Future<void> _openBrowser(Uri url) async {
    final value = url.toString();
    if (Platform.isWindows) {
      await Process.start(
        'cmd',
        ['/c', 'start', '', value],
        mode: ProcessStartMode.detached,
      );
    } else if (Platform.isMacOS) {
      await Process.start(
        'open',
        [value],
        mode: ProcessStartMode.detached,
      );
    } else {
      await Process.start(
        'xdg-open',
        [value],
        mode: ProcessStartMode.detached,
      );
    }
  }
}
