import 'dart:collection';

import 'package:widenote_core/widenote_core.dart';

import 'event.dart';
import 'run_mode.dart';
import 'task.dart';

final class ModelRequest {
  const ModelRequest({
    required this.prompt,
    this.context = const <String, Object?>{},
  });

  final String prompt;
  final JsonMap context;
}

final class ModelResponse {
  const ModelResponse({
    required this.text,
    this.raw = const <String, Object?>{},
  });

  final String text;
  final JsonMap raw;
}

abstract interface class ModelClient {
  Future<ModelResponse> complete(ModelRequest request);
}

abstract final class ModelPermissions {
  static const complete = 'model.complete';
}

final class FakeModel implements ModelClient {
  FakeModel({Iterable<String> responses = const <String>['ok']})
    : _responses = Queue<String>.of(responses);

  final Queue<String> _responses;
  final List<ModelRequest> requests = <ModelRequest>[];

  @override
  Future<ModelResponse> complete(ModelRequest request) async {
    requests.add(request);
    final text = _responses.isEmpty ? 'ok' : _responses.removeFirst();
    return ModelResponse(text: text);
  }
}

abstract interface class ToolInvoker {
  Future<WnResult<JsonMap>> invokeTool(
    String name, {
    JsonMap input = const <String, Object?>{},
  });
}

final class AgentContext {
  const AgentContext({
    required this.packId,
    required this.agentId,
    required this.task,
    required this.run,
    required this.model,
    required this.tools,
    this.runMode = RunMode.auto,
  });

  final String packId;
  final String agentId;
  final RuntimeTask task;
  final RuntimeRun run;
  final ModelClient model;
  final ToolInvoker tools;
  final RunMode runMode;

  WnEventDraft emit({
    required String type,
    JsonMap payload = const <String, Object?>{},
    SubjectRef? subjectRef,
    WnPrivacy privacy = WnPrivacy.localOnly,
  }) {
    return WnEventDraft(
      type: type,
      actor: WnActor.agent,
      packId: packId,
      agentId: agentId,
      subjectRef: subjectRef,
      payload: payload,
      privacy: privacy,
    );
  }

  Future<WnResult<JsonMap>> invokeTool(
    String name, {
    JsonMap input = const <String, Object?>{},
  }) {
    return tools.invokeTool(name, input: input);
  }
}

final class AgentHandlerResult {
  const AgentHandlerResult({
    this.events = const <WnEventDraft>[],
    this.metadata = const <String, Object?>{},
  });

  const AgentHandlerResult.empty()
    : events = const <WnEventDraft>[],
      metadata = const <String, Object?>{};

  final List<WnEventDraft> events;
  final JsonMap metadata;
}

abstract interface class AgentHandler {
  Future<AgentHandlerResult> handle(AgentContext context, WnEvent event);
}
