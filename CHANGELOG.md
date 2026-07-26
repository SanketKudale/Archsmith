# Changelog

## 0.3.0 - 2026-07-26

- Added endpoint-example JSON inference and full Clean Architecture API feature
  generation.
- Added `archsmith api-common` commands for shared base URLs, headers, and
  request fields.
- Added batch endpoint-directory generation with deterministic API summaries.
- Added generated token refresh, retry, logout, request-ID, sanitized logging,
  and offline-cache boundaries.
- Added UI-ready retryable API state and API dependency injection for
  Riverpod, Provider, BLoC/Cubit, GetX, and framework-only projects.
- Added manifest-backed GoRouter, AutoRoute, and Navigator route registration.

## 0.2.0

- Added a reusable shared widget layer with centralized component defaults.
- Added `archsmith widget` for architecture-independent common UI components.
- Generated pages now reuse the shared `AppScaffold`.
- Added structured API contracts and typed Dio/HTTP client generation through
  `archsmith api`.
- Added shared request contexts and centralized success-envelope/error
  classification for generated API clients.
- Expanded compatibility to Dart 3.0 and Flutter 3.10 or newer.

## 0.1.1

- Corrected GitHub repository, homepage, and issue-tracker metadata.
- Added public API documentation for improved generated API reference quality.

## 0.1.0

- Initial interactive and non-interactive CLI.
- Four architecture styles and common component generators.
- Safe dry-run, overwrite, skip, and idempotency behavior.
- Runtime-protection profiles and native adapter boundary.
- Doctor checks, configuration persistence, tests, and documentation.
