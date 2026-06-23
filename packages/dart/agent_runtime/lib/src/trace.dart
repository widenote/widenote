import 'package:widenote_core/widenote_core.dart';

enum TraceLevel { debug, info, warning, error }

final class RuntimeTrace {
  const RuntimeTrace({
    required this.id,
    required this.name,
    required this.message,
    required this.level,
    required this.createdAt,
    this.eventId,
    this.taskId,
    this.runId,
    this.packId,
    this.agentId,
    this.details = const <String, Object?>{},
  });

  final String id;
  final String name;
  final String message;
  final TraceLevel level;
  final DateTime createdAt;
  final String? eventId;
  final String? taskId;
  final String? runId;
  final String? packId;
  final String? agentId;
  final JsonMap details;
}

abstract interface class TraceSink {
  Future<void> record(RuntimeTrace trace);
  Future<List<RuntimeTrace>> readAll();
  Future<List<RuntimeTrace>> readByRun(String runId);
}

final class InMemoryTraceSink implements TraceSink {
  final List<RuntimeTrace> _traces = <RuntimeTrace>[];

  @override
  Future<void> record(RuntimeTrace trace) async {
    _traces.add(trace);
  }

  @override
  Future<List<RuntimeTrace>> readAll() async {
    return List<RuntimeTrace>.unmodifiable(_traces);
  }

  @override
  Future<List<RuntimeTrace>> readByRun(String runId) async {
    return List<RuntimeTrace>.unmodifiable(
      _traces.where((trace) => trace.runId == runId),
    );
  }
}
