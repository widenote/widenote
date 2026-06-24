import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';

final traceConsoleControllerProvider = Provider<TraceConsoleSnapshot>((ref) {
  final traces = ref
      .watch(localDatabaseProvider)
      .traceEvents
      .readAll(limit: 200)
      .reversed
      .map(_traceItemFromRecord)
      .toList(growable: false);
  return TraceConsoleSnapshot(items: traces);
});

final class TraceConsoleSnapshot {
  const TraceConsoleSnapshot({required this.items});

  final List<TraceConsoleItem> items;

  int get runCount {
    return items.map((item) => item.runId).whereType<String>().toSet().length;
  }

  int get warningCount {
    return items.where((item) => item.isWarningLike).length;
  }
}

final class TraceConsoleItem {
  const TraceConsoleItem({
    required this.id,
    required this.title,
    required this.severity,
    required this.status,
    required this.message,
    required this.createdAt,
    this.runId,
    this.packId,
    this.agentId,
    this.eventId,
    this.durationMs,
  });

  final String id;
  final String title;
  final String severity;
  final String status;
  final String message;
  final DateTime createdAt;
  final String? runId;
  final String? packId;
  final String? agentId;
  final String? eventId;
  final num? durationMs;

  bool get isWarningLike {
    final normalized = severity.toLowerCase();
    return normalized == 'warning' ||
        normalized == 'warn' ||
        normalized == 'error' ||
        status.toLowerCase() != 'ok';
  }
}

TraceConsoleItem _traceItemFromRecord(TraceEventRecord trace) {
  return TraceConsoleItem(
    id: trace.id,
    title: trace.traceType,
    severity: trace.severity,
    status: trace.status,
    message: trace.message,
    createdAt: trace.createdAt,
    runId: trace.runId,
    packId: trace.packId,
    agentId: trace.agentId,
    eventId: trace.eventId,
    durationMs: trace.durationMs,
  );
}
