import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../api/api_common_config.dart';
import 'base_command.dart';

class ApiCommonCommand extends ArchsmithCommand {
  ApiCommonCommand(super.context) {
    argParser
      ..addOption(
        'config',
        defaultsTo: 'archsmith_api_common.json',
        help: 'Common API configuration file.',
      )
      ..addFlag('dry-run', negatable: false, help: 'Preview without writing.');
  }

  @override
  String get name => 'api-common';

  @override
  String get description =>
      'Configure shared API values and backend success detection.';

  @override
  String get invocation =>
      'archsmith api-common <operation> <key-or-value> [value]';

  @override
  Future<int> run() async {
    final arguments = argResults!.rest;
    if (arguments.length < 2) {
      stderr.writeln(
        'Use base-url <url>, header <name> <value>, or '
        'request <name> <JSON-value>.\n'
        'Response operations: success-code <JSON-value>, '
        'add-success-code <JSON-value>, success-code-path <path>, or '
        'message-path <path>.\n'
        'Cache operations: cache-enabled <true|false> or '
        'cache-ttl <seconds>.',
      );
      return 64;
    }
    final root = Directory.current.path;
    final path = p.normalize(
      p.join(root, argResults!['config'] as String),
    );
    if (!p.isWithin(root, path)) {
      throw ArgumentError.value(path, 'config', 'Must stay inside the project');
    }
    const store = ApiCommonConfigStore();
    final operation = arguments.first;
    ApiCommonConfig config;
    if (operation == 'base-url') {
      config = File(path).existsSync()
          ? store.read(path).copyWith(baseUrl: arguments[1])
          : ApiCommonConfig(baseUrl: arguments[1]);
    } else {
      config = store.read(path);
      if (operation == 'header') {
        if (arguments.length < 3) return _missingNameAndValue(operation);
        config = config.copyWith(
          headers: {...config.headers, arguments[1]: arguments[2]},
        );
      } else if (operation == 'request') {
        if (arguments.length < 3) return _missingNameAndValue(operation);
        config = config.copyWith(
          request: {
            ...config.request,
            arguments[1]: _decodeValue(arguments[2]),
          },
        );
      } else if (operation == 'success-code') {
        config = config.copyWith(
          successCodes: [_decodeValue(arguments[1])],
        );
      } else if (operation == 'add-success-code') {
        final value = _decodeValue(arguments[1]);
        config = config.copyWith(
          successCodes: config.successCodes.contains(value)
              ? config.successCodes
              : [...config.successCodes, value],
        );
      } else if (operation == 'success-code-path') {
        config = config.copyWith(successCodePath: arguments[1]);
      } else if (operation == 'message-path') {
        config = config.copyWith(messagePath: arguments[1]);
      } else if (operation == 'cache-enabled') {
        final enabled = _decodeValue(arguments[1]);
        if (enabled is! bool) {
          stderr.writeln('cache-enabled requires true or false.');
          return 64;
        }
        config = config.copyWith(cacheEnabled: enabled);
      } else if (operation == 'cache-ttl') {
        final seconds = int.tryParse(arguments[1]);
        if (seconds == null || seconds <= 0) {
          stderr.writeln('cache-ttl requires a positive number of seconds.');
          return 64;
        }
        config = config.copyWith(cacheTtlSeconds: seconds);
      } else {
        stderr.writeln('Unsupported common API operation: $operation.');
        return 64;
      }
    }
    if (argResults!['dry-run'] as bool) {
      stdout
          .writeln(const JsonEncoder.withIndent('  ').convert(config.toJson()));
      return 0;
    }
    await store.write(path, config);
    stdout.writeln('Updated ${p.relative(path, from: root)}');
    return 0;
  }

  Object? _decodeValue(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      return value;
    }
  }

  int _missingNameAndValue(String operation) {
    stderr.writeln('$operation requires a name and value.');
    return 64;
  }
}
