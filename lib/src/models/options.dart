enum ArchitectureType {
  cleanFeature('clean_feature', 'Feature-first Clean Architecture'),
  cleanLayer('clean_layer', 'Layer-first Clean Architecture'),
  mvvm('mvvm', 'MVVM'),
  simpleFeature('simple_feature', 'Simple Feature-first');

  const ArchitectureType(this.value, this.label);
  final String value;
  final String label;
}

enum StateManagementType {
  riverpod('riverpod', 'Riverpod'),
  bloc('bloc', 'Bloc'),
  provider('provider', 'Provider'),
  none('none', 'None');

  const StateManagementType(this.value, this.label);
  final String value;
  final String label;
}

enum RouterType {
  goRouter('go_router', 'GoRouter'),
  autoRoute('auto_route', 'AutoRoute'),
  navigator('navigator', 'Navigator'),
  none('none', 'None');

  const RouterType(this.value, this.label);
  final String value;
  final String label;
}

enum NetworkType {
  dio('dio', 'Dio'),
  http('http', 'HTTP'),
  none('none', 'None');

  const NetworkType(this.value, this.label);
  final String value;
  final String label;
}

enum RuntimeProtectionProfile {
  standard('standard', 'Standard'),
  financial('financial', 'Financial'),
  examination('examination', 'Examination'),
  custom('custom', 'Custom');

  const RuntimeProtectionProfile(this.value, this.label);
  final String value;
  final String label;
}

T enumByValue<T>(Iterable<T> values, String value, String Function(T) read) {
  return values.firstWhere(
    (item) => read(item) == value,
    orElse: () => throw FormatException('Unsupported value: $value'),
  );
}
