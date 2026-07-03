import 'package:widenote_core/widenote_core.dart';

final class AgentPackUiContributionDefinition {
  const AgentPackUiContributionDefinition({
    required this.id,
    required this.surface,
    required this.kind,
    required this.title,
    this.description,
    this.slot,
    this.placement,
    this.events = const <String>{},
    this.blocks = const <String>{},
    this.settingsSchemaRef,
    this.requiredPermissions = const <String>{},
  });

  final String id;
  final String surface;
  final String kind;
  final String title;
  final String? description;
  final String? slot;
  final String? placement;
  final Set<String> events;
  final Set<String> blocks;
  final String? settingsSchemaRef;
  final Set<String> requiredPermissions;
}

List<AgentPackUiContributionDefinition> parseAgentPackUiContributions(
  Object? value, {
  required String edition,
  required Set<String> packPermissions,
  required Set<String> declaredUiBlocks,
  required bool hasSettingsSchema,
}) {
  if (value == null) {
    return const <AgentPackUiContributionDefinition>[];
  }
  if (value is! List<Object?>) {
    throw const FormatException(
      'Manifest field ui_contributions must be an object array.',
    );
  }
  final contributions = <AgentPackUiContributionDefinition>[];
  final seenIds = <String>{};
  for (var index = 0; index < value.length; index += 1) {
    final path = 'ui_contributions[$index]';
    final json = _requiredJsonMap(
      value[index],
      'Manifest field $path must be an object.',
    );
    _rejectUnknownFields(json, path, _uiContributionKeys);
    final id = _requiredString(json, 'id');
    _expectPattern(id, '$path.id', _uiContributionIdPattern);
    if (!seenIds.add(id)) {
      throw FormatException(
        'Manifest field ui_contributions contains duplicate id: $id.',
      );
    }
    final surface = _requiredEnum(json, 'surface', _uiSurfaceValues);
    final kind = _requiredEnum(json, 'kind', _uiContributionKindValues);
    final title = _requiredString(json, 'title');
    final description = _optionalString(
      json,
      'description',
      '$path.description',
    );
    final slot = _optionalString(json, 'slot', '$path.slot');
    if (slot != null) {
      _expectPattern(slot, '$path.slot', _uiContributionIdPattern);
    }
    final placement = _optionalEnum(
      json,
      'placement',
      '$path.placement',
      _uiPlacementValues,
    );
    final events = _optionalStringSet(
      json['events'],
      '$path.events',
      pattern: _eventTypePattern,
    );
    final blocks = _optionalStringSet(json['blocks'], '$path.blocks');
    for (final block in blocks) {
      _requiredEnumValue(block, '$path.blocks', _uiBlockTypeValues);
    }
    final undeclaredBlocks = blocks
        .where((block) => !declaredUiBlocks.contains(block))
        .toList();
    if (undeclaredBlocks.isNotEmpty) {
      undeclaredBlocks.sort();
      throw FormatException(
        'Manifest field $path.blocks contains UI blocks not declared by pack: '
        '${undeclaredBlocks.join(', ')}.',
      );
    }
    final requiredPermissions = _optionalStringSet(
      json['required_permissions'],
      '$path.required_permissions',
      pattern: _permissionIdPattern,
    );
    final undeclaredPermissions = requiredPermissions
        .where((permission) => !packPermissions.contains(permission))
        .toList();
    if (undeclaredPermissions.isNotEmpty) {
      undeclaredPermissions.sort();
      throw FormatException(
        'Manifest field $path.required_permissions contains permissions not '
        'declared by pack: ${undeclaredPermissions.join(', ')}.',
      );
    }
    final settingsSchemaRef = _optionalString(
      json,
      'settings_schema_ref',
      '$path.settings_schema_ref',
    );
    _validateUiContributionCombination(
      path,
      edition: edition,
      surface: surface,
      kind: kind,
      events: events,
      blocks: blocks,
      settingsSchemaRef: settingsSchemaRef,
      hasSettingsSchema: hasSettingsSchema,
    );
    contributions.add(
      AgentPackUiContributionDefinition(
        id: id,
        surface: surface,
        kind: kind,
        title: title,
        description: description,
        slot: slot,
        placement: placement,
        events: events,
        blocks: blocks,
        settingsSchemaRef: settingsSchemaRef,
        requiredPermissions: requiredPermissions,
      ),
    );
  }
  return List<AgentPackUiContributionDefinition>.unmodifiable(contributions);
}

Set<String> validateAgentPackUiBlocks(Object? value) {
  if (value == null) {
    return const <String>{};
  }
  if (value is! List<Object?>) {
    throw const FormatException(
      'Manifest field ui_blocks must be an object array.',
    );
  }
  final declaredBlocks = <String>{};
  for (var index = 0; index < value.length; index += 1) {
    final json = _requiredJsonMap(
      value[index],
      'Manifest field ui_blocks[$index] must be an object.',
    );
    _rejectUnknownFields(json, 'ui_blocks[$index]', const <String>{
      'type',
      'events',
    });
    final type = _requiredString(json, 'type');
    _requiredEnumValue(type, 'ui_blocks[$index].type', _uiBlockTypeValues);
    declaredBlocks.add(type);
    _optionalStringSet(
      json['events'],
      'ui_blocks[$index].events',
      pattern: _eventTypePattern,
    );
  }
  return Set<String>.unmodifiable(declaredBlocks);
}

const Set<String> _uiContributionKeys = <String>{
  'id',
  'surface',
  'kind',
  'title',
  'description',
  'slot',
  'placement',
  'events',
  'blocks',
  'settings_schema_ref',
  'required_permissions',
};
const Set<String> _uiBlockTypeValues = <String>{
  'claim_list',
  'metric_row',
  'source_refs',
  'note',
  'evidence_list',
  'counter_evidence',
  'confidence_band',
  'contrast',
  'trend_chart',
  'timeline',
};
const Set<String> _uiSurfaceValues = <String>{
  'home.summary',
  'capture.sheet.accessory',
  'timeline.card.accessory',
  'timeline.item.detail',
  'memory.item.detail',
  'insight.detail',
  'artifact.detail',
  'chat.tool_result',
  'todo.detail',
  'plugins.pack_home',
  'settings.pack_detail',
  'bottom_tab',
};
const Set<String> _uiContributionKindValues = <String>{
  'settings_form',
  'panel',
  'event_blocks',
  'action',
  'inline_status',
  'bottom_tab',
};
const Set<String> _uiPlacementValues = <String>{
  'section',
  'inline',
  'primary_action',
  'secondary_action',
  'tab',
};
const Set<String> _navigationUiAllowedEditions = <String>{
  'official',
  'local_dev',
};

final RegExp _uiContributionIdPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
);
final RegExp _permissionIdPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
);
final RegExp _eventTypePattern = RegExp(
  r'^wn\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$',
);

void _validateUiContributionCombination(
  String path, {
  required String edition,
  required String surface,
  required String kind,
  required Set<String> events,
  required Set<String> blocks,
  required String? settingsSchemaRef,
  required bool hasSettingsSchema,
}) {
  if (kind == 'event_blocks' && (events.isEmpty || blocks.isEmpty)) {
    throw FormatException(
      'Manifest field $path must declare events and blocks for event_blocks.',
    );
  }
  if (kind == 'settings_form' && settingsSchemaRef == null) {
    throw FormatException(
      'Manifest field $path.settings_schema_ref is required for settings_form.',
    );
  }
  if (kind == 'settings_form' &&
      settingsSchemaRef == '#/settings_schema' &&
      !hasSettingsSchema) {
    throw FormatException(
      'Manifest field $path.settings_schema_ref references missing '
      'settings_schema.',
    );
  }
  if ((kind == 'bottom_tab' || surface == 'bottom_tab') &&
      (kind != 'bottom_tab' || surface != 'bottom_tab')) {
    throw FormatException(
      'Manifest field $path must pair bottom_tab surface with bottom_tab kind.',
    );
  }
  if (surface == 'bottom_tab' &&
      !_navigationUiAllowedEditions.contains(edition)) {
    throw FormatException(
      'Manifest field $path bottom_tab is reserved for official or local_dev '
      'packs in this slice.',
    );
  }
}

String _requiredString(JsonMap json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Manifest field $key must be a non-empty string.');
}

String? _optionalString(JsonMap json, String key, String path) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Manifest field $path must be null or a string.');
}

String _requiredEnum(JsonMap json, String key, Set<String> values) {
  final value = _requiredString(json, key);
  _requiredEnumValue(value, key, values);
  return value;
}

String? _optionalEnum(
  JsonMap json,
  String key,
  String path,
  Set<String> values,
) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = _optionalString(json, key, path);
  if (value == null || values.contains(value)) {
    return value;
  }
  throw FormatException(
    'Manifest field $path must be one of ${_formatSet(values)}.',
  );
}

void _requiredEnumValue(String value, String path, Set<String> values) {
  if (values.contains(value)) {
    return;
  }
  throw FormatException(
    'Manifest field $path must be one of ${_formatSet(values)}.',
  );
}

Set<String> _optionalStringSet(
  Object? value,
  String path, {
  int minItems = 0,
  RegExp? pattern,
}) {
  if (value == null) {
    return const <String>{};
  }
  return _stringSet(value, path, minItems: minItems, pattern: pattern);
}

Set<String> _stringSet(
  Object? value,
  String path, {
  int minItems = 0,
  RegExp? pattern,
}) {
  if (value is! List<Object?>) {
    throw FormatException('Manifest field $path must be a string array.');
  }
  final result = <String>{};
  for (var index = 0; index < value.length; index += 1) {
    final entry = value[index];
    if (entry is! String || entry.isEmpty) {
      throw FormatException(
        'Manifest field $path[$index] must be a non-empty string.',
      );
    }
    if (pattern != null) {
      _expectPattern(entry, '$path[$index]', pattern);
    }
    if (!result.add(entry)) {
      throw FormatException(
        'Manifest field $path must not contain duplicates: $entry.',
      );
    }
  }
  if (result.length < minItems) {
    throw FormatException(
      'Manifest field $path must contain at least $minItems item(s).',
    );
  }
  return Set<String>.unmodifiable(result);
}

void _rejectUnknownFields(JsonMap json, String path, Set<String> allowedKeys) {
  final unknown = json.keys.where((key) => !allowedKeys.contains(key)).toList();
  if (unknown.isEmpty) {
    return;
  }
  unknown.sort();
  throw FormatException(
    'Manifest field $path contains unsupported keys: ${unknown.join(', ')}.',
  );
}

void _expectPattern(String value, String path, RegExp pattern) {
  if (pattern.hasMatch(value)) {
    return;
  }
  throw FormatException('Manifest field $path has invalid value: $value.');
}

String _formatSet(Set<String> values) {
  final sorted = values.toList()..sort();
  return '[${sorted.join(', ')}]';
}

JsonMap _requiredJsonMap(Object? value, String message) {
  final json = _asJsonMap(value, message);
  if (json == null) {
    throw FormatException(message);
  }
  return json;
}

JsonMap? _asJsonMap(Object? value, String message) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, entry) {
        if (key is! String) {
          throw FormatException(message);
        }
        return MapEntry<String, Object?>(key, entry);
      }),
    );
  }
  return null;
}
