import 'package:widenote_core/widenote_core.dart';

import 'event.dart';
import 'run_mode.dart';

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
    required Iterable<DelegationViolation> violations,
  }) : violations = List<DelegationViolation>.unmodifiable(violations);

  factory DelegationResult.planned(DelegationRequest request) {
    return DelegationResult._(
      state: DelegationResultState.planned,
      request: request,
      violations: const <DelegationViolation>[],
    );
  }

  factory DelegationResult.rejected(
    DelegationRequest request,
    Iterable<DelegationViolation> violations,
  ) {
    return DelegationResult._(
      state: DelegationResultState.rejected,
      request: request,
      violations: violations,
    );
  }

  final DelegationResultState state;
  final DelegationRequest request;
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
}

final class DelegationPlanner {
  const DelegationPlanner();

  DelegationResult plan(DelegationRequest request) {
    final violations = <DelegationViolation>[];
    final parent = request.parentBudget;
    final child = request.childBudget;

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
      request.preset.allowedTools,
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

    _checkIntBudget(
      violations,
      code: 'input_token_budget_escalation',
      label: 'maxInputTokens',
      parentValue: parent.maxInputTokens,
      childValue: child.maxInputTokens,
    );
    _checkIntBudget(
      violations,
      code: 'output_token_budget_escalation',
      label: 'maxOutputTokens',
      parentValue: parent.maxOutputTokens,
      childValue: child.maxOutputTokens,
    );
    _checkIntBudget(
      violations,
      code: 'total_token_budget_escalation',
      label: 'maxTotalTokens',
      parentValue: parent.maxTotalTokens,
      childValue: child.maxTotalTokens,
    );
    _checkCostBudget(
      violations,
      parentValue: parent.maxEstimatedCostUsd,
      childValue: child.maxEstimatedCostUsd,
    );

    if (violations.isNotEmpty) {
      return DelegationResult.rejected(request, violations);
    }
    return DelegationResult.planned(request);
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

String _sourceRefKey(SubjectRef ref) => '${ref.kind}\u0000${ref.id}';

int _runModeRank(RunMode mode) {
  return switch (mode) {
    RunMode.readOnly => 0,
    RunMode.confirm => 1,
    RunMode.auto => 2,
  };
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
