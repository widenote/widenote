import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart';
import 'package:widenote_core/widenote_core.dart';

void main() {
  const bridge = AgentPackManifestBridge();

  test('official manifest files decode and align with native registry', () {
    final defaultManifest = bridge.loadFile(_officialDefaultPath);
    final todoManifest = bridge.loadFile(_officialTodoPath);
    final insightManifest = bridge.loadFile(_officialInsightDepthPath);
    final pkmManifest = bridge.loadFile(_officialPkmPath);
    final transcriptManifest = bridge.loadFile(_officialTranscriptPath);
    final usageStatsManifest = bridge.loadFile(_officialUsageStatsPath);

    expect(defaultManifest.id, 'pack.default');
    expect(defaultManifest.name, 'Default Capture Loop');
    expect(defaultManifest.version, '0.1.0');
    expect(defaultManifest.requiredPermissions, <String>{
      ModelPermissions.complete,
      'card.write',
      'memory.propose',
      'context_packet.build',
      'memory.read',
      'timeline.read',
      'knowledge.read',
      'semantic_search.query',
    });
    expect(defaultManifest.defaultRunMode, RunMode.auto);
    expect(defaultManifest.subscriptions.single.id, 'sub.capture_created');
    expect(defaultManifest.subscriptions.single.agentId, 'agent.capture_loop');
    expect(
      defaultManifest.agentDefinitions['agent.capture_loop']?.outputEvents,
      <String>{WnEventTypes.cardCreated, WnEventTypes.memoryProposed},
    );
    expect(
      defaultManifest.agentDefinitions['agent.capture_loop']?.modelProfileRef,
      'local_or_user_selected_model',
    );
    expect(
      defaultManifest.agentDefinitions['agent.capture_loop']?.runMode,
      RunMode.auto,
    );
    expect(defaultManifest.agentDefinitions['agent.capture_loop']?.tools, {
      'context_packet.build',
      'memory.read',
      'timeline.read',
      'knowledge.read',
      'semantic_search.query',
    });
    expect(
      defaultManifest.toolDefinitions['context_packet.build']?.access,
      ToolAccess.read,
    );
    expect(
      defaultManifest.toolDefinitions['context_packet.build']?.locality,
      ToolLocality.local,
    );
    expect(
      defaultManifest
          .toolDefinitions['context_packet.build']
          ?.compatibleRunModes,
      {RunMode.readOnly, RunMode.confirm, RunMode.auto},
    );
    expect(
      defaultManifest
          .agentDefinitions['agent.capture_loop']
          ?.retryPolicy
          .normalizedMaxAttempts,
      2,
    );
    expect(_manifestOutputEvents(defaultManifest), <String>{
      WnEventTypes.cardCreated,
      WnEventTypes.memoryProposed,
    });
    expect(
      defaultManifest.uiContributions.map((contribution) => contribution.id),
      <String>['plugins.pack_home.capture_status'],
    );

    expect(todoManifest.id, 'pack.todo');
    expect(todoManifest.requiredPermissions, <String>{
      ModelPermissions.complete,
      'todo.suggest',
    });
    expect(todoManifest.defaultRunMode, RunMode.auto);
    expect(
      todoManifest.toolDefinitions['todo.suggest']?.access,
      ToolAccess.write,
    );
    expect(todoManifest.toolDefinitions['todo.suggest']?.compatibleRunModes, {
      RunMode.confirm,
      RunMode.auto,
    });
    expect(_manifestOutputEvents(todoManifest), <String>{
      WnEventTypes.todoSuggested,
    });

    expect(insightManifest.id, 'pack.insight_depth');
    expect(insightManifest.requiredPermissions, <String>{
      ModelPermissions.complete,
      'insight.write',
      'insight.context.read',
      'memory.read',
      'timeline.read',
      'knowledge.read',
    });
    expect(insightManifest.defaultRunMode, RunMode.auto);
    expect(
      insightManifest.agentDefinitions['agent.insight_depth']?.modelProfileRef,
      'local_or_user_selected_model',
    );
    expect(
      insightManifest.agentDefinitions['agent.insight_depth']?.tools,
      <String>{'insight.context.read'},
    );
    expect(
      insightManifest.toolDefinitions['insight.context.read']?.access,
      ToolAccess.read,
    );
    expect(_manifestOutputEvents(insightManifest), <String>{
      WnEventTypes.insightCreated,
    });
    expect(
      insightManifest.uiContributions.map((contribution) => contribution.id),
      <String>[
        'insight.detail.depth',
        'plugins.pack_home.insight_depth_status',
      ],
    );

    expect(pkmManifest.id, 'pack.pkm_library');
    expect(pkmManifest.requiredPermissions, <String>{
      ModelPermissions.complete,
      'artifact.write',
    });
    expect(_manifestOutputEvents(pkmManifest), <String>{
      WnEventTypes.artifactCreated,
    });
    expect(
      pkmManifest
          .agentDefinitions['agent.pkm_profile_builder']
          ?.modelProfileRef,
      'local_or_user_selected_model',
    );
    expect(
      pkmManifest.uiContributions.map((contribution) => contribution.surface),
      <String>['artifact.detail', 'plugins.pack_home'],
    );
    expect(
      transcriptManifest.uiContributions
          .singleWhere(
            (contribution) =>
                contribution.id == 'settings.transcript_correction.glossary',
          )
          .kind,
      'settings_form',
    );
    expect(
      transcriptManifest.uiContributions
          .singleWhere(
            (contribution) =>
                contribution.id == 'settings.transcript_correction.glossary',
          )
          .settingsSchemaRef,
      '#/settings_schema',
    );
    expect(usageStatsManifest.id, 'pack.usage_stats');
    expect(usageStatsManifest.requiredPermissions, isEmpty);
    expect(usageStatsManifest.subscriptions, isEmpty);
    expect(usageStatsManifest.agentDefinitions, isEmpty);
    final usageStatsContribution = usageStatsManifest.uiContributions.single;
    expect(usageStatsContribution.id, 'settings.usage_stats.dashboard');
    expect(usageStatsContribution.surface, 'settings.pack_detail');
    expect(usageStatsContribution.kind, 'panel');
    expect(usageStatsContribution.requiredPermissions, isEmpty);

    final registry = InMemoryPackRegistry()
      ..register(
        bridge.buildNativePack(
          defaultManifest,
          nativeHandlers: const <String, AgentHandler>{
            'agent.capture_loop': _OfficialDefaultHandler(),
          },
        ),
      )
      ..register(
        bridge.buildNativePack(
          pkmManifest,
          nativeHandlers: const <String, AgentHandler>{
            'agent.pkm_profile_builder': _OfficialPkmHandler(),
          },
        ),
      )
      ..register(
        bridge.buildNativePack(
          todoManifest,
          nativeHandlers: const <String, AgentHandler>{
            'agent.todo_loop': _OfficialTodoHandler(),
          },
        ),
      )
      ..register(
        bridge.buildNativePack(
          insightManifest,
          nativeHandlers: const <String, AgentHandler>{
            'agent.insight_depth': _InsightHandler(),
          },
        ),
      );

    expect(registry.checkManifestAlignment(defaultManifest).isAligned, isTrue);
    expect(registry.checkManifestAlignment(todoManifest).isAligned, isTrue);
    expect(registry.checkManifestAlignment(insightManifest).isAligned, isTrue);
    expect(registry.checkManifestAlignment(pkmManifest).isAligned, isTrue);
  });

  test(
    'bridge registers official packs from manifest metadata and runs them',
    () async {
      final defaultManifest = bridge.loadFile(_officialDefaultPath);
      final todoManifest = bridge.loadFile(_officialTodoPath);
      final insightManifest = bridge.loadFile(_officialInsightDepthPath);
      final pkmManifest = bridge.loadFile(_officialPkmPath);
      final store = InMemoryEventStore();
      final permissions = InMemoryPermissionBroker()
        ..grantAll(defaultManifest.id, defaultManifest.requiredPermissions)
        ..grantAll(todoManifest.id, todoManifest.requiredPermissions)
        ..grantAll(insightManifest.id, insightManifest.requiredPermissions)
        ..grantAll(pkmManifest.id, pkmManifest.requiredPermissions);
      final kernel = _kernel(store: store, permissions: permissions);

      bridge.registerNativePacks(
        kernel,
        manifests: <AgentPackManifestSnapshot>[
          defaultManifest,
          todoManifest,
          insightManifest,
          pkmManifest,
        ],
        nativeHandlersByPackId: const <String, Map<String, AgentHandler>>{
          'pack.default': <String, AgentHandler>{
            'agent.capture_loop': _OfficialDefaultHandler(),
          },
          'pack.todo': <String, AgentHandler>{
            'agent.todo_loop': _OfficialTodoHandler(),
          },
          'pack.insight_depth': <String, AgentHandler>{
            'agent.insight_depth': _InsightHandler(),
          },
          'pack.pkm_library': <String, AgentHandler>{
            'agent.pkm_profile_builder': _OfficialPkmHandler(),
          },
        },
      );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
          subjectRef: SubjectRef(kind: 'capture', id: 'capture-bridge'),
          payload: <String, Object?>{'text': 'Bridge official manifests.'},
        ),
      );

      expect(kernel.tasks, hasLength(4));
      final identityKeys = kernel.tasks
          .map((task) => task.identityKey)
          .join('\n');
      expect(
        identityKeys,
        contains(
          'pack.default::0.1.0::sub.capture_created::agent.capture_loop',
        ),
      );
      expect(
        identityKeys,
        contains('pack.todo::0.1.0::sub.todo_capture_created::agent.todo_loop'),
      );
      expect(
        identityKeys,
        contains(
          'pack.insight_depth::0.1.0::sub.insight_capture_created::agent.insight_depth',
        ),
      );
      expect(
        identityKeys,
        contains(
          'pack.pkm_library::0.1.0::sub.pkm_capture_created::agent.pkm_profile_builder',
        ),
      );
      expect(
        kernel.runs.map((run) => run.status),
        everyElement(RuntimeRunStatus.succeeded),
      );
      final eventTypes = (await store.readAll())
          .map((event) => event.type)
          .toList(growable: false);
      expect(eventTypes.first, WnEventTypes.captureCreated);
      expect(
        eventTypes,
        containsAll(<String>[
          WnEventTypes.memoryProposed,
          WnEventTypes.cardCreated,
          WnEventTypes.todoSuggested,
          WnEventTypes.insightCreated,
          WnEventTypes.artifactCreated,
        ]),
      );
    },
  );

  test('manifest permissions feed runtime permission checks', () async {
    final defaultManifest = bridge.loadFile(_officialDefaultPath);
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final permissions = InMemoryPermissionBroker()
      ..grantAll(defaultManifest.id, <String>{
        ModelPermissions.complete,
        'memory.propose',
      });
    final kernel = _kernel(
      store: store,
      permissions: permissions,
      traceSink: traceSink,
    );

    bridge.registerNativePacks(
      kernel,
      manifests: <AgentPackManifestSnapshot>[defaultManifest],
      nativeHandlersByPackId: const <String, Map<String, AgentHandler>>{
        'pack.default': <String, AgentHandler>{
          'agent.capture_loop': _OfficialDefaultHandler(),
        },
      },
    );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    expect(kernel.tasks.single.status, RuntimeTaskStatus.denied);
    expect(kernel.runs.single.status, RuntimeRunStatus.denied);
    expect(await store.readAll(), hasLength(1));
    final deniedTrace = (await traceSink.readAll()).singleWhere(
      (trace) => trace.name == 'runtime.permission.denied',
    );
    expect(deniedTrace.details['missing_permissions'], contains('card.write'));
  });

  test('alignment detects native and manifest drift by path', () {
    final manifest = bridge.loadFile(_officialDefaultPath);
    final native = bridge.buildNativePack(
      manifest,
      nativeHandlers: const <String, AgentHandler>{
        'agent.capture_loop': _OfficialDefaultHandler(),
      },
    );

    final cases = <({String expectedPath, AgentPackManifestSnapshot snapshot})>[
      (
        expectedPath: 'id',
        snapshot: _copyManifest(manifest, id: 'pack.changed'),
      ),
      (
        expectedPath: 'name',
        snapshot: _copyManifest(manifest, name: 'Changed'),
      ),
      (
        expectedPath: 'version',
        snapshot: _copyManifest(manifest, version: '0.1.1'),
      ),
      (
        expectedPath: 'permissions',
        snapshot: _copyManifest(
          manifest,
          requiredPermissions: const <String>{ModelPermissions.complete},
        ),
      ),
      (
        expectedPath: 'subscriptions.sub.capture_created.event_types',
        snapshot: _copyManifest(
          manifest,
          subscriptions: const <Subscription>[
            Subscription(
              id: 'sub.capture_created',
              agentId: 'agent.capture_loop',
              eventTypes: <String>{'wn.capture.changed'},
            ),
          ],
        ),
      ),
      (
        expectedPath: 'agents',
        snapshot: _copyManifest(
          manifest,
          agentDefinitions: const <String, AgentDefinition>{
            'agent.other': AgentDefinition(
              id: 'agent.other',
              outputEvents: <String>{WnEventTypes.insightCreated},
            ),
          },
        ),
      ),
      (
        expectedPath: 'agents.agent.capture_loop.runtime',
        snapshot: _copyManifest(
          manifest,
          agentDefinitions: <String, AgentDefinition>{
            'agent.capture_loop': _copyAgent(
              manifest.agentDefinitions['agent.capture_loop']!,
              runtimeKind: AgentRuntimeKind.remote,
            ),
          },
        ),
      ),
      (
        expectedPath: 'agents.agent.capture_loop.tools',
        snapshot: _copyManifest(
          manifest,
          agentDefinitions: <String, AgentDefinition>{
            'agent.capture_loop': _copyAgent(
              manifest.agentDefinitions['agent.capture_loop']!,
              tools: const <String>{'tool.echo'},
            ),
          },
        ),
      ),
      (
        expectedPath: 'agents.agent.capture_loop.run_mode',
        snapshot: _copyManifest(
          manifest,
          agentDefinitions: <String, AgentDefinition>{
            'agent.capture_loop': _copyAgent(
              manifest.agentDefinitions['agent.capture_loop']!,
              runMode: RunMode.readOnly,
            ),
          },
        ),
      ),
      (
        expectedPath: 'agents.agent.capture_loop.retry_policy.max_attempts',
        snapshot: _copyManifest(
          manifest,
          agentDefinitions: <String, AgentDefinition>{
            'agent.capture_loop': _copyAgent(
              manifest.agentDefinitions['agent.capture_loop']!,
              retryPolicy: const RetryPolicy(maxAttempts: 3),
            ),
          },
        ),
      ),
      (
        expectedPath: 'agents.agent.capture_loop.output_events',
        snapshot: _copyManifest(
          manifest,
          agentDefinitions: <String, AgentDefinition>{
            'agent.capture_loop': _copyAgent(
              manifest.agentDefinitions['agent.capture_loop']!,
              outputEvents: const <String>{WnEventTypes.cardCreated},
            ),
          },
        ),
      ),
      (
        expectedPath: 'agents.agent.capture_loop.model_profile_ref',
        snapshot: _copyManifest(
          manifest,
          agentDefinitions: <String, AgentDefinition>{
            'agent.capture_loop': _copyAgent(
              manifest.agentDefinitions['agent.capture_loop']!,
              modelProfileRef: 'different_profile',
            ),
          },
        ),
      ),
    ];

    for (final entry in cases) {
      final report = native.checkManifestAlignment(entry.snapshot);
      expect(report.isAligned, isFalse, reason: entry.expectedPath);
      expect(
        report.issues.map((issue) => issue.path),
        contains(entry.expectedPath),
        reason: entry.expectedPath,
      );
    }
  });

  test(
    'parser fails closed for malformed manifests and invalid references',
    () {
      expect(
        () => bridge.loadFile('../../../packs/official/missing/manifest.json'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('not found'),
          ),
        ),
      );
      expect(
        () => bridge.parseJsonString('{', sourceName: 'bad.json'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('invalid JSON'),
          ),
        ),
      );
      expect(
        () => bridge.parseJsonString('[]', sourceName: 'array.json'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('JSON object'),
          ),
        ),
      );

      _expectManifestFails('missing id', (json) => json.remove('id'), 'id');
      _expectManifestFails(
        'future schema',
        (json) => json['schema_version'] = 2,
        'schema_version',
      );
      _expectManifestFails(
        'bad edition',
        (json) => json['edition'] = 'beta',
        'edition',
      );
      _expectManifestFails(
        'bad entrypoint',
        (json) => json['entrypoint_kind'] = 'plugin',
        'entrypoint_kind',
      );
      _expectManifestFails(
        'bad marketplace trust',
        (json) => (json['marketplace'] as JsonMap)['trust_level'] = 'trusted',
        'marketplace.trust_level',
      );
      _expectManifestFails(
        'bad additive slot mode',
        (json) => json['additive_slots'] = <Object?>[
          <String, Object?>{
            'id': 'knowledge.organization',
            'mode': 'replace',
            'description': 'wrong mode',
          },
        ],
        'additive_slots.knowledge.organization.mode',
      );
      _expectManifestFails('community replacement slot', (json) {
        json['edition'] = 'community';
        json['replacement_slots'] = <Object?>[
          <String, Object?>{
            'id': 'memory.write',
            'mode': 'replace',
            'description': 'unsafe replacement',
          },
        ];
      }, 'replacement_slots');
      _expectManifestFails(
        'bad runtime',
        (json) => _firstAgent(json)['runtime'] = 'python',
        'runtime',
      );
      _expectManifestFails(
        'duplicate subscription id',
        (json) => (json['subscriptions'] as List<Object?>).add(
          _clone(_firstSubscription(json)),
        ),
        'duplicate id',
      );
      _expectManifestFails(
        'duplicate agent id',
        (json) =>
            (json['agents'] as List<Object?>).add(_clone(_firstAgent(json))),
        'duplicate id',
      );
      _expectManifestFails(
        'duplicate permission',
        (json) => (json['permissions'] as List<Object?>).add(
          ModelPermissions.complete,
        ),
        'duplicates',
      );
      _expectManifestFails(
        'duplicate output event',
        (json) => (_firstAgent(json)['output_events'] as List<Object?>).add(
          WnEventTypes.cardCreated,
        ),
        'duplicates',
      );
      _expectManifestFails(
        'unknown subscription agent',
        (json) => _firstSubscription(json)['agent_id'] = 'agent.missing',
        'unknown agent',
      );
      _expectManifestFails(
        'unknown depends_on',
        (json) =>
            _firstSubscription(json)['depends_on'] = <Object?>['sub.missing'],
        'unknown subscription',
      );
      _expectManifestFails(
        'self depends_on',
        (json) => _firstSubscription(json)['depends_on'] = <Object?>[
          'sub.capture_created',
        ],
        'must not reference itself',
      );
      _expectManifestFails('depends_on cycle', (json) {
        final subscriptions = json['subscriptions'] as List<Object?>;
        subscriptions.add(<String, Object?>{
          'id': 'sub.second',
          'event_types': <Object?>[WnEventTypes.captureCreated],
          'agent_id': 'agent.capture_loop',
          'depends_on': <Object?>['sub.capture_created'],
        });
        _firstSubscription(json)['depends_on'] = <Object?>['sub.second'];
      }, 'cycle');
      _expectManifestFails(
        'agent permission outside pack',
        (json) => (_firstAgent(json)['permissions'] as List<Object?>).add(
          'todo.suggest',
        ),
        'not declared by the pack',
      );
      _expectManifestFails('tool permission outside pack', (json) {
        json['tools'] = <Object?>[
          <String, Object?>{
            'id': 'tool.bad',
            'permissions': <Object?>['todo.suggest'],
            'required_permissions': <Object?>['todo.suggest'],
            'access': 'read',
            'risk': 'low',
            'locality': 'local',
            'approval_requirement': 'none',
            'execution': 'local',
            'side_effect': 'none',
            'compatible_run_modes': <Object?>['read_only', 'confirm', 'auto'],
          },
        ];
      }, 'not declared by the pack');
      _expectManifestFails(
        'tool required permission drift',
        (json) =>
            ((json['tools'] as List<Object?>).first
                as JsonMap)['required_permissions'] = <Object?>[
              'memory.read',
            ],
        'required_permissions must match',
      );
      _expectManifestFails(
        'tool missing compatible run modes',
        (json) => ((json['tools'] as List<Object?>).first as JsonMap).remove(
          'compatible_run_modes',
        ),
        'compatible_run_modes',
      );
      _expectManifestFails(
        'unknown model profile',
        (json) => _firstAgent(json)['model_profile_ref'] = 'missing_profile',
        'unknown model profile',
      );
      _expectManifestFails(
        'bad model profile ref type',
        (json) => _firstAgent(json)['model_profile_ref'] = true,
        'model_profile_ref',
      );
      _expectManifestFails(
        'retry below minimum',
        (json) => _firstAgent(json)['retry_policy'] = <String, Object?>{
          'max_attempts': 0,
        },
        'max_attempts',
      );
      _expectManifestFails(
        'retry above maximum',
        (json) => _firstAgent(json)['retry_policy'] = <String, Object?>{
          'max_attempts': 6,
        },
        'max_attempts',
      );
      _expectManifestFails(
        'missing output events',
        (json) => _firstAgent(json).remove('output_events'),
        'output_events',
      );
      _expectManifestFails(
        'empty output events',
        (json) => _firstAgent(json)['output_events'] = <Object?>[],
        'output_events',
      );
      _expectManifestFails(
        'ui contribution permission outside pack',
        (json) => json['ui_contributions'] = <Object?>[
          <String, Object?>{
            'id': 'settings.bad',
            'surface': 'settings.pack_detail',
            'kind': 'settings_form',
            'title': 'Unsafe settings',
            'settings_schema_ref': '#/settings_schema',
            'required_permissions': <Object?>['todo.suggest'],
          },
        ],
        'not declared by pack',
      );
      _expectManifestFails(
        'ui event blocks need events and blocks',
        (json) => json['ui_contributions'] = <Object?>[
          <String, Object?>{
            'id': 'insight.bad',
            'surface': 'insight.detail',
            'kind': 'event_blocks',
            'title': 'Bad blocks',
          },
        ],
        'events and blocks',
      );
      _expectManifestFails(
        'ui contribution blocks must be declared by pack',
        (json) {
          json['ui_blocks'] = <Object?>[
            <String, Object?>{
              'type': 'note',
              'events': <Object?>['wn.insight.created'],
            },
          ];
          json['ui_contributions'] = <Object?>[
            <String, Object?>{
              'id': 'insight.bad',
              'surface': 'insight.detail',
              'kind': 'event_blocks',
              'title': 'Bad blocks',
              'events': <Object?>['wn.insight.created'],
              'blocks': <Object?>['source_refs'],
            },
          ];
        },
        'UI blocks not declared by pack',
      );
      final extendedBlocksManifest = _officialDefaultJson();
      extendedBlocksManifest['ui_blocks'] = <Object?>[
        for (final block in <String>[
          'evidence_list',
          'counter_evidence',
          'confidence_band',
          'contrast',
          'trend_chart',
          'timeline',
        ])
          <String, Object?>{
            'type': block,
            'events': <Object?>['wn.insight.created'],
          },
      ];
      extendedBlocksManifest['ui_contributions'] = <Object?>[
        <String, Object?>{
          'id': 'insight.extended_blocks',
          'surface': 'insight.detail',
          'kind': 'event_blocks',
          'title': 'Extended insight blocks',
          'events': <Object?>['wn.insight.created'],
          'blocks': <Object?>[
            'evidence_list',
            'counter_evidence',
            'confidence_band',
            'contrast',
            'trend_chart',
            'timeline',
          ],
        },
      ];
      final extended = bridge.parseJsonString(
        jsonEncode(extendedBlocksManifest),
        sourceName: 'extended-ui-blocks',
      );
      expect(extended.uiContributions.single.blocks, <String>{
        'evidence_list',
        'counter_evidence',
        'confidence_band',
        'contrast',
        'trend_chart',
        'timeline',
      });
      _expectManifestFails(
        'settings form needs schema ref',
        (json) => json['ui_contributions'] = <Object?>[
          <String, Object?>{
            'id': 'settings.bad',
            'surface': 'settings.pack_detail',
            'kind': 'settings_form',
            'title': 'Bad settings',
          },
        ],
        'settings_schema_ref',
      );
      _expectManifestFails(
        'settings schema ref needs settings schema',
        (json) => json['ui_contributions'] = <Object?>[
          <String, Object?>{
            'id': 'settings.bad',
            'surface': 'settings.pack_detail',
            'kind': 'settings_form',
            'title': 'Bad settings',
            'settings_schema_ref': '#/settings_schema',
            'required_permissions': <Object?>['memory.read'],
          },
        ],
        'references missing settings_schema',
      );
      _expectManifestFails('community bottom tab contribution', (json) {
        json['edition'] = 'community';
        json['ui_contributions'] = <Object?>[
          <String, Object?>{
            'id': 'navigation.bottom',
            'surface': 'bottom_tab',
            'kind': 'bottom_tab',
            'title': 'Unsafe tab',
          },
        ];
      }, 'bottom_tab');
    },
  );

  test('unsupported runtimes and undeclared outputs fail closed', () async {
    for (final runtimeKind in <AgentRuntimeKind>[
      AgentRuntimeKind.declarative,
      AgentRuntimeKind.remote,
      AgentRuntimeKind.script,
    ]) {
      final store = InMemoryEventStore();
      final kernel = _kernel(store: store);
      kernel.registerPack(
        AgentPack(
          id: 'pack.${runtimeKind.name}',
          name: 'Unsupported runtime',
          version: '0.1.0',
          subscriptions: <Subscription>[
            Subscription(
              id: 'sub.${runtimeKind.name}',
              agentId: 'agent.${runtimeKind.name}',
              eventTypes: <String>{WnEventTypes.captureCreated},
            ),
          ],
          agentDefinitions: <String, AgentDefinition>{
            'agent.${runtimeKind.name}': AgentDefinition(
              id: 'agent.${runtimeKind.name}',
              runtimeKind: runtimeKind,
              outputEvents: <String>{WnEventTypes.insightCreated},
            ),
          },
          agents: const <String, AgentHandler>{},
        ),
      );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );

      expect(kernel.tasks.single.status, RuntimeTaskStatus.denied);
      expect(kernel.runs.single.status, RuntimeRunStatus.denied);
      expect(await store.readAll(), hasLength(1));
    }

    final store = InMemoryEventStore();
    final kernel = _kernel(store: store)
      ..registerPack(
        const AgentPack(
          id: 'pack.output',
          name: 'Output pack',
          version: '0.1.0',
          subscriptions: <Subscription>[
            Subscription(
              id: 'sub.output',
              agentId: 'agent.output',
              eventTypes: <String>{WnEventTypes.captureCreated},
            ),
          ],
          agentDefinitions: <String, AgentDefinition>{
            'agent.output': AgentDefinition(id: 'agent.output'),
          },
          agents: <String, AgentHandler>{'agent.output': _InsightHandler()},
        ),
      );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    expect(kernel.tasks.single.status, RuntimeTaskStatus.failed);
    expect(kernel.runs.single.status, RuntimeRunStatus.failed);
    expect(await store.readAll(), hasLength(1));
  });

  test(
    'bridge registration is all-or-nothing on malformed native bindings',
    () {
      final defaultManifest = bridge.loadFile(_officialDefaultPath);
      final todoManifest = bridge.loadFile(_officialTodoPath);
      final kernel = _kernel(store: InMemoryEventStore());
      final oldPack = AgentPack(
        id: defaultManifest.id,
        name: defaultManifest.name,
        version: '0.0.1',
        requiredPermissions: defaultManifest.requiredPermissions,
        subscriptions: defaultManifest.subscriptions,
        agentDefinitions: defaultManifest.agentDefinitions,
        agents: const <String, AgentHandler>{
          'agent.capture_loop': _OfficialDefaultHandler(),
        },
      );
      kernel.registerPack(oldPack);

      expect(
        () => bridge.registerNativePacks(
          kernel,
          manifests: <AgentPackManifestSnapshot>[
            defaultManifest,
            defaultManifest,
          ],
          nativeHandlersByPackId: const <String, Map<String, AgentHandler>>{
            'pack.default': <String, AgentHandler>{
              'agent.capture_loop': _OfficialDefaultHandler(),
            },
          },
        ),
        throwsArgumentError,
      );
      expect(kernel.packRegistry.lookup(defaultManifest.id)?.version, '0.0.1');

      final tempDir = Directory.systemTemp.createTempSync(
        'widenote_manifest_bridge_test',
      );
      try {
        final badManifest = File('${tempDir.path}/bad.json')
          ..writeAsStringSync('[]');
        expect(
          () => bridge.loadAndRegisterNativePacks(
            kernel,
            paths: <String>[_officialDefaultPath, badManifest.path],
            nativeHandlersByPackId: const <String, Map<String, AgentHandler>>{
              'pack.default': <String, AgentHandler>{
                'agent.capture_loop': _OfficialDefaultHandler(),
              },
            },
          ),
          throwsA(isA<FormatException>()),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
      expect(kernel.packRegistry.lookup(defaultManifest.id)?.version, '0.0.1');

      expect(
        () => bridge.registerNativePacks(
          kernel,
          manifests: <AgentPackManifestSnapshot>[
            _copyManifest(defaultManifest, version: '9.9.9'),
            todoManifest,
          ],
          nativeHandlersByPackId: const <String, Map<String, AgentHandler>>{
            'pack.default': <String, AgentHandler>{
              'agent.capture_loop': _OfficialDefaultHandler(),
            },
          },
        ),
        throwsArgumentError,
      );

      expect(kernel.packRegistry.lookup(defaultManifest.id)?.version, '0.0.1');
      expect(kernel.packRegistry.lookup(todoManifest.id), isNull);
    },
  );

  test('native bridge rejects non-official editions', () {
    final json = _officialDefaultJson()..['edition'] = 'community';
    final manifest = AgentPackManifestSnapshot.fromJson(json);

    expect(
      () => bridge.buildNativePack(
        manifest,
        nativeHandlers: const <String, AgentHandler>{
          'agent.capture_loop': _OfficialDefaultHandler(),
        },
      ),
      throwsArgumentError,
    );
  });

  test(
    'kernel bulk pack registration rolls back if registry write fails',
    () async {
      final defaultManifest = bridge.loadFile(_officialDefaultPath);
      final todoManifest = bridge.loadFile(_officialTodoPath);
      final store = InMemoryEventStore();
      final kernel = _kernel(
        store: store,
        packRegistry: _ThrowingPackRegistry(failOnPackId: todoManifest.id),
      );

      expect(
        () => bridge.registerNativePacks(
          kernel,
          manifests: <AgentPackManifestSnapshot>[defaultManifest, todoManifest],
          nativeHandlersByPackId: const <String, Map<String, AgentHandler>>{
            'pack.default': <String, AgentHandler>{
              'agent.capture_loop': _OfficialDefaultHandler(),
            },
            'pack.todo': <String, AgentHandler>{
              'agent.todo_loop': _OfficialTodoHandler(),
            },
          },
        ),
        throwsStateError,
      );

      expect(kernel.packRegistry.lookup(defaultManifest.id), isNull);
      expect(kernel.packRegistry.lookup(todoManifest.id), isNull);

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );
      expect(kernel.tasks, isEmpty);
      expect(await store.readAll(), hasLength(1));
    },
  );
}

const _officialDefaultPath = '../../../packs/official/default/manifest.json';
const _officialTodoPath = '../../../packs/official/todo/manifest.json';
const _officialInsightDepthPath =
    '../../../packs/official/insight_depth/manifest.json';
const _officialPkmPath = '../../../packs/official/pkm_library/manifest.json';
const _officialTranscriptPath =
    '../../../packs/official/transcript_correction/manifest.json';
const _officialUsageStatsPath =
    '../../../packs/official/usage_stats/manifest.json';

RuntimeKernel _kernel({
  required EventStore store,
  PermissionBroker? permissions,
  TraceSink? traceSink,
  PackRegistry? packRegistry,
}) {
  return RuntimeKernel(
    eventStore: store,
    traceSink: traceSink ?? InMemoryTraceSink(),
    permissionBroker: permissions ?? InMemoryPermissionBroker(),
    toolRegistry: InMemoryToolRegistry(),
    idGenerator: SequenceWnIdGenerator(seed: 'manifest'),
    clock: TickingWnClock(DateTime.utc(2026, 6, 26, 1)),
    model: FakeModel(responses: const <String>['official summary']),
    deviceId: 'device-local',
    packRegistry: packRegistry,
  );
}

void _expectManifestFails(
  String name,
  void Function(JsonMap json) mutate,
  String message,
) {
  final json = _officialDefaultJson();
  mutate(json);
  expect(
    () => AgentPackManifestSnapshot.fromJson(json),
    throwsA(
      isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains(message),
      ),
    ),
    reason: name,
  );
}

JsonMap _officialDefaultJson() {
  return _clone(jsonDecode(File(_officialDefaultPath).readAsStringSync()));
}

JsonMap _clone(Object? value) {
  return _deepClone(value) as JsonMap;
}

Object? _deepClone(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: _deepClone(entry.value),
    };
  }
  if (value is List) {
    return <Object?>[for (final entry in value) _deepClone(entry)];
  }
  return value;
}

JsonMap _firstAgent(JsonMap json) {
  return (json['agents'] as List<Object?>).first as JsonMap;
}

JsonMap _firstSubscription(JsonMap json) {
  return (json['subscriptions'] as List<Object?>).first as JsonMap;
}

Set<String> _manifestOutputEvents(AgentPackManifestSnapshot manifest) {
  return manifest.agentDefinitions.values
      .expand((definition) => definition.outputEvents)
      .toSet();
}

AgentPackManifestSnapshot _copyManifest(
  AgentPackManifestSnapshot manifest, {
  String? id,
  String? name,
  String? version,
  Set<String>? requiredPermissions,
  List<Subscription>? subscriptions,
  Map<String, AgentDefinition>? agentDefinitions,
  RunMode? defaultRunMode,
  Map<String, AgentPackToolDefinition>? toolDefinitions,
  List<AgentPackUiContributionDefinition>? uiContributions,
}) {
  return AgentPackManifestSnapshot(
    id: id ?? manifest.id,
    name: name ?? manifest.name,
    version: version ?? manifest.version,
    schemaVersion: manifest.schemaVersion,
    publisher: manifest.publisher,
    edition: manifest.edition,
    defaultRunMode: defaultRunMode ?? manifest.defaultRunMode,
    requiredPermissions: requiredPermissions ?? manifest.requiredPermissions,
    subscriptions: subscriptions ?? manifest.subscriptions,
    agentDefinitions: agentDefinitions ?? manifest.agentDefinitions,
    toolDefinitions: toolDefinitions ?? manifest.toolDefinitions,
    uiContributions: uiContributions ?? manifest.uiContributions,
  );
}

AgentDefinition _copyAgent(
  AgentDefinition definition, {
  AgentRuntimeKind? runtimeKind,
  RunMode? runMode,
  Set<String>? requiredPermissions,
  Set<String>? outputEvents,
  Set<String>? tools,
  RetryPolicy? retryPolicy,
  Object? modelProfileRef = _keepModelProfileRef,
}) {
  return AgentDefinition(
    id: definition.id,
    runtimeKind: runtimeKind ?? definition.runtimeKind,
    runMode: runMode ?? definition.runMode,
    requiredPermissions: requiredPermissions ?? definition.requiredPermissions,
    outputEvents: outputEvents ?? definition.outputEvents,
    tools: tools ?? definition.tools,
    retryPolicy: retryPolicy ?? definition.retryPolicy,
    modelProfileRef: identical(modelProfileRef, _keepModelProfileRef)
        ? definition.modelProfileRef
        : modelProfileRef as String?,
  );
}

const Object _keepModelProfileRef = Object();

final class _OfficialDefaultHandler implements AgentHandler {
  const _OfficialDefaultHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    final response = await context.model.complete(
      const ModelRequest(prompt: 'Summarize official capture.'),
    );
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.memoryProposed,
          subjectRef: event.subjectRef,
          payload: <String, Object?>{'text': response.text},
        ),
        context.emit(
          type: WnEventTypes.cardCreated,
          subjectRef: event.subjectRef,
          payload: <String, Object?>{'body': response.text},
        ),
      ],
    );
  }
}

final class _OfficialTodoHandler implements AgentHandler {
  const _OfficialTodoHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.todoSuggested,
          subjectRef: event.subjectRef,
          payload: const <String, Object?>{'text': 'Review capture.'},
        ),
      ],
    );
  }
}

final class _OfficialPkmHandler implements AgentHandler {
  const _OfficialPkmHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.artifactCreated,
          subjectRef: event.subjectRef,
          payload: const <String, Object?>{
            'artifact_id': 'artifact.bridge.pkm',
            'artifact_kind': 'pkm_profile_entry',
            'title': 'Bridge PKM profile entry',
            'body': 'Source-linked bridge artifact.',
          },
        ),
      ],
    );
  }
}

final class _InsightHandler implements AgentHandler {
  const _InsightHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    return AgentHandlerResult(
      events: <WnEventDraft>[context.emit(type: WnEventTypes.insightCreated)],
    );
  }
}

final class _ThrowingPackRegistry implements PackRegistry {
  _ThrowingPackRegistry({required this.failOnPackId});

  final String failOnPackId;
  final InMemoryPackRegistry _delegate = InMemoryPackRegistry();

  @override
  void register(AgentPack pack) {
    if (pack.id == failOnPackId) {
      throw StateError('intentional registry write failure');
    }
    _delegate.register(pack);
  }

  @override
  void unregister(String packId) {
    _delegate.unregister(packId);
  }

  @override
  AgentPack? lookup(String packId) => _delegate.lookup(packId);

  @override
  List<AgentPack> list() => _delegate.list();

  @override
  AgentPackAlignmentReport checkManifestAlignment(
    AgentPackManifestSnapshot manifest,
  ) {
    return _delegate.checkManifestAlignment(manifest);
  }
}
