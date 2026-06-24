import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../shared/text_preview.dart';
import '../domain/chat_models.dart';
import 'chat_context.dart';

final class LocalChatContextSource implements ChatContextSource {
  const LocalChatContextSource(
    this._database, {
    this.labels = const ChatContextLabels.english(),
  });

  final WideNoteLocalDatabase _database;
  final ChatContextLabels labels;

  @override
  Future<List<ChatSource>> loadSources() async {
    final sources = <ChatSource>[
      ..._memorySources(),
      ..._captureSources(),
      ..._todoEventSources(),
      ..._todoRecordSources(),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sources;
  }

  List<ChatSource> _memorySources() {
    return _database.memoryItems
        .readAll(status: 'active', limit: 40)
        .where((item) => !item.tombstone && item.body.trim().isNotEmpty)
        .map(
          (item) => ChatSource(
            id: item.id,
            kind: 'memory',
            title: labels.memoryTitle,
            excerpt: item.body,
            sourceLabel: _sourceLabel(
              kind: 'memory',
              id: item.id,
              sourceEventId: item.sourceEventId,
              sourceCaptureId: item.sourceCaptureId,
            ),
            createdAt: item.updatedAt,
          ),
        )
        .toList(growable: false);
  }

  List<ChatSource> _captureSources() {
    return _database.eventLog
        .readByType(runtime.WnEventTypes.captureCreated, limit: 40)
        .map((event) {
          final text = _string(event.payload['text']) ?? '';
          return ChatSource(
            id: event.id,
            kind: 'capture',
            title: labels.recordTitle,
            excerpt: text.isEmpty ? labels.untitledCapture : text,
            sourceLabel: 'event: ${event.id}',
            createdAt: event.createdAt,
          );
        })
        .toList(growable: false);
  }

  List<ChatSource> _todoEventSources() {
    return _database.eventLog
        .readByType(runtime.WnEventTypes.todoSuggested, limit: 40)
        .map((event) {
          final text = _string(event.payload['text']) ?? '';
          return ChatSource(
            id: event.id,
            kind: 'todo',
            title: labels.todoTitle,
            excerpt: text.isEmpty ? labels.untitledTodo : text,
            sourceLabel: 'event: ${event.id}',
            createdAt: event.createdAt,
          );
        })
        .toList(growable: false);
  }

  List<ChatSource> _todoRecordSources() {
    return _database.todos
        .readAll(limit: 40)
        .map((todo) {
          final title =
              _string(todo.payload['title']) ??
              _string(todo.payload['text']) ??
              previewText(todo.id);
          return ChatSource(
            id: todo.id,
            kind: 'todo',
            title: labels.todoTitle,
            excerpt: title,
            sourceLabel: _sourceLabel(
              kind: 'todo',
              id: todo.id,
              sourceEventId: todo.sourceEventId,
              sourceCaptureId: todo.sourceCaptureId,
            ),
            createdAt: todo.updatedAt,
          );
        })
        .toList(growable: false);
  }
}

final class ChatContextLabels {
  const ChatContextLabels({
    required this.memoryTitle,
    required this.recordTitle,
    required this.todoTitle,
    required this.untitledCapture,
    required this.untitledTodo,
  });

  const ChatContextLabels.english()
    : memoryTitle = 'Memory',
      recordTitle = 'Record',
      todoTitle = 'Todo',
      untitledCapture = 'Untitled local capture',
      untitledTodo = 'Untitled todo suggestion';

  final String memoryTitle;
  final String recordTitle;
  final String todoTitle;
  final String untitledCapture;
  final String untitledTodo;
}

String _sourceLabel({
  required String kind,
  required String id,
  String? sourceEventId,
  String? sourceCaptureId,
}) {
  if (sourceEventId != null) {
    return 'event: $sourceEventId';
  }
  if (sourceCaptureId != null) {
    return 'capture: $sourceCaptureId';
  }
  return '$kind: $id';
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}
