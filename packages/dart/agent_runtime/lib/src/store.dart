import 'event.dart';

abstract interface class EventStore {
  Future<void> append(WnEvent event);
  Future<void> appendAll(Iterable<WnEvent> events);
  Future<List<WnEvent>> readAll();
  Future<WnEvent?> readById(String id);
  Future<List<WnEvent>> readByType(String type);
}

final class InMemoryEventStore implements EventStore {
  final List<WnEvent> _events = <WnEvent>[];
  final Map<String, WnEvent> _byId = <String, WnEvent>{};

  @override
  Future<void> append(WnEvent event) async {
    if (_byId.containsKey(event.id)) {
      throw StateError('Event already exists: ${event.id}');
    }
    _events.add(event);
    _byId[event.id] = event;
  }

  @override
  Future<void> appendAll(Iterable<WnEvent> events) async {
    for (final event in events) {
      await append(event);
    }
  }

  @override
  Future<List<WnEvent>> readAll() async => List<WnEvent>.unmodifiable(_events);

  @override
  Future<WnEvent?> readById(String id) async => _byId[id];

  @override
  Future<List<WnEvent>> readByType(String type) async {
    return List<WnEvent>.unmodifiable(
      _events.where((event) => event.type == type),
    );
  }
}
