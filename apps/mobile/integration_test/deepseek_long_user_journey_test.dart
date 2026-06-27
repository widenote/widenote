import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_model_providers/model_providers.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/model_providers/application/model_provider_settings_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const apiKey = String.fromEnvironment('WIDENOTE_QA_DEEPSEEK_API_KEY');
  const endpointValue = String.fromEnvironment(
    'WIDENOTE_QA_DEEPSEEK_ENDPOINT',
    defaultValue: 'https://api.deepseek.com/anthropic',
  );
  const model = String.fromEnvironment(
    'WIDENOTE_QA_DEEPSEEK_MODEL',
    defaultValue: 'deepseek-v4-flash',
  );

  testWidgets(
    'DeepSeek long user journey handles 20 captures with source-linked outputs',
    skip: apiKey.trim().isEmpty,
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      final httpClient = DartIoModelProviderHttpClient();
      final provider = modelProviderFromConfig(
        config: ModelProviderConfig(
          id: 'deepseek-long-journey',
          kind: ModelProviderKind.anthropicCompatible,
          displayName: 'DeepSeek Long Journey QA',
          endpoint: Uri.parse(endpointValue),
          model: model,
          apiKey: apiKey.trim(),
        ),
        httpClient: httpClient,
      );
      final modelClient = RuntimeModelClientAdapter(
        provider: provider,
        model: model,
      );
      addTearDown(httpClient.close);
      addTearDown(database.close);

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

      await _openHome(tester);
      expect(find.byKey(const Key('home-page')), findsOneWidget);

      for (final text in _memexInspiredCaptureCorpus) {
        final reviewBefore = database.memoryCandidates
            .readAll(status: 'needs_review')
            .length;
        await _submitCapture(tester, text);
        await _waitFor(
          tester,
          () => database.captures.readAll().any(
            (record) => record.payload['text'] == text,
          ),
          description: 'capture persisted',
          diagnostics: () => _databaseDiagnostics(database),
        );
        await _waitFor(
          tester,
          () =>
              database.memoryCandidates.readAll(status: 'needs_review').length >
              reviewBefore,
          description: 'model-backed Memory proposal',
          diagnostics: () => _databaseDiagnostics(database),
          timeout: const Duration(seconds: 120),
        );
      }

      expect(
        database.captures.readAll(),
        hasLength(_memexInspiredCaptureCorpus.length),
      );
      expect(
        database.memoryCandidates.readAll(status: 'needs_review'),
        hasLength(_memexInspiredCaptureCorpus.length),
      );
      expect(database.memoryItems.readAll(status: 'active'), isEmpty);
      expect(
        database.todos.readAll(),
        hasLength(_memexInspiredCaptureCorpus.length),
      );
      expect(database.cards.readAll(status: 'active'), isNotEmpty);
      expect(database.insights.readAll(status: 'active'), isNotEmpty);
      expect(
        database.traceEvents.readAll().map((trace) => trace.name),
        contains('runtime.model.completed'),
      );
      expect(
        database.traceEvents.readAll().every(
          (trace) => !trace.payload.toString().contains(apiKey),
        ),
        isTrue,
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

      final assistantMessages = database.chatMessages
          .readAll()
          .where((message) => message.role == 'assistant')
          .toList();
      expect(database.chatSessions.readAll(), hasLength(1));
      expect(database.chatMessages.readAll(), hasLength(_chatTurns.length * 2));
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
      expect(
        database.memoryCandidates.readAll(status: 'needs_review'),
        isNotEmpty,
      );

      final backupJson = LocalBackupService(database).exportJson();
      expect(backupJson, contains('"backup_mode": "safe"'));
      expect(backupJson, contains('"includes_secrets": false'));
      expect(backupJson, isNot(contains(apiKey)));

      final restored = WideNoteLocalDatabase.inMemory();
      addTearDown(restored.close);
      LocalBackupService(restored).importJson(backupJson);
      expect(
        restored.captures.readAll(),
        hasLength(_memexInspiredCaptureCorpus.length),
      );
      expect(restored.chatMessages.readAll(), hasLength(_chatTurns.length * 2));
      expect(
        restored.memoryCandidates.readAll(status: 'needs_review'),
        hasLength(_memexInspiredCaptureCorpus.length),
      );
      expect(
        restored.todos.readAll(),
        hasLength(_memexInspiredCaptureCorpus.length),
      );
    },
    timeout: const Timeout(Duration(minutes: 18)),
  );
}

const _memexInspiredCaptureCorpus = <String>[
  'Daily fact: woke at 07:18, wrote the WideNote simulator QA plan, and felt calmer after a short walk.',
  '中文记录：今天继续验证广记的本地优先链路，原始输入必须保留，Memory 只能作为可追溯的派生产物。',
  'Project note: compare WideNote capture outputs with Memex cards, PKM notes, insights, and local task traces.',
  'Follow-up task: decide whether simulator QA reports should become a repeatable release gate before beta.',
  'Health note: slept late at 23:50, drank two coffees, anxiety felt like 5/10, and stretching helped before dinner.',
  'Home note: buy blueberries, oat milk, low-sugar yogurt, and trash bags; skip the durian snacks.',
  'Preference update: prefer concise Memory candidates in the original language, with source links visible before summaries.',
  'Long note: Memex-style workflows often mix diary facts, project context, generated cards, insights, todos, and later chat questions. WideNote should keep the same practical loop while making source truth and local persistence easier to inspect.',
  'Symbols note: keep /tmp/widenote-qa, quotes "literal text", hash #release-gate, and id QA-2026-06-27 unchanged.',
  'Sensitive-shaped synthetic note: sk-demo-redacted-token is only a fake sentinel and should not appear in traces or backups as a provider secret.',
  'Contradiction note: last week I wanted broad imports first; today I prefer quick capture and reviewable Memory first.',
  'Meeting note: Lin asked for a bilingual summary of Android and iOS simulator behavior, plus a list of decisions for product review.',
  'Research note: the app should distinguish bugs from UX choices so bounded regressions can be fixed without changing product strategy.',
  'Finance-like note: paid 128.50 for cloud storage and should tag it as a reimbursable project expense later.',
  'Location-like note: coffee shop near Xujiahui was too noisy for voice capture, so preserve audio references before transcription.',
  'Backup note: safe export should include records, traces, Memory, todos, cards, and provider metadata, but never credential values.',
  'Runtime note: pack.default should produce Memory, cards, insights, todos, and trace events after capture without overwriting raw text.',
  'Chat note: later I will ask what changed between the old import-first preference and the new quick-capture-first preference.',
  'Review note: low-risk durable facts can be accepted into Memory, but sensitive or conflicting facts need visible review affordances.',
  'Release note: before publishing, rerun targeted tests, Android emulator QA, iOS simulator QA, and a secret scan.',
];

const _chatTurns = <String>[
  'Summarize my simulator QA records in three bullets.',
  'What changed between my old import-first preference and today preference?',
  'Which sources mention backup or provider credentials?',
  'What follow-up tasks did I create?',
  'Compare the Chinese note and the English project note.',
  'What should I ask the product owner to decide?',
];

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
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  final input = tester.widget<TextField>(field);
  if (input.controller?.text != text) {
    throw TestFailure('Capture field did not receive test input.');
  }
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
    diagnostics: () => _databaseDiagnostics(database),
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
    diagnostics: () => _databaseDiagnostics(database),
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
    diagnostics: () =>
        'home=${find.byKey(const Key('home-page')).evaluate().length}',
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
  required String Function() diagnostics,
  Duration timeout = const Duration(seconds: 60),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('Timed out waiting for $description. ${diagnostics()}');
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
      'review=${database.memoryCandidates.readAll(status: 'needs_review').length} '
      'memories=${database.memoryItems.readAll(status: 'active').length} '
      'todos=${database.todos.readAll().length} '
      'cards=${database.cards.readAll(status: 'active').length} '
      'insights=${database.insights.readAll(status: 'active').length} '
      'chatMessages=${database.chatMessages.readAll().length} '
      'failedRuns=[$failedRuns]';
}
