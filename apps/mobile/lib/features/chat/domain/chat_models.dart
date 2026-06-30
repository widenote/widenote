import 'package:flutter/foundation.dart';

enum ChatRole { user, assistant }

enum ChatMessageStatus { sent, failed }

@immutable
final class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession copyWith({String? title, DateTime? updatedAt}) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.body,
    required this.createdAt,
    this.status = ChatMessageStatus.sent,
    this.sourceRefs = const <ChatSourceRef>[],
    this.runId,
    this.toolSummaries = const <ChatToolSummary>[],
  });

  final String id;
  final String sessionId;
  final ChatRole role;
  final String body;
  final DateTime createdAt;
  final ChatMessageStatus status;
  final List<ChatSourceRef> sourceRefs;
  final String? runId;
  final List<ChatToolSummary> toolSummaries;

  ChatMessage copyWith({
    String? body,
    ChatMessageStatus? status,
    List<ChatSourceRef>? sourceRefs,
    String? runId,
    List<ChatToolSummary>? toolSummaries,
  }) {
    return ChatMessage(
      id: id,
      sessionId: sessionId,
      role: role,
      body: body ?? this.body,
      createdAt: createdAt,
      status: status ?? this.status,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      runId: runId ?? this.runId,
      toolSummaries: toolSummaries ?? this.toolSummaries,
    );
  }
}

@immutable
final class ChatSource {
  const ChatSource({
    required this.id,
    required this.kind,
    required this.title,
    required this.excerpt,
    required this.sourceLabel,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String excerpt;
  final String sourceLabel;
  final DateTime createdAt;

  ChatSourceRef toRef() {
    return ChatSourceRef(
      id: id,
      kind: kind,
      title: title,
      excerpt: excerpt,
      sourceLabel: sourceLabel,
    );
  }
}

@immutable
final class ChatSourceRef {
  const ChatSourceRef({
    required this.id,
    required this.kind,
    required this.title,
    required this.excerpt,
    required this.sourceLabel,
  });

  final String id;
  final String kind;
  final String title;
  final String excerpt;
  final String sourceLabel;
}

@immutable
final class ChatToolSummary {
  const ChatToolSummary({
    required this.name,
    required this.status,
    required this.sourceRefCount,
    this.errorCode,
  });

  final String name;
  final String status;
  final int sourceRefCount;
  final String? errorCode;
}

@immutable
final class ChatAssistantPrompt {
  const ChatAssistantPrompt({
    required this.question,
    required this.sources,
    this.runId = 'chat-run-local',
    this.runMode = 'read_only',
  });

  final String question;
  final List<ChatSource> sources;
  final String runId;
  final String runMode;
}

@immutable
final class ChatAssistantReply {
  const ChatAssistantReply({
    required this.body,
    this.sourceRefs = const <ChatSourceRef>[],
    this.toolSummaries = const <ChatToolSummary>[],
  });

  final String body;
  final List<ChatSourceRef> sourceRefs;
  final List<ChatToolSummary> toolSummaries;
}

@immutable
final class ChatState {
  const ChatState({
    required this.sessions,
    required this.activeSessionId,
    required this.messages,
    required this.isSending,
    required this.errorMessage,
    required this.failedMessageId,
  });

  factory ChatState.initial() {
    return const ChatState(
      sessions: <ChatSession>[],
      activeSessionId: null,
      messages: <ChatMessage>[],
      isSending: false,
      errorMessage: null,
      failedMessageId: null,
    );
  }

  final List<ChatSession> sessions;
  final String? activeSessionId;
  final List<ChatMessage> messages;
  final bool isSending;
  final String? errorMessage;
  final String? failedMessageId;

  ChatSession? get activeSession {
    final id = activeSessionId;
    if (id == null) {
      return null;
    }
    for (final session in sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  ChatState copyWith({
    List<ChatSession>? sessions,
    String? activeSessionId,
    bool clearActiveSession = false,
    List<ChatMessage>? messages,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
    String? failedMessageId,
    bool clearFailedMessage = false,
  }) {
    return ChatState(
      sessions: sessions ?? this.sessions,
      activeSessionId: clearActiveSession
          ? null
          : activeSessionId ?? this.activeSessionId,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      failedMessageId: clearFailedMessage
          ? null
          : failedMessageId ?? this.failedMessageId,
    );
  }
}
