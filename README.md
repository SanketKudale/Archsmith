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
```

## Architectures and integrations

Architectures: feature-first Clean Architecture, layer-first Clean Architecture, MVVM, and simple feature-first. State management: Riverpod, Bloc, Provider, or none. Routing: GoRouter, AutoRoute, Navigator, or none. Networking: Dio, HTTP, or none.

Optional modules include localization, theming, secure storage, networking, routing, logging, errors, and runtime protection. Security storage/encryption concerns live under `core/security`; runtime detection and response live under `core/runtime_protection`.

## Commands

```text
archsmith create [project_name]
archsmith init
archsmith feature <feature_name>
archsmith page <page_name>
archsmith model <model_name>
archsmith repository <repository_name>
archsmith service <service_name>
archsmith usecase <usecase_name>
archsmith controller <controller_name>
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

## Development and publishing

```shell
fvm dart format .
fvm dart analyze
fvm dart test
fvm dart pub publish --dry-run
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). Before publishing, replace the repository metadata placeholders in `pubspec.yaml` and add real screenshots if desired.

## Roadmap

- Structured router updates and richer golden fixtures
- Native `runtime_guard` adapter packages
- Additional dependency-injection and localization strategies
- Project migration and configuration upgrade commands

## License

MIT. See [LICENSE](LICENSE).
