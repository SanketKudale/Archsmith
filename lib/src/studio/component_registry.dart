/// Metadata for one widget available in the visual component palette.
class StudioComponentDescriptor {
  const StudioComponentDescriptor({
    required this.type,
    required this.label,
    required this.category,
    required this.acceptsChildren,
    this.defaults = const {},
    this.properties = const [],
  });

  final String type;
  final String label;
  final String category;
  final bool acceptsChildren;
  final Map<String, Object?> defaults;
  final List<StudioPropertyDescriptor> properties;

  Map<String, Object?> toJson() => {
        'type': type,
        'label': label,
        'category': category,
        'accepts_children': acceptsChildren,
        'defaults': defaults,
        'properties': properties.map((item) => item.toJson()).toList(),
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
  const StudioComponentRegistry();

  List<StudioComponentDescriptor> get components => _components;

  StudioComponentDescriptor? find(String type) {
    for (final component in _components) {
      if (component.type == type) return component;
    }
    return null;
  }

  List<Map<String, Object?>> toJson() =>
      _components.map((item) => item.toJson()).toList(growable: false);
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
    properties: [
      StudioPropertyDescriptor('label', 'string'),
      StudioPropertyDescriptor('hint', 'string'),
      StudioPropertyDescriptor('obscureText', 'boolean'),
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
