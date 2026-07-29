# Archsmith

Archsmith is an interactive Dart CLI for creating and evolving maintainable Flutter project architectures. It records decisions in `archsmith.yaml`, generates deterministic code, protects existing files, and can add an application-level runtime-protection boundary.

> Archsmith is pre-1.0. Review generated code and platform configuration before shipping it.

## Installation

```shell
dart pub global activate archsmith
archsmith doctor
```

For local development this repository is pinned to Flutter 3.44.6 with FVM:

```shell
fvm dart pub get
fvm dart run bin/archsmith.dart --help
```

Published Archsmith releases support Dart 3.0 and newer, corresponding to Flutter 3.10 and newer for Flutter projects. Dependencies use compatibility ranges, so an older supported SDK resolves the newest package versions it can run instead of requiring the versions used during Archsmith development.

On Windows, Flutter packages containing plugins require Developer Mode (or equivalent symlink privileges). Run `start ms-settings:developers` if Flutter reports that symlink support is unavailable.

## Usage

Interactive creation:

```shell
archsmith create
```

Non-interactive creation:

```shell
archsmith create my_app --architecture clean_feature --state riverpod \
  --router go_router --network dio --localization --theme \
  --runtime-protection financial --starter-auth
```

Initialize an existing Flutter project without overwriting its files:

```shell
archsmith init --dry-run
archsmith init --skip-existing
```

Generate from saved configuration:

```shell
archsmith feature payments
archsmith page checkout --feature payments
archsmith model payment --feature payments --no-tests
archsmith widget profile_card
archsmith api path/to/cusacc.json
archsmith api-dir path/to/jsons
```

## Architectures and integrations

Architectures: feature-first Clean Architecture, layer-first Clean Architecture, MVVM, and simple feature-first. State management: Riverpod, Bloc, Provider, or none. Routing: GoRouter, AutoRoute, Navigator, or none. Networking: Dio, HTTP, or none.

Optional modules include localization, theming, secure storage, networking, routing, logging, errors, and runtime protection. Security storage/encryption concerns live under `core/security`; runtime detection and response live under `core/runtime_protection`.

## Commands

```text
archsmith create [project_name]
archsmith init
archsmith api <endpoint.json>
archsmith api-dir <json-directory>
archsmith api-common <operation> ...
archsmith feature <feature_name>
archsmith page <page_name>
archsmith model <model_name>
archsmith repository <repository_name>
archsmith service <service_name>
archsmith usecase <usecase_name>
archsmith controller <controller_name>
archsmith widget <widget_name>
archsmith doctor
```

Generators accept `--feature`, `--dry-run`, `--force`, `--skip-existing`, `--tests`, and `--no-tests` where relevant. Existing differing files become conflicts unless `--force` or `--skip-existing` is explicit. A dry run performs no writes and prints `CREATE`, `UPDATE`, `SKIP`, and `CONFLICT` entries.

## Configuration reference

```yaml
project:
  name: "my_flutter_app"
architecture:
  type: "clean_feature"
state_management:
  type: "riverpod"
router:
  type: "go_router"
network:
  type: "dio"
modules:
  localization: true
  theme: true
  secure_storage: true
  runtime_protection: true
runtime_protection:
  profile: "financial"
  checks:
    vpn: "warn"
    root: "block_screen"
generation:
  generate_tests: true
  use_barrel_files: false
  format_after_generation: true
  analyze_after_generation: true
```

Supported architecture values are `clean_feature`, `clean_layer`, `mvvm`, and `simple_feature`. See command help for the other enum values.

## API contract generation

Backend endpoint files contain only the endpoint URL plus real request and response examples. Base URL, common headers, and common request fields live once in `archsmith_api_common.json`.

```json
{
  "url": "accountDeactivate",
  "request": {
    "fullAccountNumber": "0471-0621998-001-3000-000",
    "closingReason": 1
  },
  "response": {
    "status": {
      "code": "000000",
      "description": "SUCCESS"
    },
    "data": {
      "statusCode": 0,
      "statusMessage": "OPERATION SUCCESSFUL"
    }
  }
}
```

Set the shared base URL once. Additional commands update the existing JSON object or append a new key without removing earlier values:

```shell
archsmith api-common base-url https://api.example.com
archsmith api-common header Content-Type application/json
archsmith api-common header X-Platform mobile
archsmith api-common request channel MOBILE
archsmith api-common request retryCount 3
archsmith api-common success-code "00"
archsmith api-common add-success-code "000000"
archsmith api-common success-code-path meta.resultCode
archsmith api-common message-path meta.message
archsmith api-common cache-enabled true
archsmith api-common cache-ttl 900
```

Values passed to `api-common request` are parsed as JSON when possible, so numbers, booleans, lists, and objects keep their types. Generate an endpoint with:

```shell
archsmith api path/to/cusacc.json --feature cusacc --method POST --dry-run
archsmith api path/to/cusacc.json --feature cusacc --method POST
```

The JSON filename becomes the feature name when `--feature` is omitted. Request and response field types, nested objects, and lists are inferred from the examples. Archsmith generates:

- remote datasource;
- request and response models;
- request and response entities;
- domain repository and data repository implementation;
- use case;
- state and notifier;
- one API provider that wires the data source, repository, use case, and state notifier;
- common network client and request-context providers;
- centralized success/error response handling.

The initial response envelope checks `status.code == "000000"` and reads messages from `status.description`; none of these values are hardcoded into generated endpoint logic. Use `success-code` to replace the accepted-code list, `add-success-code` to append another accepted code, and the path commands to match a different backend envelope. All values are stored in `archsmith_api_common.json`. Runtime-only values such as access tokens can still be supplied through `ApiRequestContext`; avoid storing secrets in source control.

Generate a complete directory of backend examples together:

```shell
archsmith api-dir jsons/
archsmith api-dir jsons/ --recursive --dry-run
```

Batch generation sorts inputs, emits common networking/authentication/cache files once, rejects conflicting output before writing, and creates `docs/archsmith_api_summary.md`.

Every generated remote datasource uses `ApiRequestCoordinator`. It adds request IDs, reads authorization tokens through `AuthTokenStore`, retries once through `AuthTokenRefresher` after a `401`, clears the session and invokes `AuthSessionListener` when refresh fails, and passes sanitized request/response data to `NetworkLogger`. The generated defaults are safe no-ops; inject application implementations through the generated DI file for the selected state manager.

Offline response caching is disabled initially. `cache-enabled true` enables the generated in-memory cache and `cache-ttl` controls expiration. Implement `ApiResponseCache` with Hive, Isar, SQLite, or another persistent store when cached data must survive application restarts.

Generated presentation state exposes `isLoading`, `data`, `error`, `isEmpty`, `hasData`, `hasError`, and `retry()`. API dependency files are generated for Riverpod, Provider, BLoC/Cubit, GetX, or framework-only `ValueNotifier`, based on `archsmith.yaml`.

## Route registration

Generate a page and register it in one command:

```shell
archsmith page account_deactivate \
  --feature accounts \
  --route /account-deactivate
```

Archsmith maintains `.archsmith/routes.json` and `lib/core/router/generated_routes.dart`, generates typed navigation helpers, and updates its owned GoRouter or AutoRoute registration points. AutoRoute pages receive `@RoutePage()` and require the generated `build_runner` step. Navigator projects receive a generated route map.

Existing structured YAML contracts remain available through `archsmith api --contract archsmith_api.yaml`.

## Runtime protection

The Standard, Financial, Examination, and Custom profiles generate separate detection contracts, policy evaluation, UI responses, logging boundaries, and optional session actions. A root `RuntimeProtectionGate` avoids scattered route redirects. The generated adapter boundary is designed for a separate native plugin such as `runtime_guard`; Archsmith does not pretend to implement native detection itself.

### Capability matrix

| Capability | Android | iOS | Important limitation |
|---|---:|---:|---|
| Secure display/screenshot restriction | Stronger support | Limited | iOS cannot prevent every capture path |
| Screen recording/capture observation | Partial | Partial | Timing and APIs vary |
| Root/jailbreak detection | Heuristic | Heuristic | Bypassable on compromised devices |
| USB debugging/developer mode | Partial | Limited | Primarily Android-oriented |
| VPN/proxy detection | Partial | Partial | A VPN is not evidence of malicious intent |
| Mirroring/external display | Partial | Partial | Hardware and OS behavior varies |
| App integrity | Adapter/server dependent | Adapter/server dependent | Use platform attestation and server verification |

No client-side check provides perfect prevention. Results expose confidence and platform support. High-security apps should combine conservative local UX controls with server-side attestation, authorization, audit logging, and incident response.

## Generated layout

Feature-first Clean Architecture creates `lib/app`, `lib/core`, `lib/features`, and `lib/shared`. A feature contains `data`, `domain`, and `presentation` subtrees. Other architecture layouts place generated components in their conventional layer/view-model locations.

Every architecture includes reusable UI under `lib/shared/widgets`: `AppScaffold`, `AppButton`, `AppTextField`, and `AppLoadingIndicator`, plus a `common_widgets.dart` barrel. Generated pages use `AppScaffold` instead of creating their own page shell. Change shared sizing and shape values once in `app_component_defaults.dart`, or customize a shared widget's implementation, and all usages inherit the update. `archsmith widget <name>` always creates the widget in this common folder regardless of the selected architecture.

## Development and publishing

```shell
fvm dart format .
fvm dart analyze
fvm dart test
fvm dart pub publish --dry-run
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## Roadmap

- Structured router updates and richer golden fixtures
- Native `runtime_guard` adapter packages
- Additional dependency-injection and localization strategies
- Project migration and configuration upgrade commands

## License

MIT. See [LICENSE](LICENSE).
