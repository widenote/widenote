import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_mobile/features/capture/application/capture_agent_prompts.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/chat/application/chat_assistant.dart';
import 'package:widenote_mobile/features/chat/application/chat_controller.dart';
import 'package:widenote_mobile/features/chat/application/local_chat_repository.dart';
import 'package:widenote_mobile/features/chat/domain/chat_models.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';

void main() {
  testWidgets('chat page shows empty state before a local session exists', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTab(tester, const Key('tab-chat'));

    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.byKey(const Key('chat-empty-sessions')), findsOneWidget);
    expect(find.byKey(const Key('chat-empty-state')), findsOneWidget);
    expect(find.text('No local sessions yet.'), findsOneWidget);
    expect(
      find.text('Ask a question about records, Memory, or todos.'),
      findsOneWidget,
    );
  });

  testWidgets('chat page shows localized Chinese empty state', (tester) async {
    await _pumpApp(tester, locale: const Locale('zh'));
    await _openTab(tester, const Key('tab-chat'));

    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.text('历史会话'), findsOneWidget);
    expect(find.text('还没有本地会话。'), findsOneWidget);
    expect(find.text('先问一个关于记录、记忆或待办的问题。'), findsOneWidget);
  });

  testWidgets('sending without a configured model shows retryable failure', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTab(tester, const Key('tab-chat'));

    await _sendChat(tester, 'What records do you have?');

    expect(find.text('What records do you have?'), findsWidgets);
    expect(
      find.textContaining('Model access is not configured'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('chat-open-log-center-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat-retry-button')), findsOneWidget);
    expect(find.byKey(const Key('chat-empty-sessions')), findsNothing);

    await tester.tap(find.byKey(const Key('chat-open-log-center-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-console-page')), findsOneWidget);
    expect(find.text('Agent Console'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Chat model request failed.'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Chat model request failed.'), findsOneWidget);
  });

  testWidgets('sending without a configured model localizes Chinese failure', (
    tester,
  ) async {
    await _pumpApp(tester, locale: const Locale('zh'));
    await _openTab(tester, const Key('tab-chat'));

    await _sendChat(tester, '本地记录里有什么？');

    expect(find.textContaining('尚未配置模型访问'), findsOneWidget);
    expect(find.textContaining('Model access is not configured'), findsNothing);
    expect(find.byKey(const Key('chat-retry-button')), findsOneWidget);
  });

  testWidgets('chat composer uses a regular multiline keyboard', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openTab(tester, const Key('tab-chat'));

    final field = tester.widget<TextField>(
      find.byKey(const Key('chat-input-field')),
    );

    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textCapitalization, TextCapitalization.sentences);
    expect(field.autocorrect, isTrue);
    expect(field.enableSuggestions, isTrue);
    expect(field.smartDashesType, SmartDashesType.disabled);
    expect(field.smartQuotesType, SmartQuotesType.disabled);
  });

  testWidgets('assistant answer shows source-linked local context', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      modelClient: const _CaptureTestModel(),
      overrides: <Override>[
        chatAssistantProvider.overrideWithValue(
          _ScriptedAssistant(responses: const <String>['Fake model answer.']),
        ),
      ],
    );

    const captureText = 'Met Lin about WideNote source-linked todos.';
    await _submitQuickCapture(tester, captureText);
    await _openTab(tester, const Key('tab-chat'));
    await _sendChat(tester, 'Lin 的待办是什么？');

    expect(find.text('Sources'), findsOneWidget);
    final state = _readChatState(tester);
    final refs = state.messages
        .where((message) => message.role == ChatRole.assistant)
        .last
        .sourceRefs;
    expect(
      refs.map((ref) => ref.kind),
      containsAll(<String>['memory', 'capture', 'todo']),
    );
    expect(
      refs.map((ref) => ref.sourceLabel),
      containsAll(<Matcher>[startsWith('event:'), startsWith('capture:')]),
    );

    final captureRef = refs.firstWhere((ref) => ref.kind == 'capture');
    final sourceTag = find.byKey(Key('chat-source-capture-${captureRef.id}'));
    await tester.drag(
      find.byKey(const Key('chat-message-scroll')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(sourceTag);
    tester.widget<GestureDetector>(sourceTag).onTap!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.byKey(const Key('timeline-item-detail-page')), findsNothing);
  });

  testWidgets('chat page shows cited tool-loop answer and tool summary', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    final now = DateTime.utc(2026, 6, 29, 11);
    _seedToolLoopContext(database, now);
    await _pumpApp(
      tester,
      database: database,
      modelClient: _ScriptedChatModel(
        responses: <String>[
          jsonEncode(<String, Object?>{
            'tool_calls': <Object?>[
              <String, Object?>{
                'name': LocalDbCoreToolCatalog.semanticSearchQueryTool,
                'input': <String, Object?>{
                  'query': 'What did Lin say about launch?',
                  'limit': 6,
                },
              },
            ],
          }),
          jsonEncode(<String, Object?>{
            'answer': 'Lin asked for launch citations (memory/memory-ui).',
          }),
        ],
      ),
    );
    await _openTab(tester, const Key('tab-chat'));

    await _sendChat(tester, 'What did Lin say about launch?');

    expect(
      find.text('Lin asked for launch citations (memory/memory-ui).'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat-tool-summary-0')), findsOneWidget);
    expect(find.textContaining('semantic_search.query'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);

    final state = _readChatState(tester);
    final assistant = state.messages.last;
    expect(assistant.runId, startsWith('chat-run-'));
    expect(assistant.toolSummaries.single.name, 'semantic_search.query');
    expect(
      assistant.sourceRefs.map((ref) => ref.kind),
      containsAll(<String>['memory', 'capture']),
    );
  });

  testWidgets('composer stays visible after a long answer', (tester) async {
    await _pumpApp(
      tester,
      overrides: <Override>[
        chatAssistantProvider.overrideWithValue(
          _ScriptedAssistant(
            responses: <String>[
              List.filled(
                40,
                'Long local answer keeps talking about Memory sources.',
              ).join(' '),
              'Second answer',
            ],
          ),
        ),
      ],
    );
    await _openTab(tester, const Key('tab-chat'));

    await _sendChat(tester, 'What memories mention Alice?');

    expect(find.byKey(const Key('chat-input-field')), findsOneWidget);
    expect(find.byKey(const Key('chat-send-button')), findsOneWidget);

    await _sendChat(tester, 'Can I ask a second question?');

    expect(find.text('Second answer'), findsOneWidget);
  });

  testWidgets('chat session survives tab navigation round trip', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      overrides: <Override>[
        chatAssistantProvider.overrideWithValue(
          _ScriptedAssistant(responses: const <String>['Persistent answer.']),
        ),
      ],
    );
    await _openTab(tester, const Key('tab-chat'));

    await _sendChat(tester, 'Keep this chat open.');
    final before = _readChatState(tester);

    await _openTab(tester, const Key('tab-home'));
    await _openTab(tester, const Key('tab-chat'));
    final after = _readChatState(tester);

    expect(after.activeSessionId, before.activeSessionId);
    expect(find.text('Keep this chat open.'), findsWidgets);
    expect(after.messages.length, before.messages.length);
  });

  testWidgets('chat page loads a historical local session', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    final repository = LocalChatRepository(database);
    final now = DateTime.utc(2026, 6, 24, 4);
    await repository.saveSession(
      ChatSession(
        id: 'history-1',
        title: '历史复盘',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveMessage(
      ChatMessage(
        id: 'history-message-1',
        sessionId: 'history-1',
        role: ChatRole.user,
        body: '昨天记录了什么？',
        createdAt: now,
      ),
    );

    await _pumpApp(tester, database: database);
    await _openTab(tester, const Key('tab-chat'));

    expect(find.text('历史复盘'), findsWidgets);
    expect(find.text('昨天记录了什么？'), findsOneWidget);
  });

  testWidgets('failed assistant response can be retried', (tester) async {
    final assistant = _FlakyAssistant();
    await _pumpApp(
      tester,
      overrides: <Override>[chatAssistantProvider.overrideWithValue(assistant)],
    );
    await _openTab(tester, const Key('tab-chat'));

    await _sendChat(tester, '请总结本地上下文');

    expect(find.textContaining('first response failed'), findsOneWidget);
    expect(find.byKey(const Key('chat-retry-button')), findsOneWidget);
    expect(find.text('Send failed', skipOffstage: false), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-retry-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('first response failed'), findsNothing);
    expect(find.text('Retry answer'), findsOneWidget);
    expect(assistant.calls, 2);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  WideNoteLocalDatabase? database,
  List<Override> overrides = const <Override>[],
  Locale locale = const Locale('en'),
  runtime.ModelClient? modelClient,
}) async {
  final localDatabase = database ?? WideNoteLocalDatabase.inMemory();
  addTearDown(localDatabase.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        localDatabaseProvider.overrideWithValue(localDatabase),
        if (modelClient != null) ...[
          modelClientProvider.overrideWithValue(modelClient),
          chatModelClientProvider.overrideWithValue(modelClient),
        ],
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
        ...overrides,
      ],
      child: WideNoteApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byKey(const Key('home-page')).evaluate().isEmpty) {
    await _openTab(tester, const Key('tab-home'));
  }
}

Future<void> _openTab(WidgetTester tester, Key tabKey) async {
  await tester.tap(find.byKey(tabKey));
  await tester.pumpAndSettle();
}

Future<void> _sendChat(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('chat-input-field')), text);
  await tester.tap(find.byKey(const Key('chat-send-button')));
  await tester.pumpAndSettle();
}

Future<void> _submitQuickCapture(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(const Key('tab-record-action')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('quick-capture-field')), text);
  await tester.tap(find.byKey(const Key('record-capture-button')));
  await tester.pumpAndSettle();
}

void _seedToolLoopContext(WideNoteLocalDatabase database, DateTime now) {
  database.captures.insert(
    CaptureRecord(
      id: 'capture-ui',
      sourceType: 'manual',
      sourceId: 'event-ui',
      payload: const <String, Object?>{
        'text': 'Met Lin about launch citations in read-only chat.',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.memoryItems.insert(
    MemoryItemRecord(
      id: 'memory-ui',
      key: 'launch.citations',
      body: 'Lin asked for launch citations in chat.',
      sourceEventId: 'event-ui',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-ui'},
      ],
      createdAt: now,
      updatedAt: now.add(const Duration(seconds: 1)),
    ),
  );
  database.todos.insert(
    TodoRecord(
      id: 'todo-ui',
      sourceCaptureId: 'capture-ui',
      sourceEventId: 'event-ui',
      status: 'open',
      payload: const <String, Object?>{
        'title': 'Prepare launch citation review.',
      },
      createdAt: now,
      updatedAt: now.add(const Duration(seconds: 2)),
    ),
  );
}

ChatState _readChatState(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byKey(const Key('chat-page'))),
  ).read(chatControllerProvider).requireValue;
}

final class _CaptureTestModel implements runtime.ModelClient {
  const _CaptureTestModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    return runtime.ModelResponse(
      text: _captureText(request.prompt),
      raw: const <String, Object?>{
        'memory_type': 'task_context',
        'confidence': 'high',
        'sensitivity': 'low',
        'durability': 'durable',
      },
    );
  }
}

String _captureText(String prompt) {
  final markerIndex = prompt.indexOf(captureMemoryPromptCaptureTextMarker);
  if (markerIndex == -1) {
    return prompt.replaceFirst('Summarize capture for Memory: ', '').trim();
  }
  return prompt
      .substring(markerIndex + captureMemoryPromptCaptureTextMarker.length)
      .trim();
}

final class _FlakyAssistant implements ChatAssistant {
  int calls = 0;

  @override
  Future<ChatAssistantReply> answer(ChatAssistantPrompt prompt) async {
    calls += 1;
    if (calls == 1) {
      throw StateError('first response failed');
    }
    return const ChatAssistantReply(body: 'Retry answer');
  }
}

final class _ScriptedChatModel implements runtime.ModelClient {
  _ScriptedChatModel({required List<String> responses})
    : _responses = List<String>.of(responses);

  final List<String> _responses;
  int _index = 0;

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    final response = _index < _responses.length
        ? _responses[_index]
        : _responses.last;
    _index += 1;
    return runtime.ModelResponse(text: response);
  }
}

final class _ScriptedAssistant implements ChatAssistant {
  _ScriptedAssistant({required List<String> responses})
    : _responses = List<String>.of(responses);

  final List<String> _responses;
  int calls = 0;

  @override
  Future<ChatAssistantReply> answer(ChatAssistantPrompt prompt) async {
    final response = calls < _responses.length
        ? _responses[calls]
        : _responses.last;
    calls += 1;
    return ChatAssistantReply(body: response);
  }
}
