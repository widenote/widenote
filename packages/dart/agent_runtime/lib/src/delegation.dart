import 'package:widenote_core/widenote_core.dart';

import 'event.dart';
import 'run_mode.dart';
import 'store.dart';
import 'task.dart';
import 'tools.dart';
import 'trace.dart';

final class CapabilityBudget {
  CapabilityBudget({
    required Iterable<String> allowedTools,
    required Iterable<SubjectRef> sourceRefs,
    required this.runMode,
    required this.maxDuration,
    required this.maxToolCalls,
    this.maxInputTokens,
    this.maxOutputTokens,
    this.maxTotalTokens,
    this.maxEstimatedCostUsd,
  }) : allowedTools = Set<String>.unmodifiable(allowedTools),
       sourceRefs = List<SubjectRef>.unmodifiable(sourceRefs) {
    if (maxDuration <= Duration.zero) {
      throw ArgumentError.value(
        maxDuration,
        'maxDuration',
        'Must be greater than zero.',
      );
    }
    if (maxToolCalls < 0) {
      throw ArgumentError.value(
        maxToolCalls,
        'maxToolCalls',
        'Must not be negative.',
      );
    }
    _checkOptionalInt(maxInputTokens, 'maxInputTokens');
    _checkOptionalInt(maxOutputTokens, 'maxOutputTokens');
    _checkOptionalInt(maxTotalTokens, 'maxTotalTokens');
    final cost = maxEstimatedCostUsd;
    if (cost != null && cost < 0) {
      throw ArgumentError.value(
        cost,
        'maxEstimatedCostUsd',
        'Must not be negative.',
      );
    }
  }

  final Set<String> allowedTools;
  final List<SubjectRef> sourceRefs;
  final RunMode runMode;
  final Duration maxDuration;
  final int maxToolCalls;
  final int? maxInputTokens;
  final int? maxOutputTokens;
  final int? maxTotalTokens;
  final double? maxEstimatedCostUsd;

  JsonMap toJson() {
    return <String, Object?>{
      'allowed_tools': allowedTools.toList()..sort(),
      'source_refs': sourceRefs.map((ref) => ref.toJson()).toList(),
      'run_mode': runMode.name,
      'max_duration_ms': maxDuration.inMilliseconds,
      'max_tool_calls': maxToolCalls,
      'max_input_tokens': maxInputTokens,
      'max_output_tokens': maxOutputTokens,
      'max_total_tokens': maxTotalTokens,
      'max_estimated_cost_usd': maxEstimatedCostUsd,
    };
  }
}

final class ChildAgentPreset {
  ChildAgentPreset({
    required this.id,
    required this.name,
    required this.purpose,
    required Iterable<String> allowedTools,
    required this.defaultRunMode,
    required this.defaultMaxDuration,
    required this.defaultMaxToolCalls,
    this.contextSurface,
    this.outputSchemaRef,
    this.defaultMaxInputTokens,
    this.defaultMaxOutputTokens,
    this.defaultMaxTotalTokens,
    this.defaultMaxEstimatedCostUsd,
  }) : allowedTools = Set<String>.unmodifiable(allowedTools) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (defaultMaxDuration <= Duration.zero) {
      throw ArgumentError.value(
        defaultMaxDuration,
        'defaultMaxDuration',
        'Must be greater than zero.',
      );
    }
    if (defaultMaxToolCalls < 0) {
      throw ArgumentError.value(
        defaultMaxToolCalls,
        'defaultMaxToolCalls',
        'Must not be negative.',
      );
    }
    _checkOptionalInt(defaultMaxInputTokens, 'defaultMaxInputTokens');
    _checkOptionalInt(defaultMaxOutputTokens, 'defaultMaxOutputTokens');
    _checkOptionalInt(defaultMaxTotalTokens, 'defaultMaxTotalTokens');
    final cost = defaultMaxEstimatedCostUsd;
    if (cost != null && cost < 0) {
      throw ArgumentError.value(
        cost,
        'defaultMaxEstimatedCostUsd',
        'Must not be negative.',
      );
    }
  }

  final String id;
  final String name;
  final String purpose;
  final Set<String> allowedTools;
  final RunMode defaultRunMode;
  final Duration defaultMaxDuration;
  final int defaultMaxToolCalls;
  final String? contextSurface;
  final String? outputSchemaRef;
  final int? defaultMaxInputTokens;
  final int? defaultMaxOutputTokens;
  final int? defaultMaxTotalTokens;
  final double? defaultMaxEstimatedCostUsd;
}

final class DelegationRequest {
  DelegationRequest({
    required this.id,
    required this.parentRunId,
    required this.preset,
    required this.parentBudget,
    required this.childBudget,
    JsonMap input = const <String, Object?>{},
    this.instructions,
    this.allowNestedDelegation = false,
  }) : input = immutableJsonMap(input) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (parentRunId.trim().isEmpty) {
      throw ArgumentError.value(
        parentRunId,
        'parentRunId',
        'Must not be empty.',
      );
    }
  }

  final String id;
  final String parentRunId;
  final ChildAgentPreset preset;
  final CapabilityBudget parentBudget;
  final CapabilityBudget childBudget;
  final JsonMap input;
  final String? instructions;
  final bool allowNestedDelegation;
}

enum DelegationResultState { planned, rejected }

final class DelegationResult {
  DelegationResult._({
    required this.state,
    required this.request,
    required this.effectiveChildBudget,
    required Iterable<DelegationViolation> violations,
  }) : violations = List<DelegationViolation>.unmodifiable(violations);

  factory DelegationResult.planned(
    DelegationRequest request, {
    CapabilityBudget? effectiveChildBudget,
  }) {
    return DelegationResult._(
      state: DelegationResultState.planned,
      request: request,
      effectiveChildBudget: effectiveChildBudget ?? request.childBudget,
      violations: const <DelegationViolation>[],
    );
  }

  factory DelegationResult.rejected(
    DelegationRequest request,
    Iterable<DelegationViolation> violations, {
    CapabilityBudget? effectiveChildBudget,
  }) {
    return DelegationResult._(
      state: DelegationResultState.rejected,
      request: request,
      effectiveChildBudget: effectiveChildBudget ?? request.childBudget,
      violations: violations,
    );
  }

  final DelegationResultState state;
  final DelegationRequest request;
  final CapabilityBudget effectiveChildBudget;
  final List<DelegationViolation> violations;

  bool get isPlanned => state == DelegationResultState.planned;
}

final class DelegationViolation {
  DelegationViolation({
    required this.code,
    required this.message,
    JsonMap details = const <String, Object?>{},
  }) : details = immutableJsonMap(details);

  final String code;
  final String message;
  final JsonMap details;

  JsonMap toJson() {
    return <String, Object?>{
      'code': code,
      'message': message,
      if (details.isNotEmpty) 'details': details,
    };
  }
}

final class DelegationPlanner {
  const DelegationPlanner({this.toolRegistry});

  final ToolRegistry? toolRegistry;

  CapabilityBudget attenuateBudget(DelegationRequest request) {
    final parent = request.parentBudget;
    final child = request.childBudget;
    final preset = request.preset;
    return CapabilityBudget(
      allowedTools: child.allowedTools
          .where(parent.allowedTools.contains)
          .where(preset.allowedTools.contains),
      sourceRefs: _intersectSourceRefs(child.sourceRefs, parent.sourceRefs),
      runMode: _minRunMode(<RunMode>[
        child.runMode,
        parent.runMode,
        preset.defaultRunMode,
      ]),
      maxDuration: _minDuration(<Duration>[
        child.maxDuration,
        parent.maxDuration,
        preset.defaultMaxDuration,
      ]),
      maxToolCalls: _minInt(<int>[
        child.maxToolCalls,
        parent.maxToolCalls,
        preset.defaultMaxToolCalls,
      ]),
      maxInputTokens: _minOptionalInt(<int?>[
        child.maxInputTokens,
        parent.maxInputTokens,
        preset.defaultMaxInputTokens,
      ]),
      maxOutputTokens: _minOptionalInt(<int?>[
        child.maxOutputTokens,
        parent.maxOutputTokens,
        preset.defaultMaxOutputTokens,
      ]),
      maxTotalTokens: _minOptionalInt(<int?>[
        child.maxTotalTokens,
        parent.maxTotalTokens,
        preset.defaultMaxTotalTokens,
      ]),
      maxEstimatedCostUsd: _minOptionalDouble(<double?>[
        child.maxEstimatedCostUsd,
        parent.maxEstimatedCostUsd,
        preset.defaultMaxEstimatedCostUsd,
      ]),
    );
  }

  DelegationResult plan(DelegationRequest request) {
    final violations = <DelegationViolation>[];
    final parent = request.parentBudget;
    final child = request.childBudget;
    final preset = request.preset;
    final effectiveChildBudget = attenuateBudget(request);

    if (request.allowNestedDelegation) {
      violations.add(
        DelegationViolation(
          code: 'nested_delegation_not_supported',
          message: 'Initial child agents cannot spawn further child agents.',
        ),
      );
    }

    final toolsOutsideParent = _outside(
      child.allowedTools,
      parent.allowedTools,
    );
    if (toolsOutsideParent.isNotEmpty) {
      violations.add(
        DelegationViolation(
          code: 'tool_budget_escalation',
          message: 'Child tools must be a subset of parent allowed tools.',
          details: <String, Object?>{'tools': toolsOutsideParent},
        ),
      );
    }

    final toolsOutsidePreset = _outside(
      child.allowedTools,
      preset.allowedTools,
    );
    if (toolsOutsidePreset.isNotEmpty) {
      violations.add(
        DelegationViolation(
          code: 'tool_not_in_preset',
          message: 'Child tools must be allowed by its preset.',
          details: <String, Object?>{'tools': toolsOutsidePreset},
        ),
      );
    }

    if (_runModeRank(child.runMode) > _runModeRank(parent.runMode)) {
      violations.add(
        DelegationViolation(
          code: 'run_mode_escalation',
          message: 'Child run mode cannot be wider than parent run mode.',
          details: <String, Object?>{
            'parent_run_mode': parent.runMode.name,
            'child_run_mode': child.runMode.name,
          },
        ),
      );
    }

    if (_runModeRank(child.runMode) > _runModeRank(preset.defaultRunMode)) {
      violations.add(
        DelegationViolation(
          code: 'preset_run_mode_escalation',
          message: 'Child run mode cannot exceed preset default run mode.',
          details: <String, Object?>{
            'preset_run_mode': preset.defaultRunMode.name,
            'child_run_mode': child.runMode.name,
          },
        ),
      );
    }

    _checkReadOnlyToolSafety(violations, parent: parent, child: child);

    final sourceRefsOutsideParent = _sourceRefsOutside(
      child.sourceRefs,
      parent.sourceRefs,
    );
    if (sourceRefsOutsideParent.isNotEmpty) {
      violations.add(
        DelegationViolation(
          code: 'source_ref_escalation',
          message: 'Child source refs must be a subset of parent source refs.',
          details: <String, Object?>{'source_refs': sourceRefsOutsideParent},
        ),
      );
    }

    if (child.maxDuration > parent.maxDuration) {
      violations.add(
        DelegationViolation(
          code: 'duration_budget_escalation',
          message: 'Child max duration cannot exceed parent max duration.',
          details: <String, Object?>{
            'parent_ms': parent.maxDuration.inMilliseconds,
            'child_ms': child.maxDuration.inMilliseconds,
          },
        ),
      );
    }

    if (child.maxDuration > preset.defaultMaxDuration) {
      violations.add(
        DelegationViolation(
          code: 'preset_duration_budget_escalation',
          message: 'Child max duration cannot exceed preset max duration.',
          details: <String, Object?>{
            'preset_ms': preset.defaultMaxDuration.inMilliseconds,
            'child_ms': child.maxDuration.inMilliseconds,
          },
        ),
      );
    }

    if (child.maxToolCalls > parent.maxToolCalls) {
      violations.add(
        DelegationViolation(
          code: 'tool_call_budget_escalation',
          message: 'Child max tool calls cannot exceed parent max tool calls.',
          details: <String, Object?>{
            'parent_max_tool_calls': parent.maxToolCalls,
            'child_max_tool_calls': child.maxToolCalls,
          },
        ),
      );
    }

    if (child.maxToolCalls > preset.defaultMaxToolCalls) {
      violations.add(
        DelegationViolation(
          code: 'preset_tool_call_budget_escalation',
          message: 'Child max tool calls cannot exceed preset max tool calls.',
          details: <String, Object?>{
            'preset_max_tool_calls': preset.defaultMaxToolCalls,
            'child_max_tool_calls': child.maxToolCalls,
          },
        ),
      );
    }

    _checkIntBudget(
      violations,
      code: 'input_token_budget_escalation',
      label: 'maxInputTokens',
      parentValue: parent.maxInputTokens,
      childValue: child.maxInputTokens,
    );
    _checkPresetIntBudget(
      violations,
      code: 'preset_input_token_budget_escalation',
      label: 'maxInputTokens',
      presetValue: preset.defaultMaxInputTokens,
      childValue: child.maxInputTokens,
    );
    _checkIntBudget(
      violations,
      code: 'output_token_budget_escalation',
      label: 'maxOutputTokens',
      parentValue: parent.maxOutputTokens,
      childValue: child.maxOutputTokens,
    );
    _checkPresetIntBudget(
      violations,
      code: 'preset_output_token_budget_escalation',
      label: 'maxOutputTokens',
      presetValue: preset.defaultMaxOutputTokens,
      childValue: child.maxOutputTokens,
    );
    _checkIntBudget(
      violations,
      code: 'total_token_budget_escalation',
      label: 'maxTotalTokens',
      parentValue: parent.maxTotalTokens,
      childValue: child.maxTotalTokens,
    );
    _checkPresetIntBudget(
      violations,
      code: 'preset_total_token_budget_escalation',
      label: 'maxTotalTokens',
      presetValue: preset.defaultMaxTotalTokens,
      childValue: child.maxTotalTokens,
    );
    _checkCostBudget(
      violations,
      parentValue: parent.maxEstimatedCostUsd,
      childValue: child.maxEstimatedCostUsd,
    );
    _checkPresetCostBudget(
      violations,
      presetValue: preset.defaultMaxEstimatedCostUsd,
      childValue: child.maxEstimatedCostUsd,
    );

    if (violations.isNotEmpty) {
      return DelegationResult.rejected(
        request,
        violations,
        effectiveChildBudget: effectiveChildBudget,
      );
    }
    return DelegationResult.planned(
      request,
      effectiveChildBudget: effectiveChildBudget,
    );
  }

  void _checkReadOnlyToolSafety(
    List<DelegationViolation> violations, {
    required CapabilityBudget parent,
    required CapabilityBudget child,
  }) {
    if (parent.runMode != RunMode.readOnly) {
      return;
    }
    final registry = toolRegistry;
    if (registry == null) {
      return;
    }
    final unsafeTools = <String>[];
    final unknownTools = <String>[];
    for (final toolName in child.allowedTools) {
      final definition = registry.lookup(toolName);
      if (definition == null) {
        unknownTools.add(toolName);
        continue;
      }
      if (!definition.isReadOnlySafe) {
        unsafeTools.add(toolName);
      }
    }
    unsafeTools.sort();
    unknownTools.sort();
    if (unsafeTools.isNotEmpty) {
      violations.add(
        DelegationViolation(
          code: 'tool_access_escalation',
          message: 'Read-only parents can only delegate read-only-safe tools.',
          details: <String, Object?>{'tools': unsafeTools},
        ),
      );
    }
    if (unknownTools.isNotEmpty) {
      violations.add(
        DelegationViolation(
          code: 'child_tool_unknown',
          message: 'Delegated tools must be registered before execution.',
          details: <String, Object?>{'tools': unknownTools},
        ),
      );
    }
  }
}

typedef DelegationChildHandler =
    Future<DelegationChildOutput> Function(DelegationChildContext context);

enum DelegationExecutionState { succeeded, rejected, failed }

final class DelegationExecutionRequest {
  DelegationExecutionRequest({
    required this.id,
    required this.parentRunId,
    required this.presetId,
    required this.parentBudget,
    required this.requestedChildBudget,
    required this.packId,
    required this.packVersion,
    required this.agentId,
    this.parentTaskId,
    this.triggerEventId,
    JsonMap input = const <String, Object?>{},
    this.instructions,
    this.allowNestedDelegation = false,
  }) : input = immutableJsonMap(input);

  final String id;
  final String parentRunId;
  final String? parentTaskId;
  final String? triggerEventId;
  final String presetId;
  final CapabilityBudget parentBudget;
  final CapabilityBudget requestedChildBudget;
  final String packId;
  final String packVersion;
  final String agentId;
  final JsonMap input;
  final String? instructions;
  final bool allowNestedDelegation;
}

final class DelegationChildContext {
  const DelegationChildContext({
    required this.delegationId,
    required this.parentRunId,
    required this.childTask,
    required this.childRun,
    required this.preset,
    required this.budget,
    required this.input,
    this.instructions,
  });

  final String delegationId;
  final String parentRunId;
  final RuntimeTask childTask;
  final RuntimeRun childRun;
  final ChildAgentPreset preset;
  final CapabilityBudget budget;
  final JsonMap input;
  final String? instructions;
}

final class DelegationChildOutput {
  DelegationChildOutput({
    required Iterable<SubjectRef> sourceRefs,
    JsonMap payload = const <String, Object?>{},
  }) : sourceRefs = List<SubjectRef>.unmodifiable(sourceRefs),
       payload = immutableJsonMap(payload);

  final List<SubjectRef> sourceRefs;
  final JsonMap payload;
}

final class DelegationExecutionResult {
  DelegationExecutionResult._({
    required this.state,
    required this.delegationId,
    required this.parentRunId,
    required this.presetId,
    required Iterable<DelegationViolation> violations,
    required Iterable<DelegationTraceEvent> traceEvents,
    this.childTaskId,
    this.childRunId,
    this.effectiveChildBudget,
    this.output,
  }) : violations = List<DelegationViolation>.unmodifiable(violations),
       traceEvents = List<DelegationTraceEvent>.unmodifiable(traceEvents);

  factory DelegationExecutionResult.succeeded({
    required String delegationId,
    required String parentRunId,
    required String presetId,
    required String childTaskId,
    required String childRunId,
    required CapabilityBudget effectiveChildBudget,
    required DelegationChildOutput output,
    required Iterable<DelegationTraceEvent> traceEvents,
  }) {
    return DelegationExecutionResult._(
      state: DelegationExecutionState.succeeded,
      delegationId: delegationId,
      parentRunId: parentRunId,
      presetId: presetId,
      childTaskId: childTaskId,
      childRunId: childRunId,
      effectiveChildBudget: effectiveChildBudget,
      output: output,
      violations: const <DelegationViolation>[],
      traceEvents: traceEvents,
    );
  }

  factory DelegationExecutionResult.rejected({
    required String delegationId,
    required String parentRunId,
    required String presetId,
    required Iterable<DelegationViolation> violations,
    required Iterable<DelegationTraceEvent> traceEvents,
    String? childTaskId,
    String? childRunId,
    CapabilityBudget? effectiveChildBudget,
  }) {
    return DelegationExecutionResult._(
      state: DelegationExecutionState.rejected,
      delegationId: delegationId,
      parentRunId: parentRunId,
      presetId: presetId,
      childTaskId: childTaskId,
      childRunId: childRunId,
      effectiveChildBudget: effectiveChildBudget,
      violations: violations,
      traceEvents: traceEvents,
    );
  }

  factory DelegationExecutionResult.failed({
    required String delegationId,
    required String parentRunId,
    required String presetId,
    required String childTaskId,
    required String childRunId,
    required Iterable<DelegationViolation> violations,
    required CapabilityBudget effectiveChildBudget,
    required Iterable<DelegationTraceEvent> traceEvents,
  }) {
    return DelegationExecutionResult._(
      state: DelegationExecutionState.failed,
      delegationId: delegationId,
      parentRunId: parentRunId,
      presetId: presetId,
      childTaskId: childTaskId,
      childRunId: childRunId,
      effectiveChildBudget: effectiveChildBudget,
      violations: violations,
      traceEvents: traceEvents,
    );
  }

  final DelegationExecutionState state;
  final String delegationId;
  final String parentRunId;
  final String presetId;
  final String? childTaskId;
  final String? childRunId;
  final CapabilityBudget? effectiveChildBudget;
  final DelegationChildOutput? output;
  final List<DelegationViolation> violations;
  final List<DelegationTraceEvent> traceEvents;

  bool get isSucceeded => state == DelegationExecutionState.succeeded;
}

final class DelegationTraceEvent {
  DelegationTraceEvent({
    required this.delegationId,
    required this.parentRunId,
    required this.presetId,
    required this.status,
    Iterable<DelegationViolation> violations = const <DelegationViolation>[],
    this.childRunId,
    this.childTaskId,
    this.childBudget,
    Iterable<SubjectRef> outputSourceRefs = const <SubjectRef>[],
  }) : violations = List<DelegationViolation>.unmodifiable(violations),
       outputSourceRefs = List<SubjectRef>.unmodifiable(outputSourceRefs);

  final String delegationId;
  final String parentRunId;
  final String presetId;
  final String status;
  final String? childRunId;
  final String? childTaskId;
  final CapabilityBudget? childBudget;
  final List<DelegationViolation> violations;
  final List<SubjectRef> outputSourceRefs;

  JsonMap toJson() {
    final violationCodes = violations
        .map((violation) => violation.code)
        .toList(growable: false);
    return <String, Object?>{
      'trace_type': 'delegation',
      'child_delegation_id': delegationId,
      'parent_run_id': parentRunId,
      'preset_id': presetId,
      'child_status': status,
      if (childRunId != null) 'child_run_id': childRunId,
      if (childTaskId != null) 'child_task_id': childTaskId,
      if (childBudget != null) 'child_budget': childBudget!.toJson(),
      if (violationCodes.isNotEmpty) 'violation_codes': violationCodes,
      if (violations.isNotEmpty)
        'violations': violations
            .map((violation) => violation.toJson())
            .toList(),
      if (outputSourceRefs.isNotEmpty)
        'output_source_refs': outputSourceRefs
            .map((ref) => ref.toJson())
            .toList(growable: false),
    };
  }
}

final class DelegationExecutor {
  DelegationExecutor({
    required Iterable<ChildAgentPreset> presets,
    required this.runtimeStore,
    required this.traceSink,
    required this.idGenerator,
    required this.clock,
    ToolRegistry? toolRegistry,
    DelegationPlanner? planner,
  }) : presets = Map<String, ChildAgentPreset>.unmodifiable(
         <String, ChildAgentPreset>{
           for (final preset in presets) preset.id: preset,
         },
       ),
       planner = planner ?? DelegationPlanner(toolRegistry: toolRegistry);

  final Map<String, ChildAgentPreset> presets;
  final RuntimeStore runtimeStore;
  final TraceSink traceSink;
  final WnIdGenerator idGenerator;
  final WnClock clock;
  final DelegationPlanner planner;

  Future<DelegationExecutionResult> execute(
    DelegationExecutionRequest request,
    DelegationChildHandler childHandler,
  ) async {
    final presetId = request.presetId.trim();
    if (presetId.isEmpty) {
      final violations = <DelegationViolation>[
        DelegationViolation(
          code: 'preset_malformed',
          message: 'Child preset id must not be empty.',
        ),
      ];
      final trace = DelegationTraceEvent(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: request.presetId,
        status: 'rejected',
        violations: violations,
      );
      await _recordParentTrace(request, trace, TraceLevel.warning);
      return DelegationExecutionResult.rejected(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: request.presetId,
        violations: violations,
        traceEvents: <DelegationTraceEvent>[trace],
      );
    }

    final preset = presets[presetId];
    if (preset == null) {
      final violations = <DelegationViolation>[
        DelegationViolation(
          code: 'preset_unknown',
          message: 'Child preset is not registered.',
          details: <String, Object?>{'preset_id': presetId},
        ),
      ];
      final trace = DelegationTraceEvent(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: presetId,
        status: 'rejected',
        violations: violations,
      );
      await _recordParentTrace(request, trace, TraceLevel.warning);
      return DelegationExecutionResult.rejected(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: presetId,
        violations: violations,
        traceEvents: <DelegationTraceEvent>[trace],
      );
    }

    final planRequest = DelegationRequest(
      id: request.id,
      parentRunId: request.parentRunId,
      preset: preset,
      parentBudget: request.parentBudget,
      childBudget: request.requestedChildBudget,
      input: request.input,
      instructions: request.instructions,
      allowNestedDelegation: request.allowNestedDelegation,
    );
    final plan = planner.plan(planRequest);
    if (!plan.isPlanned) {
      final trace = DelegationTraceEvent(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: preset.id,
        status: 'rejected',
        violations: plan.violations,
        childBudget: plan.effectiveChildBudget,
      );
      await _recordParentTrace(request, trace, TraceLevel.warning);
      return DelegationExecutionResult.rejected(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: preset.id,
        violations: plan.violations,
        effectiveChildBudget: plan.effectiveChildBudget,
        traceEvents: <DelegationTraceEvent>[trace],
      );
    }

    final childTask = _createChildTask(request, preset);
    final childRun = _createChildRun(
      request,
      childTask,
      plan.effectiveChildBudget,
    );
    await runtimeStore.upsertTask(childTask);
    await runtimeStore.upsertRun(childRun);

    final startedTrace = DelegationTraceEvent(
      delegationId: request.id,
      parentRunId: request.parentRunId,
      presetId: preset.id,
      status: 'running',
      childTaskId: childTask.id,
      childRunId: childRun.id,
      childBudget: plan.effectiveChildBudget,
    );
    await _recordParentTrace(request, startedTrace, TraceLevel.info);

    try {
      final output = await childHandler(
        DelegationChildContext(
          delegationId: request.id,
          parentRunId: request.parentRunId,
          childTask: childTask,
          childRun: childRun,
          preset: preset,
          budget: plan.effectiveChildBudget,
          input: request.input,
          instructions: request.instructions,
        ),
      );
      final outputViolations = _validateChildOutput(
        output,
        plan.effectiveChildBudget,
      );
      if (outputViolations.isNotEmpty) {
        final failedTask = childTask.copyWith(
          status: RuntimeTaskStatus.failed,
          updatedAt: clock.now(),
          attempts: 1,
          error: outputViolations.map((violation) => violation.code).join(', '),
        );
        final failedRun = childRun.copyWith(
          status: RuntimeRunStatus.failed,
          completedAt: clock.now(),
          error: outputViolations.map((violation) => violation.code).join(', '),
        );
        await runtimeStore.upsertTask(failedTask);
        await runtimeStore.upsertRun(failedRun);
        final failedTrace = DelegationTraceEvent(
          delegationId: request.id,
          parentRunId: request.parentRunId,
          presetId: preset.id,
          status: 'failed',
          childTaskId: childTask.id,
          childRunId: childRun.id,
          childBudget: plan.effectiveChildBudget,
          violations: outputViolations,
          outputSourceRefs: output.sourceRefs,
        );
        await _recordParentTrace(request, failedTrace, TraceLevel.error);
        return DelegationExecutionResult.failed(
          delegationId: request.id,
          parentRunId: request.parentRunId,
          presetId: preset.id,
          childTaskId: childTask.id,
          childRunId: childRun.id,
          violations: outputViolations,
          effectiveChildBudget: plan.effectiveChildBudget,
          traceEvents: <DelegationTraceEvent>[startedTrace, failedTrace],
        );
      }

      final succeededTask = childTask.copyWith(
        status: RuntimeTaskStatus.succeeded,
        updatedAt: clock.now(),
        attempts: 1,
      );
      final succeededRun = childRun.copyWith(
        status: RuntimeRunStatus.succeeded,
        completedAt: clock.now(),
      );
      await runtimeStore.upsertTask(succeededTask);
      await runtimeStore.upsertRun(succeededRun);
      final completedTrace = DelegationTraceEvent(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: preset.id,
        status: 'succeeded',
        childTaskId: childTask.id,
        childRunId: childRun.id,
        childBudget: plan.effectiveChildBudget,
        outputSourceRefs: output.sourceRefs,
      );
      await _recordParentTrace(request, completedTrace, TraceLevel.info);
      return DelegationExecutionResult.succeeded(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: preset.id,
        childTaskId: childTask.id,
        childRunId: childRun.id,
        effectiveChildBudget: plan.effectiveChildBudget,
        output: output,
        traceEvents: <DelegationTraceEvent>[startedTrace, completedTrace],
      );
    } catch (error) {
      final violations = <DelegationViolation>[
        DelegationViolation(
          code: 'child_handler_failed',
          message: 'Child handler failed before returning output.',
          details: <String, Object?>{
            'error_type': error.runtimeType.toString(),
          },
        ),
      ];
      final failedTask = childTask.copyWith(
        status: RuntimeTaskStatus.failed,
        updatedAt: clock.now(),
        attempts: 1,
        error: 'child_handler_failed',
      );
      final failedRun = childRun.copyWith(
        status: RuntimeRunStatus.failed,
        completedAt: clock.now(),
        error: 'child_handler_failed',
      );
      await runtimeStore.upsertTask(failedTask);
      await runtimeStore.upsertRun(failedRun);
      final failedTrace = DelegationTraceEvent(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: preset.id,
        status: 'failed',
        childTaskId: childTask.id,
        childRunId: childRun.id,
        childBudget: plan.effectiveChildBudget,
        violations: violations,
      );
      await _recordParentTrace(request, failedTrace, TraceLevel.error);
      return DelegationExecutionResult.failed(
        delegationId: request.id,
        parentRunId: request.parentRunId,
        presetId: preset.id,
        childTaskId: childTask.id,
        childRunId: childRun.id,
        violations: violations,
        effectiveChildBudget: plan.effectiveChildBudget,
        traceEvents: <DelegationTraceEvent>[startedTrace, failedTrace],
      );
    }
  }

  RuntimeTask _createChildTask(
    DelegationExecutionRequest request,
    ChildAgentPreset preset,
  ) {
    final now = clock.now();
    return RuntimeTask(
      id: idGenerator.nextId('task'),
      identityKey: 'delegation:${request.parentRunId}:${request.id}',
      packId: request.packId,
      packVersion: request.packVersion,
      agentId: request.agentId,
      handlerRole: preset.id,
      subscriptionId: 'delegation:${preset.id}',
      triggerEventId: request.triggerEventId ?? request.parentRunId,
      status: RuntimeTaskStatus.running,
      createdAt: now,
      updatedAt: now,
      attempts: 1,
      maxAttempts: 1,
    );
  }

  RuntimeRun _createChildRun(
    DelegationExecutionRequest request,
    RuntimeTask childTask,
    CapabilityBudget childBudget,
  ) {
    final now = clock.now();
    return RuntimeRun(
      id: idGenerator.nextId('run'),
      taskId: childTask.id,
      packId: request.packId,
      packVersion: request.packVersion,
      agentId: request.agentId,
      status: RuntimeRunStatus.running,
      startedAt: now,
      attempt: childTask.attempts,
      runMode: childBudget.runMode,
      leaseExpiresAt: now.add(childBudget.maxDuration),
    );
  }

  List<DelegationViolation> _validateChildOutput(
    DelegationChildOutput output,
    CapabilityBudget budget,
  ) {
    if (output.sourceRefs.isEmpty) {
      return <DelegationViolation>[
        DelegationViolation(
          code: 'child_output_source_refs_required',
          message: 'Child output must include source refs.',
        ),
      ];
    }
    final outside = _sourceRefsOutside(output.sourceRefs, budget.sourceRefs);
    if (outside.isEmpty) {
      return const <DelegationViolation>[];
    }
    return <DelegationViolation>[
      DelegationViolation(
        code: 'child_output_source_ref_escalation',
        message: 'Child output source refs must stay within child budget.',
        details: <String, Object?>{'source_refs': outside},
      ),
    ];
  }

  Future<void> _recordParentTrace(
    DelegationExecutionRequest request,
    DelegationTraceEvent event,
    TraceLevel level,
  ) {
    return traceSink.record(
      RuntimeTrace(
        id: idGenerator.nextId('trace'),
        name: 'runtime.delegation.${event.status}',
        message: 'Child delegation ${event.status}.',
        level: level,
        createdAt: clock.now(),
        taskId: request.parentTaskId,
        runId: request.parentRunId,
        packId: request.packId,
        agentId: request.agentId,
        details: event.toJson(),
      ),
    );
  }
}

List<String> _outside(Set<String> childValues, Set<String> parentValues) {
  return childValues.where((value) => !parentValues.contains(value)).toList()
    ..sort();
}

List<JsonMap> _sourceRefsOutside(
  List<SubjectRef> childRefs,
  List<SubjectRef> parentRefs,
) {
  final parentKeys = parentRefs.map(_sourceRefKey).toSet();
  return childRefs
      .where((ref) => !parentKeys.contains(_sourceRefKey(ref)))
      .map((ref) => ref.toJson())
      .toList(growable: false);
}

List<SubjectRef> _intersectSourceRefs(
  List<SubjectRef> requestedRefs,
  List<SubjectRef> parentRefs,
) {
  final parentKeys = parentRefs.map(_sourceRefKey).toSet();
  return requestedRefs
      .where((ref) => parentKeys.contains(_sourceRefKey(ref)))
      .toList(growable: false);
}

String _sourceRefKey(SubjectRef ref) => '${ref.kind}\u0000${ref.id}';

int _runModeRank(RunMode mode) {
  return switch (mode) {
    RunMode.readOnly => 0,
    RunMode.confirm => 1,
    RunMode.auto => 2,
  };
}

RunMode _minRunMode(Iterable<RunMode> modes) {
  var selected = RunMode.auto;
  for (final mode in modes) {
    if (_runModeRank(mode) < _runModeRank(selected)) {
      selected = mode;
    }
  }
  return selected;
}

Duration _minDuration(Iterable<Duration> values) {
  Duration? selected;
  for (final value in values) {
    if (selected == null || value < selected) {
      selected = value;
    }
  }
  return selected ?? Duration.zero;
}

int _minInt(Iterable<int> values) {
  int? selected;
  for (final value in values) {
    if (selected == null || value < selected) {
      selected = value;
    }
  }
  return selected ?? 0;
}

int? _minOptionalInt(Iterable<int?> values) {
  int? selected;
  for (final value in values) {
    if (value == null) {
      continue;
    }
    if (selected == null || value < selected) {
      selected = value;
    }
  }
  return selected;
}

double? _minOptionalDouble(Iterable<double?> values) {
  double? selected;
  for (final value in values) {
    if (value == null) {
      continue;
    }
    if (selected == null || value < selected) {
      selected = value;
    }
  }
  return selected;
}

void _checkOptionalInt(int? value, String name) {
  if (value != null && value < 0) {
    throw ArgumentError.value(value, name, 'Must not be negative.');
  }
}

void _checkIntBudget(
  List<DelegationViolation> violations, {
  required String code,
  required String label,
  required int? parentValue,
  required int? childValue,
}) {
  if (parentValue == null) {
    return;
  }
  if (childValue == null || childValue > parentValue) {
    violations.add(
      DelegationViolation(
        code: code,
        message: 'Child $label cannot exceed parent $label.',
        details: <String, Object?>{
          'parent_value': parentValue,
          'child_value': childValue,
        },
      ),
    );
  }
}

void _checkPresetIntBudget(
  List<DelegationViolation> violations, {
  required String code,
  required String label,
  required int? presetValue,
  required int? childValue,
}) {
  if (presetValue == null) {
    return;
  }
  if (childValue == null || childValue > presetValue) {
    violations.add(
      DelegationViolation(
        code: code,
        message: 'Child $label cannot exceed preset $label.',
        details: <String, Object?>{
          'preset_value': presetValue,
          'child_value': childValue,
        },
      ),
    );
  }
}

void _checkCostBudget(
  List<DelegationViolation> violations, {
  required double? parentValue,
  required double? childValue,
}) {
  if (parentValue == null) {
    return;
  }
  if (childValue == null || childValue > parentValue) {
    violations.add(
      DelegationViolation(
        code: 'cost_budget_escalation',
        message: 'Child cost budget cannot exceed parent cost budget.',
        details: <String, Object?>{
          'parent_value': parentValue,
          'child_value': childValue,
        },
      ),
    );
  }
}

void _checkPresetCostBudget(
  List<DelegationViolation> violations, {
  required double? presetValue,
  required double? childValue,
}) {
  if (presetValue == null) {
    return;
  }
  if (childValue == null || childValue > presetValue) {
    violations.add(
      DelegationViolation(
        code: 'preset_cost_budget_escalation',
        message: 'Child cost budget cannot exceed preset cost budget.',
        details: <String, Object?>{
          'preset_value': presetValue,
          'child_value': childValue,
        },
      ),
    );
  }
}
