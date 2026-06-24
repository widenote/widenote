import 'package:widenote_local_db/widenote_local_db.dart';

import '../domain/chat_models.dart';
import 'chat_repository.dart';

final class LocalChatRepository implements ChatRepository {
  LocalChatRepository(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<List<ChatSession>> listSessions() async {
    return _database.chatSessions.readAll().map(_sessionFromRecord).toList();
  }

  @override
  Future<List<ChatMessage>> listMessages(String sessionId) async {
    return _database.chatMessages
        .readBySession(sessionId)
        .map(_messageFromRecord)
        .toList();
  }

  @override
  Future<void> saveSession(ChatSession session) async {
    _database.chatSessions.save(
      ChatSessionRecord(
        id: session.id,
        title: session.title,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
      ),
    );
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    _database.chatMessages.save(
      ChatMessageRecord(
        id: message.id,
        sessionId: message.sessionId,
        role: message.role.name,
        body: message.body,
        status: message.status.name,
        sourceRefs: _sourceRefsToJson(message.sourceRefs),
        createdAt: message.createdAt,
      ),
    );
  }
}

ChatSession _sessionFromRecord(ChatSessionRecord record) {
  return ChatSession(
    id: record.id,
    title: record.title,
    createdAt: record.createdAt,
    updatedAt: record.updatedAt,
  );
}

ChatMessage _messageFromRecord(ChatMessageRecord record) {
  return ChatMessage(
    id: record.id,
    sessionId: record.sessionId,
    role: _role(record.role),
    body: record.body,
    status: _status(record.status),
    sourceRefs: _sourceRefsFromJson(record.sourceRefs),
    createdAt: record.createdAt,
  );
}

List<Object?> _sourceRefsToJson(List<ChatSourceRef> refs) {
  return <Object?>[
    for (final ref in refs)
      <String, Object?>{
        'id': ref.id,
        'kind': ref.kind,
        'title': ref.title,
        'excerpt': ref.excerpt,
        'source_label': ref.sourceLabel,
      },
  ];
}

List<ChatSourceRef> _sourceRefsFromJson(List<Object?> value) {
  return value
      .whereType<Map<String, Object?>>()
      .map(
        (item) => ChatSourceRef(
          id: _string(item['id']),
          kind: _string(item['kind']),
          title: _string(item['title']),
          excerpt: _string(item['excerpt']),
          sourceLabel: _string(item['source_label']),
        ),
      )
      .toList(growable: false);
}

ChatRole _role(String value) {
  return ChatRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => ChatRole.assistant,
  );
}

ChatMessageStatus _status(String value) {
  return ChatMessageStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => ChatMessageStatus.sent,
  );
}

String _string(Object? value) => value is String ? value : '';
