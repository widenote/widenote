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
        payload: _payloadToJson(message),
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
    runId: _stringOrNull(record.payload['run_id']),
    toolSummaries: _toolSummariesFromJson(record.payload['tool_summary']),
    createdAt: record.createdAt,
  );
}

Map<String, Object?> _payloadToJson(ChatMessage message) {
  return <String, Object?>{
    if (message.runId != null) 'run_id': message.runId,
    if (message.toolSummaries.isNotEmpty)
      'tool_summary': <Object?>[
        for (final summary in message.toolSummaries)
          <String, Object?>{
            'name': summary.name,
            'status': summary.status,
            'source_ref_count': summary.sourceRefCount,
            if (summary.errorCode != null) 'error_code': summary.errorCode,
          },
      ],
  };
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

List<ChatToolSummary> _toolSummariesFromJson(Object? value) {
  if (value is! List) {
    return const <ChatToolSummary>[];
  }
  return value
      .whereType<Map<String, Object?>>()
      .map(
        (item) => ChatToolSummary(
          name: _string(item['name']),
          status: _string(item['status']),
          sourceRefCount: _int(item['source_ref_count']),
          errorCode: _stringOrNull(item['error_code']),
        ),
      )
      .where((summary) => summary.name.isNotEmpty)
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

String? _stringOrNull(Object? value) {
  final string = _string(value);
  return string.isEmpty ? null : string;
}

int _int(Object? value) => value is int ? value : 0;
