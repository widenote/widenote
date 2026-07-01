import '../domain/chat_models.dart';

abstract interface class ChatRepository {
  Future<List<ChatSession>> listSessions();

  Future<List<ChatMessage>> listMessages(String sessionId);

  Future<void> saveSession(ChatSession session);

  Future<void> saveMessage(ChatMessage message);

  Future<void> deleteSession(String sessionId);
}

final class InMemoryChatRepository implements ChatRepository {
  final Map<String, ChatSession> _sessions = <String, ChatSession>{};
  final Map<String, ChatMessage> _messages = <String, ChatMessage>{};

  @override
  Future<List<ChatSession>> listSessions() async {
    final sessions = _sessions.values.map((session) {
      return session.copyWith(messageCount: _messageCount(session.id));
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  @override
  Future<List<ChatMessage>> listMessages(String sessionId) async {
    final messages =
        _messages.values
            .where((message) => message.sessionId == sessionId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  @override
  Future<void> saveSession(ChatSession session) async {
    _sessions[session.id] = session;
  }

  @override
  Future<void> saveMessage(ChatMessage message) async {
    _messages[message.id] = message;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _sessions.remove(sessionId);
    _messages.removeWhere((_, message) => message.sessionId == sessionId);
  }

  int _messageCount(String sessionId) {
    return _messages.values
        .where((message) => message.sessionId == sessionId)
        .length;
  }
}
