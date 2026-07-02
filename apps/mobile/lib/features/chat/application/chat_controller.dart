import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';
import '../../../shared/text_preview.dart';
import '../domain/chat_models.dart';
import 'chat_assistant.dart';
import 'chat_context.dart';
import 'chat_read_only_tool_loop.dart';
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

final chatReadOnlyToolRegistryProvider = Provider<runtime.ToolRegistry>((ref) {
  final registry = runtime.InMemoryToolRegistry();
  LocalDbCoreToolCatalog(
    ref.watch(localDatabaseProvider),
  ).registerInto(registry);
  return registry;
});

final chatPermissionBrokerProvider = Provider<runtime.PermissionBroker>((ref) {
  final database = ref.watch(localDatabaseProvider);
  _seedChatReadOnlyPermissionGrants(database);
  return runtime.InMemoryPermissionBroker(
    store: LocalDbPermissionStore(database),
  );
});

final chatAssistantProvider = Provider<ChatAssistant>((ref) {
  final model = ref.watch(chatModelClientProvider);
  if (model == null) {
    return const ChatModelRequiredAssistant();
  }
  return ModelBackedChatAssistant(
    model: model,
    toolRegistry: ref.watch(chatReadOnlyToolRegistryProvider),
    permissionBroker: ref.watch(chatPermissionBrokerProvider),
    labels: ref.watch(chatContextLabelsProvider),
  );
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
    await openSession(sessionId);
  }

  Future<bool> openSession(String sessionId) async {
    final current = await _currentState();
    if (_sessionById(current.sessions, sessionId) == null) {
      return false;
    }
    if (current.activeSessionId == sessionId) {
      return true;
    }
    if (current.isSending) {
      return false;
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
    return true;
  }

  Future<void> startNewSession() async {
    final current = await _currentState();
    if (current.isSending) {
      return;
    }
    if (current.activeSession != null && current.messages.isEmpty) {
      state = AsyncData(
        current.copyWith(clearError: true, clearFailedMessage: true),
      );
      return;
    }

    final session = _newSession();
    await ref.read(chatRepositoryProvider).saveSession(session);
    state = AsyncData(
      current.copyWith(
        sessions: _upsertSession(current.sessions, session),
        activeSessionId: session.id,
        messages: const <ChatMessage>[],
        clearError: true,
        clearFailedMessage: true,
      ),
    );
  }

  Future<void> renameSession(String sessionId, String value) async {
    final title = previewText(value.trim(), maxLength: 48);
    if (title.isEmpty) {
      return;
    }
    final current = await _currentState();
    if (current.isSending) {
      return;
    }
    final session = _sessionById(current.sessions, sessionId);
    if (session == null || session.title == title) {
      return;
    }

    final updated = session.copyWith(title: title);
    await ref.read(chatRepositoryProvider).saveSession(updated);
    state = AsyncData(
      current.copyWith(
        sessions: _replaceSession(current.sessions, updated),
        clearError: true,
      ),
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final current = await _currentState();
    if (current.isSending) {
      return;
    }
    final remaining = [
      for (final session in current.sessions)
        if (session.id != sessionId) session,
    ];
    if (remaining.length == current.sessions.length) {
      return;
    }

    await ref.read(chatRepositoryProvider).deleteSession(sessionId);
    if (current.activeSessionId != sessionId) {
      state = AsyncData(
        current.copyWith(
          sessions: remaining,
          clearError: true,
          clearFailedMessage: true,
        ),
      );
      return;
    }

    final nextActive = remaining.isEmpty ? null : remaining.first;
    final nextMessages = nextActive == null
        ? const <ChatMessage>[]
        : await ref.read(chatRepositoryProvider).listMessages(nextActive.id);
    state = AsyncData(
      ChatState(
        sessions: remaining,
        activeSessionId: nextActive?.id,
        messages: nextMessages,
        isSending: false,
        errorMessage: null,
        failedMessageId: null,
      ),
    );
  }

  Future<void> sendMessage(String value) async {
    final current = await _currentState();
    final activeSessionId = current.activeSessionId;
    if (activeSessionId != null) {
      await sendMessageToSession(activeSessionId, value);
      return;
    }
    await _sendMessage(value);
  }

  Future<void> sendMessageToSession(String sessionId, String value) async {
    var current = await _currentState();
    if (_sessionById(current.sessions, sessionId) == null) {
      return;
    }
    if (current.activeSessionId != sessionId) {
      if (current.isSending) {
        return;
      }
      final opened = await openSession(sessionId);
      if (!opened) {
        return;
      }
      current = await _currentState();
    }
    if (current.activeSessionId != sessionId) {
      return;
    }
    await _sendMessage(value);
  }

  Future<void> _sendMessage(String value) async {
    final text = value.trim();
    if (text.isEmpty) {
      return;
    }
    final current = await _currentState();
    if (current.isSending) {
      return;
    }

    var session = current.activeSession ?? _newSession(text);
    final userMessage = _newMessage(
      sessionId: session.id,
      role: ChatRole.user,
      body: text,
    );
    session = _sessionForUserMessage(current, session, userMessage, text);
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
    final updatedSession = session.copyWith(
      updatedAt: userMessage.createdAt,
      messageCount: current.messages.length + 1,
    );
    await repository.saveSession(updatedSession);
    await repository.saveMessage(userMessage);

    state = AsyncData(
      current.copyWith(
        sessions: _upsertSession(current.sessions, updatedSession),
        activeSessionId: updatedSession.id,
        messages: [...current.messages, userMessage],
        isSending: true,
        clearError: true,
        clearFailedMessage: true,
      ),
    );
  }

  Future<void> _answerFor(ChatMessage userMessage) async {
    final runId = ref.read(chatIdGeneratorProvider).nextId('chat-run');
    try {
      final sources = await _selectedSources(userMessage.body);
      final reply = await ref
          .read(chatAssistantProvider)
          .answer(
            ChatAssistantPrompt(
              question: userMessage.body,
              sources: sources,
              runId: runId,
            ),
          );
      await _persistAssistantReply(userMessage, reply, sources, runId);
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
    String runId,
  ) async {
    final assistantMessage = _newMessage(
      sessionId: userMessage.sessionId,
      role: ChatRole.assistant,
      body: reply.body,
      sourceRefs: reply.sourceRefs.isEmpty
          ? sources.map((source) => source.toRef()).toList()
          : reply.sourceRefs,
      runId: runId,
      toolSummaries: reply.toolSummaries,
    );
    final repository = ref.read(chatRepositoryProvider);
    await repository.saveMessage(assistantMessage);

    final current = await _currentState();
    final updatedSession = current.activeSession?.copyWith(
      updatedAt: assistantMessage.createdAt,
      messageCount: current.messages.length + 1,
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
    await _recordFailureTrace(failed, error);
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

  Future<void> _recordFailureTrace(
    ChatMessage userMessage,
    Object error,
  ) async {
    final diagnosticType = error is ChatAssistantException
        ? error.diagnosticType
        : null;
    final diagnosticMessage = error is ChatAssistantException
        ? error.diagnosticMessage
        : null;
    final details = <String, Object?>{
      'trace_type': 'model',
      'surface': 'chat',
      'call_state': 'failed',
      'error_type': diagnosticType ?? error.runtimeType.toString(),
    };
    if (diagnosticMessage != null) {
      details['error_message'] = diagnosticMessage;
    }
    try {
      await ref
          .read(localTraceSinkProvider)
          .record(
            runtime.RuntimeTrace(
              id: ref.read(chatIdGeneratorProvider).nextId('chat-trace'),
              name: 'chat.model.failed',
              message: 'Chat model request failed.',
              level: runtime.TraceLevel.error,
              createdAt: ref.read(chatClockProvider)(),
              packId: 'chat',
              agentId: 'chat.local',
              details: details,
            ),
          );
    } catch (_) {
      // Logging must not mask the original chat failure state.
    }
  }

  ChatSession _newSession([String? firstMessage]) {
    final now = ref.read(chatClockProvider)();
    final id = ref.read(chatIdGeneratorProvider).nextId('chat-session');
    return ChatSession(
      id: id,
      title: firstMessage == null
          ? chatDefaultSessionTitle
          : previewText(firstMessage, maxLength: 28),
      createdAt: now,
      updatedAt: now,
    );
  }

  ChatSession _sessionForUserMessage(
    ChatState current,
    ChatSession session,
    ChatMessage userMessage,
    String text,
  ) {
    if (current.activeSession == null) {
      return session;
    }
    if (current.messages.isEmpty && _isDefaultSessionTitle(session.title)) {
      return session.copyWith(
        title: previewText(text, maxLength: 28),
        updatedAt: userMessage.createdAt,
      );
    }
    return session;
  }

  ChatMessage _newMessage({
    required String sessionId,
    required ChatRole role,
    required String body,
    List<ChatSourceRef> sourceRefs = const <ChatSourceRef>[],
    String? runId,
    List<ChatToolSummary> toolSummaries = const <ChatToolSummary>[],
  }) {
    return ChatMessage(
      id: ref.read(chatIdGeneratorProvider).nextId('chat-message'),
      sessionId: sessionId,
      role: role,
      body: body,
      sourceRefs: sourceRefs,
      runId: runId,
      toolSummaries: toolSummaries,
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

List<ChatSession> _replaceSession(
  List<ChatSession> sessions,
  ChatSession replacement,
) {
  return [
    for (final session in sessions)
      if (session.id == replacement.id) replacement else session,
  ];
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

ChatSession? _sessionById(List<ChatSession> sessions, String sessionId) {
  for (final session in sessions) {
    if (session.id == sessionId) {
      return session;
    }
  }
  return null;
}

bool _isDefaultSessionTitle(String title) {
  return title == chatDefaultSessionTitle;
}

const _chatReadOnlyPermissionIds = <String>{
  LocalDbCoreToolCatalog.semanticSearchQueryTool,
  LocalDbCoreToolCatalog.contextPacketBuildTool,
  LocalDbCoreToolCatalog.memoryReadTool,
  LocalDbCoreToolCatalog.timelineReadTool,
  LocalDbCoreToolCatalog.knowledgeReadTool,
  LocalDbCoreToolCatalog.traceReadTool,
};

void _seedChatReadOnlyPermissionGrants(WideNoteLocalDatabase database) {
  final now = DateTime.now().toUtc();
  if (database.packInstallations.readById(chatReadOnlyPackId) == null) {
    database.packInstallations.insert(
      PackInstallationRecord(
        packId: chatReadOnlyPackId,
        name: 'Chat',
        version: '0.1.0',
        publisher: 'widenote',
        edition: 'app_owned',
        status: 'enabled',
        runtimeStatus: 'idle',
        entrypointKind: 'native',
        requestedPermissions: <Object?>[..._chatReadOnlyPermissionIds],
        manifest: const <String, Object?>{
          'id': chatReadOnlyPackId,
          'name': 'Chat',
          'version': '0.1.0',
        },
        payload: const <String, Object?>{'source': 'mobile_chat_read_only'},
        installedAt: now,
        updatedAt: now,
      ),
    );
  }
  for (final permission in _chatReadOnlyPermissionIds) {
    if (database.permissionGrants.readByPackAndPermission(
          chatReadOnlyPackId,
          permission,
        ) !=
        null) {
      continue;
    }
    database.permissionGrants.insert(
      PermissionGrantRecord(
        id: 'permission:$chatReadOnlyPackId:$permission',
        packId: chatReadOnlyPackId,
        permissionId: permission,
        status: runtime.PermissionDecisionState.granted.name,
        grantKind: 'built_in_default',
        grantedAt: now,
        reason: 'built_in_default',
        payload: const <String, Object?>{'source': 'mobile_chat_read_only'},
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
