import 'package:widenote_core/widenote_core.dart';

import 'event.dart';
import 'model.dart';
import 'task.dart';

enum AgentRuntimeKind { native, declarative, remote, script }

final class AgentDefinition {
  const AgentDefinition({
    required this.id,
    this.runtimeKind = AgentRuntimeKind.native,
    this.requiredPermissions = const <String>{},
    this.outputEvents = const <String>{},
    this.tools = const <String>{},
    this.retryPolicy = const RetryPolicy(),
    this.modelProfileRef,
  });

  final String id;
  final AgentRuntimeKind runtimeKind;
  final Set<String> requiredPermissions;
  final Set<String> outputEvents;
  final Set<String> tools;
  final RetryPolicy retryPolicy;
  final String? modelProfileRef;
}

final class Subscription {
  const Subscription({
    required this.id,
    required this.agentId,
    required this.eventTypes,
    this.dependsOn = const <String>{},
  });

  final String id;
  final String agentId;
  final Set<String> eventTypes;
  final Set<String> dependsOn;

  bool matches(WnEvent event) => eventTypes.contains(event.type);
}

final class AgentPack {
  const AgentPack({
    required this.id,
    required this.name,
    required this.version,
    required this.subscriptions,
    required this.agents,
    this.requiredPermissions = const <String>{},
    this.agentDefinitions = const <String, AgentDefinition>{},
  });

  final String id;
  final String name;
  final String version;
  final List<Subscription> subscriptions;
  final Map<String, AgentHandler> agents;
  final Set<String> requiredPermissions;
  final Map<String, AgentDefinition> agentDefinitions;

  AgentHandler? handlerFor(String agentId) => agents[agentId];

  AgentDefinition definitionFor(String agentId) {
    return agentDefinitions[agentId] ??
        AgentDefinition(id: agentId, requiredPermissions: requiredPermissions);
  }

  AgentPackAlignmentReport checkManifestAlignment(
    AgentPackManifestSnapshot manifest,
  ) {
    final issues = <AgentPackAlignmentIssue>[];
    _expectEqual(issues, 'id', id, manifest.id);
    _expectEqual(issues, 'name', name, manifest.name);
    _expectEqual(issues, 'version', version, manifest.version);
    _expectSetEqual(
      issues,
      'permissions',
      requiredPermissions,
      manifest.requiredPermissions,
    );
    _compareSubscriptions(issues, subscriptions, manifest.subscriptions);
    _compareAgents(issues, this, manifest.agentDefinitions);
    _compareOfficialGuardrails(issues, this, manifest);
    return AgentPackAlignmentReport(packId: manifest.id, issues: issues);
  }
}

abstract interface class PackRegistry {
  void register(AgentPack pack);
  void unregister(String packId);
  AgentPack? lookup(String packId);
  List<AgentPack> list();
  AgentPackAlignmentReport checkManifestAlignment(
    AgentPackManifestSnapshot manifest,
  );
}

final class InMemoryPackRegistry implements PackRegistry {
  final Map<String, AgentPack> _packs = <String, AgentPack>{};

  @override
  void register(AgentPack pack) {
    _packs[pack.id] = pack;
  }

  @override
  void unregister(String packId) {
    _packs.remove(packId);
  }

  @override
  AgentPack? lookup(String packId) => _packs[packId];

  @override
  List<AgentPack> list() {
    return List<AgentPack>.unmodifiable(_packs.values);
  }

  @override
  AgentPackAlignmentReport checkManifestAlignment(
    AgentPackManifestSnapshot manifest,
  ) {
    final pack = lookup(manifest.id);
    if (pack == null) {
      return AgentPackAlignmentReport(
        packId: manifest.id,
        issues: <AgentPackAlignmentIssue>[
          AgentPackAlignmentIssue(
            path: 'id',
            message: 'No native pack is registered for ${manifest.id}.',
          ),
        ],
      );
    }
    return pack.checkManifestAlignment(manifest);
  }
}

final class AgentPackManifestSnapshot {
  const AgentPackManifestSnapshot({
    required this.id,
    required this.name,
    required this.version,
    required this.schemaVersion,
    required this.publisher,
    required this.edition,
    required this.requiredPermissions,
    required this.subscriptions,
    required this.agentDefinitions,
  });

  factory AgentPackManifestSnapshot.fromJson(JsonMap json) {
    _rejectUnknownFields(json, 'manifest', _manifestKeys);
    final id = _requiredString(json, 'id');
    _expectPattern(id, 'id', _packIdPattern);
    final name = _requiredString(json, 'name');
    final version = _requiredString(json, 'version');
    _expectPattern(version, 'version', _semverPattern);
    final schemaVersion = _requiredInt(json, 'schema_version', min: 1);
    if (schemaVersion != 1) {
      throw FormatException(
        'Manifest field schema_version has unsupported value: $schemaVersion.',
      );
    }
    _optionalString(json, r'$schema', r'$schema');
    final publisher = _requiredString(json, 'publisher');
    final edition = _requiredEnum(json, 'edition', _editionValues);
    _optionalString(json, 'description', 'description');
    _validateCompatibility(json['compatibility']);
    if (json.containsKey('entrypoint_kind')) {
      _runtimeKindAt(json['entrypoint_kind'], 'entrypoint_kind');
    }
    final requiredPermissions = _requiredStringSet(
      json,
      'permissions',
      pattern: _permissionIdPattern,
    );
    final subscriptions = _subscriptionList(json['subscriptions']);
    final agentDefinitions = _agentDefinitions(json['agents']);
    final modelProfileIds = _modelProfileIds(json['model_profiles']);
    final toolIds = _validateToolDefinitions(
      json['tools'],
      packPermissions: requiredPermissions,
    );
    _validateUiBlocks(json['ui_blocks']);
    _validateOpenObject(json['settings_schema'], 'settings_schema');
    _validateOpenObject(json['secrets_schema'], 'secrets_schema');
    _validateStorageQuota(json['storage_quota']);
    _validateIntegrity(json['integrity']);
    _validateOpenObject(json['metadata'], 'metadata');
    _validateReferences(
      subscriptions: subscriptions,
      agentDefinitions: agentDefinitions,
      modelProfileIds: modelProfileIds,
      toolIds: toolIds,
      packPermissions: requiredPermissions,
    );
    return AgentPackManifestSnapshot(
      id: id,
      name: name,
      version: version,
      schemaVersion: schemaVersion,
      publisher: publisher,
      edition: edition,
      requiredPermissions: requiredPermissions,
      subscriptions: subscriptions,
      agentDefinitions: agentDefinitions,
    );
  }

  final String id;
  final String name;
  final String version;
  final int schemaVersion;
  final String publisher;
  final String edition;
  final Set<String> requiredPermissions;
  final List<Subscription> subscriptions;
  final Map<String, AgentDefinition> agentDefinitions;
}

final class AgentPackAlignmentIssue {
  const AgentPackAlignmentIssue({required this.path, required this.message});

  final String path;
  final String message;
}

final class AgentPackAlignmentReport {
  const AgentPackAlignmentReport({required this.packId, required this.issues});

  final String packId;
  final List<AgentPackAlignmentIssue> issues;

  bool get isAligned => issues.isEmpty;
}

void _compareSubscriptions(
  List<AgentPackAlignmentIssue> issues,
  List<Subscription> nativeSubscriptions,
  List<Subscription> manifestSubscriptions,
) {
  final nativeById = <String, Subscription>{
    for (final subscription in nativeSubscriptions)
      subscription.id: subscription,
  };
  final manifestById = <String, Subscription>{
    for (final subscription in manifestSubscriptions)
      subscription.id: subscription,
  };
  _expectSetEqual(
    issues,
    'subscriptions',
    nativeById.keys.toSet(),
    manifestById.keys.toSet(),
  );
  for (final entry in manifestById.entries) {
    final native = nativeById[entry.key];
    if (native == null) {
      continue;
    }
    final path = 'subscriptions.${entry.key}';
    final manifest = entry.value;
    _expectEqual(issues, '$path.agent_id', native.agentId, manifest.agentId);
    _expectSetEqual(
      issues,
      '$path.event_types',
      native.eventTypes,
      manifest.eventTypes,
    );
    _expectSetEqual(
      issues,
      '$path.depends_on',
      native.dependsOn,
      manifest.dependsOn,
    );
  }
}

void _compareAgents(
  List<AgentPackAlignmentIssue> issues,
  AgentPack pack,
  Map<String, AgentDefinition> manifestDefinitions,
) {
  final nativeAgentIds = <String>{
    ...pack.agents.keys,
    ...pack.agentDefinitions.keys,
  };
  _expectSetEqual(
    issues,
    'agents',
    nativeAgentIds,
    manifestDefinitions.keys.toSet(),
  );
  for (final entry in manifestDefinitions.entries) {
    final native = pack.definitionFor(entry.key);
    final manifest = entry.value;
    final path = 'agents.${entry.key}';
    if (!pack.agents.containsKey(entry.key) &&
        manifest.runtimeKind == AgentRuntimeKind.native) {
      issues.add(
        AgentPackAlignmentIssue(
          path: '$path.handler',
          message: 'Native agent handler is not registered.',
        ),
      );
    }
    _expectEqual(
      issues,
      '$path.runtime',
      native.runtimeKind.name,
      manifest.runtimeKind.name,
    );
    _expectSetEqual(
      issues,
      '$path.permissions',
      native.requiredPermissions,
      manifest.requiredPermissions,
    );
    _expectSetEqual(
      issues,
      '$path.output_events',
      native.outputEvents,
      manifest.outputEvents,
    );
    _expectSetEqual(issues, '$path.tools', native.tools, manifest.tools);
    _expectEqual(
      issues,
      '$path.retry_policy.max_attempts',
      native.retryPolicy.normalizedMaxAttempts,
      manifest.retryPolicy.normalizedMaxAttempts,
    );
    _expectEqual(
      issues,
      '$path.model_profile_ref',
      native.modelProfileRef,
      manifest.modelProfileRef,
    );
  }
}

void _compareOfficialGuardrails(
  List<AgentPackAlignmentIssue> issues,
  AgentPack pack,
  AgentPackManifestSnapshot manifest,
) {
  if (manifest.id == 'pack.default') {
    _expectAbsent(issues, 'pack.default.permissions', {
      ...pack.requiredPermissions,
      ...manifest.requiredPermissions,
    }, 'todo.suggest');
    _expectAbsent(issues, 'pack.default.output_events', {
      ..._nativeOutputEvents(pack),
      ..._manifestOutputEvents(manifest),
    }, WnEventTypes.todoSuggested);
  }

  if (manifest.id == 'pack.todo') {
    _expectSetEqual(
      issues,
      'pack.todo.permissions',
      pack.requiredPermissions,
      const <String>{'todo.suggest'},
    );
    _expectSetEqual(
      issues,
      'pack.todo.manifest_permissions',
      manifest.requiredPermissions,
      const <String>{'todo.suggest'},
    );
    _expectSetEqual(
      issues,
      'pack.todo.output_events',
      _nativeOutputEvents(pack),
      const <String>{WnEventTypes.todoSuggested},
    );
    _expectSetEqual(
      issues,
      'pack.todo.manifest_output_events',
      _manifestOutputEvents(manifest),
      const <String>{WnEventTypes.todoSuggested},
    );
  }
}

Set<String> _nativeOutputEvents(AgentPack pack) {
  return Set<String>.unmodifiable(
    pack.agentDefinitions.values.expand(
      (definition) => definition.outputEvents,
    ),
  );
}

Set<String> _manifestOutputEvents(AgentPackManifestSnapshot manifest) {
  return Set<String>.unmodifiable(
    manifest.agentDefinitions.values.expand(
      (definition) => definition.outputEvents,
    ),
  );
}

void _expectAbsent(
  List<AgentPackAlignmentIssue> issues,
  String path,
  Set<String> values,
  String disallowed,
) {
  if (!values.contains(disallowed)) {
    return;
  }
  issues.add(
    AgentPackAlignmentIssue(
      path: path,
      message: 'Disallowed phase-one value declared: $disallowed.',
    ),
  );
}

void _expectEqual<T>(
  List<AgentPackAlignmentIssue> issues,
  String path,
  T native,
  T manifest,
) {
  if (native == manifest) {
    return;
  }
  issues.add(
    AgentPackAlignmentIssue(
      path: path,
      message: 'Native value "$native" does not match manifest "$manifest".',
    ),
  );
}

void _expectSetEqual(
  List<AgentPackAlignmentIssue> issues,
  String path,
  Set<String> native,
  Set<String> manifest,
) {
  if (_setEquals(native, manifest)) {
    return;
  }
  issues.add(
    AgentPackAlignmentIssue(
      path: path,
      message:
          'Native values ${_formatSet(native)} do not match manifest '
          '${_formatSet(manifest)}.',
    ),
  );
}

bool _setEquals(Set<String> left, Set<String> right) {
  return left.length == right.length && left.containsAll(right);
}

String _formatSet(Set<String> values) {
  final sorted = values.toList()..sort();
  return '[${sorted.join(', ')}]';
}

final RegExp _packIdPattern = RegExp(
  r'^pack\.[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$',
);
final RegExp _agentIdPattern = RegExp(
  r'^agent\.[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$',
);
final RegExp _subscriptionIdPattern = RegExp(
  r'^sub\.[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$',
);
final RegExp _permissionIdPattern = RegExp(
  r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
);
final RegExp _eventTypePattern = RegExp(
  r'^wn\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$',
);
final RegExp _semverPattern = RegExp(
  r'^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$',
);

const Set<String> _manifestKeys = <String>{
  r'$schema',
  'id',
  'name',
  'version',
  'schema_version',
  'publisher',
  'edition',
  'description',
  'compatibility',
  'entrypoint_kind',
  'permissions',
  'subscriptions',
  'agents',
  'model_profiles',
  'tools',
  'ui_blocks',
  'settings_schema',
  'secrets_schema',
  'storage_quota',
  'integrity',
  'metadata',
};
const Set<String> _subscriptionKeys = <String>{
  'id',
  'event_types',
  'agent_id',
  'delivery',
  'enabled_by_default',
  'depends_on',
};
const Set<String> _agentKeys = <String>{
  'id',
  'runtime',
  'name',
  'prompt_ref',
  'model_profile_ref',
  'permissions',
  'tools',
  'output_events',
  'retry_policy',
};
const Set<String> _retryPolicyKeys = <String>{'max_attempts'};
const Set<String> _toolKeys = <String>{'id', 'permissions', 'side_effect'};
const Set<String> _modelProfileKeys = <String>{
  'id',
  'purpose',
  'required',
  'routing_policy',
  'provider_ref',
  'model_ref',
  'required_capabilities',
  'allow_fallback',
};
const Set<String> _editionValues = <String>{
  'official',
  'store',
  'community',
  'local_dev',
};
const Set<String> _deliveryValues = <String>{'async', 'sync'};
const Set<String> _sideEffectValues = <String>{
  'none',
  'local_write',
  'external_write',
  'network',
  'model_call',
  'file_access',
  'script_execution',
};
const Set<String> _routingPolicyValues = <String>{
  'app_default',
  'user_selected',
  'pack_preferred',
  'fixed_provider',
};
const Set<String> _modelCapabilityValues = <String>{
  'chat',
  'completion',
  'embedding',
  'vision',
  'audio',
  'streaming',
  'tool_use',
  'toolUse',
};

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

int _requiredInt(JsonMap json, String key, {int? min, int? max}) {
  final value = json[key];
  if (value is int &&
      (min == null || value >= min) &&
      (max == null || value <= max)) {
    return value;
  }
  final range = switch ((min, max)) {
    (final int lower, final int upper) => ' between $lower and $upper',
    (final int lower, null) => ' greater than or equal to $lower',
    (null, final int upper) => ' less than or equal to $upper',
    (null, null) => '',
  };
  throw FormatException('Manifest field $key must be an integer$range.');
}

String _requiredEnum(JsonMap json, String key, Set<String> values) {
  final value = _requiredString(json, key);
  if (values.contains(value)) {
    return value;
  }
  throw FormatException(
    'Manifest field $key must be one of ${_formatSet(values)}.',
  );
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

void _expectPattern(String value, String path, RegExp pattern) {
  if (pattern.hasMatch(value)) {
    return;
  }
  throw FormatException('Manifest field $path has invalid value: $value.');
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

Set<String> _requiredStringSet(
  JsonMap json,
  String key, {
  int minItems = 0,
  RegExp? pattern,
}) {
  if (!json.containsKey(key)) {
    throw FormatException('Manifest field $key is required.');
  }
  return _stringSet(json[key], key, minItems: minItems, pattern: pattern);
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

List<Subscription> _subscriptionList(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException(
      'Manifest field subscriptions must be an object array.',
    );
  }
  final seenIds = <String>{};
  final subscriptions = <Subscription>[];
  for (var index = 0; index < value.length; index += 1) {
    final json = _requiredJsonMap(
      value[index],
      'Manifest field subscriptions[$index] must be an object.',
    );
    _rejectUnknownFields(json, 'subscriptions[$index]', _subscriptionKeys);
    final id = _requiredString(json, 'id');
    _expectPattern(id, 'subscriptions[$index].id', _subscriptionIdPattern);
    if (!seenIds.add(id)) {
      throw FormatException(
        'Manifest field subscriptions contains duplicate id: $id.',
      );
    }
    final agentId = _requiredString(json, 'agent_id');
    _expectPattern(agentId, 'subscriptions.$id.agent_id', _agentIdPattern);
    _optionalEnum(
      json,
      'delivery',
      'subscriptions.$id.delivery',
      _deliveryValues,
    );
    _optionalBool(
      json,
      'enabled_by_default',
      'subscriptions.$id.enabled_by_default',
    );
    subscriptions.add(
      Subscription(
        id: id,
        agentId: agentId,
        eventTypes: _requiredStringSet(
          json,
          'event_types',
          minItems: 1,
          pattern: _eventTypePattern,
        ),
        dependsOn: _optionalStringSet(
          json['depends_on'],
          'subscriptions.$id.depends_on',
          pattern: _subscriptionIdPattern,
        ),
      ),
    );
  }
  return List<Subscription>.unmodifiable(subscriptions);
}

Map<String, AgentDefinition> _agentDefinitions(Object? value) {
  if (value is! List<Object?>) {
    throw const FormatException(
      'Manifest field agents must be an object array.',
    );
  }
  final agents = <String, AgentDefinition>{};
  for (var index = 0; index < value.length; index += 1) {
    final json = _requiredJsonMap(
      value[index],
      'Manifest field agents[$index] must be an object.',
    );
    _rejectUnknownFields(json, 'agents[$index]', _agentKeys);
    final agent = _agentDefinition(json, index);
    if (agents.containsKey(agent.id)) {
      throw FormatException(
        'Manifest field agents contains duplicate id: ${agent.id}.',
      );
    }
    agents[agent.id] = agent;
  }
  return Map<String, AgentDefinition>.unmodifiable(agents);
}

AgentDefinition _agentDefinition(JsonMap json, int index) {
  final id = _requiredString(json, 'id');
  _expectPattern(id, 'agents[$index].id', _agentIdPattern);
  _optionalString(json, 'name', 'agents.$id.name');
  _optionalString(json, 'prompt_ref', 'agents.$id.prompt_ref');
  return AgentDefinition(
    id: id,
    runtimeKind: _runtimeKindAt(json['runtime'], 'agents.$id.runtime'),
    requiredPermissions: _optionalStringSet(
      json['permissions'],
      'agents.$id.permissions',
      pattern: _permissionIdPattern,
    ),
    outputEvents: _requiredStringSet(
      json,
      'output_events',
      minItems: 1,
      pattern: _eventTypePattern,
    ),
    tools: _optionalStringSet(json['tools'], 'agents.$id.tools'),
    retryPolicy: RetryPolicy(
      maxAttempts: _maxAttempts(
        json['retry_policy'],
        'agents.$id.retry_policy',
      ),
    ),
    modelProfileRef: _optionalString(
      json,
      'model_profile_ref',
      'agents.$id.model_profile_ref',
    ),
  );
}

AgentRuntimeKind _runtimeKindAt(Object? value, String path) {
  if (value is! String) {
    throw FormatException('Manifest field $path must be a string.');
  }
  return AgentRuntimeKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => throw FormatException(
      'Manifest field $path has unsupported value: $value.',
    ),
  );
}

int _maxAttempts(Object? value, String path) {
  if (value == null) {
    return 1;
  }
  final json = _requiredJsonMap(
    value,
    'Manifest field $path must be an object.',
  );
  _rejectUnknownFields(json, path, _retryPolicyKeys);
  final maxAttempts = json['max_attempts'];
  if (maxAttempts == null) {
    throw FormatException(
      'Manifest field $path.max_attempts is required when retry_policy is set.',
    );
  }
  if (maxAttempts is int && maxAttempts >= 1 && maxAttempts <= 5) {
    return maxAttempts;
  }
  throw FormatException(
    'Manifest field $path.max_attempts must be an integer between 1 and 5.',
  );
}

void _optionalBool(JsonMap json, String key, String path) {
  if (!json.containsKey(key) || json[key] == null) {
    return;
  }
  if (json[key] is bool) {
    return;
  }
  throw FormatException('Manifest field $path must be a boolean.');
}

void _validateCompatibility(Object? value) {
  if (value == null) {
    return;
  }
  final json = _requiredJsonMap(
    value,
    'Manifest field compatibility must be an object.',
  );
  _rejectUnknownFields(json, 'compatibility', const <String>{
    'widenote_min',
    'widenote_max',
    'schema_version',
  });
  _optionalString(json, 'widenote_min', 'compatibility.widenote_min');
  _optionalString(json, 'widenote_max', 'compatibility.widenote_max');
  if (json.containsKey('schema_version')) {
    _requiredInt(json, 'schema_version', min: 1);
  }
}

void _validateUiBlocks(Object? value) {
  if (value == null) {
    return;
  }
  if (value is! List<Object?>) {
    throw const FormatException(
      'Manifest field ui_blocks must be an object array.',
    );
  }
  for (var index = 0; index < value.length; index += 1) {
    final json = _requiredJsonMap(
      value[index],
      'Manifest field ui_blocks[$index] must be an object.',
    );
    _rejectUnknownFields(json, 'ui_blocks[$index]', const <String>{
      'type',
      'events',
    });
    _requiredString(json, 'type');
    _optionalStringSet(
      json['events'],
      'ui_blocks[$index].events',
      pattern: _eventTypePattern,
    );
  }
}

void _validateStorageQuota(Object? value) {
  if (value == null) {
    return;
  }
  final json = _requiredJsonMap(
    value,
    'Manifest field storage_quota must be an object.',
  );
  _rejectUnknownFields(json, 'storage_quota', const <String>{'local_bytes'});
  if (json.containsKey('local_bytes')) {
    _requiredInt(json, 'local_bytes', min: 0);
  }
}

void _validateIntegrity(Object? value) {
  if (value == null) {
    return;
  }
  final json = _requiredJsonMap(
    value,
    'Manifest field integrity must be an object.',
  );
  _rejectUnknownFields(json, 'integrity', const <String>{
    'checksum_sha256',
    'signature',
  });
  _optionalString(json, 'checksum_sha256', 'integrity.checksum_sha256');
  _optionalString(json, 'signature', 'integrity.signature');
}

void _validateOpenObject(Object? value, String path) {
  if (value == null) {
    return;
  }
  _requiredJsonMap(value, 'Manifest field $path must be an object.');
}

Set<String> _modelProfileIds(Object? value) {
  if (value == null) {
    return const <String>{};
  }
  if (value is! List<Object?>) {
    throw const FormatException(
      'Manifest field model_profiles must be an object array.',
    );
  }
  final ids = <String>{};
  for (var index = 0; index < value.length; index += 1) {
    final json = _requiredJsonMap(
      value[index],
      'Manifest field model_profiles[$index] must be an object.',
    );
    _rejectUnknownFields(json, 'model_profiles[$index]', _modelProfileKeys);
    final id = _requiredString(json, 'id');
    if (!ids.add(id)) {
      throw FormatException(
        'Manifest field model_profiles contains duplicate id: $id.',
      );
    }
    _requiredString(json, 'purpose');
    _optionalBool(json, 'required', 'model_profiles.$id.required');
    _optionalEnum(
      json,
      'routing_policy',
      'model_profiles.$id.routing_policy',
      _routingPolicyValues,
    );
    _optionalString(json, 'provider_ref', 'model_profiles.$id.provider_ref');
    _optionalString(json, 'model_ref', 'model_profiles.$id.model_ref');
    _optionalStringSet(
      json['required_capabilities'],
      'model_profiles.$id.required_capabilities',
    ).difference(_modelCapabilityValues).forEach((capability) {
      throw FormatException(
        'Manifest field model_profiles.$id.required_capabilities has '
        'unsupported value: $capability.',
      );
    });
    _optionalBool(json, 'allow_fallback', 'model_profiles.$id.allow_fallback');
  }
  return Set<String>.unmodifiable(ids);
}

Set<String> _validateToolDefinitions(
  Object? value, {
  required Set<String> packPermissions,
}) {
  if (value == null) {
    return const <String>{};
  }
  if (value is! List<Object?>) {
    throw const FormatException(
      'Manifest field tools must be an object array.',
    );
  }
  final ids = <String>{};
  for (var index = 0; index < value.length; index += 1) {
    final json = _requiredJsonMap(
      value[index],
      'Manifest field tools[$index] must be an object.',
    );
    _rejectUnknownFields(json, 'tools[$index]', _toolKeys);
    final id = _requiredString(json, 'id');
    if (!ids.add(id)) {
      throw FormatException('Manifest field tools contains duplicate id: $id.');
    }
    final permissions = _requiredStringSet(
      json,
      'permissions',
      pattern: _permissionIdPattern,
    );
    final undeclaredPermissions = permissions.difference(packPermissions);
    if (undeclaredPermissions.isNotEmpty) {
      throw FormatException(
        'Manifest field tools.$id.permissions contains permissions not '
        'declared by the pack: ${_formatSet(undeclaredPermissions)}.',
      );
    }
    _optionalEnum(
      json,
      'side_effect',
      'tools.$id.side_effect',
      _sideEffectValues,
    );
  }
  return Set<String>.unmodifiable(ids);
}

void _validateReferences({
  required List<Subscription> subscriptions,
  required Map<String, AgentDefinition> agentDefinitions,
  required Set<String> modelProfileIds,
  required Set<String> toolIds,
  required Set<String> packPermissions,
}) {
  final subscriptionIds = subscriptions
      .map((subscription) => subscription.id)
      .toSet();
  for (final subscription in subscriptions) {
    if (!agentDefinitions.containsKey(subscription.agentId)) {
      throw FormatException(
        'Manifest field subscriptions.${subscription.id}.agent_id references '
        'unknown agent: ${subscription.agentId}.',
      );
    }
    for (final dependency in subscription.dependsOn) {
      if (dependency == subscription.id) {
        throw FormatException(
          'Manifest field subscriptions.${subscription.id}.depends_on '
          'must not reference itself.',
        );
      }
      if (!subscriptionIds.contains(dependency)) {
        throw FormatException(
          'Manifest field subscriptions.${subscription.id}.depends_on '
          'references unknown subscription: $dependency.',
        );
      }
    }
  }
  _validateSubscriptionCycles(subscriptions);

  for (final definition in agentDefinitions.values) {
    final undeclaredPermissions = definition.requiredPermissions.difference(
      packPermissions,
    );
    if (undeclaredPermissions.isNotEmpty) {
      throw FormatException(
        'Manifest field agents.${definition.id}.permissions contains '
        'permissions not declared by the pack: '
        '${_formatSet(undeclaredPermissions)}.',
      );
    }
    for (final tool in definition.tools) {
      if (!toolIds.contains(tool)) {
        throw FormatException(
          'Manifest field agents.${definition.id}.tools references unknown '
          'tool: $tool.',
        );
      }
    }
    final modelProfileRef = definition.modelProfileRef;
    if (modelProfileRef != null && !modelProfileIds.contains(modelProfileRef)) {
      throw FormatException(
        'Manifest field agents.${definition.id}.model_profile_ref references '
        'unknown model profile: $modelProfileRef.',
      );
    }
  }
}

void _validateSubscriptionCycles(List<Subscription> subscriptions) {
  final byId = <String, Subscription>{
    for (final subscription in subscriptions) subscription.id: subscription,
  };
  final visiting = <String>{};
  final visited = <String>{};

  void visit(String id, List<String> path) {
    if (visited.contains(id)) {
      return;
    }
    if (!visiting.add(id)) {
      throw FormatException(
        'Manifest field subscriptions contains depends_on cycle: '
        '${[...path, id].join(' -> ')}.',
      );
    }
    final subscription = byId[id];
    if (subscription != null) {
      for (final dependency in subscription.dependsOn) {
        visit(dependency, <String>[...path, id]);
      }
    }
    visiting.remove(id);
    visited.add(id);
  }

  for (final id in byId.keys) {
    visit(id, const <String>[]);
  }
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
