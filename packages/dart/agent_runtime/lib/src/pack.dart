import 'event.dart';
import 'model.dart';

final class Subscription {
  const Subscription({
    required this.id,
    required this.agentId,
    required this.eventTypes,
  });

  final String id;
  final String agentId;
  final Set<String> eventTypes;

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
  });

  final String id;
  final String name;
  final String version;
  final List<Subscription> subscriptions;
  final Map<String, AgentHandler> agents;
  final Set<String> requiredPermissions;

  AgentHandler? handlerFor(String agentId) => agents[agentId];
}
