import 'event.dart';
import 'task.dart';

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
    final batch = events.toList(growable: false);
    final batchIds = <String>{};
    for (final event in batch) {
      if (_byId.containsKey(event.id)) {
        throw StateError('Event already exists: ${event.id}');
      }
      if (!batchIds.add(event.id)) {
        throw StateError('Duplicate event in batch: ${event.id}');
      }
    }
    for (final event in batch) {
      _events.add(event);
      _byId[event.id] = event;
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

abstract interface class RuntimeStore {
  Future<void> upsertTask(RuntimeTask task);
  Future<RuntimeTask?> readTaskById(String id);
  Future<List<RuntimeTask>> readTasks({String? packId});

  Future<void> upsertRun(RuntimeRun run);
  Future<RuntimeRun?> readRunById(String id);
  Future<List<RuntimeRun>> readRuns({String? taskId, String? packId});

  Future<void> upsertPackStatus(RuntimePackStatus status);
  Future<RuntimePackStatus?> readPackStatus(String packId);
  Future<List<RuntimePackStatus>> readPackStatuses();
}

final class InMemoryRuntimeStore implements RuntimeStore {
  final Map<String, RuntimeTask> _tasksById = <String, RuntimeTask>{};
  final List<String> _taskOrder = <String>[];
  final Map<String, RuntimeRun> _runsById = <String, RuntimeRun>{};
  final List<String> _runOrder = <String>[];
  final Map<String, RuntimePackStatus> _packStatusesById =
      <String, RuntimePackStatus>{};
  final List<String> _packStatusOrder = <String>[];

  @override
  Future<void> upsertTask(RuntimeTask task) async {
    if (!_tasksById.containsKey(task.id)) {
      _taskOrder.add(task.id);
    }
    _tasksById[task.id] = task;
  }

  @override
  Future<RuntimeTask?> readTaskById(String id) async => _tasksById[id];

  @override
  Future<List<RuntimeTask>> readTasks({String? packId}) async {
    return List<RuntimeTask>.unmodifiable(
      _taskOrder
          .map((id) => _tasksById[id])
          .whereType<RuntimeTask>()
          .where((task) => packId == null || task.packId == packId),
    );
  }

  @override
  Future<void> upsertRun(RuntimeRun run) async {
    if (!_runsById.containsKey(run.id)) {
      _runOrder.add(run.id);
    }
    _runsById[run.id] = run;
  }

  @override
  Future<RuntimeRun?> readRunById(String id) async => _runsById[id];

  @override
  Future<List<RuntimeRun>> readRuns({String? taskId, String? packId}) async {
    return List<RuntimeRun>.unmodifiable(
      _runOrder
          .map((id) => _runsById[id])
          .whereType<RuntimeRun>()
          .where((run) => taskId == null || run.taskId == taskId)
          .where((run) => packId == null || run.packId == packId),
    );
  }

  @override
  Future<void> upsertPackStatus(RuntimePackStatus status) async {
    if (!_packStatusesById.containsKey(status.packId)) {
      _packStatusOrder.add(status.packId);
    }
    _packStatusesById[status.packId] = status;
  }

  @override
  Future<RuntimePackStatus?> readPackStatus(String packId) async {
    return _packStatusesById[packId];
  }

  @override
  Future<List<RuntimePackStatus>> readPackStatuses() async {
    return List<RuntimePackStatus>.unmodifiable(
      _packStatusOrder
          .map((id) => _packStatusesById[id])
          .whereType<RuntimePackStatus>(),
    );
  }
}
