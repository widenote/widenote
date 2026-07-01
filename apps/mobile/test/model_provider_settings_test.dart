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
    expect(find.text('Runtime model access'), findsOneWidget);
    expect(find.text('Using MIMO Main'), findsOneWidget);
  });

  testWidgets(
    'provider settings supports add, default selection, test, edit, and keep key',
    (tester) async {
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      await _pumpSettings(tester, database: database);

      expect(find.text('Model not configured'), findsOneWidget);
      expect(find.text('Model roles'), findsOneWidget);
      expect(find.text('Requires configured model'), findsWidgets);

      await _addProvider(
        tester,
        displayName: 'Team OpenAI',
        endpoint: 'https://example.invalid/v1/chat/completions',
        model: 'team-chat',
      );

      expect(find.byKey(const Key('provider-row-team-openai')), findsOneWidget);
      expect(find.text('Team OpenAI'), findsOneWidget);
      expect(find.text('Default'), findsWidgets);
      expect(find.text('Using Team OpenAI'), findsOneWidget);
      expect(find.text('Chat'), findsWidgets);
      expect(find.text('Completion'), findsWidgets);

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
        find.text('OpenAI validated offline. No live request sent.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('provider-edit-team-openai')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('provider-name-field')),
        'Team OpenAI Edited',
      );
      await _setCustomModel(tester, 'edited-chat');
      await tester.tap(find.byKey(const Key('provider-save-button')));
      await tester.pumpAndSettle();

      expect(find.text('Team OpenAI Edited'), findsOneWidget);
      expect(find.textContaining('edited-chat'), findsOneWidget);
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
    expect(
      find.text(
        'Leave unchecked and keep this field blank to keep the saved key.',
      ),
      findsOneWidget,
    );

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

  testWidgets('provider settings deletes a non-default provider', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database);

    await _addProvider(
      tester,
      displayName: 'Team OpenAI',
      endpoint: 'https://example.invalid/v1/chat/completions',
      model: 'team-chat',
    );
    await _addProvider(
      tester,
      displayName: 'Kimi Main',
      endpoint: 'https://example.invalid/v1/chat/completions',
      model: 'kimi-chat',
      kindLabel: 'Kimi',
    );
    await tester.tap(find.byKey(const Key('provider-default-kimi-main')));
    await tester.pumpAndSettle();

    await _deleteProvider(tester, 'team-openai');

    expect(find.byKey(const Key('provider-row-team-openai')), findsNothing);
    expect(find.byKey(const Key('provider-row-kimi-main')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('provider-row-kimi-main')),
        matching: find.text('Default'),
      ),
      findsOneWidget,
    );
    expect(
      database.modelProviderConfigs
          .readAll(status: 'active')
          .map((provider) => provider.id),
      <String>['kimi-main'],
    );
    final deleted = database.modelProviderConfigs.readById('team-openai')!;
    expect(deleted.status, 'deleted');
    expect(deleted.hasApiKey, isFalse);
    expect(deleted.apiKey, isEmpty);
  });

  testWidgets('provider settings deleting default falls back or clears', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database);

    await _addProvider(
      tester,
      displayName: 'Team OpenAI',
      endpoint: 'https://example.invalid/v1/chat/completions',
      model: 'team-chat',
    );
    await _addProvider(
      tester,
      displayName: 'Kimi Main',
      endpoint: 'https://example.invalid/v1/chat/completions',
      model: 'kimi-chat',
      kindLabel: 'Kimi',
    );

    await _deleteProvider(tester, 'team-openai');

    expect(database.modelProviderConfigs.readDefault()!.id, 'kimi-main');
    expect(
      find.descendant(
        of: find.byKey(const Key('provider-row-kimi-main')),
        matching: find.text('Default'),
      ),
      findsOneWidget,
    );

    await _deleteProvider(tester, 'kimi-main');

    expect(find.text('No providers configured.'), findsOneWidget);
    expect(database.modelProviderConfigs.readDefault(), isNull);
    expect(database.modelProviderConfigs.readAll(status: 'active'), isEmpty);
  });

  testWidgets('provider settings localizes delete confirmation in Chinese', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database, locale: const Locale('zh'));

    await _addProvider(
      tester,
      displayName: 'Kimi Main',
      endpoint: 'https://example.invalid/v1/chat/completions',
      model: 'kimi-chat',
      kindLabel: 'Kimi',
    );

    await tester.ensureVisible(
      find.byKey(const Key('provider-delete-kimi-main')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('provider-delete-kimi-main')));
    await tester.pumpAndSettle();

    expect(find.text('删除提供商？'), findsOneWidget);
    expect(find.text('从本地模型设置中移除“Kimi Main”。'), findsOneWidget);
    expect(find.text('Delete provider?'), findsNothing);
  });

  testWidgets('provider kind picker exposes common provider presets only', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database);

    await tester.tap(find.byKey(const Key('provider-add-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('provider-kind-field')));
    await tester.pumpAndSettle();

    expect(find.text('OpenAI'), findsWidgets);
    expect(find.text('Anthropic Claude'), findsOneWidget);
    expect(find.text('Google Gemini'), findsOneWidget);
    expect(find.text('OpenRouter'), findsOneWidget);
    expect(find.text('DeepSeek'), findsOneWidget);
    expect(find.text('Alibaba Qwen'), findsOneWidget);
    expect(find.text('Volcengine Doubao'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -280));
    await tester.pumpAndSettle();

    expect(find.text('Zhipu GLM'), findsOneWidget);
    expect(find.text('MiniMax'), findsOneWidget);
    expect(find.text('Ollama'), findsOneWidget);
    expect(find.text('OpenAI-compatible'), findsOneWidget);
    expect(find.text('Anthropic-compatible'), findsOneWidget);
    expect(find.text('Xiaomi MIMO'), findsOneWidget);
    expect(find.text('Kimi'), findsOneWidget);
    expect(find.text('Fake Model Provider'), findsNothing);
    expect(find.text('fake-model'), findsNothing);
  });

  testWidgets('provider presets fill endpoint and model fields', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database);

    await tester.tap(find.byKey(const Key('provider-add-button')));
    await tester.pumpAndSettle();
    await _selectProviderKind(tester, 'Google Gemini');

    expect(_fieldText(tester, 'provider-name-field'), 'Google Gemini');
    expect(
      _fieldText(tester, 'provider-endpoint-field'),
      'https://generativelanguage.googleapis.com/v1beta/openai',
    );
    expect(_selectedModel(tester), 'gemini-3.5-flash');

    await _selectProviderKind(tester, 'Anthropic Claude');

    expect(_fieldText(tester, 'provider-name-field'), 'Anthropic Claude');
    expect(
      _fieldText(tester, 'provider-endpoint-field'),
      'https://api.anthropic.com',
    );
    expect(_selectedModel(tester), 'claude-sonnet-5');

    await _selectProviderKind(tester, 'OpenRouter');

    expect(_fieldText(tester, 'provider-name-field'), 'OpenRouter');
    expect(
      _fieldText(tester, 'provider-endpoint-field'),
      'https://openrouter.ai/api/v1',
    );
    expect(_selectedModel(tester), 'openrouter/auto');

    await _selectProviderKind(tester, 'DeepSeek');

    expect(_fieldText(tester, 'provider-name-field'), 'DeepSeek');
    expect(
      _fieldText(tester, 'provider-endpoint-field'),
      'https://api.deepseek.com',
    );
    expect(_selectedModel(tester), 'deepseek-v4-pro');

    await _selectProviderKind(tester, 'Kimi');

    expect(_fieldText(tester, 'provider-name-field'), 'Kimi');
    expect(
      _fieldText(tester, 'provider-endpoint-field'),
      'https://api.moonshot.ai/v1',
    );
    expect(_selectedModel(tester), 'kimi-k2.6');
  });

  testWidgets('provider settings fetches models and saves selected model', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final modelListService = _QueueModelListService(
      <ModelProviderModelListResult>[
        ModelProviderModelListResult.success(<String>[
          'deepseek-chat',
          'deepseek-reasoner',
        ]),
      ],
    );
    await _pumpSettings(
      tester,
      database: database,
      overrides: [
        modelProviderModelListServiceProvider.overrideWithValue(
          modelListService,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('provider-add-button')));
    await tester.pumpAndSettle();
    await _selectProviderKind(tester, 'DeepSeek');
    await tester.enterText(
      find.byKey(const Key('provider-api-key-field')),
      _runtimeCredential(),
    );
    await tester.tap(find.byKey(const Key('provider-fetch-models-button')));
    await tester.pumpAndSettle();

    expect(modelListService.requests.single.kind, ModelProviderKind.deepSeek);
    expect(modelListService.requests.single.apiKey, _runtimeCredential());
    expect(find.text('deepseek-chat'), findsOneWidget);
    await _selectModel(tester, 'deepseek-reasoner');

    await tester.tap(find.byKey(const Key('provider-save-button')));
    await tester.pumpAndSettle();

    final persisted = database.modelProviderConfigs.readById('deepseek')!;
    expect(persisted.model, 'deepseek-reasoner');
    expect(find.textContaining('deepseek-reasoner'), findsWidgets);
  });

  testWidgets('provider model fetch failure keeps custom fallback', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final modelListService =
        _QueueModelListService(<ModelProviderModelListResult>[
          ModelProviderModelListResult.failure(
            errorKind: ModelProviderErrorKind.authentication,
          ),
          ModelProviderModelListResult.success(const <String>[]),
        ]);
    await _pumpSettings(
      tester,
      database: database,
      overrides: [
        modelProviderModelListServiceProvider.overrideWithValue(
          modelListService,
        ),
      ],
    );

    await tester.tap(find.byKey(const Key('provider-add-button')));
    await tester.pumpAndSettle();
    await _selectProviderKind(tester, 'Kimi');
    await tester.enterText(
      find.byKey(const Key('provider-api-key-field')),
      _runtimeCredential(),
    );

    await tester.tap(find.byKey(const Key('provider-fetch-models-button')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Model fetch authentication failed. Check the API key and account access.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('provider-fetch-models-button')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No models were returned. Keep the current model or enter a custom ID.',
      ),
      findsOneWidget,
    );

    await _setCustomModel(tester, 'kimi-private-gateway-model');
    await tester.tap(find.byKey(const Key('provider-save-button')));
    await tester.pumpAndSettle();

    final persisted = database.modelProviderConfigs.readById('kimi')!;
    expect(persisted.model, 'kimi-private-gateway-model');
  });

  testWidgets('provider settings can save no-key Ollama preset', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database);

    await tester.tap(find.byKey(const Key('provider-add-button')));
    await tester.pumpAndSettle();
    await _selectProviderKind(tester, 'Ollama');
    expect(
      find.text(
        'Optional for this provider; fill it only if your local server requires one.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('provider-save-button')));
    await tester.pumpAndSettle();

    final persisted = database.modelProviderConfigs.readById('ollama')!;
    expect(persisted.providerKind, ModelProviderKind.ollama.name);
    expect(persisted.hasApiKey, isFalse);
    expect(persisted.apiKey, isEmpty);
    expect(find.byKey(const Key('provider-row-ollama')), findsOneWidget);
    expect(find.text('Using Ollama'), findsOneWidget);
  });

  testWidgets('provider dialog fields use regular non-password keyboards', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpSettings(tester, database: database);

    await tester.tap(find.byKey(const Key('provider-add-button')));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(
      find.byKey(const Key('provider-name-field')),
    );
    final endpointField = tester.widget<TextField>(
      find.byKey(const Key('provider-endpoint-field')),
    );
    await _setCustomModel(tester, 'custom-chat');
    final customModelField = tester.widget<TextField>(
      find.byKey(const Key('provider-custom-model-field')),
    );
    final apiKeyField = tester.widget<TextField>(
      find.byKey(const Key('provider-api-key-field')),
    );

    expect(nameField.keyboardType, TextInputType.text);
    expect(nameField.textCapitalization, TextCapitalization.words);
    expect(endpointField.keyboardType, TextInputType.url);
    expect(endpointField.autocorrect, isFalse);
    expect(endpointField.enableSuggestions, isTrue);
    expect(endpointField.enableIMEPersonalizedLearning, isFalse);
    expect(customModelField.keyboardType, TextInputType.text);
    expect(customModelField.autocorrect, isFalse);
    expect(customModelField.enableSuggestions, isFalse);
    expect(apiKeyField.keyboardType, TextInputType.text);
    expect(apiKeyField.obscureText, isFalse);
    expect(apiKeyField.autocorrect, isFalse);
    expect(apiKeyField.enableSuggestions, isTrue);
    expect(apiKeyField.enableIMEPersonalizedLearning, isFalse);
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
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        modelProviderModelListServiceProvider.overrideWithValue(
          const OfflineModelProviderModelListService(),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: ModelProviderSettingsPage()),
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

final class _QueueModelListService implements ModelProviderModelListService {
  _QueueModelListService(Iterable<ModelProviderModelListResult> results)
    : _results = Queue<ModelProviderModelListResult>.of(results);

  final Queue<ModelProviderModelListResult> _results;
  final List<ModelProviderConfig> requests = <ModelProviderConfig>[];

  @override
  Future<ModelProviderModelListResult> listModels(
    ModelProviderConfig config,
  ) async {
    requests.add(config);
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
    await _selectProviderKind(tester, kindLabel);
  }

  await tester.enterText(
    find.byKey(const Key('provider-name-field')),
    displayName,
  );
  await tester.enterText(
    find.byKey(const Key('provider-endpoint-field')),
    endpoint,
  );
  await _setCustomModel(tester, model);
  await tester.enterText(
    find.byKey(const Key('provider-api-key-field')),
    _runtimeCredential(),
  );
  await tester.tap(find.byKey(const Key('provider-save-button')));
  await tester.pumpAndSettle();
}

Future<void> _deleteProvider(WidgetTester tester, String providerId) async {
  await tester.ensureVisible(find.byKey(Key('provider-delete-$providerId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('provider-delete-$providerId')));
  await tester.pumpAndSettle();
  expect(find.text('Delete provider?'), findsOneWidget);
  await tester.tap(find.byKey(Key('provider-confirm-delete-$providerId')));
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

String _fieldText(WidgetTester tester, String key) {
  final field = tester.widget<TextField>(find.byKey(Key(key)));
  return field.controller?.text ?? '';
}

String? _selectedModel(WidgetTester tester) {
  final field = tester.widget<DropdownButton<String>>(
    find.byKey(const Key('provider-model-field')),
  );
  return field.value;
}

Future<void> _selectModel(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('provider-model-field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _setCustomModel(WidgetTester tester, String model) async {
  await tester.tap(find.byKey(const Key('provider-model-field')));
  await tester.pumpAndSettle();
  final english = find.text('Custom model ID');
  final customFinder = english.evaluate().isNotEmpty
      ? english.last
      : find.text('自定义模型 ID').last;
  await tester.tap(customFinder);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('provider-custom-model-field')),
    model,
  );
  await tester.pumpAndSettle();
}

Future<void> _selectProviderKind(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('provider-kind-field')));
  await tester.pumpAndSettle();
  for (var attempt = 0; attempt < 8; attempt += 1) {
    if (find.text(label).evaluate().isNotEmpty) {
      break;
    }
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -280));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}
