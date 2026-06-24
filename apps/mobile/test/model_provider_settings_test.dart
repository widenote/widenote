import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_model_providers/model_providers.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/model_providers/application/model_provider_settings_controller.dart';
import 'package:widenote_mobile/features/model_providers/presentation/model_provider_settings_page.dart';
import 'package:widenote_mobile/features/plugins/presentation/plugins_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  test('live provider connection tests require explicit opt-in flag', () {
    expect(liveProviderConnectionTestsEnabled(flag: ''), isFalse);
    expect(liveProviderConnectionTestsEnabled(flag: 'false'), isFalse);
    expect(liveProviderConnectionTestsEnabled(flag: '1'), isTrue);
    expect(liveProviderConnectionTestsEnabled(flag: 'true'), isTrue);
    expect(liveProviderConnectionTestsEnabled(flag: 'live'), isTrue);
  });

  testWidgets('plugins entry opens provider settings route', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 6, 24, 10);
    database.modelProviderConfigs.save(
      ModelProviderConfigRecord(
        id: 'mimo-main',
        providerKind: ModelProviderKind.mimo.name,
        displayName: 'MIMO Main',
        endpoint: ModelProviderKind.mimo.defaultEndpoint.toString(),
        model: ModelProviderKind.mimo.defaultModel,
        hasApiKey: true,
        apiKey: _runtimeCredential(),
        capabilities: [ModelCapability.chat.name],
        createdAt: now,
        updatedAt: now,
      ),
    );
    final router = GoRouter(
      initialLocation: '/plugins',
      routes: [
        GoRoute(
          path: '/plugins',
          builder: (context, state) => const Scaffold(body: PluginsPage()),
          routes: [
            GoRoute(
              path: 'model-providers',
              builder: (context, state) =>
                  const Scaffold(body: ModelProviderSettingsPage()),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 provider'), findsOneWidget);

    await tester.tap(find.byKey(const Key('model-provider-entry')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('model-provider-settings-page')),
      findsOneWidget,
    );
  });

  testWidgets(
    'provider settings supports add, default selection, test, edit, and keep key',
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      await _pumpSettings(tester, database: database);

      expect(find.text('No providers configured.'), findsOneWidget);

      await _addProvider(
        tester,
        displayName: 'Team OpenAI',
        endpoint: 'https://example.invalid/v1/chat/completions',
        model: 'team-chat',
      );

      expect(find.byKey(const Key('provider-row-team-openai')), findsOneWidget);
      expect(find.text('Team OpenAI'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);

      await _addProvider(
        tester,
        displayName: 'Kimi Main',
        endpoint: 'https://example.invalid/v1/chat/completions',
        model: 'kimi-chat',
        kindLabel: 'Kimi',
      );

      await tester.tap(find.byKey(const Key('provider-default-kimi-main')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('provider-row-kimi-main')),
          matching: find.text('Default'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('provider-test-team-openai')));
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(
        find.text('OpenAI-compatible validated offline. No live request sent.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('provider-edit-team-openai')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('provider-name-field')),
        'Team OpenAI Edited',
      );
      await tester.enterText(
        find.byKey(const Key('provider-model-field')),
        'edited-chat',
      );
      await tester.tap(find.byKey(const Key('provider-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Team OpenAI Edited'), findsOneWidget);
      expect(find.text('edited-chat'), findsOneWidget);
      expect(find.byKey(const Key('provider-row-team-openai')), findsOneWidget);
      expect(
        find.text('Connection test has not run for these saved settings.'),
        findsOneWidget,
      );

      final persisted = database.modelProviderConfigs.readById('team-openai')!;
      expect(persisted.displayName, 'Team OpenAI Edited');
      expect(persisted.model, 'edited-chat');
      expect(persisted.hasApiKey, isTrue);
      expect(persisted.apiKey, _runtimeCredential());
      expect(persisted.payload.toString(), isNot(contains('credential')));
    },
  );

  testWidgets('provider settings can clear a saved API key', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database);

    await _addProvider(
      tester,
      displayName: 'Team OpenAI',
      endpoint: 'https://example.invalid/v1/chat/completions',
      model: 'team-chat',
    );

    await tester.tap(find.byKey(const Key('provider-edit-team-openai')));
    await tester.pumpAndSettle();
    expect(find.text('Clear saved API key'), findsOneWidget);
    expect(find.textContaining('Leave blank'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('provider-clear-key-checkbox')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear saved API key'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('provider-save-button')));
    await tester.pumpAndSettle();

    final persisted = database.modelProviderConfigs.readById('team-openai')!;
    expect(persisted.hasApiKey, isFalse);
    expect(persisted.apiKey, isEmpty);
    expect(
      find.text('Saved API key cleared. Add a key before testing.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('provider-test-team-openai')));
    await tester.pumpAndSettle();

    expect(find.text('Failed'), findsOneWidget);
    expect(
      find.textContaining('configuration is incomplete: missingApiKey'),
      findsOneWidget,
    );
  });

  testWidgets('provider settings displays injected failure classification', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(
      tester,
      database: database,
      overrides: [
        modelProviderConnectionTestServiceProvider.overrideWithValue(
          _QueueConnectionTestService(<ModelProviderConnectionTestResult>[
            ModelProviderConnectionTestResult.failure(
              usedLiveAdapter: true,
              errorKind: ModelProviderErrorKind.authentication,
              message:
                  'Kimi authentication failed. HTTP 401. Check the saved API key and account access.',
            ),
          ]),
        ),
      ],
    );

    await _addProvider(
      tester,
      displayName: 'Kimi Main',
      endpoint: 'https://example.invalid/v1/chat/completions',
      model: 'kimi-chat',
      kindLabel: 'Kimi',
    );

    await tester.tap(find.byKey(const Key('provider-test-kimi-main')));
    await tester.pumpAndSettle();

    expect(find.text('Failed'), findsOneWidget);
    expect(find.textContaining('Kimi authentication failed'), findsOneWidget);
  });

  testWidgets('provider settings surfaces validation errors', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database);

    await tester.tap(find.byKey(const Key('provider-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('provider-name-field')), '');
    await tester.enterText(find.byKey(const Key('provider-api-key-field')), '');
    await tester.tap(find.byKey(const Key('provider-save-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Provider config invalid:'), findsWidgets);
    expect(find.textContaining('missingDisplayName'), findsWidgets);
    expect(find.textContaining('missingApiKey'), findsWidgets);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required WideNoteLocalDatabase database,
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        ...overrides,
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ModelProviderSettingsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _QueueConnectionTestService
    implements ModelProviderConnectionTestService {
  _QueueConnectionTestService(
    Iterable<ModelProviderConnectionTestResult> results,
  ) : _results = Queue<ModelProviderConnectionTestResult>.of(results);

  final Queue<ModelProviderConnectionTestResult> _results;

  @override
  Future<ModelProviderConnectionTestResult> test(
    ModelProviderConfig config,
  ) async {
    return _results.removeFirst();
  }
}

Future<void> _addProvider(
  WidgetTester tester, {
  required String displayName,
  required String endpoint,
  required String model,
  String? kindLabel,
}) async {
  await tester.tap(find.byKey(const Key('provider-add-button')));
  await tester.pumpAndSettle();

  if (kindLabel != null) {
    await tester.tap(find.byKey(const Key('provider-kind-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kindLabel).last);
    await tester.pumpAndSettle();
  }

  await tester.enterText(
    find.byKey(const Key('provider-name-field')),
    displayName,
  );
  await tester.enterText(
    find.byKey(const Key('provider-endpoint-field')),
    endpoint,
  );
  await tester.enterText(find.byKey(const Key('provider-model-field')), model);
  await tester.enterText(
    find.byKey(const Key('provider-api-key-field')),
    _runtimeCredential(),
  );
  await tester.tap(find.byKey(const Key('provider-save-button')));
  await tester.pumpAndSettle();
}

String _runtimeCredential() {
  return String.fromCharCodes(<int>[
    99,
    114,
    101,
    100,
    101,
    110,
    116,
    105,
    97,
    108,
  ]);
}
