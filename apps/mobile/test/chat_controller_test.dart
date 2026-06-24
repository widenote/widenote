import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/features/chat/application/chat_assistant.dart';
import 'package:widenote_mobile/features/chat/application/chat_context.dart';
import 'package:widenote_mobile/features/chat/application/chat_controller.dart';
import 'package:widenote_mobile/features/chat/application/chat_repository.dart';
import 'package:widenote_mobile/features/chat/application/local_chat_repository.dart';
import 'package:widenote_mobile/features/chat/domain/chat_models.dart';

void main() {
  test('local repository persists sessions and messages', () async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);

    final now = DateTime.utc(2026, 6, 24, 1);
    final repository = LocalChatRepository(database);
    await repository.saveSession(
      ChatSession(
        id: 'session-1',
        title: 'Launch review',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveMessage(
      ChatMessage(
        id: 'message-1',
        sessionId: 'session-1',
        role: ChatRole.user,
        body: 'What did Lin ask?',
        createdAt: now,
      ),
    );
    await repository.saveMessage(
      ChatMessage(
        id: 'message-2',
        sessionId: 'session-1',
        role: ChatRole.assistant,
        body: 'Lin asked about source links.',
        sourceRefs: const <ChatSourceRef>[
          ChatSourceRef(
            id: 'memory-1',
            kind: 'memory',
            title: 'Memory',
            excerpt: 'Lin cares about source links.',
            sourceLabel: 'event: capture-1',
          ),
        ],
        createdAt: now.add(const Duration(seconds: 1)),
      ),
    );

    final reloaded = LocalChatRepository(database);
    final sessions = await reloaded.listSessions();
    final messages = await reloaded.listMessages('session-1');

    expect(sessions.single.title, 'Launch review');
    expect(messages.map((message) => message.body), <String>[
      'What did Lin ask?',
      'Lin asked about source links.',
    ]);
    expect(messages.last.sourceRefs.single.sourceLabel, 'event: capture-1');
  });

  test('context selector prioritizes matching Memory, capture, and todo', () {
    final selector = ChatContextSelector();
    final now = DateTime.utc(2026, 6, 24, 2);
    final sources = <ChatSource>[
      ChatSource(
        id: 'capture-1',
        kind: 'capture',
        title: 'Record',
        excerpt: 'Met Lin about WideNote source-linked todos.',
        sourceLabel: 'event: capture-1',
        createdAt: now,
      ),
      ChatSource(
        id: 'memory-1',
        kind: 'memory',
        title: 'Memory',
        excerpt: 'Lin prefers source-linked WideNote todos.',
        sourceLabel: 'event: capture-1',
        createdAt: now.add(const Duration(minutes: 1)),
      ),
      ChatSource(
        id: 'todo-1',
        kind: 'todo',
        title: 'Todo',
        excerpt: 'Follow up: Lin todos.',
        sourceLabel: 'event: todo-1',
        createdAt: now.add(const Duration(minutes: 2)),
      ),
    ];

    final selected = selector.select(
      question: 'Lin source linked todos?',
      sources: sources,
    );

    expect(selected.map((source) => source.kind), <String>[
      'memory',
      'capture',
      'todo',
    ]);
  });

  test('assistant gives a useful empty-context answer', () async {
    final reply = await const DeterministicLocalChatAssistant().answer(
      const ChatAssistantPrompt(question: '你知道什么？', sources: <ChatSource>[]),
    );

    expect(reply.body, contains("I don't have local records"));
    expect(reply.body, contains('Memory'));
  });

  test(
    'model-backed assistant uses local sources and falls back safely',
    () async {
      final source = ChatSource(
        id: 'memory-1',
        kind: 'memory',
        title: 'Memory',
        excerpt: 'Lin wants source-linked chat answers.',
        sourceLabel: 'event: capture-1',
        createdAt: DateTime.utc(2026, 6, 24, 2),
      );
      final model = _RecordingModelClient(
        response: 'The answer cites memory/memory-1.',
      );
      final assistant = ModelBackedChatAssistant(
        model: model,
        fallback: const DeterministicLocalChatAssistant(),
      );

      final reply = await assistant.answer(
        ChatAssistantPrompt(question: 'What does Lin want?', sources: [source]),
      );

      expect(reply.body, 'The answer cites memory/memory-1.');
      expect(model.lastPrompt, contains('memory/memory-1'));

      final fallback = ModelBackedChatAssistant(
        model: _ThrowingModelClient(),
        fallback: const DeterministicLocalChatAssistant(),
      );
      final fallbackReply = await fallback.answer(
        ChatAssistantPrompt(question: 'What does Lin want?', sources: [source]),
      );
      expect(
        fallbackReply.body,
        contains('The closest match is a Memory item'),
      );

      final emptyModelReply =
          await ModelBackedChatAssistant(
            model: _RecordingModelClient(response: '   '),
            fallback: const DeterministicLocalChatAssistant(),
          ).answer(
            ChatAssistantPrompt(
              question: 'What does Lin want?',
              sources: [source],
            ),
          );
      expect(
        emptyModelReply.body,
        contains('The closest match is a Memory item'),
      );
    },
  );

  test('controller marks user message failed when assistant throws', () async {
    final repository = InMemoryChatRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        chatRepositoryProvider.overrideWithValue(repository),
        chatContextSourceProvider.overrideWithValue(
          const _StaticContextSource(<ChatSource>[]),
        ),
        chatAssistantProvider.overrideWithValue(const _FailingAssistant()),
        chatClockProvider.overrideWithValue(
          _FixedClock(DateTime.utc(2026, 6, 24, 3)).call,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.future);
    await container
        .read(chatControllerProvider.notifier)
        .sendMessage('Can you answer from local context?');

    final state = container.read(chatControllerProvider).requireValue;
    expect(state.errorMessage, contains('assistant unavailable'));
    expect(state.failedMessageId, isNotNull);
    expect(state.messages.single.status, ChatMessageStatus.failed);
    expect(
      (await repository.listMessages(state.activeSessionId!)).single.status,
      ChatMessageStatus.failed,
    );
  });
}

final class _StaticContextSource implements ChatContextSource {
  const _StaticContextSource(this.sources);

  final List<ChatSource> sources;

  @override
  Future<List<ChatSource>> loadSources() async => sources;
}

final class _FailingAssistant implements ChatAssistant {
  const _FailingAssistant();

  @override
  Future<ChatAssistantReply> answer(ChatAssistantPrompt prompt) {
    throw StateError('assistant unavailable');
  }
}

final class _FixedClock {
  const _FixedClock(this.now);

  final DateTime now;

  DateTime call() => now;
}

final class _RecordingModelClient implements runtime.ModelClient {
  _RecordingModelClient({required this.response});

  final String response;
  String lastPrompt = '';

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    lastPrompt = request.prompt;
    return runtime.ModelResponse(text: response);
  }
}

final class _ThrowingModelClient implements runtime.ModelClient {
  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) {
    throw StateError('model unavailable');
  }
}
