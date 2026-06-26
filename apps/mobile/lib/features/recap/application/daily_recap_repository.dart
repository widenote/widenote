import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_cards/widenote_cards.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import '../../../shared/text_preview.dart';
import '../domain/daily_recap_models.dart';

final dailyRecapRepositoryProvider = Provider<DailyRecapRepository>((ref) {
  return LocalDbDailyRecapRepository(ref.watch(localDatabaseProvider));
});

final dailyRecapNowProvider = Provider<DateTime>((ref) {
  return DateTime.now();
});

final dailyRecapProvider = FutureProvider.autoDispose<DailyRecapSnapshot>((
  ref,
) {
  final now = ref.watch(dailyRecapNowProvider);
  return ref.watch(dailyRecapRepositoryProvider).loadForLocalDate(now);
});

abstract interface class DailyRecapRepository {
  Future<DailyRecapSnapshot> loadForLocalDate(DateTime localDate);
}

final class LocalDbDailyRecapRepository implements DailyRecapRepository {
  const LocalDbDailyRecapRepository(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<DailyRecapSnapshot> loadForLocalDate(DateTime localDate) async {
    final day = _LocalDay(localDate);
    final captures = _database.captures
        .readAll(limit: 500)
        .where((record) => record.status != 'deleted')
        .where((record) => day.contains(record.createdAt))
        .toList(growable: false);
    final captureDates = <String, DateTime>{
      for (final capture in _database.captures.readAll(limit: 500))
        if (capture.status != 'deleted') capture.id: capture.createdAt,
    };
    final eventDates = <String, DateTime>{
      for (final event in _database.eventLog.readAll(limit: 500))
        event.id: event.createdAt,
    };
    final memories = _database.memoryItems
        .readAll(status: 'active', limit: 500)
        .where((record) => !record.tombstone)
        .where((record) => day.contains(record.createdAt))
        .toList(growable: false);
    final todos = _database.todos
        .readAll(limit: 500)
        .where((record) => record.status != 'deleted')
        .map(
          (record) => _SourcedTodoEntry(
            record: record,
            sourceDate: _todoSourceDate(record, captureDates, eventDates),
          ),
        )
        .where((entry) => day.contains(entry.sourceDate))
        .toList(growable: false);
    final cards = _database.cards
        .readAll(status: 'active', limit: 500)
        .where((record) => day.contains(record.createdAt))
        .toList(growable: false);
    final insights = _database.insights
        .readAll(status: 'active', limit: 500)
        .where((record) => day.contains(record.createdAt))
        .toList(growable: false);
    final events = _database.eventLog
        .readAll(limit: 500)
        .where((record) => day.contains(record.createdAt))
        .toList(growable: false);
    final traces = _database.traceEvents
        .readAll(limit: 500)
        .where((record) => day.contains(record.createdAt))
        .toList(growable: false);

    return DailyRecapSnapshot(
      localDate: day.start,
      captureCount: captures.length,
      eventCount: events.length,
      memoryCount: memories.length,
      todoOpenCount: todos
          .where((todo) => todo.record.status != 'completed')
          .length,
      todoCompletedCount: todos
          .where((todo) => todo.record.status == 'completed')
          .length,
      cardCount: cards.length,
      insightCount: insights.length,
      traceCount: traces.length,
      records: _latest(
        captures.map(_captureEntry),
        createdAt: (entry) => entry._createdAt,
      ),
      memories: _latest(
        memories.map(_memoryEntry),
        createdAt: (entry) => entry._createdAt,
      ),
      cards: _latest(
        cards.map(_cardEntry),
        createdAt: (entry) => entry._createdAt,
      ),
      insights: _latest(
        insights.map(_insightEntry),
        createdAt: (entry) => entry._createdAt,
      ),
      todos: _latest(
        todos.map(_todoEntry),
        createdAt: (entry) => entry._createdAt,
      ),
    );
  }
}

_TimedRecapEntry _captureEntry(CaptureRecord record) {
  final body = _string(record.payload['text']) ?? 'Untitled capture';
  return _TimedRecapEntry(
    createdAt: record.createdAt,
    entry: DailyRecapEntry(
      id: record.id,
      title: 'Record',
      body: previewText(body, maxLength: 140),
      sourceLabel: _captureSourceLabel(record),
      timeLabel: _timeLabel(record.createdAt.toLocal()),
    ),
  );
}

_TimedRecapEntry _memoryEntry(MemoryItemRecord record) {
  return _TimedRecapEntry(
    createdAt: record.createdAt,
    entry: DailyRecapEntry(
      id: record.id,
      title: 'Memory',
      body: previewText(record.body, maxLength: 140),
      sourceLabel: _objectSourceLabel(
        selfKind: 'memory',
        selfId: record.id,
        sourceCaptureId: record.sourceCaptureId,
        sourceEventId: record.sourceEventId,
        sourceRefs: record.sourceRefs,
      ),
      timeLabel: _timeLabel(record.createdAt.toLocal()),
    ),
  );
}

_TimedRecapEntry _cardEntry(CardRecord record) {
  return _TimedRecapEntry(
    createdAt: record.createdAt,
    entry: DailyRecapEntry(
      id: record.id,
      title: record.title,
      body: previewText(record.body, maxLength: 140),
      sourceLabel: _sourceRefsLabel(record.sourceRefs, 'card:${record.id}'),
      timeLabel: _timeLabel(record.createdAt.toLocal()),
    ),
  );
}

_TimedRecapEntry _insightEntry(InsightRecord record) {
  return _TimedRecapEntry(
    createdAt: record.createdAt,
    entry: DailyRecapEntry(
      id: record.id,
      title: record.title,
      body: previewText(record.summary, maxLength: 140),
      sourceLabel: _sourceRefsLabel(record.sourceRefs, 'insight:${record.id}'),
      timeLabel: _timeLabel(record.createdAt.toLocal()),
    ),
  );
}

_TimedRecapEntry _todoEntry(_SourcedTodoEntry sourcedTodo) {
  final record = sourcedTodo.record;
  final title =
      _string(record.payload['title']) ??
      _string(record.payload['text']) ??
      'Untitled todo';
  return _TimedRecapEntry(
    createdAt: sourcedTodo.sourceDate,
    entry: DailyRecapEntry(
      id: record.id,
      title: record.status == 'completed' ? 'Completed todo' : 'Open todo',
      body: previewText(title, maxLength: 140),
      sourceLabel: _objectSourceLabel(
        selfKind: 'todo',
        selfId: record.id,
        sourceCaptureId: record.sourceCaptureId,
        sourceEventId: record.sourceEventId,
        sourceRefs: const <Object?>[],
      ),
      timeLabel: _timeLabel(sourcedTodo.sourceDate.toLocal()),
    ),
  );
}

DateTime _todoSourceDate(
  TodoRecord record,
  Map<String, DateTime> captureDates,
  Map<String, DateTime> eventDates,
) {
  final sourceCaptureDate = captureDates[record.sourceCaptureId];
  if (sourceCaptureDate != null) {
    return sourceCaptureDate;
  }
  final sourceEventDate = eventDates[record.sourceEventId];
  if (sourceEventDate != null) {
    return sourceEventDate;
  }
  return record.createdAt;
}

List<DailyRecapEntry> _latest(
  Iterable<_TimedRecapEntry> entries, {
  required DateTime Function(_TimedRecapEntry entry) createdAt,
}) {
  final sorted = entries.toList()
    ..sort((a, b) => createdAt(b).compareTo(createdAt(a)));
  return sorted.map((entry) => entry.entry).take(4).toList(growable: false);
}

String _captureSourceLabel(CaptureRecord record) {
  final eventId = _string(record.payload['source_event_id']) ?? record.sourceId;
  if (eventId != null) {
    return 'event: $eventId';
  }
  return 'capture: ${record.id}';
}

String _objectSourceLabel({
  required String selfKind,
  required String selfId,
  required String? sourceCaptureId,
  required String? sourceEventId,
  required List<Object?> sourceRefs,
}) {
  if (sourceRefs.isNotEmpty) {
    return _sourceRefsLabel(sourceRefs, '$selfKind:$selfId');
  }
  if (sourceEventId != null) {
    return 'event: $sourceEventId';
  }
  if (sourceCaptureId != null) {
    return 'capture: $sourceCaptureId';
  }
  return '$selfKind: $selfId';
}

String _sourceRefsLabel(List<Object?> refs, String fallback) {
  final links = sourceLinksFromJsonList(refs);
  if (links.isEmpty) {
    return 'source: $fallback';
  }
  final first = links.first;
  final extra = links.length == 1 ? '' : ' +${links.length - 1}';
  return 'source: ${first.kind}:${first.id}$extra';
}

String _timeLabel(DateTime localTime) {
  final hour = localTime.hour.toString().padLeft(2, '0');
  final minute = localTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

final class _TimedRecapEntry {
  const _TimedRecapEntry({required this.createdAt, required this.entry});

  final DateTime createdAt;
  final DailyRecapEntry entry;

  DateTime get _createdAt => createdAt;
}

final class _SourcedTodoEntry {
  const _SourcedTodoEntry({required this.record, required this.sourceDate});

  final TodoRecord record;
  final DateTime sourceDate;
}

final class _LocalDay {
  _LocalDay(DateTime value)
    : start = DateTime(
        value.toLocal().year,
        value.toLocal().month,
        value.toLocal().day,
      ),
      end = DateTime(
        value.toLocal().year,
        value.toLocal().month,
        value.toLocal().day,
      ).add(const Duration(days: 1));

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    final local = value.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }
}
