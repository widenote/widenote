import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/app/widenote_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const apiKey = String.fromEnvironment('WIDENOTE_QA_MIMO_API_KEY');
  final hasApiKey = apiKey.trim().isNotEmpty;

  testWidgets(
    'live LLM long journey produces source-linked local state',
    skip: !hasApiKey,
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      final modelClient = XiaomiMimoModelClient(apiKey: apiKey.trim());
      addTearDown(modelClient.close);
      addTearDown(database.close);
      await _pumpApp(tester, database, modelClient);

      await _openHome(tester);
      expect(find.byKey(const Key('home-page')), findsOneWidget);
      expect(database.captures.readAll(), isEmpty);

      for (final text in _captureCorpus) {
        final acceptedBefore = database.memoryItems
            .readAll(status: 'active')
            .length;
        await _submitCapture(tester, text);
        await _waitFor(
          tester,
          () => database.captures.readAll().any(
            (record) => record.payload['text'] == text,
          ),
          description: 'capture persisted: ${text.substring(0, 16)}',
          diagnostics: () => _databaseDiagnostics(database),
        );
        await _waitFor(
          tester,
          () =>
              database.memoryCandidates
                  .readAll(status: 'needs_review')
                  .isNotEmpty ||
              database.memoryItems.readAll(status: 'active').length >
                  acceptedBefore,
          description: 'model-backed Memory proposal',
          diagnostics: () => _databaseDiagnostics(database),
          timeout: const Duration(seconds: 90),
        );
        await _acceptAllVisibleMemoryReview(tester, database);
      }

      expect(database.captures.readAll(), hasLength(_captureCorpus.length));
      expect(
        database.memoryItems.readAll(status: 'active'),
        hasLength(_captureCorpus.length),
      );
      expect(database.todos.readAll(), hasLength(_captureCorpus.length));
      expect(database.cards.readAll(status: 'active'), isNotEmpty);
      expect(database.insights.readAll(status: 'active'), isNotEmpty);
      expect(
        database.traceEvents.readAll().map((trace) => trace.name),
        contains('runtime.model.completed'),
      );

      await tester.tap(find.byKey(const Key('tab-chat')));
      await tester.pumpAndSettle();

      for (var index = 0; index < _chatTurns.length; index += 1) {
        await _sendChat(tester, database, _chatTurns[index]);
        await _waitFor(
          tester,
          () =>
              database.chatMessages.readAll().length >= (index + 1) * 2 &&
              database.chatMessages
                      .readAll()
                      .where((message) => message.role == 'assistant')
                      .length >=
                  index + 1,
          description: 'chat turn ${index + 1}',
          diagnostics: () => _databaseDiagnostics(database),
          timeout: const Duration(seconds: 120),
        );
      }

      final chatMessages = database.chatMessages.readAll();
      final assistantMessages = chatMessages
          .where((message) => message.role == 'assistant')
          .toList();
      expect(database.chatSessions.readAll(), hasLength(1));
      expect(chatMessages, hasLength(_chatTurns.length * 2));
      expect(assistantMessages, hasLength(_chatTurns.length));
      expect(
        assistantMessages.every((message) => message.body.trim().isNotEmpty),
        isTrue,
      );
      expect(
        assistantMessages.every((message) => message.sourceRefs.isNotEmpty),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('tab-todos')));
      await tester.pumpAndSettle();
      final firstTodo = database.todos.readAll(status: 'open').first;
      final firstTodoCheckbox = find.byKey(
        Key('todo-checkbox-${firstTodo.id}'),
      );
      await tester.scrollUntilVisible(
        firstTodoCheckbox,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(firstTodoCheckbox),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(firstTodoCheckbox);
      await tester.pumpAndSettle();
      expect(database.todos.readById(firstTodo.id)!.status, 'completed');

      await tester.tap(find.byKey(const Key('tab-home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-memory-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('memory-page')), findsOneWidget);
      expect(database.memoryItems.readAll(status: 'active'), isNotEmpty);

      final backupJson = LocalBackupService(database).exportJson();
      expect(backupJson, contains('"backup_mode": "safe"'));
      expect(backupJson, contains('"includes_secrets": false'));
      expect(backupJson, isNot(contains(apiKey)));

      final restored = WideNoteLocalDatabase.inMemory();
      addTearDown(restored.close);
      LocalBackupService(restored).importJson(backupJson);
      expect(restored.captures.readAll(), hasLength(_captureCorpus.length));
      expect(restored.chatMessages.readAll(), hasLength(_chatTurns.length * 2));
      expect(
        restored.memoryItems.readAll(status: 'active'),
        hasLength(_captureCorpus.length),
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

const _captureCorpus = <String>[
  'Project note: WideNote live QA should preserve raw records and source refs.',
  '中文记录：广记要保持本地优先，并且 Memory 必须能追溯来源。',
  'English note: Lin reviewed the source-linked todo behavior.',
  'Follow up task: draft the Android and iOS live LLM acceptance summary.',
  'Long note: The product loop starts with quick capture, then local runtime, Memory review, cards, insights, todos, chat, and safe backup. The user wants long-session evidence instead of a tiny smoke test.',
  'Symbols note: keep paths like /tmp/widenote-live, quotes "literal", and id qa-2026-06-27 unchanged.',
  'Sensitive-shaped synthetic note: sk-demo-secret should remain raw evidence but core must not keyword-classify it locally.',
  'Preference update: prefer model-backed retrieval over local keyword ranking for source selection.',
];

const _chatTurns = <String>[
  'What did I say about the project note?',
  'Summarize today records in three bullets.',
  'What follow-up tasks should I do?',
  'Which source mentioned Lin?',
  'Do I have anything sensitive-shaped that should be handled carefully?',
  'Compare the Chinese and English notes.',
  'What changed in the preference update?',
  'What do you know only from local records?',
  'What do you not know from these sources?',
  'Summarize this whole conversation so far.',
];

Future<void> _pumpApp(
  WidgetTester tester,
  WideNoteLocalDatabase database,
  XiaomiMimoModelClient modelClient,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        modelClientProvider.overrideWithValue(modelClient),
        chatModelClientProvider.overrideWithValue(modelClient),
      ],
      child: const WideNoteApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitCapture(WidgetTester tester, String text) async {
  await _openHome(tester);
  final field = find.byKey(const Key('quick-capture-field'));
  if (field.evaluate().isEmpty) {
    final openButton = find.byKey(const Key('open-new-record-button'));
    await tester.ensureVisible(openButton);
    await tester.tap(openButton);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await _unfocus(tester);
  final button = find.byKey(const Key('record-capture-button'));
  if (button.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      button,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> _acceptAllVisibleMemoryReview(
  WidgetTester tester,
  WideNoteLocalDatabase database,
) async {
  while (true) {
    final pending = database.memoryCandidates
        .readAll(status: 'needs_review')
        .map((candidate) => candidate.id)
        .toList();
    if (pending.isEmpty) {
      return;
    }
    final button = find.byKey(Key('memory-review-accept-${pending.first}'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }
}

Future<void> _sendChat(
  WidgetTester tester,
  WideNoteLocalDatabase database,
  String text,
) async {
  final messagesBefore = database.chatMessages.readAll().length;
  final field = find.byKey(const Key('chat-input-field'));
  final button = find.byKey(const Key('chat-send-button'));
  await _waitFor(
    tester,
    () => _chatComposerReady(tester),
    description: 'chat composer ready',
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
  final input = tester.widget<TextField>(field);
  if (input.controller?.text != text) {
    throw TestFailure('Chat composer did not receive test input.');
  }
  await _unfocus(tester);
  await _waitFor(
    tester,
    () => _chatComposerReady(tester),
    description: 'chat composer ready after input',
  );
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await _waitFor(
    tester,
    () => database.chatMessages.readAll().length > messagesBefore,
    description: 'chat user message persisted',
    diagnostics: () => _databaseDiagnostics(database),
    timeout: const Duration(seconds: 10),
  );
}

bool _chatComposerReady(WidgetTester tester) {
  final field = find.byKey(const Key('chat-input-field'));
  final button = find.byKey(const Key('chat-send-button'));
  if (field.evaluate().isEmpty || button.evaluate().isEmpty) {
    return false;
  }
  final input = tester.widget<TextField>(field);
  final sendButton = tester.widget<FilledButton>(button);
  return input.enabled != false && sendButton.onPressed != null;
}

Future<void> _openHome(WidgetTester tester) async {
  if (find.byKey(const Key('home-page')).evaluate().isEmpty &&
      find.byKey(const Key('tab-home')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
  }
  await _waitFor(
    tester,
    () => find.byKey(const Key('home-page')).evaluate().isNotEmpty,
    description: 'home page',
  );
}

Future<void> _unfocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  String Function()? diagnostics,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      final suffix = diagnostics == null ? '' : ' ${diagnostics()}';
      throw TestFailure('Timed out waiting for $description.$suffix');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

String _databaseDiagnostics(WideNoteLocalDatabase database) {
  final failedRuns = database.runtimeRuns
      .readAll(status: 'failed')
      .map((run) => run.error ?? run.status)
      .join('|');
  return 'captures=${database.captures.readAll().length} '
      'memories=${database.memoryItems.readAll(status: 'active').length} '
      'review=${database.memoryCandidates.readAll(status: 'needs_review').length} '
      'todos=${database.todos.readAll().length} '
      'cards=${database.cards.readAll(status: 'active').length} '
      'insights=${database.insights.readAll(status: 'active').length} '
      'chatMessages=${database.chatMessages.readAll().length} '
      'failedRuns=[$failedRuns]';
}
