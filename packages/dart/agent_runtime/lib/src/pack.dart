import 'event.dart';
import 'model.dart';
import 'task.dart';

enum AgentRuntimeKind { native, declarative, remote, script }

final class AgentDefinition {
  const AgentDefinition({
    required this.id,
    this.runtimeKind = AgentRuntimeKind.native,
    this.requiredPermissions = const <String>{},
    this.outputEvents = const <String>{},
    this.tools = const <String>{},
    this.retryPolicy = const RetryPolicy(),
    this.modelProfileRef,
  });

  final String id;
  final AgentRuntimeKind runtimeKind;
  final Set<String> requiredPermissions;
  final Set<String> outputEvents;
  final Set<String> tools;
  final RetryPolicy retryPolicy;
  final String? modelProfileRef;
}

final class Subscription {
  const Subscription({
    required this.id,
    required this.agentId,
    required this.eventTypes,
    this.dependsOn = const <String>{},
  });

  final String id;
  final String agentId;
  final Set<String> eventTypes;
  final Set<String> dependsOn;

  bool matches(WnEvent event) => eventTypes.contains(event.type);
}

final class AgentPack {
  const AgentPack({
    required this.id,
    required this.name,
    required this.version,
    required this.subscriptions,
    required this.agents,
    this.requiredPermissions = const <String>{},
    this.agentDefinitions = const <String, AgentDefinition>{},
  });

  final String id;
  final String name;
  final String version;
  final List<Subscription> subscriptions;
  final Map<String, AgentHandler> agents;
  final Set<String> requiredPermissions;
  final Map<String, AgentDefinition> agentDefinitions;

  AgentHandler? handlerFor(String agentId) => agents[agentId];

  AgentDefinition definitionFor(String agentId) {
    return agentDefinitions[agentId] ??
        AgentDefinition(id: agentId, requiredPermissions: requiredPermissions);
  }
}
