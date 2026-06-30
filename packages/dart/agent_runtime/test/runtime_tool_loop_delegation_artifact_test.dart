import 'package:test/test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart';
import 'package:widenote_core/widenote_core.dart';

void main() {
  group('ToolLoopExecutor', () {
    test('stops before exceeding max tool calls', () async {
      final invoker = _RecordingToolInvoker();
      final executor = ToolLoopExecutor(
        tools: invoker,
        clock: FixedWnClock(DateTime.utc(2026, 6, 27, 2)),
      );

      final result = await executor.run(
        ToolLoopRequest(
          declaredTools: const <String>{'memory.read'},
          maxToolCalls: 2,
          calls: <ToolLoopCall>[
            ToolLoopCall(toolName: 'memory.read'),
            ToolLoopCall(toolName: 'memory.read'),
            ToolLoopCall(toolName: 'memory.read'),
          ],
        ),
      );

      expect(result.stopReason, ToolLoopStopReason.maxCalls);
      expect(result.steps, hasLength(2));
      expect(invoker.toolNames, <String>['memory.read', 'memory.read']);
    });

    test('stops on non-denial tool error result', () async {
      final invoker = _RecordingToolInvoker(
        results: <WnResult<JsonMap>>[
          const WnResult<JsonMap>.err(
            WnFailure(code: 'tool_failed', message: 'Fake tool failed.'),
          ),
        ],
      );
      final executor = ToolLoopExecutor(
        tools: invoker,
        clock: FixedWnClock(DateTime.utc(2026, 6, 27, 2)),
      );

      final result = await executor.run(
        ToolLoopRequest(
          declaredTools: const <String>{'memory.read'},
          maxToolCalls: 5,
          calls: <ToolLoopCall>[
            ToolLoopCall(toolName: 'memory.read'),
            ToolLoopCall(toolName: 'memory.read'),
          ],
        ),
      );

      expect(result.stopReason, ToolLoopStopReason.toolError);
      expect(result.steps, hasLength(1));
      expect(result.failure?.code, 'tool_failed');
      expect(invoker.toolNames, <String>['memory.read']);
    });

    test('stops on denied tool result', () async {
      final invoker = _RecordingToolInvoker(
        results: <WnResult<JsonMap>>[
          const WnResult<JsonMap>.err(
            WnFailure(
              code: 'permission_denied',
              message: 'Tool permission denied.',
            ),
          ),
        ],
      );
      final executor = ToolLoopExecutor(
        tools: invoker,
        clock: FixedWnClock(DateTime.utc(2026, 6, 27, 2)),
      );

      final result = await executor.run(
        ToolLoopRequest(
          declaredTools: const <String>{'memory.read'},
          maxToolCalls: 5,
          calls: <ToolLoopCall>[
            ToolLoopCall(toolName: 'memory.read'),
            ToolLoopCall(toolName: 'memory.read'),
          ],
        ),
      );

      expect(result.stopReason, ToolLoopStopReason.denied);
      expect(result.steps, hasLength(1));
      expect(result.failure?.code, 'permission_denied');
      expect(invoker.toolNames, <String>['memory.read']);
    });

    test('stops when the clock exceeds max duration', () async {
      final clock = _ManualClock(DateTime.utc(2026, 6, 27, 2));
      final invoker = _RecordingToolInvoker(
        onInvoke: () => clock.advance(const Duration(seconds: 2)),
      );
      final executor = ToolLoopExecutor(tools: invoker, clock: clock);

      final result = await executor.run(
        ToolLoopRequest(
          declaredTools: const <String>{'memory.read'},
          maxToolCalls: 5,
          maxDuration: const Duration(seconds: 1),
          calls: <ToolLoopCall>[
            ToolLoopCall(toolName: 'memory.read'),
            ToolLoopCall(toolName: 'memory.read'),
          ],
        ),
      );

      expect(result.stopReason, ToolLoopStopReason.timeout);
      expect(result.steps, hasLength(1));
      expect(invoker.toolNames, <String>['memory.read']);
    });
  });

  group('DelegationExecutor', () {
    test('executes an attenuated source-linked child run', () async {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final runtimeStore = InMemoryRuntimeStore();
      final traceSink = InMemoryTraceSink();
      final executor = DelegationExecutor(
        presets: <ChildAgentPreset>[
          _preset(
            allowedTools: const <String>{'memory.read', 'context.build'},
            defaultMaxToolCalls: 2,
            defaultMaxTotalTokens: 500,
            defaultMaxEstimatedCostUsd: 0.005,
          ),
        ],
        runtimeStore: runtimeStore,
        traceSink: traceSink,
        idGenerator: SequenceWnIdGenerator(seed: 'delegate'),
        clock: FixedWnClock(DateTime.utc(2026, 6, 27, 2)),
      );

      final result = await executor.execute(
        DelegationExecutionRequest(
          id: 'delegate-attenuated',
          parentRunId: 'run-parent',
          presetId: 'memory-review',
          packId: 'pack.default',
          packVersion: '0.1.0',
          agentId: 'agent.capture_loop',
          parentBudget: _budget(
            allowedTools: const <String>{'memory.read', 'context.build'},
            sourceRefs: const <SubjectRef>[source],
            runMode: RunMode.auto,
            maxToolCalls: 4,
            maxTotalTokens: 1000,
            maxEstimatedCostUsd: 0.01,
          ),
          requestedChildBudget: _budget(
            allowedTools: const <String>{'memory.read'},
            sourceRefs: const <SubjectRef>[source],
            runMode: RunMode.readOnly,
            maxToolCalls: 2,
            maxTotalTokens: 400,
            maxEstimatedCostUsd: 0.004,
          ),
        ),
        (context) async {
          expect(context.budget.allowedTools, <String>{'memory.read'});
          expect(context.budget.runMode, RunMode.readOnly);
          return DelegationChildOutput(
            sourceRefs: context.budget.sourceRefs,
            payload: const <String, Object?>{'accepted': true},
          );
        },
      );

      expect(result.state, DelegationExecutionState.succeeded);
      expect(result.childRunId, isNotNull);
      expect(result.effectiveChildBudget!.maxToolCalls, 2);
      expect(result.effectiveChildBudget!.maxTotalTokens, 400);
      expect(result.effectiveChildBudget!.maxEstimatedCostUsd, 0.004);
      final childRun = await runtimeStore.readRunById(result.childRunId!);
      expect(childRun?.status, RuntimeRunStatus.succeeded);
      expect(childRun?.runMode, RunMode.readOnly);
      final traces = await traceSink.readByRun('run-parent');
      expect(traces.map((trace) => trace.name), <String>[
        'runtime.delegation.running',
        'runtime.delegation.succeeded',
      ]);
      expect(traces.last.details['child_run_id'], result.childRunId);
      expect(traces.last.details['child_status'], 'succeeded');
    });

    test('rejects child run-mode escalation', () async {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final result = await _executeDelegation(
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.confirm,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.auto,
        ),
      );

      expect(result.state, DelegationExecutionState.rejected);
      expect(_codes(result.violations), contains('run_mode_escalation'));
      expect(result.childRunId, isNull);
    });

    test('rejects child source ref escalation', () async {
      const parentSource = SubjectRef(kind: 'event', id: 'evt-parent');
      const extraSource = SubjectRef(kind: 'event', id: 'evt-extra');
      final result = await _executeDelegation(
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[parentSource],
          runMode: RunMode.confirm,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[parentSource, extraSource],
          runMode: RunMode.readOnly,
        ),
      );

      expect(result.state, DelegationExecutionState.rejected);
      expect(_codes(result.violations), contains('source_ref_escalation'));
      expect(result.effectiveChildBudget!.sourceRefs, const <SubjectRef>[
        parentSource,
      ]);
    });

    test('rejects tool-call, token, and cost budget escalation', () async {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final result = await _executeDelegation(
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.auto,
          maxToolCalls: 2,
          maxTotalTokens: 500,
          maxEstimatedCostUsd: 0.005,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.readOnly,
          maxToolCalls: 3,
          maxTotalTokens: 600,
          maxEstimatedCostUsd: 0.006,
        ),
      );

      expect(
        _codes(result.violations),
        containsAll(<String>[
          'tool_call_budget_escalation',
          'total_token_budget_escalation',
          'cost_budget_escalation',
        ]),
      );
      expect(result.effectiveChildBudget!.maxToolCalls, 2);
      expect(result.effectiveChildBudget!.maxTotalTokens, 500);
      expect(result.effectiveChildBudget!.maxEstimatedCostUsd, 0.005);
    });

    test('rejects read-only parent write-tool delegation', () {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final request = DelegationRequest(
        id: 'delegate-write-tool',
        parentRunId: 'run-parent',
        preset: _preset(allowedTools: const <String>{'todo.write'}),
        parentBudget: _budget(
          allowedTools: const <String>{'todo.write'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.readOnly,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'todo.write'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.readOnly,
        ),
      );
      final registry = InMemoryToolRegistry()
        ..register(
          ToolDefinition(
            name: 'todo.write',
            description: 'Write todo',
            access: ToolAccess.write,
            handler: (_) async => const <String, Object?>{},
          ),
        );

      final result = DelegationPlanner(toolRegistry: registry).plan(request);

      expect(result.state, DelegationResultState.rejected);
      expect(_codes(result.violations), contains('tool_access_escalation'));
    });

    test('rejects nested delegation', () async {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final result = await _executeDelegation(
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.auto,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.readOnly,
        ),
        allowNestedDelegation: true,
      );

      expect(result.state, DelegationExecutionState.rejected);
      expect(
        _codes(result.violations),
        contains('nested_delegation_not_supported'),
      );
    });

    test('returns structured violation for unknown preset', () async {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final result = await _executeDelegation(
        presetId: 'missing-preset',
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.auto,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.readOnly,
        ),
      );

      expect(result.state, DelegationExecutionState.rejected);
      expect(_codes(result.violations), contains('preset_unknown'));
    });

    test('returns structured violation for malformed preset id', () async {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final result = await _executeDelegation(
        presetId: ' ',
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.auto,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.readOnly,
        ),
      );

      expect(result.state, DelegationExecutionState.rejected);
      expect(_codes(result.violations), contains('preset_malformed'));
    });

    test('rejects child output without source refs', () async {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final result = await _executeDelegation(
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.auto,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.readOnly,
        ),
        childHandler: (_) async {
          return DelegationChildOutput(
            sourceRefs: const <SubjectRef>[],
            payload: const <String, Object?>{'accepted': true},
          );
        },
      );

      expect(result.state, DelegationExecutionState.failed);
      expect(
        _codes(result.violations),
        contains('child_output_source_refs_required'),
      );
    });
  });

  group('ArtifactRegistry', () {
    test('rejects artifact drafts without source refs', () async {
      final registry = InMemoryArtifactRegistry(
        idGenerator: SequenceWnIdGenerator(seed: 'artifact'),
        clock: FixedWnClock(DateTime.utc(2026, 6, 27, 2)),
      );

      final result = await registry.create(
        ArtifactDraft(
          kind: 'report',
          title: 'Runtime report',
          creatorRunId: 'run-1',
          sourceRefs: const <SubjectRef>[],
          privacyClass: WnPrivacy.localOnly,
          retentionPolicy: ArtifactRetentionPolicy.keepUntilDeleted,
        ),
      );

      expect(result.isErr, isTrue);
      expect(result.failure.code, 'artifact_source_refs_required');
      expect(await registry.readAll(), isEmpty);
    });
  });
}

Future<DelegationExecutionResult> _executeDelegation({
  required CapabilityBudget parentBudget,
  required CapabilityBudget childBudget,
  String presetId = 'memory-review',
  bool allowNestedDelegation = false,
  DelegationChildHandler? childHandler,
}) async {
  final executor = DelegationExecutor(
    presets: <ChildAgentPreset>[
      _preset(allowedTools: const <String>{'memory.read', 'todo.write'}),
    ],
    runtimeStore: InMemoryRuntimeStore(),
    traceSink: InMemoryTraceSink(),
    idGenerator: SequenceWnIdGenerator(seed: 'delegate'),
    clock: FixedWnClock(DateTime.utc(2026, 6, 27, 2)),
  );
  return executor.execute(
    DelegationExecutionRequest(
      id: 'delegate-test',
      parentRunId: 'run-parent',
      presetId: presetId,
      packId: 'pack.default',
      packVersion: '0.1.0',
      agentId: 'agent.capture_loop',
      parentBudget: parentBudget,
      requestedChildBudget: childBudget,
      allowNestedDelegation: allowNestedDelegation,
    ),
    childHandler ??
        (context) async {
          return DelegationChildOutput(sourceRefs: context.budget.sourceRefs);
        },
  );
}

List<String> _codes(Iterable<DelegationViolation> violations) {
  return violations.map((violation) => violation.code).toList(growable: false);
}

ChildAgentPreset _preset({
  required Iterable<String> allowedTools,
  int defaultMaxToolCalls = 2,
  int? defaultMaxTotalTokens = 1000,
  double? defaultMaxEstimatedCostUsd = 0.01,
}) {
  return ChildAgentPreset(
    id: 'memory-review',
    name: 'Memory review',
    purpose: 'Review source-linked memory candidates.',
    allowedTools: allowedTools,
    defaultRunMode: RunMode.readOnly,
    defaultMaxDuration: const Duration(seconds: 30),
    defaultMaxToolCalls: defaultMaxToolCalls,
    contextSurface: 'memory-review',
    outputSchemaRef: 'memory-review-result',
    defaultMaxTotalTokens: defaultMaxTotalTokens,
    defaultMaxEstimatedCostUsd: defaultMaxEstimatedCostUsd,
  );
}

CapabilityBudget _budget({
  required Iterable<String> allowedTools,
  required Iterable<SubjectRef> sourceRefs,
  required RunMode runMode,
  Duration maxDuration = const Duration(seconds: 30),
  int maxToolCalls = 2,
  int? maxTotalTokens = 1000,
  double? maxEstimatedCostUsd = 0.01,
}) {
  return CapabilityBudget(
    allowedTools: allowedTools,
    sourceRefs: sourceRefs,
    runMode: runMode,
    maxDuration: maxDuration,
    maxToolCalls: maxToolCalls,
    maxTotalTokens: maxTotalTokens,
    maxEstimatedCostUsd: maxEstimatedCostUsd,
  );
}

final class _RecordingToolInvoker implements ToolInvoker {
  _RecordingToolInvoker({
    List<WnResult<JsonMap>> results = const <WnResult<JsonMap>>[],
    this.onInvoke,
  }) : _results = List<WnResult<JsonMap>>.of(results);

  final List<WnResult<JsonMap>> _results;
  final void Function()? onInvoke;
  final List<String> toolNames = <String>[];
  var _index = 0;

  @override
  Future<WnResult<JsonMap>> invokeTool(
    String name, {
    JsonMap input = const <String, Object?>{},
  }) async {
    toolNames.add(name);
    onInvoke?.call();
    if (_index < _results.length) {
      return _results[_index++];
    }
    return WnResult<JsonMap>.ok(<String, Object?>{'tool_name': name});
  }
}

final class _ManualClock implements WnClock {
  _ManualClock(DateTime instant) : _instant = instant.toUtc();

  DateTime _instant;

  void advance(Duration duration) {
    _instant = _instant.add(duration);
  }

  @override
  DateTime now() => _instant;
}
