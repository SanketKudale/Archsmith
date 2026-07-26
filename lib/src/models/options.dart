/// Architecture layouts supported by Archsmith generators.
enum ArchitectureType {
  cleanFeature('clean_feature', 'Feature-first Clean Architecture'),
  cleanLayer('clean_layer', 'Layer-first Clean Architecture'),
  mvvm('mvvm', 'MVVM'),
  simpleFeature('simple_feature', 'Simple Feature-first');

  const ArchitectureType(this.value, this.label);
  final String value;
  final String label;
}

/// State-management integrations available to generated applications.
enum StateManagementType {
  riverpod('riverpod', 'Riverpod'),
  bloc('bloc', 'Bloc'),
  provider('provider', 'Provider'),
  getx('getx', 'GetX'),
  none('none', 'None');

  const StateManagementType(this.value, this.label);
  final String value;
  final String label;
}

/// Routing integrations available to generated applications.
enum RouterType {
  goRouter('go_router', 'GoRouter'),
  autoRoute('auto_route', 'AutoRoute'),
  navigator('navigator', 'Navigator'),
  none('none', 'None');

  const RouterType(this.value, this.label);
  final String value;
  final String label;
}

/// Networking clients available to generated applications.
enum NetworkType {
  dio('dio', 'Dio'),
  http('http', 'HTTP'),
  none('none', 'None');

  const NetworkType(this.value, this.label);
  final String value;
  final String label;
}

/// Preset runtime-protection policy profiles.
enum RuntimeProtectionProfile {
  standard('standard', 'Standard'),
  financial('financial', 'Financial'),
  examination('examination', 'Examination'),
  custom('custom', 'Custom');

  const RuntimeProtectionProfile(this.value, this.label);
  final String value;
  final String label;
}

/// Finds an enum-like value using its serialized representation.
T enumByValue<T>(Iterable<T> values, String value, String Function(T) read) {
  return values.firstWhere(
    (item) => read(item) == value,
    orElse: () => throw FormatException('Unsupported value: $value'),
  );
}
