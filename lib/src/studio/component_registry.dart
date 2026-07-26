import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/generation.dart';

/// Metadata for one widget available in the visual component palette.
class StudioComponentDescriptor {
  const StudioComponentDescriptor({
    required this.type,
    required this.label,
    required this.category,
    required this.acceptsChildren,
    this.defaults = const {},
    this.properties = const [],
    this.dartClass,
    this.importPath,
    this.childParameter,
  });

  factory StudioComponentDescriptor.fromJson(Map<String, Object?> json) {
    final properties = json['properties'];
    if (properties != null && properties is! List) {
      throw const FormatException('Component properties must be a list.');
    }
    return StudioComponentDescriptor(
      type: _requiredString(json, 'type'),
      label: _requiredString(json, 'label'),
      category: _requiredString(json, 'category'),
      acceptsChildren: json['accepts_children'] as bool? ?? false,
      defaults: Map.unmodifiable(
        Map<String, Object?>.from(json['defaults'] as Map? ?? const {}),
      ),
      properties: (properties as List? ?? const [])
          .map(
            (item) => StudioPropertyDescriptor.fromJson(
              Map<String, Object?>.from(item as Map),
            ),
          )
          .toList(growable: false),
      dartClass: json['dart_class'] as String?,
      importPath: json['import'] as String?,
      childParameter: json['child_parameter'] as String?,
    );
  }

  final String type;
  final String label;
  final String category;
  final bool acceptsChildren;
  final Map<String, Object?> defaults;
  final List<StudioPropertyDescriptor> properties;
  final String? dartClass;
  final String? importPath;
  final String? childParameter;

  Map<String, Object?> toJson() => {
        'type': type,
        'label': label,
        'category': category,
        'accepts_children': acceptsChildren,
        'defaults': defaults,
        'properties': properties.map((item) => item.toJson()).toList(),
        if (dartClass != null) 'dart_class': dartClass,
        if (importPath != null) 'import': importPath,
        if (childParameter != null) 'child_parameter': childParameter,
      };
}

/// Editable property metadata rendered by the Studio inspector.
class StudioPropertyDescriptor {
  const StudioPropertyDescriptor(
    this.name,
    this.type, {
    this.label,
    this.options = const [],
  });

  factory StudioPropertyDescriptor.fromJson(Map<String, Object?> json) =>
      StudioPropertyDescriptor(
        _requiredString(json, 'name'),
        _requiredString(json, 'type'),
        label: json['label'] as String?,
        options: (json['options'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
      );

  final String name;
  final String type;
  final String? label;
  final List<String> options;

  Map<String, Object?> toJson() => {
        'name': name,
        'type': type,
        'label': label ?? name,
        if (options.isNotEmpty) 'options': options,
      };
}

/// Built-in responsive and shared components supported by the MVP generator.
class StudioComponentRegistry {
  const StudioComponentRegistry({this.custom = const []});

  final List<StudioComponentDescriptor> custom;

  List<StudioComponentDescriptor> get components => [
        ..._components,
        ...custom,
      ];

  StudioComponentDescriptor? find(String type) {
    for (final component in components) {
      if (component.type == type) return component;
    }
    return null;
  }

  List<Map<String, Object?>> toJson() =>
      components.map((item) => item.toJson()).toList(growable: false);
}

/// Persists project-specific common widgets exposed in Studio.
class StudioComponentManifestStore {
  const StudioComponentManifestStore();

  List<StudioComponentDescriptor> readAll(String projectRoot) {
    final file = File(_path(projectRoot));
    if (!file.existsSync()) return const [];
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map || decoded['components'] is! List) {
      throw const FormatException(
        '.archsmith/components.json must contain a components list.',
      );
    }
    return (decoded['components'] as List)
        .map(
          (item) => StudioComponentDescriptor.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  PlannedFile plan(
    String projectRoot,
    StudioComponentDescriptor component,
  ) {
    if (const StudioComponentRegistry().find(component.type) != null) {
      throw FormatException(
        '${component.type} is a built-in component and cannot be replaced.',
      );
    }
    if (component.dartClass == null || component.importPath == null) {
      throw const FormatException(
        'Custom components require dart_class and import.',
      );
    }
    if (component.acceptsChildren &&
        component.childParameter != 'child' &&
        component.childParameter != 'children') {
      throw const FormatException(
        'A component with children requires child_parameter child or children.',
      );
    }
    final components = readAll(projectRoot).toList();
    final index = components.indexWhere(
      (existing) => existing.type == component.type,
    );
    if (index < 0) {
      components.add(component);
    } else {
      components[index] = component;
    }
    components.sort((left, right) => left.type.compareTo(right.type));
    return PlannedFile(
      '.archsmith/components.json',
      '${const JsonEncoder.withIndent('  ').convert({
            'version': 1,
            'components': components.map((item) => item.toJson()).toList(),
          })}\n',
      isUpdate: true,
    );
  }

  String _path(String root) => p.join(root, '.archsmith', 'components.json');
}

const _axis = StudioPropertyDescriptor(
  'mainAxisAlignment',
  'select',
  options: [
    'start',
    'center',
    'end',
    'spaceBetween',
    'spaceAround',
    'spaceEvenly',
  ],
);
const _crossAxis = StudioPropertyDescriptor(
  'crossAxisAlignment',
  'select',
  options: ['start', 'center', 'end', 'stretch'],
);
const _components = <StudioComponentDescriptor>[
  StudioComponentDescriptor(
    type: 'appScaffold',
    label: 'App Scaffold',
    category: 'Common',
    acceptsChildren: true,
    properties: [
      StudioPropertyDescriptor('title', 'string'),
      StudioPropertyDescriptor('padding', 'number'),
    ],
  ),
  StudioComponentDescriptor(
    type: 'column',
    label: 'Column',
    category: 'Layout',
    acceptsChildren: true,
    properties: [_axis, _crossAxis, StudioPropertyDescriptor('gap', 'number')],
  ),
  StudioComponentDescriptor(
    type: 'row',
    label: 'Row',
    category: 'Layout',
    acceptsChildren: true,
    properties: [_axis, _crossAxis, StudioPropertyDescriptor('gap', 'number')],
  ),
  StudioComponentDescriptor(
    type: 'wrap',
    label: 'Wrap',
    category: 'Layout',
    acceptsChildren: true,
    properties: [
      StudioPropertyDescriptor('spacing', 'number'),
      StudioPropertyDescriptor('runSpacing', 'number'),
    ],
  ),
  StudioComponentDescriptor(
    type: 'container',
    label: 'Container',
    category: 'Layout',
    acceptsChildren: true,
    properties: [
      StudioPropertyDescriptor('padding', 'number'),
      StudioPropertyDescriptor('width', 'number'),
      StudioPropertyDescriptor('height', 'number'),
      StudioPropertyDescriptor('color', 'color'),
      StudioPropertyDescriptor('borderRadius', 'number'),
    ],
  ),
  StudioComponentDescriptor(
    type: 'text',
    label: 'Text',
    category: 'Content',
    acceptsChildren: false,
    defaults: {'text': 'Text'},
    properties: [
      StudioPropertyDescriptor('text', 'string'),
      StudioPropertyDescriptor('fontSize', 'number'),
      StudioPropertyDescriptor('fontWeight', 'select', options: [
        'normal',
        'medium',
        'bold',
      ]),
      StudioPropertyDescriptor('color', 'color'),
      StudioPropertyDescriptor('textAlign', 'select', options: [
        'left',
        'center',
        'right',
      ]),
    ],
  ),
  StudioComponentDescriptor(
    type: 'appTextField',
    label: 'App Text Field',
    category: 'Common',
    acceptsChildren: false,
    defaults: {'required': false, 'trim': true, 'valueType': 'string'},
    properties: [
      StudioPropertyDescriptor('label', 'string'),
      StudioPropertyDescriptor('hint', 'string'),
      StudioPropertyDescriptor('obscureText', 'boolean'),
      StudioPropertyDescriptor('required', 'boolean'),
      StudioPropertyDescriptor('trim', 'boolean'),
      StudioPropertyDescriptor('minLength', 'number'),
      StudioPropertyDescriptor('maxLength', 'number'),
      StudioPropertyDescriptor('pattern', 'string'),
      StudioPropertyDescriptor('validationMessage', 'string'),
      StudioPropertyDescriptor('valueType', 'select', options: [
        'string',
        'int',
        'double',
        'num',
        'bool',
      ]),
    ],
  ),
  StudioComponentDescriptor(
    type: 'appButton',
    label: 'App Button',
    category: 'Common',
    acceptsChildren: false,
    defaults: {'label': 'Continue'},
    properties: [
      StudioPropertyDescriptor('label', 'string'),
      StudioPropertyDescriptor('enabled', 'boolean'),
    ],
  ),
  StudioComponentDescriptor(
    type: 'appLoadingIndicator',
    label: 'Loading Indicator',
    category: 'State',
    acceptsChildren: false,
  ),
  StudioComponentDescriptor(
    type: 'stateText',
    label: 'State Text',
    category: 'State',
    acceptsChildren: false,
    properties: [
      StudioPropertyDescriptor('binding', 'binding'),
      StudioPropertyDescriptor('fallback', 'string'),
    ],
  ),
  StudioComponentDescriptor(
    type: 'stateList',
    label: 'Response List',
    category: 'State',
    acceptsChildren: false,
    defaults: {
      'emptyText': 'No items',
      'errorText': 'Could not load items',
      'shrinkWrap': true,
      'refreshable': true,
    },
    properties: [
      StudioPropertyDescriptor('binding', 'listBinding'),
      StudioPropertyDescriptor('itemTextPath', 'itemBinding'),
      StudioPropertyDescriptor('emptyText', 'string'),
      StudioPropertyDescriptor('errorText', 'string'),
      StudioPropertyDescriptor('shrinkWrap', 'boolean'),
      StudioPropertyDescriptor('refreshable', 'boolean'),
      StudioPropertyDescriptor('separator', 'number'),
    ],
  ),
  StudioComponentDescriptor(
    type: 'stateGrid',
    label: 'Response Grid',
    category: 'State',
    acceptsChildren: false,
    defaults: {
      'emptyText': 'No items',
      'errorText': 'Could not load items',
      'columns': 2,
      'childAspectRatio': 1,
      'shrinkWrap': true,
      'refreshable': true,
    },
    properties: [
      StudioPropertyDescriptor('binding', 'listBinding'),
      StudioPropertyDescriptor('itemTextPath', 'itemBinding'),
      StudioPropertyDescriptor('emptyText', 'string'),
      StudioPropertyDescriptor('errorText', 'string'),
      StudioPropertyDescriptor('columns', 'number'),
      StudioPropertyDescriptor('childAspectRatio', 'number'),
      StudioPropertyDescriptor('shrinkWrap', 'boolean'),
      StudioPropertyDescriptor('refreshable', 'boolean'),
      StudioPropertyDescriptor('spacing', 'number'),
    ],
  ),
  StudioComponentDescriptor(
    type: 'card',
    label: 'Card',
    category: 'Content',
    acceptsChildren: true,
    properties: [
      StudioPropertyDescriptor('elevation', 'number'),
      StudioPropertyDescriptor('padding', 'number'),
    ],
  ),
  StudioComponentDescriptor(
    type: 'spacer',
    label: 'Spacer',
    category: 'Layout',
    acceptsChildren: false,
    properties: [StudioPropertyDescriptor('size', 'number')],
  ),
];

String _requiredString(Map<String, Object?> source, String key) {
  final value = source[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value.trim();
}
