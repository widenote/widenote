import 'package:test/test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart';
import 'package:widenote_core/widenote_core.dart';

void main() {
  test('read-only mode rejects a mutating tool without executing it', () async {
    var toolCalls = 0;
    final traceSink = InMemoryTraceSink();
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'todo.create',
          description: 'Creates a todo.',
          access: ToolAccess.write,
          handler: (invocation) async {
            toolCalls += 1;
            return const <String, Object?>{'created': true};
          },
        ),
      );
    final kernel = _kernel(
      traceSink: traceSink,
      tools: tools,
      runMode: RunMode.readOnly,
      handler: const _ToolCallingHandler('todo.create'),
    );

    await _publishCapture(kernel);

    final output = (await kernel.eventStore.readByType(
      WnEventTypes.insightCreated,
    )).single;
    final traces = await traceSink.readAll();

    expect(toolCalls, 0);
    expect(output.payload['tool_error'], 'run_mode_denied');
    expect(kernel.runs.single.runMode, RunMode.readOnly);
    expect(kernel.runs.single.status, RuntimeRunStatus.succeeded);
    expect(
      traces.map((trace) => trace.name),
      contains('runtime.tool.run_mode_denied'),
    );
    final denied = traces.singleWhere(
      (trace) => trace.name == 'runtime.tool.run_mode_denied',
    );
    expect(denied.details['run_mode'], 'read_only');
    expect(denied.details['tool_access'], 'write');
    expect(denied.details['tool_risk'], 'low');
    expect(denied.details['input_keys'], <String>['value']);
    _expectRawToolInput(denied);
  });

  test('maps run mode public wire names and compatibility aliases', () {
    expect(RunMode.readOnly.wireName, 'read_only');
    expect(runModeFromWireName('read_only'), RunMode.readOnly);
    expect(runModeFromWireName('readOnly'), RunMode.readOnly);
    expect(runModeFromWireName('confirm'), RunMode.confirm);
    expect(runModeFromWireName('auto'), RunMode.auto);
  });

  test('read-only mode rejects external and high-risk tools', () async {
    for (final scenario in <_ToolScenario>[
      _ToolScenario(
        name: 'external.lookup',
        definition: ToolDefinition(
          name: 'external.lookup',
          description: 'Would read an external system.',
          external: true,
          handler: (invocation) async => const <String, Object?>{'ok': true},
        ),
      ),
      _ToolScenario(
        name: 'memory.bulk_delete',
        definition: ToolDefinition(
          name: 'memory.bulk_delete',
          description: 'High-risk destructive action.',
          risk: ToolRisk.high,
          handler: (invocation) async => const <String, Object?>{'ok': true},
        ),
      ),
    ]) {
      final tools = InMemoryToolRegistry()..register(scenario.definition);
      final kernel = _kernel(
        tools: tools,
        runMode: RunMode.readOnly,
        handler: _ToolCallingHandler(scenario.name),
      );

      await _publishCapture(kernel);

      final output = (await kernel.eventStore.readByType(
        WnEventTypes.insightCreated,
      )).single;
      expect(output.payload['tool_error'], 'run_mode_denied');
    }
  });

  test('confirm mode returns approval denied without executing tool', () async {
    var toolCalls = 0;
    final traceSink = InMemoryTraceSink();
    final approvals = _StaticApprovalBroker(approved: false);
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'memory.write',
          description: 'Writes a memory proposal.',
          access: ToolAccess.write,
          handler: (invocation) async {
            toolCalls += 1;
            return const <String, Object?>{'written': true};
          },
        ),
      );
    final kernel = _kernel(
      traceSink: traceSink,
      tools: tools,
      runMode: RunMode.confirm,
      approvalBroker: approvals,
      handler: const _ToolCallingHandler('memory.write'),
    );

    await _publishCapture(kernel);

    final output = (await kernel.eventStore.readByType(
      WnEventTypes.insightCreated,
    )).single;
    final traces = await traceSink.readAll();

    expect(toolCalls, 0);
    expect(output.payload['tool_error'], 'approval_denied');
    expect(approvals.requests, hasLength(1));
    expect(approvals.requests.single.runMode, RunMode.confirm);
    expect(approvals.requests.single.toolAccess, ToolAccess.write);
    expect(approvals.requests.single.inputKeys, <String>['value']);
    expect(
      traces.map((trace) => trace.name),
      containsAll(<String>[
        'runtime.tool.approval_requested',
        'runtime.tool.approval_denied',
      ]),
    );
    _expectRawToolInput(
      traces.singleWhere(
        (trace) => trace.name == 'runtime.tool.approval_requested',
      ),
    );
    _expectRawToolInput(
      traces.singleWhere(
        (trace) => trace.name == 'runtime.tool.approval_denied',
      ),
    );
  });

  test('confirm mode executes tool after approval', () async {
    var toolCalls = 0;
    final traceSink = InMemoryTraceSink();
    final approvals = _StaticApprovalBroker(approved: true);
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'todo.complete',
          description: 'Completes a todo.',
          access: ToolAccess.write,
          handler: (invocation) async {
            toolCalls += 1;
            return <String, Object?>{'echo': invocation.input['value']};
          },
        ),
      );
    final kernel = _kernel(
      traceSink: traceSink,
      tools: tools,
      runMode: RunMode.confirm,
      approvalBroker: approvals,
      handler: const _ToolCallingHandler('todo.complete'),
    );

    await _publishCapture(kernel);

    final output = (await kernel.eventStore.readByType(
      WnEventTypes.insightCreated,
    )).single;
    final traces = await traceSink.readAll();

    expect(toolCalls, 1);
    expect(output.payload['tool_error'], isNull);
    expect(output.payload['tool_echo'], 'private-tool-input');
    expect(approvals.requests, hasLength(1));
    expect(
      traces.map((trace) => trace.name),
      containsAll(<String>[
        'runtime.tool.approval_requested',
        'runtime.tool.approval_approved',
        'runtime.tool.completed',
      ]),
    );
  });

  test('auto mode executes low-risk local tools without approval', () async {
    var toolCalls = 0;
    final traceSink = InMemoryTraceSink();
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'memory.read',
          description: 'Reads local approved memory.',
          handler: (invocation) async {
            toolCalls += 1;
            return const <String, Object?>{'echo': 'read-ok'};
          },
        ),
      );
    final kernel = _kernel(
      traceSink: traceSink,
      tools: tools,
      runMode: RunMode.auto,
      handler: const _ToolCallingHandler('memory.read'),
    );

    await _publishCapture(kernel);

    final output = (await kernel.eventStore.readByType(
      WnEventTypes.insightCreated,
    )).single;
    final traces = await traceSink.readAll();

    expect(toolCalls, 1);
    expect(output.payload['tool_echo'], 'read-ok');
    expect(
      traces.map((trace) => trace.name),
      isNot(contains('runtime.tool.approval_requested')),
    );
    final completed = traces.singleWhere(
      (trace) => trace.name == 'runtime.tool.completed',
    );
    expect(completed.details['run_mode'], 'auto');
    expect(completed.details['tool_access'], 'read');
    expect(completed.details['tool_risk'], 'low');
  });

  test('auto mode executes low-risk local writes without approval', () async {
    var toolCalls = 0;
    final traceSink = InMemoryTraceSink();
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'memory.propose',
          description: 'Creates a source-linked local Memory proposal.',
          access: ToolAccess.write,
          handler: (invocation) async {
            toolCalls += 1;
            return const <String, Object?>{'echo': 'proposal-created'};
          },
        ),
      );
    final kernel = _kernel(
      traceSink: traceSink,
      tools: tools,
      runMode: RunMode.auto,
      handler: const _ToolCallingHandler('memory.propose'),
    );

    await _publishCapture(kernel);

    final output = (await kernel.eventStore.readByType(
      WnEventTypes.insightCreated,
    )).single;
    final traces = await traceSink.readAll();

    expect(toolCalls, 1);
    expect(output.payload['tool_echo'], 'proposal-created');
    expect(
      traces.map((trace) => trace.name),
      isNot(contains('runtime.tool.approval_requested')),
    );
    final completed = traces.singleWhere(
      (trace) => trace.name == 'runtime.tool.completed',
    );
    expect(completed.details['run_mode'], 'auto');
    expect(completed.details['tool_access'], 'write');
    expect(completed.details['approval_required'], isFalse);
  });

  test('auto mode still approval-gates explicit or high-risk tools', () async {
    for (final scenario in <_ToolScenario>[
      _ToolScenario(
        name: 'external.lookup',
        definition: ToolDefinition(
          name: 'external.lookup',
          description: 'Would call an external system.',
          external: true,
          handler: (invocation) async => const <String, Object?>{'ok': true},
        ),
      ),
      _ToolScenario(
        name: 'settings.force',
        definition: ToolDefinition(
          name: 'settings.force',
          description: 'Explicitly approval-gated setting write.',
          access: ToolAccess.write,
          approvalRequirement: ToolApprovalRequirement.always,
          handler: (invocation) async => const <String, Object?>{'ok': true},
        ),
      ),
      _ToolScenario(
        name: 'memory.bulk_delete',
        definition: ToolDefinition(
          name: 'memory.bulk_delete',
          description: 'High-risk destructive action.',
          risk: ToolRisk.high,
          handler: (invocation) async => const <String, Object?>{'ok': true},
        ),
      ),
    ]) {
      final tools = InMemoryToolRegistry()..register(scenario.definition);
      final kernel = _kernel(
        tools: tools,
        runMode: RunMode.auto,
        handler: _ToolCallingHandler(scenario.name),
      );

      await _publishCapture(kernel);

      final output = (await kernel.eventStore.readByType(
        WnEventTypes.insightCreated,
      )).single;
      expect(output.payload['tool_error'], 'approval_unavailable');
    }
  });

  test(
    'approval-gated tool fails safely when no broker is available',
    () async {
      var toolCalls = 0;
      final traceSink = InMemoryTraceSink();
      final tools = InMemoryToolRegistry()
        ..register(
          ToolDefinition(
            name: 'settings.write',
            description: 'Writes settings.',
            access: ToolAccess.write,
            handler: (invocation) async {
              toolCalls += 1;
              return const <String, Object?>{'written': true};
            },
          ),
        );
      final kernel = _kernel(
        traceSink: traceSink,
        tools: tools,
        runMode: RunMode.confirm,
        handler: const _ToolCallingHandler('settings.write'),
      );

      await _publishCapture(kernel);

      final output = (await kernel.eventStore.readByType(
        WnEventTypes.insightCreated,
      )).single;
      final traces = await traceSink.readAll();

      expect(toolCalls, 0);
      expect(output.payload['tool_error'], 'approval_unavailable');
      expect(
        traces.map((trace) => trace.name),
        contains('runtime.tool.approval_unavailable'),
      );
      expect(
        traces.map((trace) => trace.name),
        isNot(contains('runtime.tool.completed')),
      );
    },
  );

  test(
    'pending approval broker stores request and fails run without executing tool',
    () async {
      var toolCalls = 0;
      final traceSink = InMemoryTraceSink();
      final approvalStore = InMemoryApprovalStore();
      final tools = InMemoryToolRegistry()
        ..register(
          ToolDefinition(
            name: 'todo.external_complete',
            description: 'Would complete a todo through an external system.',
            access: ToolAccess.write,
            external: true,
            handler: (invocation) async {
              toolCalls += 1;
              return const <String, Object?>{'written': true};
            },
          ),
        );
      final kernel = _kernel(
        traceSink: traceSink,
        tools: tools,
        runMode: RunMode.confirm,
        approvalBroker: PendingApprovalBroker(approvalStore),
        handler: const _ToolCallingHandler('todo.external_complete'),
      );

      await _publishCapture(kernel);

      final traces = await traceSink.readAll();
      final pending = await approvalStore.readPending(
        now: DateTime.utc(2026, 6, 27, 1, 1),
      );

      expect(toolCalls, 0);
      expect(
        await kernel.eventStore.readByType(WnEventTypes.insightCreated),
        isEmpty,
      );
      expect(kernel.tasks.single.status, RuntimeTaskStatus.failed);
      expect(kernel.tasks.single.error, contains('Approval pending'));
      expect(kernel.runs.single.status, RuntimeRunStatus.failed);
      expect(kernel.runs.single.error, contains('Approval pending'));
      expect(pending, hasLength(1));
      expect(pending.single.toolName, 'todo.external_complete');
      expect(pending.single.runMode, RunMode.confirm);
      expect(pending.single.toolAccess, ToolAccess.write);
      expect(pending.single.isExternal, isTrue);
      expect(pending.single.inputKeys, <String>['value']);
      expect(pending.single.actionSummary, contains('todo.external_complete'));
      expect(
        pending.single.expiresAt,
        pending.single.requestedAt.add(const Duration(minutes: 15)),
      );
      _expectRawToolInput(
        traces.singleWhere(
          (trace) => trace.name == 'runtime.tool.approval_requested',
        ),
      );
      _expectRawToolInput(
        traces.singleWhere(
          (trace) => trace.name == 'runtime.tool.approval_pending',
        ),
      );
      expect(
        traces.map((trace) => trace.name),
        containsAll(<String>[
          'runtime.tool.approval_requested',
          'runtime.tool.approval_pending',
          'runtime.run.approval_pending',
        ]),
      );
      expect(
        traces.map((trace) => trace.name),
        isNot(contains('runtime.tool.completed')),
      );
    },
  );

  test('tool permission denial still happens before run-mode denial', () async {
    var toolCalls = 0;
    final traceSink = InMemoryTraceSink();
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'secret.write',
          description: 'Needs an explicit permission.',
          requiredPermissions: const <String>{'tool.secret.write'},
          access: ToolAccess.write,
          handler: (invocation) async {
            toolCalls += 1;
            return const <String, Object?>{'ok': true};
          },
        ),
      );
    final kernel = _kernel(
      traceSink: traceSink,
      tools: tools,
      runMode: RunMode.readOnly,
      handler: const _ToolCallingHandler('secret.write'),
    );

    await _publishCapture(kernel);

    final output = (await kernel.eventStore.readByType(
      WnEventTypes.insightCreated,
    )).single;
    final traces = await traceSink.readAll();

    expect(toolCalls, 0);
    expect(output.payload['tool_error'], 'permission_denied');
    expect(
      traces.map((trace) => trace.name),
      contains('runtime.tool.permission_denied'),
    );
    expect(
      traces.map((trace) => trace.name),
      isNot(contains('runtime.tool.run_mode_denied')),
    );
    final denied = traces.singleWhere(
      (trace) => trace.name == 'runtime.tool.permission_denied',
    );
    expect(denied.details['missing_permissions'], <String>[
      'tool.secret.write',
    ]);
  });

  test(
    'undeclared tool is denied without executing registered handler',
    () async {
      var toolCalls = 0;
      final traceSink = InMemoryTraceSink();
      final tools = InMemoryToolRegistry()
        ..register(
          ToolDefinition(
            name: 'memory.read',
            description: 'Reads memory.',
            handler: (invocation) async {
              toolCalls += 1;
              return const <String, Object?>{'ok': true};
            },
          ),
        );
      final kernel = _kernel(
        traceSink: traceSink,
        tools: tools,
        declaredTools: const <String>{},
        handler: const _ToolCallingHandler('memory.read'),
      );

      await _publishCapture(kernel);

      final output = (await kernel.eventStore.readByType(
        WnEventTypes.insightCreated,
      )).single;
      final traces = await traceSink.readAll();

      expect(toolCalls, 0);
      expect(output.payload['tool_error'], 'tool_undeclared');
      expect(
        traces.map((trace) => trace.name),
        contains('runtime.tool.undeclared'),
      );
      expect(
        traces.map((trace) => trace.name),
        isNot(contains('runtime.tool.completed')),
      );
    },
  );

  test('deferred tool returns unsupported trace without executing', () async {
    var toolCalls = 0;
    final traceSink = InMemoryTraceSink();
    final tools = InMemoryToolRegistry()
      ..register(
        ToolDefinition(
          name: 'http.fetch',
          description: 'Deferred HTTP fetch.',
          locality: ToolLocality.external,
          execution: ToolExecution.deferred,
          compatibleRunModes: const <RunMode>{RunMode.confirm},
          handler: (invocation) async {
            toolCalls += 1;
            return const <String, Object?>{'ok': true};
          },
        ),
      );
    final kernel = _kernel(
      traceSink: traceSink,
      tools: tools,
      runMode: RunMode.confirm,
      handler: const _ToolCallingHandler('http.fetch'),
    );

    await _publishCapture(kernel);

    final output = (await kernel.eventStore.readByType(
      WnEventTypes.insightCreated,
    )).single;
    final traces = await traceSink.readAll();

    expect(toolCalls, 0);
    expect(output.payload['tool_error'], 'unsupported_tool');
    final unsupported = traces.singleWhere(
      (trace) => trace.name == 'runtime.tool.unsupported',
    );
    expect(unsupported.details['tool_execution'], 'deferred');
    expect(unsupported.details['tool_locality'], 'external');
  });
}

RuntimeKernel _kernel({
  TraceSink? traceSink,
  ToolRegistry? tools,
  RunMode runMode = RunMode.auto,
  ApprovalBroker? approvalBroker,
  PermissionBroker? permissions,
  Set<String>? declaredTools,
  required AgentHandler handler,
}) {
  final effectiveDeclaredTools =
      declaredTools ??
      (handler is _ToolCallingHandler
          ? <String>{handler.toolName}
          : const <String>{});
  final kernel = RuntimeKernel(
    eventStore: InMemoryEventStore(),
    traceSink: traceSink ?? InMemoryTraceSink(),
    permissionBroker: permissions ?? InMemoryPermissionBroker(),
    toolRegistry: tools ?? InMemoryToolRegistry(),
    idGenerator: SequenceWnIdGenerator(seed: 'run-mode'),
    clock: TickingWnClock(DateTime.utc(2026, 6, 27, 1)),
    model: FakeModel(),
    deviceId: 'device-local',
    runMode: runMode,
    approvalBroker: approvalBroker,
  );
  kernel.registerPack(
    AgentPack(
      id: 'pack.runtime',
      name: 'Runtime contract test pack',
      version: '0.1.0',
      subscriptions: const <Subscription>[
        Subscription(
          id: 'sub.capture',
          agentId: 'agent.runtime',
          eventTypes: <String>{WnEventTypes.captureCreated},
        ),
      ],
      agentDefinitions: <String, AgentDefinition>{
        'agent.runtime': AgentDefinition(
          id: 'agent.runtime',
          tools: effectiveDeclaredTools,
          outputEvents: <String>{WnEventTypes.insightCreated},
        ),
      },
      agents: <String, AgentHandler>{'agent.runtime': handler},
    ),
  );
  return kernel;
}

Future<void> _publishCapture(RuntimeKernel kernel) {
  return kernel.publish(
    const WnEventDraft(
      type: WnEventTypes.captureCreated,
      actor: WnActor.user,
      payload: <String, Object?>{'text': 'exercise run mode'},
    ),
  );
}

void _expectRawToolInput(RuntimeTrace trace) {
  expect(trace.details['raw_tool_input'], <String, Object?>{
    'value': 'private-tool-input',
  });
}

final class _ToolCallingHandler implements AgentHandler {
  const _ToolCallingHandler(this.toolName);

  final String toolName;

  @override
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event) async {
    final result = await context.invokeTool(
      toolName,
      input: const <String, Object?>{'value': 'private-tool-input'},
    );
    return AgentHandlerResult(
      events: <WnEventDraft>[
        context.emit(
          type: WnEventTypes.insightCreated,
          payload: <String, Object?>{
            'run_mode': context.runMode.wireName,
            'tool_echo': result.isOk ? result.value['echo'] : null,
            'tool_error': result.isErr ? result.failure.code : null,
          },
        ),
      ],
    );
  }
}

final class _StaticApprovalBroker implements ApprovalBroker {
  _StaticApprovalBroker({required this.approved});

  final bool approved;
  final List<ApprovalRequest> requests = <ApprovalRequest>[];

  @override
  Future<ApprovalDecision> requestApproval(ApprovalRequest request) async {
    requests.add(request);
    if (approved) {
      return ApprovalDecision.approved(requestId: request.id);
    }
    return ApprovalDecision.denied(requestId: request.id);
  }
}

final class _ToolScenario {
  const _ToolScenario({required this.name, required this.definition});

  final String name;
  final ToolDefinition definition;
}
