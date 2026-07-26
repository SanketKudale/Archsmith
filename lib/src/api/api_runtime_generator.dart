import '../models/generation.dart';

/// Generates reusable authentication, observability, and offline-cache hooks.
class ApiRuntimeGenerator {
  const ApiRuntimeGenerator();

  List<PlannedFile> generate() => const [
        PlannedFile(
          'lib/core/network/auth/auth_session.dart',
          _authSession,
        ),
        PlannedFile(
          'lib/core/network/auth/api_request_coordinator.dart',
          _requestCoordinator,
        ),
        PlannedFile(
          'lib/core/network/observability/network_log_sanitizer.dart',
          _logSanitizer,
        ),
        PlannedFile(
          'lib/core/network/observability/request_id_generator.dart',
          _requestId,
        ),
        PlannedFile(
          'lib/core/network/cache/api_response_cache.dart',
          _responseCache,
        ),
        PlannedFile(
          'lib/core/network/cache/memory_api_response_cache.dart',
          _memoryCache,
        ),
      ];
}

const _authSession = '''
class AuthTokens {
  const AuthTokens({required this.accessToken, this.refreshToken});
  final String accessToken;
  final String? refreshToken;
}

abstract interface class AuthTokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

abstract interface class AuthTokenRefresher {
  Future<AuthTokens?> refresh(String refreshToken);
}

abstract interface class AuthSessionListener {
  Future<void> onSessionExpired();
}

class NoAuthTokenStore implements AuthTokenStore {
  const NoAuthTokenStore();
  @override
  Future<AuthTokens?> read() async => null;
  @override
  Future<void> write(AuthTokens tokens) async {}
  @override
  Future<void> clear() async {}
}

class NoAuthTokenRefresher implements AuthTokenRefresher {
  const NoAuthTokenRefresher();
  @override
  Future<AuthTokens?> refresh(String refreshToken) async => null;
}

class NoAuthSessionListener implements AuthSessionListener {
  const NoAuthSessionListener();
  @override
  Future<void> onSessionExpired() async {}
}
''';

const _requestCoordinator = '''
import '../observability/network_log_sanitizer.dart';
import '../observability/request_id_generator.dart';
import 'auth_session.dart';

typedef AuthenticatedRequest<T> = Future<T> Function(
  Map<String, String> headers,
);

class ApiRequestCoordinator {
  const ApiRequestCoordinator({
    this.tokenStore = const NoAuthTokenStore(),
    this.refresher = const NoAuthTokenRefresher(),
    this.sessionListener = const NoAuthSessionListener(),
    this.logger = const NoopNetworkLogger(),
    this.requestIds = const RequestIdGenerator(),
    this.sanitizer = const NetworkLogSanitizer(),
  });

  final AuthTokenStore tokenStore;
  final AuthTokenRefresher refresher;
  final AuthSessionListener sessionListener;
  final NetworkLogger logger;
  final RequestIdGenerator requestIds;
  final NetworkLogSanitizer sanitizer;

  Future<T> execute<T>({
    required Map<String, String> headers,
    required AuthenticatedRequest<T> request,
    required bool Function(T response) isUnauthorized,
  }) async {
    var tokens = await tokenStore.read();
    var prepared = _headers(headers, tokens?.accessToken);
    logger.request(sanitizer.sanitizeHeaders(prepared));
    var response = await request(prepared);
    if (!isUnauthorized(response)) return response;

    final refreshToken = tokens?.refreshToken;
    if (refreshToken != null) {
      tokens = await refresher.refresh(refreshToken);
      if (tokens != null) {
        await tokenStore.write(tokens);
        prepared = _headers(headers, tokens.accessToken);
        response = await request(prepared);
        if (!isUnauthorized(response)) return response;
      }
    }
    await tokenStore.clear();
    await sessionListener.onSessionExpired();
    return response;
  }

  Map<String, String> _headers(
    Map<String, String> source,
    String? accessToken,
  ) => <String, String>{
    ...source,
    'X-Request-ID': requestIds.next(),
    if (accessToken != null && accessToken.isNotEmpty)
      'Authorization': 'Bearer \$accessToken',
  };

  void logResponse(int statusCode, Object? body) {
    logger.response(sanitizer.sanitize({
      'statusCode': statusCode,
      'body': body,
    }));
  }
}
''';

const _logSanitizer = '''
abstract interface class NetworkLogger {
  void request(Map<String, Object?> values);
  void response(Map<String, Object?> values);
}

class NoopNetworkLogger implements NetworkLogger {
  const NoopNetworkLogger();
  @override
  void request(Map<String, Object?> values) {}
  @override
  void response(Map<String, Object?> values) {}
}

class NetworkLogSanitizer {
  const NetworkLogSanitizer({
    this.sensitiveKeys = const {
      'authorization',
      'password',
      'token',
      'access_token',
      'refresh_token',
      'pin',
      'otp',
    },
  });

  final Set<String> sensitiveKeys;

  Map<String, Object?> sanitizeHeaders(Map<String, String> headers) =>
      sanitize(headers);

  Map<String, Object?> sanitize(Map<Object?, Object?> source) => {
    for (final entry in source.entries)
      entry.key.toString(): sensitiveKeys.contains(
        entry.key.toString().toLowerCase(),
      )
          ? '***'
          : _sanitizeValue(entry.value),
  };

  Object? _sanitizeValue(Object? value) {
    if (value is Map) {
      return sanitize(Map<Object?, Object?>.from(value));
    }
    if (value is List) return value.map(_sanitizeValue).toList();
    return value;
  }
}
''';

const _requestId = '''
class RequestIdGenerator {
  const RequestIdGenerator();

  String next() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'req-\$now';
  }
}
''';

const _responseCache = '''
class ApiCachedResponse {
  const ApiCachedResponse({
    required this.statusCode,
    required this.body,
    required this.storedAt,
  });
  final int statusCode;
  final Object? body;
  final DateTime storedAt;
}

abstract interface class ApiResponseCache {
  Future<ApiCachedResponse?> read(String key);
  Future<void> write(String key, ApiCachedResponse response);
  Future<void> remove(String key);
  Future<void> clear();
}
''';

const _memoryCache = '''
import 'api_response_cache.dart';

class MemoryApiResponseCache implements ApiResponseCache {
  MemoryApiResponseCache({
    this.enabled = false,
    this.timeToLive = const Duration(minutes: 5),
  });

  final bool enabled;
  final Duration timeToLive;
  final Map<String, ApiCachedResponse> _values = {};

  @override
  Future<ApiCachedResponse?> read(String key) async {
    if (!enabled) return null;
    final value = _values[key];
    if (value == null) return null;
    if (DateTime.now().difference(value.storedAt) > timeToLive) {
      _values.remove(key);
      return null;
    }
    return value;
  }

  @override
  Future<void> write(String key, ApiCachedResponse response) async {
    if (enabled) _values[key] = response;
  }

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}
''';
