import 'package:widenote_core/widenote_core.dart';

import 'model.dart';

enum ToolLoopStopReason { completed, maxCalls, toolError, denied, timeout }

final class ToolLoopCall {
  ToolLoopCall({
    required this.toolName,
    JsonMap input = const <String, Object?>{},
    this.roundId,
  }) : input = immutableJsonMap(input) {
    if (toolName.trim().isEmpty) {
      throw ArgumentError.value(toolName, 'toolName', 'Must not be empty.');
    }
  }

  final String toolName;
  final JsonMap input;
  final String? roundId;
}

final class ToolLoopRequest {
  ToolLoopRequest({
    required Iterable<ToolLoopCall> calls,
    required Iterable<String> declaredTools,
    required this.maxToolCalls,
    this.maxDuration,
  }) : calls = List<ToolLoopCall>.unmodifiable(calls),
       declaredTools = Set<String>.unmodifiable(declaredTools) {
    if (maxToolCalls < 0) {
      throw ArgumentError.value(
        maxToolCalls,
        'maxToolCalls',
        'Must not be negative.',
      );
    }
    final duration = maxDuration;
    if (duration != null && duration < Duration.zero) {
      throw ArgumentError.value(
        duration,
        'maxDuration',
        'Must not be negative.',
      );
    }
  }

  final List<ToolLoopCall> calls;
  final Set<String> declaredTools;
  final int maxToolCalls;
  final Duration? maxDuration;
}

final class ToolLoopStep {
  const ToolLoopStep({
    required this.callIndex,
    required this.call,
    required this.startedAt,
    required this.completedAt,
    required this.result,
  });

  final int callIndex;
  final ToolLoopCall call;
  final DateTime startedAt;
  final DateTime completedAt;
  final WnResult<JsonMap> result;
}

final class ToolLoopResult {
  ToolLoopResult({
    required this.stopReason,
    required Iterable<ToolLoopStep> steps,
    required this.startedAt,
    required this.completedAt,
    this.failure,
  }) : steps = List<ToolLoopStep>.unmodifiable(steps);

  final ToolLoopStopReason stopReason;
  final List<ToolLoopStep> steps;
  final DateTime startedAt;
  final DateTime completedAt;
  final WnFailure? failure;

  bool get completed => stopReason == ToolLoopStopReason.completed;
  int get toolCallCount => steps.length;
}

final class ToolLoopExecutor {
  const ToolLoopExecutor({required this.tools, required this.clock});

  final ToolInvoker tools;
  final WnClock clock;

  Future<ToolLoopResult> run(ToolLoopRequest request) async {
    final startedAt = clock.now();
    final steps = <ToolLoopStep>[];

    for (final call in request.calls) {
      final observedAt = clock.now();
      if (_timedOut(startedAt, observedAt, request.maxDuration)) {
        return _finish(
          ToolLoopStopReason.timeout,
          startedAt: startedAt,
          steps: steps,
          completedAt: observedAt,
        );
      }

      if (steps.length >= request.maxToolCalls) {
        return _finish(
          ToolLoopStopReason.maxCalls,
          startedAt: startedAt,
          steps: steps,
          completedAt: observedAt,
        );
      }

      if (!request.declaredTools.contains(call.toolName)) {
        final completedAt = clock.now();
        final failure = WnFailure(
          code: 'tool_not_declared',
          message: 'Tool was not declared for this loop: ${call.toolName}',
          details: <String, Object?>{'tool_name': call.toolName},
        );
        steps.add(
          ToolLoopStep(
            callIndex: steps.length,
            call: call,
            startedAt: observedAt,
            completedAt: completedAt,
            result: WnResult<JsonMap>.err(failure),
          ),
        );
        return _finish(
          ToolLoopStopReason.denied,
          startedAt: startedAt,
          steps: steps,
          completedAt: completedAt,
          failure: failure,
        );
      }

      final result = await _invoke(call);
      final completedAt = clock.now();
      steps.add(
        ToolLoopStep(
          callIndex: steps.length,
          call: call,
          startedAt: observedAt,
          completedAt: completedAt,
          result: result,
        ),
      );

      if (result.isErr) {
        final failure = result.failure;
        return _finish(
          isToolLoopDeniedFailure(failure)
              ? ToolLoopStopReason.denied
              : ToolLoopStopReason.toolError,
          startedAt: startedAt,
          steps: steps,
          completedAt: completedAt,
          failure: failure,
        );
      }

      if (_timedOut(startedAt, completedAt, request.maxDuration)) {
        return _finish(
          ToolLoopStopReason.timeout,
          startedAt: startedAt,
          steps: steps,
          completedAt: completedAt,
        );
      }
    }

    return _finish(
      ToolLoopStopReason.completed,
      startedAt: startedAt,
      steps: steps,
      completedAt: clock.now(),
    );
  }

  Future<WnResult<JsonMap>> _invoke(ToolLoopCall call) async {
    try {
      return await tools.invokeTool(call.toolName, input: call.input);
    } catch (error) {
      return WnResult<JsonMap>.err(
        WnFailure(
          code: 'tool_exception',
          message: 'Tool invocation threw before returning a result.',
          details: <String, Object?>{
            'tool_name': call.toolName,
            'error_type': error.runtimeType.toString(),
          },
        ),
      );
    }
  }

  bool _timedOut(
    DateTime startedAt,
    DateTime observedAt,
    Duration? maxDuration,
  ) {
    if (maxDuration == null) {
      return false;
    }
    return observedAt.isAfter(startedAt.add(maxDuration));
  }

  ToolLoopResult _finish(
    ToolLoopStopReason reason, {
    required DateTime startedAt,
    required List<ToolLoopStep> steps,
    required DateTime completedAt,
    WnFailure? failure,
  }) {
    return ToolLoopResult(
      stopReason: reason,
      steps: steps,
      startedAt: startedAt,
      completedAt: completedAt,
      failure: failure,
    );
  }
}

bool isToolLoopDeniedFailure(WnFailure failure) {
  return _deniedFailureCodes.contains(failure.code);
}

const _deniedFailureCodes = <String>{
  'approval_denied',
  'approval_failed',
  'approval_unavailable',
  'permission_denied',
  'run_mode_denied',
  'tool_not_declared',
};
