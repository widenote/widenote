import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_database.dart';
import '../../../shared/text_preview.dart';
import '../domain/chat_models.dart';
import 'chat_assistant.dart';
import 'chat_context.dart';
import 'chat_repository.dart';
import 'local_chat_context_source.dart';
import 'local_chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return LocalChatRepository(ref.watch(localDatabaseProvider));
});

final chatContextSourceProvider = Provider<ChatContextSource>((ref) {
  return LocalChatContextSource(
    ref.watch(localDatabaseProvider),
    labels: ref.watch(chatContextLabelsProvider),
  );
});

final chatContextLabelsProvider = Provider<ChatContextLabels>((ref) {
  return const ChatContextLabels.english();
});

final chatContextSelectorProvider = Provider<ChatContextSelector>((ref) {
  return const ChatContextSelector();
});

final chatAssistantProvider = Provider<ChatAssistant>((ref) {
  return DeterministicLocalChatAssistant(
    copy: ref.watch(chatAssistantCopyProvider),
  );
});

final chatAssistantCopyProvider = Provider<ChatAssistantCopy>((ref) {
  return const ChatAssistantCopy.english();
});

final chatClockProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now().toUtc();
});

final chatIdGeneratorProvider = Provider<ChatIdGenerator>((ref) {
  return ChatIdGenerator(clock: ref.watch(chatClockProvider));
});

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

final class ChatIdGenerator {
  ChatIdGenerator({required DateTime Function() clock}) : _clock = clock;

  final DateTime Function() _clock;
  int _counter = 0;

  String nextId(String prefix) {
    final timestamp = _clock().toUtc().microsecondsSinceEpoch;
    return '$prefix-$timestamp-${_counter++}';
  }
}

final class ChatController extends AsyncNotifier<ChatState> {
  @override
  Future<ChatState> build() async {
    final repository = ref.watch(chatRepositoryProvider);
    final sessions = await repository.listSessions();
    if (sessions.isEmpty) {
      return ChatState.initial();
    }
    final active = sessions.first;
    final messages = await repository.listMessages(active.id);
    return ChatState(
      sessions: sessions,
      activeSessionId: active.id,
      messages: messages,
      isSending: false,
      errorMessage: null,
      failedMessageId: null,
    );
  }

  Future<void> selectSession(String sessionId) async {
    final current = await _currentState();
    if (current.activeSessionId == sessionId || current.isSending) {
      return;
    }
    final messages = await ref
        .read(chatRepositoryProvider)
        .listMessages(sessionId);
    state = AsyncData(
      current.copyWith(
        activeSessionId: sessionId,
        messages: messages,
        clearError: true,
        clearFailedMessage: true,
      ),
    );
  }

  Future<void> sendMessage(String value) async {
    final text = value.trim();
    if (text.isEmpty) {
      return;
    }
    final current = await _currentState();
    if (current.isSending) {
      return;
    }

    final session = current.activeSession ?? _newSession(text);
    final userMessage = _newMessage(
      sessionId: session.id,
      role: ChatRole.user,
      body: text,
    );
    await _persistTurnStart(current, session, userMessage);
    await _answerFor(userMessage);
  }

  Future<void> retryFailedMessage() async {
    final current = await _currentState();
    final failed = _failedUserMessage(current);
    if (failed == null || current.isSending) {
      return;
    }

    final retry = failed.copyWith(status: ChatMessageStatus.sent);
    await ref.read(chatRepositoryProvider).saveMessage(retry);
    state = AsyncData(
      current.copyWith(
        messages: _replaceMessage(current.messages, retry),
        isSending: true,
        clearError: true,
        clearFailedMessage: true,
      ),
    );
    await _answerFor(retry);
  }

  Future<void> _persistTurnStart(
    ChatState current,
    ChatSession session,
    ChatMessage userMessage,
  ) async {
    final repository = ref.read(chatRepositoryProvider);
    await repository.saveSession(session);
    await repository.saveMessage(userMessage);

    state = AsyncData(
      current.copyWith(
        sessions: _upsertSession(current.sessions, session),
        activeSessionId: session.id,
        messages: [...current.messages, userMessage],
        isSending: true,
        clearError: true,
        clearFailedMessage: true,
      ),
    );
  }

  Future<void> _answerFor(ChatMessage userMessage) async {
    try {
      final sources = await _selectedSources(userMessage.body);
      final reply = await ref
          .read(chatAssistantProvider)
          .answer(
            ChatAssistantPrompt(question: userMessage.body, sources: sources),
          );
      await _persistAssistantReply(userMessage, reply, sources);
    } catch (error) {
      await _markFailed(userMessage, error);
    }
  }

  Future<List<ChatSource>> _selectedSources(String question) async {
    final allSources = await ref.read(chatContextSourceProvider).loadSources();
    return ref
        .read(chatContextSelectorProvider)
        .select(question: question, sources: allSources);
  }

  Future<void> _persistAssistantReply(
    ChatMessage userMessage,
    ChatAssistantReply reply,
    List<ChatSource> sources,
  ) async {
    final assistantMessage = _newMessage(
      sessionId: userMessage.sessionId,
      role: ChatRole.assistant,
      body: reply.body,
      sourceRefs: sources.map((source) => source.toRef()).toList(),
    );
    final repository = ref.read(chatRepositoryProvider);
    await repository.saveMessage(assistantMessage);

    final current = await _currentState();
    final updatedSession = current.activeSession?.copyWith(
      updatedAt: assistantMessage.createdAt,
    );
    if (updatedSession != null) {
      await repository.saveSession(updatedSession);
    }

    state = AsyncData(
      current.copyWith(
        sessions: updatedSession == null
            ? current.sessions
            : _upsertSession(current.sessions, updatedSession),
        messages: [...current.messages, assistantMessage],
        isSending: false,
        clearError: true,
        clearFailedMessage: true,
      ),
    );
  }

  Future<void> _markFailed(ChatMessage userMessage, Object error) async {
    final failed = userMessage.copyWith(status: ChatMessageStatus.failed);
    await ref.read(chatRepositoryProvider).saveMessage(failed);
    final current = await _currentState();
    state = AsyncData(
      current.copyWith(
        messages: _replaceMessage(current.messages, failed),
        isSending: false,
        errorMessage: '$error',
        failedMessageId: failed.id,
      ),
    );
  }

  ChatSession _newSession(String firstMessage) {
    final now = ref.read(chatClockProvider)();
    final id = ref.read(chatIdGeneratorProvider).nextId('chat-session');
    return ChatSession(
      id: id,
      title: previewText(firstMessage, maxLength: 28),
      createdAt: now,
      updatedAt: now,
    );
  }

  ChatMessage _newMessage({
    required String sessionId,
    required ChatRole role,
    required String body,
    List<ChatSourceRef> sourceRefs = const <ChatSourceRef>[],
  }) {
    return ChatMessage(
      id: ref.read(chatIdGeneratorProvider).nextId('chat-message'),
      sessionId: sessionId,
      role: role,
      body: body,
      sourceRefs: sourceRefs,
      createdAt: ref.read(chatClockProvider)(),
    );
  }

  Future<ChatState> _currentState() async {
    final current = state.valueOrNull;
    if (current != null) {
      return current;
    }
    return future;
  }
}

ChatMessage? _failedUserMessage(ChatState state) {
  final failedId = state.failedMessageId;
  if (failedId == null) {
    return null;
  }
  for (final message in state.messages.reversed) {
    if (message.id == failedId && message.role == ChatRole.user) {
      return message;
    }
  }
  return null;
}

List<ChatSession> _upsertSession(
  List<ChatSession> sessions,
  ChatSession session,
) {
  final next = <ChatSession>[
    session,
    for (final existing in sessions)
      if (existing.id != session.id) existing,
  ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return next;
}

List<ChatMessage> _replaceMessage(
  List<ChatMessage> messages,
  ChatMessage replacement,
) {
  return [
    for (final message in messages)
      if (message.id == replacement.id) replacement else message,
  ];
}
