import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../../timeline/application/timeline_repository.dart';

final todoControllerProvider = NotifierProvider<TodoController, TodoState>(
  TodoController.new,
);

final todoNowProvider = Provider<DateTime>((ref) => DateTime.now());

enum TodoDuePreset { none, today, tomorrow, later }

enum TodoBucket { overdue, today, tomorrow, later, noDeadline }

@immutable
final class TodoState {
  const TodoState({
    required this.allItems,
    required this.actionItems,
    required this.scheduleItems,
    required this.completedItems,
    required this.quietItems,
    required this.overdueItems,
    required this.todayItems,
    required this.tomorrowItems,
    required this.laterItems,
    required this.noDeadlineItems,
    required this.searchQuery,
    required this.totalOpenActionCount,
    required this.totalScheduleCount,
    required this.totalCompletedCount,
    this.errorMessage,
  });

  final List<TodoListItem> allItems;
  final List<TodoListItem> actionItems;
  final List<TodoListItem> scheduleItems;
  final List<TodoListItem> completedItems;
  final List<TodoListItem> quietItems;
  final List<TodoListItem> overdueItems;
  final List<TodoListItem> todayItems;
  final List<TodoListItem> tomorrowItems;
  final List<TodoListItem> laterItems;
  final List<TodoListItem> noDeadlineItems;
  final String searchQuery;
  final int totalOpenActionCount;
  final int totalScheduleCount;
  final int totalCompletedCount;
  final String? errorMessage;

  List<TodoListItem> get items => <TodoListItem>[
    ...actionItems,
    ...scheduleItems,
    ...completedItems,
  ];

  int get quietCount => quietItems.length;

  bool get hasSearch => searchQuery.trim().isNotEmpty;

  bool get hasVisibleItems {
    return actionItems.isNotEmpty ||
        scheduleItems.isNotEmpty ||
        completedItems.isNotEmpty;
  }

  TodoListItem? itemById(String id) {
    for (final item in allItems) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  TodoState copyWith({String? errorMessage, bool clearError = false}) {
    return TodoState(
      allItems: allItems,
      actionItems: actionItems,
      scheduleItems: scheduleItems,
      completedItems: completedItems,
      quietItems: quietItems,
      overdueItems: overdueItems,
      todayItems: todayItems,
      tomorrowItems: tomorrowItems,
      laterItems: laterItems,
      noDeadlineItems: noDeadlineItems,
      searchQuery: searchQuery,
      totalOpenActionCount: totalOpenActionCount,
      totalScheduleCount: totalScheduleCount,
      totalCompletedCount: totalCompletedCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

@immutable
final class TodoListItem {
  const TodoListItem({
    required this.id,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.sourceLabel,
    required this.suggestionKind,
    required this.confidenceLabel,
    required this.createdAt,
    required this.updatedAt,
    this.body,
    this.reasonLabel,
    this.scheduledAtLabel,
    this.dueAt,
    this.dueLabel,
    this.scheduledStart,
    this.scheduledEnd,
    this.priority,
    this.sortOrder = 0,
    this.indentLevel = 0,
    this.completedAt,
    this.completedBy,
    this.userOverrides = const <String>[],
    this.subtasks = const <TodoSubtask>[],
    this.sourceCaptureId,
    this.sourceEventId,
  });

  final String id;
  final String title;
  final String status;
  final String statusLabel;
  final String sourceLabel;
  final String suggestionKind;
  final String confidenceLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? body;
  final String? reasonLabel;
  final String? scheduledAtLabel;
  final DateTime? dueAt;
  final String? dueLabel;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final String? priority;
  final int sortOrder;
  final int indentLevel;
  final DateTime? completedAt;
  final String? completedBy;
  final List<String> userOverrides;
  final List<TodoSubtask> subtasks;
  final String? sourceCaptureId;
  final String? sourceEventId;

  bool get isCompleted => status == 'completed';
  bool get isAction => suggestionKind == 'action';
  bool get isSchedule => suggestionKind == 'schedule';
  bool get isQuiet => suggestionKind == 'quiet';
  bool get hasDue => dueAt != null || (dueLabel?.isNotEmpty ?? false);

  DateTime? get sortDate => dueAt ?? scheduledStart;

  String get searchText {
    return <String?>[
      title,
      body,
      status,
      statusLabel,
      sourceLabel,
      suggestionKind,
      confidenceLabel,
      reasonLabel,
      scheduledAtLabel,
      dueLabel,
      priority,
      completedBy,
      ...subtasks.map((subtask) => subtask.title),
    ].whereType<String>().join(' ').toLowerCase();
  }
}

@immutable
final class TodoSubtask {
  const TodoSubtask({
    required this.id,
    required this.title,
    required this.completed,
  });

  final String id;
  final String title;
  final bool completed;
}

final class TodoController extends Notifier<TodoState> {
  @override
  TodoState build() {
    return _readState(searchQuery: '');
  }

  void setSearchQuery(String query) {
    state = _readState(searchQuery: query).copyWith(clearError: true);
  }

  Future<void> refresh() async {
    state = _readState(
      searchQuery: state.searchQuery,
    ).copyWith(clearError: true);
  }

  void complete(String id) {
    _setActionStatus(id, 'completed');
  }

  void reopen(String id) {
    _setActionStatus(id, 'open');
  }

  void updateTitle(String id, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _updatePayload(
      id,
      (payload, now) => payload
        ..['title'] = trimmed
        ..['todo_schema_version'] = 1,
      userOverrideKeys: const <String>{'title'},
    );
  }

  void setPriority(String id, String? priority) {
    final normalized = _normalizedPriority(priority);
    _updatePayload(id, (payload, now) {
      payload['todo_schema_version'] = 1;
      if (normalized == null) {
        payload.remove('priority');
      } else {
        payload['priority'] = normalized;
      }
      return payload;
    }, userOverrideKeys: const <String>{'priority'});
  }

  void setDuePreset(String id, TodoDuePreset preset) {
    _updatePayload(id, (payload, now) {
      payload['todo_schema_version'] = 1;
      if (preset == TodoDuePreset.none) {
        payload.remove('due_at');
        payload.remove('due_label');
        return payload;
      }
      payload['due_at'] = _dueAtForPreset(preset, now).toIso8601String();
      payload.remove('due_label');
      return payload;
    }, userOverrideKeys: const <String>{'due_at'});
  }

  void increaseIndent(String id) {
    _adjustIndent(id, 1);
  }

  void decreaseIndent(String id) {
    _adjustIndent(id, -1);
  }

  void moveEarlier(String id) {
    _adjustSortOrder(id, -100);
  }

  void moveLater(String id) {
    _adjustSortOrder(id, 100);
  }

  void _setActionStatus(String id, String status) {
    try {
      final record = _database.todos.readById(id);
      if (record == null) {
        return;
      }
      final item = _todoView(record);
      if (!item.isAction) {
        return;
      }
      final now = ref.read(todoNowProvider).toUtc();
      final payload = Map<String, Object?>.from(record.payload)
        ..['todo_schema_version'] = 1;
      if (status == 'completed') {
        payload['completed_at'] = now.toIso8601String();
        payload['completed_by'] = 'user';
      } else {
        payload.remove('completed_at');
        payload.remove('completed_by');
      }
      payload['user_overrides'] = _mergeUserOverrides(
        payload['user_overrides'],
        const <String>{'status'},
      );
      _database.todos.save(
        record.copyWith(status: status, payload: payload, updatedAt: now),
      );
      ref.invalidate(timelineSnapshotProvider);
      state = _readState(
        searchQuery: state.searchQuery,
      ).copyWith(clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Todo update failed.');
    }
  }

  void _adjustIndent(String id, int delta) {
    _updatePayload(id, (payload, now) {
      final current = _int(payload['indent_level']) ?? 0;
      payload['todo_schema_version'] = 1;
      payload['indent_level'] = (current + delta).clamp(0, 3);
      return payload;
    }, userOverrideKeys: const <String>{'indent_level'});
  }

  void _adjustSortOrder(String id, int delta) {
    _updatePayload(id, (payload, now) {
      final current = _int(payload['sort_order']) ?? 0;
      payload['todo_schema_version'] = 1;
      payload['sort_order'] = current + delta;
      return payload;
    }, userOverrideKeys: const <String>{'sort_order'});
  }

  void _updatePayload(
    String id,
    Map<String, Object?> Function(Map<String, Object?> payload, DateTime now)
    update, {
    Set<String> userOverrideKeys = const <String>{},
  }) {
    try {
      final record = _database.todos.readById(id);
      if (record == null) {
        return;
      }
      final now = ref.read(todoNowProvider).toUtc();
      final payload = update(Map<String, Object?>.from(record.payload), now);
      if (userOverrideKeys.isNotEmpty) {
        payload['user_overrides'] = _mergeUserOverrides(
          payload['user_overrides'],
          userOverrideKeys,
        );
      }
      _database.todos.save(record.copyWith(payload: payload, updatedAt: now));
      ref.invalidate(timelineSnapshotProvider);
      state = _readState(
        searchQuery: state.searchQuery,
      ).copyWith(clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Todo update failed.');
    }
  }

  TodoState _readState({required String searchQuery}) {
    final now = ref.read(todoNowProvider);
    final allItems =
        _database.todos.readAll().map(_todoView).toList(growable: false)
          ..sort(_compareTodoDisplay);
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final searchedItems = normalizedQuery.isEmpty
        ? allItems
        : allItems
              .where((item) => item.searchText.contains(normalizedQuery))
              .toList(growable: false);
    final visibleItems = searchedItems
        .where((item) => !item.isQuiet)
        .toList(growable: false);
    final actionItems = visibleItems
        .where((item) => item.isAction && !item.isCompleted)
        .toList(growable: false);
    final completedItems =
        visibleItems.where((item) => item.isCompleted).toList(growable: false)
          ..sort(_compareCompletedTodoDisplay);
    final scheduleItems = visibleItems
        .where((item) => item.isSchedule && !item.isCompleted)
        .toList(growable: false);
    final quietItems = allItems
        .where((item) => item.isQuiet)
        .toList(growable: false);

    return TodoState(
      allItems: allItems,
      actionItems: actionItems,
      scheduleItems: scheduleItems,
      completedItems: completedItems,
      quietItems: quietItems,
      overdueItems: actionItems
          .where((item) => _bucketFor(item, now) == TodoBucket.overdue)
          .toList(growable: false),
      todayItems: actionItems
          .where((item) => _bucketFor(item, now) == TodoBucket.today)
          .toList(growable: false),
      tomorrowItems: actionItems
          .where((item) => _bucketFor(item, now) == TodoBucket.tomorrow)
          .toList(growable: false),
      laterItems: actionItems
          .where((item) => _bucketFor(item, now) == TodoBucket.later)
          .toList(growable: false),
      noDeadlineItems: actionItems
          .where((item) => _bucketFor(item, now) == TodoBucket.noDeadline)
          .toList(growable: false),
      searchQuery: searchQuery,
      totalOpenActionCount: allItems
          .where((item) => item.isAction && !item.isCompleted)
          .length,
      totalScheduleCount: allItems
          .where((item) => item.isSchedule && !item.isCompleted)
          .length,
      totalCompletedCount: allItems
          .where((item) => item.isCompleted && !item.isQuiet)
          .length,
    );
  }

  localdb.WideNoteLocalDatabase get _database {
    return ref.read(localDatabaseProvider);
  }
}

TodoListItem _todoView(localdb.TodoRecord record) {
  final title =
      _string(record.payload['title']) ??
      _string(record.payload['text']) ??
      'Review capture';
  final suggestionKind = _normalizedSuggestionKind(
    _string(record.payload['suggestion_kind']),
  );
  final statusLabel =
      _string(record.payload['status_label']) ??
      switch (suggestionKind) {
        'schedule' => 'schedule candidate',
        'action' => record.status,
        _ => 'not suggested',
      };
  return TodoListItem(
    id: record.id,
    title: title,
    body: _string(record.payload['body']) ?? _string(record.payload['summary']),
    status: record.status,
    statusLabel: record.status == 'completed' ? 'completed' : statusLabel,
    sourceLabel:
        _string(record.payload['source_label']) ??
        _sourceLabel(
          id: record.id,
          sourceCaptureId: record.sourceCaptureId,
          sourceEventId: record.sourceEventId,
        ),
    suggestionKind: suggestionKind,
    confidenceLabel: _string(record.payload['suggestion_confidence']) ?? 'low',
    reasonLabel:
        _string(record.payload['suggestion_reason']) ??
        'legacy_missing_suggestion_kind',
    scheduledAtLabel:
        _string(record.payload['scheduled_at_label']) ??
        _string(record.payload['scheduled_start_label']),
    dueAt: _dateTime(record.payload['due_at']),
    dueLabel: _string(record.payload['due_label']),
    scheduledStart: _dateTime(record.payload['scheduled_start']),
    scheduledEnd: _dateTime(record.payload['scheduled_end']),
    priority: _normalizedPriority(_string(record.payload['priority'])),
    sortOrder: _int(record.payload['sort_order']) ?? 0,
    indentLevel: (_int(record.payload['indent_level']) ?? 0).clamp(0, 3),
    completedAt: _dateTime(record.payload['completed_at']),
    completedBy: _string(record.payload['completed_by']),
    userOverrides: _stringList(record.payload['user_overrides']),
    subtasks: _subtasks(record.payload['subtasks']),
    sourceCaptureId: record.sourceCaptureId,
    sourceEventId: record.sourceEventId,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
  );
}

TodoBucket _bucketFor(TodoListItem item, DateTime now) {
  final dueAt = item.dueAt;
  if (dueAt == null) {
    return TodoBucket.noDeadline;
  }
  final dueLocal = dueAt.toLocal();
  final today = _startOfLocalDay(now);
  final dueDay = _startOfLocalDay(dueLocal);
  if (dueDay.isBefore(today)) {
    return TodoBucket.overdue;
  }
  if (dueDay == today) {
    return TodoBucket.today;
  }
  if (dueDay == today.add(const Duration(days: 1))) {
    return TodoBucket.tomorrow;
  }
  return TodoBucket.later;
}

DateTime _dueAtForPreset(TodoDuePreset preset, DateTime now) {
  final today = _startOfLocalDay(now.toLocal());
  final dueDay = switch (preset) {
    TodoDuePreset.today => today,
    TodoDuePreset.tomorrow => today.add(const Duration(days: 1)),
    TodoDuePreset.later => today.add(const Duration(days: 7)),
    TodoDuePreset.none => today,
  };
  return DateTime(dueDay.year, dueDay.month, dueDay.day, 23, 59).toUtc();
}

DateTime _startOfLocalDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

int _compareTodoDisplay(TodoListItem a, TodoListItem b) {
  final sort = a.sortOrder.compareTo(b.sortOrder);
  if (sort != 0) {
    return sort;
  }
  final aDate = a.sortDate;
  final bDate = b.sortDate;
  if (aDate != null && bDate != null) {
    final date = aDate.compareTo(bDate);
    if (date != 0) {
      return date;
    }
  } else if (aDate != null) {
    return -1;
  } else if (bDate != null) {
    return 1;
  }
  final updated = b.updatedAt.compareTo(a.updatedAt);
  if (updated != 0) {
    return updated;
  }
  return a.id.compareTo(b.id);
}

int _compareCompletedTodoDisplay(TodoListItem a, TodoListItem b) {
  final aCompletedAt = a.completedAt ?? a.updatedAt;
  final bCompletedAt = b.completedAt ?? b.updatedAt;
  final completed = bCompletedAt.compareTo(aCompletedAt);
  if (completed != 0) {
    return completed;
  }
  return _compareTodoDisplay(a, b);
}

String _sourceLabel({
  required String id,
  String? sourceCaptureId,
  String? sourceEventId,
}) {
  if (sourceCaptureId != null) {
    return 'source: $sourceCaptureId';
  }
  if (sourceEventId != null) {
    return 'event: $sourceEventId';
  }
  return 'todo: $id';
}

String _normalizedSuggestionKind(String? value) {
  return switch (value) {
    'action' => 'action',
    'schedule' => 'schedule',
    _ => 'quiet',
  };
}

String? _normalizedPriority(String? value) {
  return switch (value) {
    'high' => 'high',
    'medium' => 'medium',
    'low' => 'low',
    _ => null,
  };
}

DateTime? _dateTime(Object? value) {
  final raw = _string(value);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  final raw = _string(value);
  if (raw == null) {
    return null;
  }
  return int.tryParse(raw);
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map(_string).whereType<String>().toSet().toList(growable: false)
    ..sort();
}

List<String> _mergeUserOverrides(Object? value, Set<String> keys) {
  final merged = <String>{..._stringList(value), ...keys};
  return merged.toList(growable: false)..sort();
}

List<TodoSubtask> _subtasks(Object? value) {
  if (value is! List) {
    return const <TodoSubtask>[];
  }
  final subtasks = <TodoSubtask>[];
  for (final entry in value) {
    if (entry is! Map) {
      continue;
    }
    final map = entry.cast<String, Object?>();
    final title = _string(map['title']);
    if (title == null) {
      continue;
    }
    subtasks.add(
      TodoSubtask(
        id: _string(map['id']) ?? 'subtask-${subtasks.length + 1}',
        title: title,
        completed: map['completed'] == true,
      ),
    );
  }
  return subtasks.toList(growable: false);
}
