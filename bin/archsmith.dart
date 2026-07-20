import 'dart:io';

import 'package:archsmith/archsmith.dart';

Future<void> main(List<String> arguments) async {
  final runner = ArchsmithRunner();
  exitCode = await runner.run(arguments);
}
