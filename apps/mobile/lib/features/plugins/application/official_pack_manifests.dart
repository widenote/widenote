import 'dart:convert';

import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

const officialPackManifestIds = <String>[
  'pack.default',
  'pack.todo',
  'pack.pkm_library',
];

const officialPackManifestMaps = <String, Map<String, Object?>>{
  'pack.default': <String, Object?>{
    r'$schema':
        '../../../packages/schemas/src/agent_pack/agent_pack_manifest.schema.json',
    'id': 'pack.default',
    'name': 'Default Capture Loop',
    'version': '0.1.0',
    'schema_version': 1,
    'publisher': 'widenote',
    'edition': 'official',
    'description':
        'Conservative built-in pack for capture cards, Memory candidates, and lightweight insight.',
    'compatibility': <String, Object?>{
      'widenote_min': '0.1.0',
      'widenote_max': null,
      'schema_version': 1,
    },
    'marketplace': <String, Object?>{
      'source': 'bundled',
      'trust_level': 'official',
      'install_mode': 'bundled',
      'repository_url': 'https://github.com/widenote/widenote',
      'docs_path': 'packs/official/default/README.md',
      'icon_path': null,
      'categories': <String>['capture', 'memory'],
      'capabilities': <String>['memory.propose', 'card.write', 'insight.write'],
      'status': 'available',
    },
    'default_run_mode': 'auto',
    'entrypoint_kind': 'native',
    'permissions': <String>[
      'model.complete',
      'card.write',
      'memory.propose',
      'insight.write',
      'context_packet.build',
      'memory.read',
      'timeline.read',
      'knowledge.read',
      'semantic_search.query',
    ],
    'subscriptions': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'sub.capture_created',
        'event_types': <String>['wn.capture.created'],
        'agent_id': 'agent.capture_loop',
        'delivery': 'async',
        'enabled_by_default': true,
      },
    ],
    'agents': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'agent.capture_loop',
        'runtime': 'native',
        'run_mode': 'auto',
        'name': 'Capture Loop Agent',
        'prompt_ref': 'capture.memory_candidate.v2',
        'model_profile_ref': 'local_or_user_selected_model',
        'permissions': <String>[
          'model.complete',
          'card.write',
          'memory.propose',
          'insight.write',
          'context_packet.build',
          'memory.read',
          'timeline.read',
          'knowledge.read',
          'semantic_search.query',
        ],
        'tools': <String>[
          'context_packet.build',
          'memory.read',
          'timeline.read',
          'knowledge.read',
          'semantic_search.query',
        ],
        'output_events': <String>[
          'wn.card.created',
          'wn.memory.proposed',
          'wn.insight.created',
        ],
        'retry_policy': <String, Object?>{'max_attempts': 2},
      },
    ],
    'model_profiles': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'local_or_user_selected_model',
        'purpose':
            'Summarize captures into cards, Memory candidates, and lightweight insights.',
        'required': false,
      },
    ],
    'tools': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'context_packet.build',
        'capability_kind': 'context_packet',
        'permissions': <String>['context_packet.build'],
        'required_permissions': <String>['context_packet.build'],
        'access': 'read',
        'risk': 'low',
        'locality': 'local',
        'approval_requirement': 'none',
        'execution': 'local',
        'side_effect': 'none',
        'compatible_run_modes': <String>['read_only', 'confirm', 'auto'],
      },
      <String, Object?>{
        'id': 'memory.read',
        'capability_kind': 'memory',
        'permissions': <String>['memory.read'],
        'required_permissions': <String>['memory.read'],
        'access': 'read',
        'risk': 'low',
        'locality': 'local',
        'approval_requirement': 'none',
        'execution': 'local',
        'side_effect': 'none',
        'compatible_run_modes': <String>['read_only', 'confirm', 'auto'],
      },
      <String, Object?>{
        'id': 'timeline.read',
        'capability_kind': 'local_core',
        'permissions': <String>['timeline.read'],
        'required_permissions': <String>['timeline.read'],
        'access': 'read',
        'risk': 'low',
        'locality': 'local',
        'approval_requirement': 'none',
        'execution': 'local',
        'side_effect': 'none',
        'compatible_run_modes': <String>['read_only', 'confirm', 'auto'],
      },
      <String, Object?>{
        'id': 'knowledge.read',
        'capability_kind': 'local_core',
        'permissions': <String>['knowledge.read'],
        'required_permissions': <String>['knowledge.read'],
        'access': 'read',
        'risk': 'low',
        'locality': 'local',
        'approval_requirement': 'none',
        'execution': 'local',
        'side_effect': 'none',
        'compatible_run_modes': <String>['read_only', 'confirm', 'auto'],
      },
      <String, Object?>{
        'id': 'semantic_search.query',
        'capability_kind': 'local_core',
        'permissions': <String>['semantic_search.query'],
        'required_permissions': <String>['semantic_search.query'],
        'access': 'read',
        'risk': 'low',
        'locality': 'local',
        'approval_requirement': 'none',
        'execution': 'local',
        'side_effect': 'none',
        'compatible_run_modes': <String>['read_only', 'confirm', 'auto'],
      },
    ],
    'ui_blocks': <Map<String, Object?>>[
      <String, Object?>{
        'type': 'claim_list',
        'events': <String>['wn.insight.created'],
      },
      <String, Object?>{
        'type': 'metric_row',
        'events': <String>['wn.insight.created'],
      },
      <String, Object?>{
        'type': 'source_refs',
        'events': <String>['wn.insight.created'],
      },
      <String, Object?>{
        'type': 'note',
        'events': <String>['wn.insight.created'],
      },
    ],
    'storage_quota': <String, Object?>{'local_bytes': 0},
    'integrity': <String, Object?>{'checksum_sha256': null, 'signature': null},
    'metadata': <String, Object?>{
      'status': 'draft',
      'source': 'packs/official/default/manifest.json',
    },
  },
  'pack.todo': <String, Object?>{
    r'$schema':
        '../../../packages/schemas/src/agent_pack/agent_pack_manifest.schema.json',
    'id': 'pack.todo',
    'name': 'Todo Extraction Loop',
    'version': '0.1.0',
    'schema_version': 1,
    'publisher': 'widenote',
    'edition': 'official',
    'description': 'Built-in pack for source-linked todo suggestions.',
    'compatibility': <String, Object?>{
      'widenote_min': '0.1.0',
      'widenote_max': null,
      'schema_version': 1,
    },
    'marketplace': <String, Object?>{
      'source': 'bundled',
      'trust_level': 'official',
      'install_mode': 'bundled',
      'repository_url': 'https://github.com/widenote/widenote',
      'docs_path': 'packs/official/todo/README.md',
      'icon_path': null,
      'categories': <String>['task', 'capture'],
      'capabilities': <String>['todo.suggest'],
      'status': 'available',
    },
    'default_run_mode': 'auto',
    'entrypoint_kind': 'native',
    'permissions': <String>['todo.suggest'],
    'subscriptions': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'sub.todo_capture_created',
        'event_types': <String>['wn.capture.created'],
        'agent_id': 'agent.todo_loop',
        'delivery': 'async',
        'enabled_by_default': true,
      },
    ],
    'agents': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'agent.todo_loop',
        'runtime': 'native',
        'run_mode': 'auto',
        'name': 'Todo Loop Agent',
        'prompt_ref': null,
        'model_profile_ref': null,
        'permissions': <String>['todo.suggest'],
        'tools': <String>['todo.suggest'],
        'output_events': <String>['wn.todo.suggested'],
        'retry_policy': <String, Object?>{'max_attempts': 2},
      },
    ],
    'model_profiles': <Map<String, Object?>>[],
    'tools': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'todo.suggest',
        'capability_kind': 'todo',
        'permissions': <String>['todo.suggest'],
        'required_permissions': <String>['todo.suggest'],
        'access': 'write',
        'risk': 'low',
        'locality': 'local',
        'approval_requirement': 'none',
        'execution': 'local',
        'side_effect': 'local_write',
        'compatible_run_modes': <String>['confirm', 'auto'],
      },
    ],
    'ui_blocks': <Map<String, Object?>>[],
    'storage_quota': <String, Object?>{'local_bytes': 0},
    'integrity': <String, Object?>{'checksum_sha256': null, 'signature': null},
    'metadata': <String, Object?>{
      'status': 'draft',
      'source': 'packs/official/todo/manifest.json',
    },
  },
  'pack.pkm_library': <String, Object?>{
    r'$schema':
        '../../../packages/schemas/src/agent_pack/agent_pack_manifest.schema.json',
    'id': 'pack.pkm_library',
    'name': 'PKM Personal Library',
    'version': '0.1.0',
    'schema_version': 1,
    'publisher': 'widenote',
    'edition': 'official',
    'description':
        'Official example Pack that projects captures into source-linked PKM profile artifacts without replacing Memory as source truth.',
    'compatibility': <String, Object?>{
      'widenote_min': '0.1.0',
      'widenote_max': null,
      'schema_version': 1,
    },
    'marketplace': <String, Object?>{
      'source': 'bundled',
      'trust_level': 'official',
      'install_mode': 'bundled',
      'repository_url': 'https://github.com/widenote/widenote',
      'docs_path': 'packs/official/pkm_library/README.md',
      'icon_path': null,
      'categories': <String>['pkm', 'knowledge'],
      'capabilities': <String>['derived_artifact', 'knowledge.organization'],
      'status': 'available',
    },
    'additive_slots': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'knowledge.organization',
        'mode': 'additive',
        'description':
            'Create derived organization artifacts such as PKM profile entries.',
      },
    ],
    'entrypoint_kind': 'native',
    'permissions': <String>['model.complete', 'artifact.write'],
    'subscriptions': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'sub.pkm_capture_created',
        'event_types': <String>['wn.capture.created'],
        'agent_id': 'agent.pkm_profile_builder',
        'delivery': 'async',
        'enabled_by_default': true,
      },
    ],
    'agents': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'agent.pkm_profile_builder',
        'runtime': 'native',
        'name': 'PKM Profile Builder',
        'prompt_ref': 'pkm.profile_entry.v1',
        'model_profile_ref': 'local_or_user_selected_model',
        'permissions': <String>['model.complete', 'artifact.write'],
        'tools': <String>[],
        'output_events': <String>['wn.artifact.created'],
        'retry_policy': <String, Object?>{'max_attempts': 2},
      },
    ],
    'model_profiles': <Map<String, Object?>>[
      <String, Object?>{
        'id': 'local_or_user_selected_model',
        'purpose':
            'Extract compact source-linked PKM profile entries from captures.',
        'required': false,
        'routing_policy': 'app_default',
        'required_capabilities': <String>['chat', 'completion'],
        'allow_fallback': false,
      },
    ],
    'tools': <Map<String, Object?>>[],
    'ui_blocks': <Map<String, Object?>>[],
    'storage_quota': <String, Object?>{'local_bytes': 0},
    'integrity': <String, Object?>{'checksum_sha256': null, 'signature': null},
    'metadata': <String, Object?>{
      'status': 'draft',
      'source': 'packs/official/pkm_library/manifest.json',
      'derived_output': true,
      'source_truth': 'raw_capture_and_memory_remain_canonical',
    },
  },
};

const officialPackManifestBridge = runtime.AgentPackManifestBridge();

final officialPackManifestSources =
    Map<String, String>.unmodifiable(<String, String>{
      for (final packId in officialPackManifestIds)
        packId: officialPackManifestSource(packId),
    });

final officialPackManifestSnapshots = parseOfficialPackManifestSources(
  officialPackManifestSources,
);

final officialPackManifestSnapshotsById =
    Map<String, runtime.AgentPackManifestSnapshot>.unmodifiable(
      <String, runtime.AgentPackManifestSnapshot>{
        for (final snapshot in officialPackManifestSnapshots)
          snapshot.id: snapshot,
      },
    );

Map<String, Object?> officialPackManifestMap(String packId) {
  final manifest = officialPackManifestMaps[packId];
  if (manifest == null) {
    throw ArgumentError.value(packId, 'packId', 'Unknown official pack');
  }
  return manifest;
}

String officialPackManifestSource(String packId) {
  return jsonEncode(officialPackManifestMap(packId));
}

List<runtime.AgentPackManifestSnapshot> parseOfficialPackManifestSources(
  Map<String, String> sources, {
  Iterable<String> expectedPackIds = officialPackManifestIds,
  runtime.AgentPackManifestBridge bridge = officialPackManifestBridge,
}) {
  final expectedIds = expectedPackIds.toSet();
  final providedIds = sources.keys.toSet();
  final missing = expectedIds.difference(providedIds);
  final extra = providedIds.difference(expectedIds);
  if (missing.isNotEmpty || extra.isNotEmpty) {
    throw ArgumentError(
      'Official mobile manifest sources mismatch. '
      'Missing: ${_formatSet(missing)}. Extra: ${_formatSet(extra)}.',
    );
  }

  final snapshots = <runtime.AgentPackManifestSnapshot>[];
  final seenManifestIds = <String>{};
  for (final sourceId in expectedPackIds) {
    final source = sources[sourceId]!;
    final snapshot = bridge.parseJsonString(
      source,
      sourceName: 'mobile embedded official manifest $sourceId',
    );
    if (!seenManifestIds.add(snapshot.id)) {
      throw ArgumentError(
        'Duplicate official pack manifest id: ${snapshot.id}.',
      );
    }
    if (snapshot.id != sourceId) {
      throw ArgumentError(
        'Official mobile manifest source $sourceId parsed as ${snapshot.id}.',
      );
    }
    snapshots.add(snapshot);
  }
  return List<runtime.AgentPackManifestSnapshot>.unmodifiable(snapshots);
}

runtime.AgentPackManifestSnapshot officialPackManifestSnapshot(String packId) {
  final manifest = officialPackManifestSnapshotsById[packId];
  if (manifest == null) {
    throw ArgumentError.value(packId, 'packId', 'Unknown official pack');
  }
  return manifest;
}

String officialPackManifestDescription(String packId) {
  final description = officialPackManifestMap(packId)['description'];
  if (description is String) {
    return description;
  }
  return '';
}

List<runtime.AgentPack> buildOfficialNativePacks({
  Iterable<runtime.AgentPackManifestSnapshot>? manifests,
  required Map<String, Map<String, runtime.AgentHandler>>
  nativeHandlersByPackId,
  runtime.AgentPackManifestBridge bridge = officialPackManifestBridge,
}) {
  final manifestList = (manifests ?? officialPackManifestSnapshots).toList(
    growable: false,
  );
  final manifestIds = <String>{};
  for (final manifest in manifestList) {
    if (!manifestIds.add(manifest.id)) {
      throw ArgumentError(
        'Duplicate official pack manifest id: ${manifest.id}.',
      );
    }
    _validateMobileNativeManifest(manifest);
  }

  final extraHandlerPackIds = nativeHandlersByPackId.keys.toSet().difference(
    manifestIds,
  );
  if (extraHandlerPackIds.isNotEmpty) {
    throw ArgumentError(
      'Native handlers provided for unknown official pack(s): '
      '${_formatSet(extraHandlerPackIds)}.',
    );
  }

  final packs = <runtime.AgentPack>[];
  for (final manifest in manifestList) {
    final pack = bridge.buildNativePack(
      manifest,
      nativeHandlers:
          nativeHandlersByPackId[manifest.id] ??
          const <String, runtime.AgentHandler>{},
    );
    final alignment = pack.checkManifestAlignment(manifest);
    if (!alignment.isAligned) {
      throw ArgumentError(
        'Mobile official pack ${manifest.id} does not align with manifest: '
        '${alignment.issues.map((issue) => issue.path).join(', ')}.',
      );
    }
    packs.add(pack);
  }
  return List<runtime.AgentPack>.unmodifiable(packs);
}

void registerOfficialNativePacks(
  runtime.RuntimeKernel kernel, {
  Iterable<runtime.AgentPackManifestSnapshot>? manifests,
  required Map<String, Map<String, runtime.AgentHandler>>
  nativeHandlersByPackId,
  runtime.AgentPackManifestBridge bridge = officialPackManifestBridge,
}) {
  kernel.registerPacks(
    buildOfficialNativePacks(
      manifests: manifests,
      nativeHandlersByPackId: nativeHandlersByPackId,
      bridge: bridge,
    ),
  );
}

void assertOfficialNativePackAlignment(
  runtime.AgentPack pack,
  runtime.AgentPackManifestSnapshot manifest,
) {
  final alignment = pack.checkManifestAlignment(manifest);
  if (alignment.isAligned) {
    return;
  }
  throw ArgumentError(
    'Mobile official pack ${manifest.id} does not align with manifest: '
    '${alignment.issues.map((issue) => issue.path).join(', ')}.',
  );
}

void _validateMobileNativeManifest(runtime.AgentPackManifestSnapshot manifest) {
  if (manifest.edition != 'official') {
    throw ArgumentError(
      'Mobile official pack bridge only accepts official manifests; '
      '${manifest.id} is ${manifest.edition}.',
    );
  }
  for (final definition in manifest.agentDefinitions.values) {
    if (definition.runtimeKind != runtime.AgentRuntimeKind.native) {
      throw ArgumentError(
        'Mobile official pack ${manifest.id} declares non-native runtime at '
        'agents.${definition.id}.runtime: ${definition.runtimeKind.name}.',
      );
    }
  }
}

String _formatSet(Set<String> values) {
  final sorted = values.toList()..sort();
  return '[${sorted.join(', ')}]';
}
