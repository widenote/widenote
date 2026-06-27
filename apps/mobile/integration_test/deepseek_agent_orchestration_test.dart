import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
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
    'DeepSeek simulator smoke produces source-linked agent state',
    skip: apiKey.trim().isEmpty,
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      final httpClient = DartIoModelProviderHttpClient();
      final provider = modelProviderFromConfig(
        config: ModelProviderConfig(
          id: 'deepseek-simulator',
          kind: ModelProviderKind.anthropicCompatible,
          displayName: 'DeepSeek Simulator QA',
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

      const captureText =
          'Simulator DeepSeek QA: Zhang Yu needs the Project Atlas ADR-12 '
          'local-first runtime summary before next Wednesday.';
      await _submitCapture(tester, captureText);

      await _waitFor(
        tester,
        () =>
            database.captures.readAll().any(
              (record) => record.payload['text'] == captureText,
            ) &&
            database.memoryItems.readAll(status: 'active').isNotEmpty &&
            database.todos.readAll().isNotEmpty,
        description: 'DeepSeek capture pipeline',
        diagnostics: () => _databaseDiagnostics(database),
        timeout: const Duration(seconds: 120),
      );

      final memory = database.memoryItems.readAll(status: 'active').single;
      expect(memory.body.trim(), isNotEmpty);
      expect(memory.body.length, lessThanOrEqualTo(240));
      expect(
        memory.body,
        anyOf(contains('Project Atlas'), contains('ADR-12'), contains('Zhang')),
      );
      expect(
        database.memoryCandidates.readAll(status: 'needs_review'),
        isEmpty,
      );
      expect(database.todos.readAll(), hasLength(1));
      expect(
        database.eventLog.readAll().map((event) => event.type),
        containsAll(<String>[
          runtime.WnEventTypes.captureCreated,
          runtime.WnEventTypes.memoryProposed,
          runtime.WnEventTypes.cardCreated,
          runtime.WnEventTypes.insightCreated,
          runtime.WnEventTypes.todoSuggested,
        ]),
      );

      final traces = database.traceEvents.readAll();
      expect(
        traces.map((trace) => trace.name),
        contains('runtime.model.completed'),
      );
      for (final trace in traces) {
        expect(trace.payload.toString(), isNot(contains(apiKey)));
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _submitCapture(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.byKey(const Key('open-new-record-button')));
  await tester.tap(find.byKey(const Key('open-new-record-button')));
  await tester.pumpAndSettle();

  final field = find.byKey(const Key('quick-capture-field'));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await _unfocus(tester);

  final button = find.byKey(const Key('record-capture-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
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
      'todos=${database.todos.readAll().length} '
      'events=${database.eventLog.readAll().map((event) => event.type).join(',')} '
      'traces=${database.traceEvents.readAll().map((trace) => trace.name).join(',')} '
      'failedRuns=[$failedRuns]';
}
