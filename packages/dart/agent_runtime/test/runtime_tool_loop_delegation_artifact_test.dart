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

  group('DelegationPlanner', () {
    test('rejects wider child tools, run mode, and source refs', () {
      const parentSource = SubjectRef(kind: 'event', id: 'evt-parent');
      const extraSource = SubjectRef(kind: 'event', id: 'evt-extra');
      final request = DelegationRequest(
        id: 'delegate-1',
        parentRunId: 'run-parent',
        preset: _preset(
          allowedTools: const <String>{'memory.read', 'todo.write'},
        ),
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[parentSource],
          runMode: RunMode.confirm,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read', 'todo.write'},
          sourceRefs: const <SubjectRef>[parentSource, extraSource],
          runMode: RunMode.auto,
        ),
      );

      final result = const DelegationPlanner().plan(request);
      final codes = result.violations.map((violation) => violation.code);

      expect(result.state, DelegationResultState.rejected);
      expect(
        codes,
        containsAll(<String>[
          'tool_budget_escalation',
          'run_mode_escalation',
          'source_ref_escalation',
        ]),
      );
    });

    test('plans a child when capabilities are attenuated', () {
      const source = SubjectRef(kind: 'event', id: 'evt-parent');
      final request = DelegationRequest(
        id: 'delegate-2',
        parentRunId: 'run-parent',
        preset: _preset(
          allowedTools: const <String>{'memory.read', 'context.build'},
        ),
        parentBudget: _budget(
          allowedTools: const <String>{'memory.read', 'context.build'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.auto,
          maxToolCalls: 4,
        ),
        childBudget: _budget(
          allowedTools: const <String>{'memory.read'},
          sourceRefs: const <SubjectRef>[source],
          runMode: RunMode.readOnly,
          maxToolCalls: 2,
        ),
      );

      final result = const DelegationPlanner().plan(request);

      expect(result.state, DelegationResultState.planned);
      expect(result.violations, isEmpty);
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

ChildAgentPreset _preset({required Iterable<String> allowedTools}) {
  return ChildAgentPreset(
    id: 'memory-review',
    name: 'Memory review',
    purpose: 'Review source-linked memory candidates.',
    allowedTools: allowedTools,
    defaultRunMode: RunMode.readOnly,
    defaultMaxDuration: const Duration(seconds: 30),
    defaultMaxToolCalls: 2,
    contextSurface: 'memory-review',
    outputSchemaRef: 'memory-review-result',
  );
}

CapabilityBudget _budget({
  required Iterable<String> allowedTools,
  required Iterable<SubjectRef> sourceRefs,
  required RunMode runMode,
  Duration maxDuration = const Duration(seconds: 30),
  int maxToolCalls = 2,
}) {
  return CapabilityBudget(
    allowedTools: allowedTools,
    sourceRefs: sourceRefs,
    runMode: runMode,
    maxDuration: maxDuration,
    maxToolCalls: maxToolCalls,
    maxTotalTokens: 1000,
    maxEstimatedCostUsd: 0.01,
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
