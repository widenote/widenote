import 'package:test/test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart';
import 'package:widenote_core/widenote_core.dart';

void main() {
  test(
    'capture.created drives subscription, run, output events, and trace',
    () async {
      final model = FakeModel(responses: <String>['runtime slice summary']);
      final permissions = InMemoryPermissionBroker()
        ..grantAll('pack.default', <String>{
          ModelPermissions.complete,
          'memory.propose',
          'card.write',
          'insight.write',
          'todo.suggest',
        });
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final kernel = _kernel(
        store: store,
        traceSink: traceSink,
        permissions: permissions,
        model: model,
        handler: const _CaptureProjectionHandler(),
      );

      final capture = await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
          subjectRef: SubjectRef(kind: 'capture', id: 'capture-1'),
          payload: <String, Object?>{
            'text': 'Ship the local runtime test slice.',
            'source': 'manual',
          },
        ),
      );

      final events = await store.readAll();
      final eventTypes = events.map((event) => event.type).toList();

      expect(eventTypes, <String>[
        WnEventTypes.captureCreated,
        WnEventTypes.memoryProposed,
        WnEventTypes.cardCreated,
        WnEventTypes.insightCreated,
        WnEventTypes.todoSuggested,
      ]);
      expect(model.requests.single.prompt, contains('Ship the local runtime'));
      final task = kernel.tasks.single;
      final run = kernel.runs.single;
      expect(task.packId, 'pack.default');
      expect(task.agentId, 'agent.capture');
      expect(task.subscriptionId, 'sub.capture');
      expect(task.triggerEventId, capture.id);
      expect(task.status, RuntimeTaskStatus.succeeded);
      expect(run.taskId, task.id);
      expect(run.packId, task.packId);
      expect(run.agentId, task.agentId);
      expect(run.status, RuntimeRunStatus.succeeded);

      final outputs = events.skip(1).toList();
      expect(run.outputEventIds, outputs.map((event) => event.id).toList());
      for (final output in outputs) {
        expect(output.actor, WnActor.agent);
        expect(output.packId, 'pack.default');
        expect(output.agentId, 'agent.capture');
        expect(output.causationId, capture.id);
        expect(output.correlationId, capture.id);
        final sourceRefs = output.payload['source_refs']! as List;
        expect(sourceRefs, isNotEmpty);
        expect((sourceRefs.single as Map)['kind'], 'event');
        expect((sourceRefs.single as Map)['id'], capture.id);
      }
      expect(outputs.first.payload['state'], 'proposed');

      final traces = await traceSink.readAll();
      final traceNames = traces.map((trace) => trace.name).toList();
      expect(traceNames, contains('runtime.event.appended'));
      expect(traceNames, contains('runtime.task.created'));
      expect(traceNames, contains('runtime.run.started'));
      expect(
        traceNames.where((name) => name == 'runtime.handler.output'),
        hasLength(4),
      );
      expect(traceNames, contains('runtime.run.completed'));

      final taskTrace = traces.singleWhere(
        (trace) => trace.name == 'runtime.task.created',
      );
      expect(taskTrace.eventId, capture.id);
      expect(taskTrace.taskId, task.id);
      expect(taskTrace.packId, task.packId);
      expect(taskTrace.agentId, task.agentId);

      final runStartedTrace = traces.singleWhere(
        (trace) => trace.name == 'runtime.run.started',
      );
      expect(runStartedTrace.taskId, task.id);
      expect(runStartedTrace.runId, run.id);

      final outputTraces = traces
          .where((trace) => trace.name == 'runtime.handler.output')
          .toList();
      expect(outputTraces.map((trace) => trace.eventId), run.outputEventIds);
      expect(
        outputTraces.map((trace) => trace.details['type']),
        outputs.map((event) => event.type),
      );
      expect(outputTraces.map((trace) => trace.taskId), everyElement(task.id));
      expect(outputTraces.map((trace) => trace.runId), everyElement(run.id));

      final completedTrace = traces.singleWhere(
        (trace) => trace.name == 'runtime.run.completed',
      );
      expect(completedTrace.taskId, task.id);
      expect(completedTrace.runId, run.id);
      expect(completedTrace.details['output_event_count'], 4);
    },
  );

  test('derived output with malformed source refs is rejected', () async {
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
      });
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final kernel = _kernel(
      store: store,
      traceSink: traceSink,
      permissions: permissions,
      model: FakeModel(),
      handler: const _MalformedSourceRefsHandler(),
    );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'Bad refs should fail.'},
      ),
    );

    expect(await store.readByType(WnEventTypes.insightCreated), isEmpty);
    expect(kernel.tasks.single.status, RuntimeTaskStatus.failed);
    expect(kernel.runs.single.status, RuntimeRunStatus.failed);
    expect(kernel.runs.single.error, contains('without valid source refs'));

    final rejected = (await traceSink.readAll()).singleWhere(
      (trace) =>
          trace.name == 'runtime.handler.output_rejected' &&
          trace.details['error_code'] == 'invalid_source_refs',
    );
    expect(rejected.details['event_type'], WnEventTypes.insightCreated);
  });

  test('unmatched event appends without creating a task or run', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
      });
    final handler = _CountingHandler();
    final kernel = _kernel(
      store: store,
      traceSink: traceSink,
      permissions: permissions,
      model: FakeModel(),
      handler: handler,
    );

    await kernel.publish(
      const WnEventDraft(
        type: 'wn.capture.ignored',
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'No pack subscribes to this.'},
      ),
    );

    final events = await store.readAll();
    final traces = await traceSink.readAll();

    expect(events.single.type, 'wn.capture.ignored');
    expect(handler.calls, 0);
    expect(kernel.tasks, isEmpty);
    expect(kernel.runs, isEmpty);
    expect(traces.map((trace) => trace.name), ['runtime.event.appended']);
  });

  test('multiple packs subscribed to one event both run', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final kernel = _blankKernel(store: store, traceSink: traceSink);
    kernel
      ..registerPack(
        const AgentPack(
          id: 'pack.alpha',
          name: 'Alpha pack',
          version: '0.1.0',
          subscriptions: <Subscription>[
            Subscription(
              id: 'sub.alpha',
              agentId: 'agent.alpha',
              eventTypes: <String>{WnEventTypes.captureCreated},
            ),
          ],
          agentDefinitions: <String, AgentDefinition>{
            'agent.alpha': AgentDefinition(
              id: 'agent.alpha',
              outputEvents: <String>{WnEventTypes.insightCreated},
            ),
          },
          agents: <String, AgentHandler>{
            'agent.alpha': _NamedInsightHandler('alpha'),
          },
        ),
      )
      ..registerPack(
        const AgentPack(
          id: 'pack.beta',
          name: 'Beta pack',
          version: '0.1.0',
          subscriptions: <Subscription>[
            Subscription(
              id: 'sub.beta',
              agentId: 'agent.beta',
              eventTypes: <String>{WnEventTypes.captureCreated},
            ),
          ],
          agentDefinitions: <String, AgentDefinition>{
            'agent.beta': AgentDefinition(
              id: 'agent.beta',
              outputEvents: <String>{WnEventTypes.insightCreated},
            ),
          },
          agents: <String, AgentHandler>{
            'agent.beta': _NamedInsightHandler('beta'),
          },
        ),
      );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'Fan out to both packs.'},
      ),
    );

    final insights = await store.readByType(WnEventTypes.insightCreated);

    expect(kernel.tasks, hasLength(2));
    expect(kernel.runs, hasLength(2));
    expect(
      kernel.runs.map((run) => run.status),
      everyElement(RuntimeRunStatus.succeeded),
    );
    expect(insights.map((event) => event.packId), ['pack.alpha', 'pack.beta']);
    expect(insights.map((event) => event.payload['source']), ['alpha', 'beta']);
  });

  test('event and output privacy tiers are materialized from drafts', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final kernel = _blankKernel(store: store, traceSink: traceSink);
    kernel.registerPack(
      const AgentPack(
        id: 'pack.privacy',
        name: 'Privacy pack',
        version: '0.1.0',
        subscriptions: <Subscription>[
          Subscription(
            id: 'sub.privacy',
            agentId: 'agent.privacy',
            eventTypes: <String>{WnEventTypes.captureCreated},
          ),
        ],
        agentDefinitions: <String, AgentDefinition>{
          'agent.privacy': AgentDefinition(
            id: 'agent.privacy',
            outputEvents: <String>{WnEventTypes.insightCreated},
          ),
        },
        agents: <String, AgentHandler>{'agent.privacy': _PrivacyEchoHandler()},
      ),
    );

    final capture = await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        privacy: WnPrivacy.encryptedSync,
        payload: <String, Object?>{'text': 'Preserve privacy tier.'},
      ),
    );

    final events = await store.readAll();
    final output = events.singleWhere(
      (event) => event.type == WnEventTypes.insightCreated,
    );

    expect(capture.privacy, WnPrivacy.encryptedSync);
    expect(capture.toJson()['privacy'], WnPrivacy.encryptedSync.wireName);
    expect(output.privacy, WnPrivacy.encryptedSync);
    expect(output.toJson()['privacy'], WnPrivacy.encryptedSync.wireName);
    expect(output.causationId, capture.id);
    expect(output.correlationId, capture.id);
  });

  test('default and todo packs keep output ownership separated', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final model = FakeModel(responses: <String>['official summary']);
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
      })
      ..grantAll('pack.todo', <String>{
        ModelPermissions.complete,
        'todo.suggest',
      });
    final kernel = _blankKernel(
      store: store,
      traceSink: traceSink,
      model: model,
      permissions: permissions,
    );
    kernel
      ..registerPack(
        const AgentPack(
          id: 'pack.default',
          name: 'Default capture loop',
          version: '0.1.0',
          requiredPermissions: <String>{
            ModelPermissions.complete,
            'memory.propose',
            'card.write',
            'insight.write',
          },
          subscriptions: <Subscription>[
            Subscription(
              id: 'sub.capture_created',
              agentId: 'agent.capture_loop',
              eventTypes: <String>{WnEventTypes.captureCreated},
            ),
          ],
          agentDefinitions: <String, AgentDefinition>{
            'agent.capture_loop': AgentDefinition(
              id: 'agent.capture_loop',
              requiredPermissions: <String>{
                ModelPermissions.complete,
                'memory.propose',
                'card.write',
                'insight.write',
              },
              outputEvents: <String>{
                WnEventTypes.memoryProposed,
                WnEventTypes.cardCreated,
                WnEventTypes.insightCreated,
              },
            ),
          },
          agents: <String, AgentHandler>{
            'agent.capture_loop': _DefaultPackHandler(),
          },
        ),
      )
      ..registerPack(
        const AgentPack(
          id: 'pack.todo',
          name: 'Todo extraction loop',
          version: '0.1.0',
          requiredPermissions: <String>{
            ModelPermissions.complete,
            'todo.suggest',
          },
          subscriptions: <Subscription>[
            Subscription(
              id: 'sub.todo_capture_created',
              agentId: 'agent.todo_loop',
              eventTypes: <String>{WnEventTypes.captureCreated},
            ),
          ],
          agentDefinitions: <String, AgentDefinition>{
            'agent.todo_loop': AgentDefinition(
              id: 'agent.todo_loop',
              requiredPermissions: <String>{
                ModelPermissions.complete,
                'todo.suggest',
              },
              outputEvents: <String>{WnEventTypes.todoSuggested},
            ),
          },
          agents: <String, AgentHandler>{'agent.todo_loop': _TodoPackHandler()},
        ),
      );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        subjectRef: SubjectRef(kind: 'capture', id: 'capture-official'),
        payload: <String, Object?>{'text': 'Keep official packs separate.'},
      ),
    );

    final outputs = (await store.readAll()).skip(1).toList(growable: false);

    expect(model.requests, hasLength(1));
    expect(
      outputs
          .where((event) => event.packId == 'pack.default')
          .map((event) => event.type),
      <String>[
        WnEventTypes.memoryProposed,
        WnEventTypes.cardCreated,
        WnEventTypes.insightCreated,
      ],
    );
    expect(
      outputs.where((event) => event.packId == 'pack.todo').map((event) {
        return event.type;
      }),
      <String>[WnEventTypes.todoSuggested],
    );
    expect(
      outputs
          .where((event) => event.type == WnEventTypes.todoSuggested)
          .single
          .agentId,
      'agent.todo_loop',
    );
    expect(kernel.runs.map((run) => run.packId), ['pack.default', 'pack.todo']);
  });

  test(
    'missing pack permission creates denied run without handler output',
    () async {
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final handler = _CountingHandler();
      final kernel = _kernel(
        store: store,
        traceSink: traceSink,
        permissions: InMemoryPermissionBroker(),
        model: FakeModel(),
        handler: handler,
      );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
          payload: <String, Object?>{'text': 'Needs permission.'},
        ),
      );

      final events = await store.readAll();
      final traces = await traceSink.readAll();

      expect(handler.calls, 0);
      expect(events, hasLength(1));
      expect(kernel.tasks.single.status, RuntimeTaskStatus.denied);
      expect(kernel.runs.single.status, RuntimeRunStatus.denied);
      expect(
        traces.map((trace) => trace.name),
        contains('runtime.permission.denied'),
      );
    },
  );

  test(
    'missing declared model permission denies before the handler runs',
    () async {
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final model = FakeModel(responses: <String>['should not be called']);
      final kernel =
          _blankKernel(
            store: store,
            traceSink: traceSink,
            permissions: InMemoryPermissionBroker(),
            model: model,
          )..registerPack(
            const AgentPack(
              id: 'pack.model',
              name: 'Model pack',
              version: '0.1.0',
              requiredPermissions: <String>{ModelPermissions.complete},
              subscriptions: <Subscription>[
                Subscription(
                  id: 'sub.model',
                  agentId: 'agent.model',
                  eventTypes: <String>{WnEventTypes.captureCreated},
                ),
              ],
              agentDefinitions: <String, AgentDefinition>{
                'agent.model': AgentDefinition(
                  id: 'agent.model',
                  requiredPermissions: <String>{ModelPermissions.complete},
                  outputEvents: <String>{WnEventTypes.insightCreated},
                ),
              },
              agents: <String, AgentHandler>{
                'agent.model': _ModelUsingHandler(),
              },
            ),
          );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
          payload: <String, Object?>{'text': 'No model grant.'},
        ),
      );

      final events = await store.readAll();
      final traces = await traceSink.readAll();
      final traceNames = traces.map((trace) => trace.name).toList();

      expect(events, hasLength(1));
      expect(model.requests, isEmpty);
      expect(kernel.tasks.single.status, RuntimeTaskStatus.denied);
      expect(kernel.runs.single.status, RuntimeRunStatus.denied);
      expect(traceNames, contains('runtime.task.created'));
      expect(traceNames, contains('runtime.permission.denied'));
      expect(traceNames, isNot(contains('runtime.run.started')));
      expect(traceNames, isNot(contains('runtime.run.failed')));
      expect(traceNames, isNot(contains('runtime.handler.output')));

      final deniedTrace = traces.singleWhere(
        (trace) => trace.name == 'runtime.permission.denied',
      );
      expect(deniedTrace.taskId, kernel.tasks.single.id);
      expect(deniedTrace.runId, kernel.runs.single.id);
      expect(deniedTrace.details['missing_permissions'], <String>[
        ModelPermissions.complete,
      ]);
    },
  );

  test('model.complete is permission checked at call time', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final model = FakeModel(responses: <String>['should not be used']);
    final kernel =
        _blankKernel(
          store: store,
          traceSink: traceSink,
          model: model,
        )..registerPack(
          const AgentPack(
            id: 'pack.model',
            name: 'Model pack',
            version: '0.1.0',
            subscriptions: <Subscription>[
              Subscription(
                id: 'sub.model',
                agentId: 'agent.model',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
            ],
            agentDefinitions: <String, AgentDefinition>{
              'agent.model': AgentDefinition(
                id: 'agent.model',
                outputEvents: <String>{WnEventTypes.insightCreated},
              ),
            },
            agents: <String, AgentHandler>{'agent.model': _ModelUsingHandler()},
          ),
        );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'Needs model permission.'},
      ),
    );

    final events = await store.readAll();
    final traces = await traceSink.readAll();

    expect(events, hasLength(1));
    expect(model.requests, isEmpty);
    expect(kernel.tasks.single.status, RuntimeTaskStatus.denied);
    expect(kernel.runs.single.status, RuntimeRunStatus.denied);
    expect(kernel.runs.single.error, contains(ModelPermissions.complete));
    final deniedTrace = traces.singleWhere(
      (trace) => trace.name == 'runtime.permission.denied',
    );
    expect(deniedTrace.details['missing_permissions'], <String>[
      ModelPermissions.complete,
    ]);
  });

  test('model traces usage metadata with raw prompt and response', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final model = _UsageModel();
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.model', <String>{ModelPermissions.complete});
    final kernel =
        _blankKernel(
          store: store,
          traceSink: traceSink,
          model: model,
          permissions: permissions,
        )..registerPack(
          const AgentPack(
            id: 'pack.model',
            name: 'Model pack',
            version: '0.1.0',
            subscriptions: <Subscription>[
              Subscription(
                id: 'sub.model',
                agentId: 'agent.model',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
            ],
            agentDefinitions: <String, AgentDefinition>{
              'agent.model': AgentDefinition(
                id: 'agent.model',
                requiredPermissions: <String>{ModelPermissions.complete},
                outputEvents: <String>{WnEventTypes.insightCreated},
              ),
            },
            agents: <String, AgentHandler>{'agent.model': _ModelUsingHandler()},
          ),
        );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'Trace usage only.'},
      ),
    );

    final traces = await traceSink.readAll();
    final requested = traces.singleWhere(
      (trace) => trace.name == 'runtime.model.requested',
    );
    final completed = traces.singleWhere(
      (trace) => trace.name == 'runtime.model.completed',
    );

    expect(requested.details['prompt_length'], 'Use a model.'.length);
    expect(requested.details['raw_prompt'], 'Use a model.');
    expect(completed.details['provider_id'], 'fake.byok');
    expect(completed.details['model'], 'fake-large');
    expect(completed.details['input_tokens'], 11);
    expect(completed.details['output_tokens'], 7);
    expect(completed.details['total_tokens'], 18);
    expect(completed.details['estimated_cost_usd'], 0.0042);
    expect(completed.details['raw_prompt'], 'Use a model.');
    expect(completed.details['raw_model_response'], 'usage visible');
  });

  test('agent tool invocation is permission checked', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
        'tool.echo',
      });
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'echo',
          description: 'Returns input for tests.',
          requiredPermissions: const <String>{'tool.echo'},
          handler: (invocation) async => <String, Object?>{
            'echo': invocation.input['value'],
          },
        ),
      );
    final kernel = _kernel(
      store: store,
      traceSink: traceSink,
      permissions: permissions,
      model: FakeModel(),
      tools: tools,
      handler: const _ToolUsingHandler(),
    );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'hello'},
      ),
    );

    final insights = await store.readByType(WnEventTypes.insightCreated);
    expect(insights.single.payload['tool_echo'], 'hello');

    final traces = await traceSink.readAll();
    final requested = traces.singleWhere(
      (trace) => trace.name == 'runtime.tool.requested',
    );
    final completed = traces.singleWhere(
      (trace) => trace.name == 'runtime.tool.completed',
    );
    expect(requested.details['raw_tool_input'], <String, Object?>{
      'value': 'hello',
    });
    expect(completed.details['result_keys'], <String>['echo']);
    expect(completed.details['raw_tool_result'], <String, Object?>{
      'echo': 'hello',
    });
  });

  test('handler failure marks task and run failed with error trace', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
      });
    final kernel = _kernel(
      store: store,
      traceSink: traceSink,
      permissions: permissions,
      model: FakeModel(),
      handler: const _ThrowingHandler(),
    );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'boom'},
      ),
    );

    expect(kernel.tasks.single.status, RuntimeTaskStatus.failed);
    expect(kernel.runs.single.status, RuntimeRunStatus.failed);
    expect(kernel.runs.single.error, contains('handler exploded'));

    final traces = await traceSink.readAll();
    final failedTrace = traces.singleWhere(
      (trace) => trace.name == 'runtime.run.failed',
    );
    expect(failedTrace.level, TraceLevel.error);
    expect(failedTrace.details['error'], contains('handler exploded'));
  });

  test(
    'missing native handler creates terminal failure without output',
    () async {
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final kernel = _blankKernel(store: store, traceSink: traceSink);
      kernel.registerPack(
        const AgentPack(
          id: 'pack.default',
          name: 'Missing handler pack',
          version: '0.1.0',
          subscriptions: <Subscription>[
            Subscription(
              id: 'sub.capture',
              agentId: 'agent.missing',
              eventTypes: <String>{WnEventTypes.captureCreated},
            ),
          ],
          agentDefinitions: <String, AgentDefinition>{
            'agent.missing': AgentDefinition(
              id: 'agent.missing',
              outputEvents: <String>{WnEventTypes.insightCreated},
            ),
          },
          agents: <String, AgentHandler>{},
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
      final traces = await traceSink.readAll();
      expect(
        traces.map((trace) => trace.name),
        contains('runtime.handler.missing'),
      );
      expect(traces.map((trace) => trace.name), contains('runtime.run.failed'));
    },
  );

  test('tool permission denial is returned to the handler', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
      });
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'secret',
          description: 'Requires an extra permission.',
          requiredPermissions: const <String>{'tool.secret'},
          handler: (invocation) async => const <String, Object?>{'ok': true},
        ),
      );
    final kernel = _kernel(
      store: store,
      traceSink: traceSink,
      permissions: permissions,
      model: FakeModel(),
      tools: tools,
      handler: const _ToolDeniedHandler(),
    );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    final insights = await store.readByType(WnEventTypes.insightCreated);
    expect(insights.single.payload['tool_error'], 'permission_denied');
    expect(kernel.runs.single.status, RuntimeRunStatus.succeeded);
  });

  test('tool_not_found is returned to the handler', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
      });
    final kernel = _kernel(
      store: store,
      traceSink: traceSink,
      permissions: permissions,
      model: FakeModel(),
      handler: const _ToolMissingHandler(),
    );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    final insights = await store.readByType(WnEventTypes.insightCreated);
    expect(insights.single.payload['tool_error'], 'tool_not_found');
    expect(kernel.runs.single.status, RuntimeRunStatus.succeeded);
  });

  test('empty handler result still completes task and run', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
      });
    final kernel = _kernel(
      store: store,
      traceSink: traceSink,
      permissions: permissions,
      model: FakeModel(),
      handler: const _EmptyHandler(),
    );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    final events = await store.readAll();
    expect(events, hasLength(1));
    expect(kernel.tasks.single.status, RuntimeTaskStatus.succeeded);
    expect(kernel.runs.single.status, RuntimeRunStatus.succeeded);
    expect(kernel.runs.single.outputEventIds, isEmpty);
  });

  test('trace readByRun filters traces to one run', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final permissions = InMemoryPermissionBroker()
      ..grantAll('pack.default', <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
      });
    final kernel = _kernel(
      store: store,
      traceSink: traceSink,
      permissions: permissions,
      model: FakeModel(responses: <String>['trace summary']),
      handler: const _CaptureProjectionHandler(),
    );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'Trace this run.'},
      ),
    );

    final runId = kernel.runs.single.id;
    final runTraces = await traceSink.readByRun(runId);

    expect(runTraces, isNotEmpty);
    expect(runTraces.map((trace) => trace.runId), everyElement(runId));
    expect(
      runTraces.map((trace) => trace.name),
      containsAll(<String>[
        'runtime.run.started',
        'runtime.handler.output',
        'runtime.run.completed',
      ]),
    );
    expect(await traceSink.readByRun('missing-run'), isEmpty);
  });

  test('publish can enqueue tasks without draining immediately', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final kernel =
        _blankKernel(store: store, traceSink: traceSink, autoDrain: false)
          ..registerPack(
            const AgentPack(
              id: 'pack.queue',
              name: 'Queued pack',
              version: '0.1.0',
              subscriptions: <Subscription>[
                Subscription(
                  id: 'sub.queue',
                  agentId: 'agent.queue',
                  eventTypes: <String>{WnEventTypes.captureCreated},
                ),
              ],
              agentDefinitions: <String, AgentDefinition>{
                'agent.queue': AgentDefinition(
                  id: 'agent.queue',
                  outputEvents: <String>{WnEventTypes.insightCreated},
                ),
              },
              agents: <String, AgentHandler>{
                'agent.queue': _NamedInsightHandler('queue'),
              },
            ),
          );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    expect((await store.readAll()).map((event) => event.type), <String>[
      WnEventTypes.captureCreated,
    ]);
    expect(kernel.tasks.single.status, RuntimeTaskStatus.queued);
    expect(kernel.runs, isEmpty);
    expect(kernel.packStatuses.single.status, RuntimePackStatusKind.queued);

    expect(await kernel.drainQueue(), 1);

    expect(kernel.tasks.single.status, RuntimeTaskStatus.succeeded);
    expect(kernel.runs.single.status, RuntimeRunStatus.succeeded);
    expect(kernel.packStatuses.single.status, RuntimePackStatusKind.succeeded);
    expect(await store.readByType(WnEventTypes.insightCreated), hasLength(1));
  });

  test('disabled pack does not enqueue new matching tasks', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final runtimeStore = InMemoryRuntimeStore();
    await runtimeStore.upsertPackInstallation(
      RuntimePackInstallation(
        packId: 'pack.disabled',
        status: PackInstallationStatus.disabled,
        updatedAt: DateTime.utc(2026, 6, 23, 1),
        reason: 'user_disabled',
      ),
    );
    final kernel =
        _blankKernel(
          store: store,
          traceSink: traceSink,
          runtimeStore: runtimeStore,
          autoDrain: false,
        )..registerPack(
          const AgentPack(
            id: 'pack.disabled',
            name: 'Disabled pack',
            version: '0.1.0',
            subscriptions: <Subscription>[
              Subscription(
                id: 'sub.disabled',
                agentId: 'agent.disabled',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
            ],
            agentDefinitions: <String, AgentDefinition>{
              'agent.disabled': AgentDefinition(
                id: 'agent.disabled',
                outputEvents: <String>{WnEventTypes.insightCreated},
              ),
            },
            agents: <String, AgentHandler>{
              'agent.disabled': _NamedInsightHandler('disabled'),
            },
          ),
        );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    expect(kernel.tasks, isEmpty);
    expect(kernel.runs, isEmpty);
    expect(await store.readAll(), hasLength(1));
    final trace = (await traceSink.readAll()).singleWhere(
      (candidate) => candidate.name == 'runtime.pack.disabled_at_enqueue',
    );
    expect(trace.details['error_code'], 'pack_disabled');
    expect(trace.details['reason'], 'user_disabled');
  });

  test(
    'pending task is denied when pack is disabled before execution',
    () async {
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final runtimeStore = InMemoryRuntimeStore();
      final kernel =
          _blankKernel(
            store: store,
            traceSink: traceSink,
            runtimeStore: runtimeStore,
            autoDrain: false,
          )..registerPack(
            const AgentPack(
              id: 'pack.disable_pending',
              name: 'Disable pending pack',
              version: '0.1.0',
              subscriptions: <Subscription>[
                Subscription(
                  id: 'sub.disable_pending',
                  agentId: 'agent.disable_pending',
                  eventTypes: <String>{WnEventTypes.captureCreated},
                ),
              ],
              agentDefinitions: <String, AgentDefinition>{
                'agent.disable_pending': AgentDefinition(
                  id: 'agent.disable_pending',
                  outputEvents: <String>{WnEventTypes.insightCreated},
                ),
              },
              agents: <String, AgentHandler>{
                'agent.disable_pending': _NamedInsightHandler(
                  'disable-pending',
                ),
              },
            ),
          );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );
      expect(kernel.tasks.single.status, RuntimeTaskStatus.queued);

      await runtimeStore.upsertPackInstallation(
        RuntimePackInstallation(
          packId: 'pack.disable_pending',
          status: PackInstallationStatus.disabled,
          updatedAt: DateTime.utc(2026, 6, 23, 1, 1),
          reason: 'disabled_between_enqueue_and_execution',
        ),
      );

      expect(await kernel.drainQueue(), 1);
      expect(kernel.tasks.single.status, RuntimeTaskStatus.denied);
      expect(kernel.runs.single.status, RuntimeRunStatus.denied);
      expect(await store.readByType(WnEventTypes.insightCreated), isEmpty);
      final trace = (await traceSink.readAll()).singleWhere(
        (candidate) => candidate.name == 'runtime.pack.disabled_at_execution',
      );
      expect(trace.details['error_code'], 'pack_disabled');
      expect(trace.details['reason'], 'disabled_between_enqueue_and_execution');
    },
  );

  test(
    'pending task is denied when permission is revoked before execution',
    () async {
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final permissions = InMemoryPermissionBroker()
        ..grant('pack.revoke_pending', 'memory.propose');
      final kernel =
          _blankKernel(
            store: store,
            traceSink: traceSink,
            permissions: permissions,
            autoDrain: false,
          )..registerPack(
            const AgentPack(
              id: 'pack.revoke_pending',
              name: 'Revoke pending pack',
              version: '0.1.0',
              requiredPermissions: <String>{'memory.propose'},
              subscriptions: <Subscription>[
                Subscription(
                  id: 'sub.revoke_pending',
                  agentId: 'agent.revoke_pending',
                  eventTypes: <String>{WnEventTypes.captureCreated},
                ),
              ],
              agentDefinitions: <String, AgentDefinition>{
                'agent.revoke_pending': AgentDefinition(
                  id: 'agent.revoke_pending',
                  requiredPermissions: <String>{'memory.propose'},
                  outputEvents: <String>{WnEventTypes.memoryProposed},
                ),
              },
              agents: <String, AgentHandler>{
                'agent.revoke_pending': _EmptyHandler(),
              },
            ),
          );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );
      expect(kernel.tasks.single.status, RuntimeTaskStatus.queued);

      permissions.revoke(
        'pack.revoke_pending',
        'memory.propose',
        reason: 'user_revoked_after_enqueue',
      );

      expect(await kernel.drainQueue(), 1);
      expect(kernel.tasks.single.status, RuntimeTaskStatus.denied);
      expect(kernel.runs.single.status, RuntimeRunStatus.denied);
      final deniedTrace = (await traceSink.readAll()).singleWhere(
        (trace) => trace.name == 'runtime.permission.denied',
      );
      expect(deniedTrace.details['missing_permissions'], <String>[
        'memory.propose',
      ]);
    },
  );

  test(
    'dependencies run after prerequisite subscriptions even when listed first',
    () async {
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final order = <String>[];
      final kernel = _blankKernel(store: store, traceSink: traceSink)
        ..registerPack(
          AgentPack(
            id: 'pack.deps',
            name: 'Dependency pack',
            version: '0.1.0',
            subscriptions: const <Subscription>[
              Subscription(
                id: 'sub.finalize',
                agentId: 'agent.finalize',
                eventTypes: <String>{WnEventTypes.captureCreated},
                dependsOn: <String>{'sub.prepare'},
              ),
              Subscription(
                id: 'sub.prepare',
                agentId: 'agent.prepare',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
            ],
            agentDefinitions: const <String, AgentDefinition>{
              'agent.finalize': AgentDefinition(
                id: 'agent.finalize',
                outputEvents: <String>{WnEventTypes.insightCreated},
              ),
              'agent.prepare': AgentDefinition(
                id: 'agent.prepare',
                outputEvents: <String>{WnEventTypes.insightCreated},
              ),
            },
            agents: <String, AgentHandler>{
              'agent.finalize': _OrderRecordingHandler('finalize', order),
              'agent.prepare': _OrderRecordingHandler('prepare', order),
            },
          ),
        );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );

      expect(order, <String>['prepare', 'finalize']);
      expect(
        kernel.tasks.map((task) => task.status),
        everyElement(RuntimeTaskStatus.succeeded),
      );
      expect(kernel.tasks.first.dependencyTaskIds, <String>[
        kernel.tasks.last.id,
      ]);
      final traces = await traceSink.readAll();
      expect(
        traces.map((trace) => trace.name),
        contains('runtime.task.waiting'),
      );
    },
  );

  test(
    'failed task retries with a fake executor until retry policy is exhausted',
    () async {
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final handler = _FailsOnceHandler();
      final kernel = _blankKernel(store: store, traceSink: traceSink)
        ..registerPack(
          AgentPack(
            id: 'pack.retry',
            name: 'Retry pack',
            version: '0.1.0',
            subscriptions: const <Subscription>[
              Subscription(
                id: 'sub.retry',
                agentId: 'agent.retry',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
            ],
            agentDefinitions: const <String, AgentDefinition>{
              'agent.retry': AgentDefinition(
                id: 'agent.retry',
                outputEvents: <String>{WnEventTypes.insightCreated},
                retryPolicy: RetryPolicy(maxAttempts: 2),
              ),
            },
            agents: <String, AgentHandler>{'agent.retry': handler},
          ),
        );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );

      expect(handler.calls, 2);
      expect(kernel.tasks.single.status, RuntimeTaskStatus.succeeded);
      expect(kernel.tasks.single.attempts, 2);
      expect(kernel.runs.map((run) => run.status), <RuntimeRunStatus>[
        RuntimeRunStatus.failed,
        RuntimeRunStatus.succeeded,
      ]);
      final traces = await traceSink.readAll();
      expect(
        traces.map((trace) => trace.name),
        contains('runtime.task.retry_queued'),
      );
    },
  );

  test('queued task can be canceled before the fake executor runs', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final handler = _CountingHandler();
    final kernel =
        _blankKernel(store: store, traceSink: traceSink, autoDrain: false)
          ..registerPack(
            AgentPack(
              id: 'pack.cancel',
              name: 'Cancelable pack',
              version: '0.1.0',
              subscriptions: const <Subscription>[
                Subscription(
                  id: 'sub.cancel',
                  agentId: 'agent.cancel',
                  eventTypes: <String>{WnEventTypes.captureCreated},
                ),
              ],
              agents: <String, AgentHandler>{'agent.cancel': handler},
            ),
          );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    expect(await kernel.cancelTask(kernel.tasks.single.id), isTrue);
    expect(await kernel.drainQueue(), 0);
    expect(handler.calls, 0);
    expect(kernel.tasks.single.status, RuntimeTaskStatus.canceled);
    expect(kernel.runs, isEmpty);
    expect(kernel.packStatuses.single.status, RuntimePackStatusKind.canceled);
    final traces = await traceSink.readAll();
    expect(
      traces.map((trace) => trace.name),
      contains('runtime.task.canceled'),
    );
  });

  test('queued durable task restores after restart and drains once', () async {
    final eventStore = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final runtimeStore = InMemoryRuntimeStore();
    final pack = AgentPack(
      id: 'pack.restart',
      name: 'Restart pack',
      version: '1.2.3',
      subscriptions: const <Subscription>[
        Subscription(
          id: 'sub.restart',
          agentId: 'agent.restart',
          eventTypes: <String>{WnEventTypes.captureCreated},
        ),
      ],
      agentDefinitions: const <String, AgentDefinition>{
        'agent.restart': AgentDefinition(
          id: 'agent.restart',
          outputEvents: <String>{WnEventTypes.insightCreated},
        ),
      },
      agents: const <String, AgentHandler>{
        'agent.restart': _NamedInsightHandler('restart'),
      },
    );
    final firstKernel = _blankKernel(
      store: eventStore,
      traceSink: traceSink,
      runtimeStore: runtimeStore,
      autoDrain: false,
    )..registerPack(pack);

    final capture = await firstKernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
        payload: <String, Object?>{'text': 'survive restart'},
      ),
    );

    final queuedTask = (await runtimeStore.readTasks()).single;
    expect(queuedTask.status, RuntimeTaskStatus.queued);
    expect(queuedTask.packVersion, '1.2.3');
    expect(queuedTask.identityKey, contains(capture.id));
    expect(queuedTask.identityKey, contains('pack.restart'));
    expect(queuedTask.identityKey, contains('1.2.3'));
    expect(queuedTask.identityKey, contains('sub.restart'));
    expect(queuedTask.identityKey, contains('agent.restart'));

    final restartedKernel = _blankKernel(
      store: eventStore,
      traceSink: traceSink,
      runtimeStore: runtimeStore,
      idGenerator: SequenceWnIdGenerator(seed: 'restart', startAt: 100),
    )..registerPack(pack);
    await restartedKernel.restoreRuntimeState();

    expect(restartedKernel.tasks.single.id, queuedTask.id);
    expect(await restartedKernel.drainQueue(), 1);
    expect(await restartedKernel.drainQueue(), 0);

    final events = await eventStore.readAll();
    expect(events.map((event) => event.type), <String>[
      WnEventTypes.captureCreated,
      WnEventTypes.insightCreated,
    ]);
    expect(
      await eventStore.readByType(WnEventTypes.insightCreated),
      hasLength(1),
    );
    expect(
      (await runtimeStore.readTaskById(queuedTask.id))?.status,
      RuntimeTaskStatus.succeeded,
    );
  });

  test(
    'restore preserves terminal task states and terminates stale running run',
    () async {
      final runtimeStore = InMemoryRuntimeStore();
      final now = DateTime.utc(2026, 6, 23, 1);
      await runtimeStore.upsertTask(
        _taskFixture(id: 'task-failed', status: RuntimeTaskStatus.failed),
      );
      await runtimeStore.upsertTask(
        _taskFixture(id: 'task-denied', status: RuntimeTaskStatus.denied),
      );
      await runtimeStore.upsertTask(
        _taskFixture(id: 'task-canceled', status: RuntimeTaskStatus.canceled),
      );
      await runtimeStore.upsertTask(
        _taskFixture(id: 'task-blocked', status: RuntimeTaskStatus.blocked),
      );
      await runtimeStore.upsertTask(
        _taskFixture(id: 'task-running', status: RuntimeTaskStatus.running),
      );
      await runtimeStore.upsertRun(
        _runFixture(
          id: 'run-running',
          taskId: 'task-running',
          status: RuntimeRunStatus.running,
          startedAt: now.subtract(const Duration(hours: 1)),
          leaseExpiresAt: now.subtract(const Duration(minutes: 30)),
        ),
      );

      final kernel =
          _blankKernel(
            store: InMemoryEventStore(),
            traceSink: InMemoryTraceSink(),
            runtimeStore: runtimeStore,
            clock: FixedWnClock(now),
          )..registerPack(
            const AgentPack(
              id: 'pack.restore',
              name: 'Restore pack',
              version: '1.0.0',
              subscriptions: <Subscription>[],
              agents: <String, AgentHandler>{},
            ),
          );

      await kernel.restoreRuntimeState();
      expect(await kernel.drainQueue(), 0);

      expect(
        (await runtimeStore.readTaskById('task-failed'))?.status,
        RuntimeTaskStatus.failed,
      );
      expect(
        (await runtimeStore.readTaskById('task-denied'))?.status,
        RuntimeTaskStatus.denied,
      );
      expect(
        (await runtimeStore.readTaskById('task-canceled'))?.status,
        RuntimeTaskStatus.canceled,
      );
      expect(
        (await runtimeStore.readTaskById('task-blocked'))?.status,
        RuntimeTaskStatus.blocked,
      );
      expect(
        (await runtimeStore.readTaskById('task-running'))?.status,
        RuntimeTaskStatus.failed,
      );
      expect(
        (await runtimeStore.readRunById('run-running'))?.status,
        RuntimeRunStatus.failed,
      );
    },
  );

  test('dependent task is blocked when prerequisite fails', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final runtimeStore = InMemoryRuntimeStore();
    final finalizeHandler = _CountingHandler();
    final kernel =
        _blankKernel(
          store: store,
          traceSink: traceSink,
          runtimeStore: runtimeStore,
        )..registerPack(
          AgentPack(
            id: 'pack.dependency-failure',
            name: 'Dependency failure pack',
            version: '0.1.0',
            subscriptions: const <Subscription>[
              Subscription(
                id: 'sub.prepare',
                agentId: 'agent.prepare',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
              Subscription(
                id: 'sub.finalize',
                agentId: 'agent.finalize',
                eventTypes: <String>{WnEventTypes.captureCreated},
                dependsOn: <String>{'sub.prepare'},
              ),
            ],
            agentDefinitions: const <String, AgentDefinition>{
              'agent.prepare': AgentDefinition(
                id: 'agent.prepare',
                outputEvents: <String>{WnEventTypes.insightCreated},
              ),
              'agent.finalize': AgentDefinition(
                id: 'agent.finalize',
                outputEvents: <String>{WnEventTypes.insightCreated},
              ),
            },
            agents: <String, AgentHandler>{
              'agent.prepare': const _ThrowingHandler(),
              'agent.finalize': finalizeHandler,
            },
          ),
        );

    await kernel.publish(
      const WnEventDraft(
        type: WnEventTypes.captureCreated,
        actor: WnActor.user,
      ),
    );

    expect(finalizeHandler.calls, 0);
    expect(kernel.tasks.map((task) => task.status), <RuntimeTaskStatus>[
      RuntimeTaskStatus.failed,
      RuntimeTaskStatus.blocked,
    ]);
    expect(
      (await runtimeStore.readTasks()).map((task) => task.status),
      <RuntimeTaskStatus>[RuntimeTaskStatus.failed, RuntimeTaskStatus.blocked],
    );
    expect(
      (await traceSink.readAll()).map((trace) => trace.name),
      contains('runtime.task.blocked'),
    );
  });

  test(
    'undeclared handler output fails terminally without auto retry or output append',
    () async {
      final store = InMemoryEventStore();
      final traceSink = InMemoryTraceSink();
      final kernel = _blankKernel(store: store, traceSink: traceSink)
        ..registerPack(
          const AgentPack(
            id: 'pack.schema',
            name: 'Schema pack',
            version: '0.1.0',
            subscriptions: <Subscription>[
              Subscription(
                id: 'sub.schema',
                agentId: 'agent.schema',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
            ],
            agentDefinitions: <String, AgentDefinition>{
              'agent.schema': AgentDefinition(
                id: 'agent.schema',
                outputEvents: <String>{WnEventTypes.insightCreated},
                retryPolicy: RetryPolicy(maxAttempts: 2),
              ),
            },
            agents: <String, AgentHandler>{
              'agent.schema': _UndeclaredOutputHandler(),
            },
          ),
        );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );

      expect(await store.readAll(), hasLength(1));
      expect(kernel.tasks.single.status, RuntimeTaskStatus.failed);
      expect(kernel.tasks.single.attempts, 1);
      expect(kernel.runs, hasLength(1));
      expect(kernel.runs.single.status, RuntimeRunStatus.failed);
      expect(
        (await traceSink.readAll()).map((trace) => trace.name),
        contains('runtime.handler.output_rejected'),
      );
    },
  );

  test('appendAll is atomic when a batch contains a duplicate event', () async {
    final store = InMemoryEventStore();
    await store.append(_eventFixture(id: 'evt-1', type: 'wn.test.one'));

    expect(
      () => store.appendAll(<WnEvent>[
        _eventFixture(id: 'evt-2', type: 'wn.test.two'),
        _eventFixture(id: 'evt-1', type: 'wn.test.duplicate'),
        _eventFixture(id: 'evt-3', type: 'wn.test.three'),
      ]),
      throwsStateError,
    );

    expect((await store.readAll()).map((event) => event.id), <String>['evt-1']);
  });

  test(
    'pack registry validates manifest alignment and official guardrails',
    () {
      final registry = InMemoryPackRegistry()
        ..register(
          const AgentPack(
            id: 'pack.default',
            name: 'Default Capture Loop',
            version: '0.1.0',
            requiredPermissions: <String>{
              ModelPermissions.complete,
              'card.write',
              'memory.propose',
              'insight.write',
            },
            subscriptions: <Subscription>[
              Subscription(
                id: 'sub.capture_created',
                agentId: 'agent.capture_loop',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
            ],
            agentDefinitions: <String, AgentDefinition>{
              'agent.capture_loop': AgentDefinition(
                id: 'agent.capture_loop',
                requiredPermissions: <String>{
                  ModelPermissions.complete,
                  'card.write',
                  'memory.propose',
                  'insight.write',
                },
                outputEvents: <String>{
                  WnEventTypes.cardCreated,
                  WnEventTypes.memoryProposed,
                  WnEventTypes.insightCreated,
                },
                retryPolicy: RetryPolicy(maxAttempts: 2),
                modelProfileRef: 'local_or_user_selected_model',
              ),
            },
            agents: <String, AgentHandler>{
              'agent.capture_loop': _DefaultPackHandler(),
            },
          ),
        )
        ..register(
          const AgentPack(
            id: 'pack.todo',
            name: 'Todo Extraction Loop',
            version: '0.1.0',
            requiredPermissions: <String>{
              ModelPermissions.complete,
              'todo.suggest',
            },
            subscriptions: <Subscription>[
              Subscription(
                id: 'sub.todo_capture_created',
                agentId: 'agent.todo_loop',
                eventTypes: <String>{WnEventTypes.captureCreated},
              ),
            ],
            agentDefinitions: <String, AgentDefinition>{
              'agent.todo_loop': AgentDefinition(
                id: 'agent.todo_loop',
                requiredPermissions: <String>{
                  ModelPermissions.complete,
                  'todo.suggest',
                },
                outputEvents: <String>{WnEventTypes.todoSuggested},
                retryPolicy: RetryPolicy(maxAttempts: 2),
              ),
            },
            agents: <String, AgentHandler>{
              'agent.todo_loop': _TodoPackHandler(),
            },
          ),
        );

      expect(
        registry.checkManifestAlignment(_defaultManifest()).isAligned,
        isTrue,
      );

      final badDefault = registry.checkManifestAlignment(
        _defaultManifest(
          outputEvents: const <String>[
            WnEventTypes.memoryProposed,
            WnEventTypes.todoSuggested,
          ],
        ),
      );
      expect(badDefault.isAligned, isFalse);
      expect(
        badDefault.issues.map((issue) => issue.path),
        contains('pack.default.output_events'),
      );

      final badTodo = registry.checkManifestAlignment(
        _todoManifest(
          permissions: const <String>{
            ModelPermissions.complete,
            'todo.suggest',
            'memory.propose',
          },
        ),
      );
      expect(badTodo.isAligned, isFalse);
      expect(
        badTodo.issues.map((issue) => issue.path),
        contains('pack.todo.manifest_permissions'),
      );
    },
  );

  test(
    'permission broker persists decisions and revoke gates queued/future tasks',
    () async {
      final permissionStore = InMemoryPermissionStore();
      final permissions = InMemoryPermissionBroker(store: permissionStore);
      permissions.grant('pack.permission', 'memory.propose');
      expect(
        (await permissions.readDecision(
          'pack.permission',
          'memory.propose',
        ))?.state,
        PermissionDecisionState.granted,
      );
      permissions.deny(
        'pack.permission',
        'memory.propose',
        reason: 'test deny',
      );
      expect(
        (await permissions.readDecision(
          'pack.permission',
          'memory.propose',
        ))?.state,
        PermissionDecisionState.denied,
      );
      permissions.grant('pack.permission', 'memory.propose');

      final runtimeStore = InMemoryRuntimeStore();
      final traceSink = InMemoryTraceSink();
      final kernel =
          _blankKernel(
            store: InMemoryEventStore(),
            traceSink: traceSink,
            permissions: permissions,
            runtimeStore: runtimeStore,
            autoDrain: false,
          )..registerPack(
            const AgentPack(
              id: 'pack.permission',
              name: 'Permission pack',
              version: '0.1.0',
              requiredPermissions: <String>{'memory.propose'},
              subscriptions: <Subscription>[
                Subscription(
                  id: 'sub.permission',
                  agentId: 'agent.permission',
                  eventTypes: <String>{WnEventTypes.captureCreated},
                ),
              ],
              agentDefinitions: <String, AgentDefinition>{
                'agent.permission': AgentDefinition(
                  id: 'agent.permission',
                  requiredPermissions: <String>{'memory.propose'},
                  outputEvents: <String>{WnEventTypes.memoryProposed},
                ),
              },
              agents: <String, AgentHandler>{
                'agent.permission': _EmptyHandler(),
              },
            ),
          );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );
      expect(kernel.tasks.single.status, RuntimeTaskStatus.queued);

      permissions.revoke('pack.permission', 'memory.propose');
      expect(
        (await permissions.readDecision(
          'pack.permission',
          'memory.propose',
        ))?.state,
        PermissionDecisionState.revoked,
      );
      final revokeResult = await kernel.handlePermissionRevoked(
        'pack.permission',
        'memory.propose',
      );
      expect(revokeResult.affectedTaskIds, <String>[kernel.tasks.first.id]);
      expect(revokeResult.contextCacheInvalidationRequested, isTrue);
      expect(kernel.tasks.first.status, RuntimeTaskStatus.denied);
      expect(await kernel.drainQueue(), 0);

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );
      expect(kernel.tasks.last.status, RuntimeTaskStatus.blocked);
      expect(
        (await traceSink.readAll()).map((trace) => trace.name),
        contains('runtime.context_cache.invalidate_requested'),
      );

      final restoredKernel =
          _blankKernel(
            store: InMemoryEventStore(),
            traceSink: InMemoryTraceSink(),
            permissions: permissions,
            runtimeStore: runtimeStore,
            autoDrain: false,
          )..registerPack(
            const AgentPack(
              id: 'pack.permission',
              name: 'Permission pack',
              version: '0.1.0',
              requiredPermissions: <String>{'memory.propose'},
              subscriptions: <Subscription>[
                Subscription(
                  id: 'sub.permission',
                  agentId: 'agent.permission',
                  eventTypes: <String>{WnEventTypes.captureCreated},
                ),
              ],
              agentDefinitions: <String, AgentDefinition>{
                'agent.permission': AgentDefinition(
                  id: 'agent.permission',
                  requiredPermissions: <String>{'memory.propose'},
                  outputEvents: <String>{WnEventTypes.memoryProposed},
                ),
              },
              agents: <String, AgentHandler>{
                'agent.permission': _EmptyHandler(),
              },
            ),
          );
      await restoredKernel.restoreRuntimeState();
      await restoredKernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );
      expect(restoredKernel.tasks.last.status, RuntimeTaskStatus.blocked);
    },
  );

  test(
    'trace details and persisted errors redact sensitive handler failures',
    () async {
      final traceSink = InMemoryTraceSink();
      final kernel =
          _blankKernel(store: InMemoryEventStore(), traceSink: traceSink)
            ..registerPack(
              const AgentPack(
                id: 'pack.trace',
                name: 'Trace pack',
                version: '0.1.0',
                subscriptions: <Subscription>[
                  Subscription(
                    id: 'sub.trace',
                    agentId: 'agent.trace',
                    eventTypes: <String>{WnEventTypes.captureCreated},
                  ),
                ],
                agents: <String, AgentHandler>{
                  'agent.trace': _TraceThrowingHandler(),
                },
              ),
            );

      await kernel.publish(
        const WnEventDraft(
          type: WnEventTypes.captureCreated,
          actor: WnActor.user,
        ),
      );

      final failedTrace = (await traceSink.readAll()).singleWhere(
        (trace) => trace.name == 'runtime.run.failed',
      );
      expect(failedTrace.details['error'], contains('api_key=[redacted]'));
      expect(failedTrace.details['error'], contains('raw_db=[redacted]'));
      expect(failedTrace.details['error'], isNot(contains('super-secret')));
      expect(failedTrace.details['error_type'], 'StateError');
      expect(kernel.tasks.single.error, isNot(contains('super-secret')));
      expect(kernel.runs.single.error, isNot(contains('super-secret')));
    },
  );

  test('script runtime is denied without adding script execution', () async {
    final store = InMemoryEventStore();
    final traceSink = InMemoryTraceSink();
    final kernel = _blankKernel(store: store, traceSink: traceSink)
      ..registerPack(
        const AgentPack(
          id: 'pack.script',
          name: 'Script pack',
          version: '0.1.0',
          subscriptions: <Subscription>[
            Subscription(
              id: 'sub.script',
              agentId: 'agent.script',
              eventTypes: <String>{WnEventTypes.captureCreated},
            ),
          ],
          agentDefinitions: <String, AgentDefinition>{
            'agent.script': AgentDefinition(
              id: 'agent.script',
              runtimeKind: AgentRuntimeKind.script,
            ),
          },
          agents: <String, AgentHandler>{},
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
    expect((await store.readAll()), hasLength(1));
    final traces = await traceSink.readAll();
    expect(
      traces.map((trace) => trace.name),
      contains('runtime.agent.unsupported_runtime'),
    );
  });
}

RuntimeKernel _kernel({
  required EventStore store,
  required TraceSink traceSink,
  required PermissionBroker permissions,
  required ModelClient model,
  required AgentHandler handler,
  ToolRegistry? tools,
}) {
  final kernel = RuntimeKernel(
    eventStore: store,
    traceSink: traceSink,
    permissionBroker: permissions,
    toolRegistry: tools ?? InMemoryToolRegistry(),
    idGenerator: SequenceWnIdGenerator(seed: 'test'),
    clock: TickingWnClock(DateTime.utc(2026, 6, 23, 1)),
    model: model,
    deviceId: 'device-local',
  );
  kernel.registerPack(
    AgentPack(
      id: 'pack.default',
      name: 'Default capture projections',
      version: '0.1.0',
      requiredPermissions: const <String>{
        ModelPermissions.complete,
        'memory.propose',
        'card.write',
        'insight.write',
        'todo.suggest',
      },
      subscriptions: const <Subscription>[
        Subscription(
          id: 'sub.capture',
          agentId: 'agent.capture',
          eventTypes: <String>{WnEventTypes.captureCreated},
        ),
      ],
      agentDefinitions: <String, AgentDefinition>{
        'agent.capture': AgentDefinition(
          id: 'agent.capture',
          requiredPermissions: const <String>{
            ModelPermissions.complete,
            'memory.propose',
            'card.write',
            'insight.write',
            'todo.suggest',
          },
          outputEvents: const <String>{
            WnEventTypes.memoryProposed,
            WnEventTypes.cardCreated,
            WnEventTypes.insightCreated,
            WnEventTypes.todoSuggested,
          },
          tools: _declaredToolsFor(handler),
        ),
      },
      agents: <String, AgentHandler>{'agent.capture': handler},
    ),
  );
  return kernel;
}

RuntimeKernel _blankKernel({
  required EventStore store,
  required TraceSink traceSink,
  ModelClient? model,
  PermissionBroker? permissions,
  RuntimeStore? runtimeStore,
  WnIdGenerator? idGenerator,
  WnClock? clock,
  bool autoDrain = true,
}) {
  return RuntimeKernel(
    eventStore: store,
    traceSink: traceSink,
    permissionBroker: permissions ?? InMemoryPermissionBroker(),
    toolRegistry: InMemoryToolRegistry(),
    idGenerator: idGenerator ?? SequenceWnIdGenerator(seed: 'test'),
    clock: clock ?? TickingWnClock(DateTime.utc(2026, 6, 23, 1)),
    model: model ?? FakeModel(),
    deviceId: 'device-local',
    runtimeStore: runtimeStore,
    autoDrain: autoDrain,
  );
}

Set<String> _declaredToolsFor(AgentHandler handler) {
  if (handler is _ToolUsingHandler) {
    return const <String>{'echo'};
  }
  if (handler is _ToolMissingHandler) {
    return const <String>{'missing'};
  }
  if (handler is _ToolDeniedHandler) {
    return const <String>{'secret'};
  }
  return const <String>{};
}

final class _CaptureProjectionHandler implements AgentHandler {
  const _CaptureProjectionHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    final text = event.payload['text'] as String? ?? '';
    final summary = await context.model.complete(
      ModelRequest(prompt: 'Summarize capture: $text'),
    );
    final subject =
        event.subjectRef ?? SubjectRef(kind: 'capture', id: event.id);

    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.memoryProposed,
          subjectRef: subject,
          payload: <String, Object?>{
            'state': 'proposed',
            'source_event_id': event.id,
            'text': summary.text,
            'confidence': 0.76,
          },
        ),
        context.emit(
          type: WnEventTypes.cardCreated,
          subjectRef: subject,
          payload: <String, Object?>{
            'title': 'Runtime slice',
            'body': summary.text,
          },
        ),
        context.emit(
          type: WnEventTypes.insightCreated,
          subjectRef: subject,
          payload: <String, Object?>{
            'kind': 'implementation',
            'text': 'Capture can drive local agent output offline.',
          },
        ),
        context.emit(
          type: WnEventTypes.todoSuggested,
          subjectRef: subject,
          payload: <String, Object?>{
            'text': 'Review generated runtime events.',
            'source_event_id': event.id,
          },
        ),
      ],
    );
  }
}

final class _CountingHandler implements AgentHandler {
  int calls = 0;

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    calls += 1;
    return const AgentHandlerResult.empty();
  }
}

final class _NamedInsightHandler implements AgentHandler {
  const _NamedInsightHandler(this.source);

  final String source;

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: <String, Object?>{'source': source},
        ),
      ],
    );
  }
}

final class _OrderRecordingHandler implements AgentHandler {
  const _OrderRecordingHandler(this.step, this.order);

  final String step;
  final List<String> order;

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    order.add(step);
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: <String, Object?>{'step': step},
        ),
      ],
    );
  }
}

final class _FailsOnceHandler implements AgentHandler {
  int calls = 0;

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    calls += 1;
    if (calls == 1) {
      throw StateError('transient fake executor failure');
    }
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: const <String, Object?>{'retry': 'succeeded'},
        ),
      ],
    );
  }
}

final class _DefaultPackHandler implements AgentHandler {
  const _DefaultPackHandler();

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
        context.emit(
          type: WnEventTypes.insightCreated,
          subjectRef: event.subjectRef,
          payload: const <String, Object?>{'kind': 'official'},
        ),
      ],
    );
  }
}

final class _TodoPackHandler implements AgentHandler {
  const _TodoPackHandler();

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

final class _PrivacyEchoHandler implements AgentHandler {
  const _PrivacyEchoHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: const <String, Object?>{'kind': 'privacy_echo'},
          privacy: event.privacy,
        ),
      ],
    );
  }
}

final class _ToolUsingHandler implements AgentHandler {
  const _ToolUsingHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    final result = await context.invokeTool(
      'echo',
      input: <String, Object?>{'value': event.payload['text']},
    );
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: <String, Object?>{
            'tool_echo': result.isOk ? result.value['echo'] : null,
            'tool_error': result.isErr ? result.failure.code : null,
          },
        ),
      ],
    );
  }
}

final class _ModelUsingHandler implements AgentHandler {
  const _ModelUsingHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    final response = await context.model.complete(
      const ModelRequest(prompt: 'Use a model.'),
    );
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: <String, Object?>{'text': response.text},
        ),
      ],
    );
  }
}

final class _UsageModel implements ModelClient {
  @override
  Future<ModelResponse> complete(ModelRequest request) async {
    return const ModelResponse(
      text: 'usage visible',
      raw: <String, Object?>{
        'provider_id': 'fake.byok',
        'model': 'fake-large',
        'usage': <String, Object?>{
          'input_tokens': 11,
          'output_tokens': 7,
          'total_tokens': 18,
          'cached_tokens': 2,
        },
        'estimated_cost_usd': 0.0042,
      },
    );
  }
}

final class _ToolMissingHandler implements AgentHandler {
  const _ToolMissingHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    final result = await context.invokeTool('missing');
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: <String, Object?>{
            'tool_error': result.isErr ? result.failure.code : null,
          },
        ),
      ],
    );
  }
}

final class _ThrowingHandler implements AgentHandler {
  const _ThrowingHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) {
    throw StateError('handler exploded');
  }
}

final class _ToolDeniedHandler implements AgentHandler {
  const _ToolDeniedHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    final result = await context.invokeTool('secret');
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: <String, Object?>{
            'tool_error': result.isErr ? result.failure.code : null,
          },
        ),
      ],
    );
  }
}

final class _EmptyHandler implements AgentHandler {
  const _EmptyHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    return const AgentHandlerResult.empty();
  }
}

final class _UndeclaredOutputHandler implements AgentHandler {
  const _UndeclaredOutputHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    return AgentHandlerResult(
      events: <WnEventDraft>[context.emit(type: WnEventTypes.todoSuggested)],
    );
  }
}

final class _MalformedSourceRefsHandler implements AgentHandler {
  const _MalformedSourceRefsHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: const <String, Object?>{
            'source_refs': <Object?>['not-a-source-ref'],
          },
        ),
      ],
    );
  }
}

final class _TraceThrowingHandler implements AgentHandler {
  const _TraceThrowingHandler();

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) {
    throw StateError('api_key=super-secret raw_db=dump');
  }
}

RuntimeTask _taskFixture({
  required String id,
  required RuntimeTaskStatus status,
  String packId = 'pack.restore',
  String packVersion = '1.0.0',
  String agentId = 'agent.restore',
  String subscriptionId = 'sub.restore',
  String triggerEventId = 'evt-restore',
}) {
  final now = DateTime.utc(2026, 6, 23, 1);
  return RuntimeTask(
    id: id,
    identityKey:
        '$triggerEventId::$packId::$packVersion::$subscriptionId::$agentId',
    packId: packId,
    packVersion: packVersion,
    agentId: agentId,
    handlerRole: agentId,
    subscriptionId: subscriptionId,
    triggerEventId: triggerEventId,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

RuntimeRun _runFixture({
  required String id,
  required String taskId,
  required RuntimeRunStatus status,
  DateTime? startedAt,
  DateTime? leaseExpiresAt,
}) {
  final started = startedAt ?? DateTime.utc(2026, 6, 23, 1);
  return RuntimeRun(
    id: id,
    taskId: taskId,
    packId: 'pack.restore',
    packVersion: '1.0.0',
    agentId: 'agent.restore',
    status: status,
    startedAt: started,
    attempt: 1,
    leaseExpiresAt: leaseExpiresAt,
  );
}

WnEvent _eventFixture({required String id, required String type}) {
  return WnEvent(
    id: id,
    type: type,
    schemaVersion: 1,
    actor: WnActor.system,
    payload: const <String, Object?>{},
    privacy: WnPrivacy.localOnly,
    deviceId: 'device-local',
    createdAt: DateTime.utc(2026, 6, 23, 1),
  );
}

AgentPackManifestSnapshot _defaultManifest({
  Iterable<String> outputEvents = const <String>[
    WnEventTypes.cardCreated,
    WnEventTypes.memoryProposed,
    WnEventTypes.insightCreated,
  ],
}) {
  return AgentPackManifestSnapshot.fromJson(<String, Object?>{
    'id': 'pack.default',
    'name': 'Default Capture Loop',
    'version': '0.1.0',
    'schema_version': 1,
    'publisher': 'widenote',
    'edition': 'official',
    'permissions': <Object?>[
      ModelPermissions.complete,
      'card.write',
      'memory.propose',
      'insight.write',
    ],
    'subscriptions': <Object?>[
      <String, Object?>{
        'id': 'sub.capture_created',
        'event_types': <Object?>[WnEventTypes.captureCreated],
        'agent_id': 'agent.capture_loop',
      },
    ],
    'agents': <Object?>[
      <String, Object?>{
        'id': 'agent.capture_loop',
        'runtime': 'native',
        'model_profile_ref': 'local_or_user_selected_model',
        'permissions': <Object?>[
          ModelPermissions.complete,
          'card.write',
          'memory.propose',
          'insight.write',
        ],
        'tools': <Object?>[],
        'output_events': outputEvents.toList(growable: false),
        'retry_policy': <String, Object?>{'max_attempts': 2},
      },
    ],
    'model_profiles': <Object?>[
      <String, Object?>{
        'id': 'local_or_user_selected_model',
        'purpose': 'Test profile.',
      },
    ],
  });
}

AgentPackManifestSnapshot _todoManifest({
  Iterable<String> permissions = const <String>{
    ModelPermissions.complete,
    'todo.suggest',
  },
  Iterable<String> outputEvents = const <String>{WnEventTypes.todoSuggested},
}) {
  return AgentPackManifestSnapshot.fromJson(<String, Object?>{
    'id': 'pack.todo',
    'name': 'Todo Extraction Loop',
    'version': '0.1.0',
    'schema_version': 1,
    'publisher': 'widenote',
    'edition': 'official',
    'permissions': permissions.toList(growable: false),
    'subscriptions': <Object?>[
      <String, Object?>{
        'id': 'sub.todo_capture_created',
        'event_types': <Object?>[WnEventTypes.captureCreated],
        'agent_id': 'agent.todo_loop',
      },
    ],
    'agents': <Object?>[
      <String, Object?>{
        'id': 'agent.todo_loop',
        'runtime': 'native',
        'model_profile_ref': null,
        'permissions': permissions.toList(growable: false),
        'tools': <Object?>[],
        'output_events': outputEvents.toList(growable: false),
        'retry_policy': <String, Object?>{'max_attempts': 2},
      },
    ],
    'model_profiles': <Object?>[],
  });
}
