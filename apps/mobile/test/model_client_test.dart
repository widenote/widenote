import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_model_providers/model_providers.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/features/backup/application/backup_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_controller.dart';
import 'package:widenote_mobile/features/chat/application/chat_controller.dart';
import 'package:widenote_mobile/features/chat/domain/chat_models.dart';
import 'package:widenote_mobile/features/model_providers/application/model_provider_settings_controller.dart';

void main() {
  test('ModelUnavailableModelClient requires configuration', () async {
    const client = ModelUnavailableModelClient();

    await expectLater(
      client.complete(
        const runtime.ModelRequest(
          prompt: 'Summarize capture for Memory: Keep WideNote local-first.',
        ),
      ),
      throwsA(isA<ModelUnavailableException>()),
    );
  });

  test('XiaomiMimoModelException does not expose request secrets', () {
    const exception = XiaomiMimoModelException('MIMO request failed.');

    expect(
      exception.toString(),
      'XiaomiMimoModelException: MIMO request failed.',
    );
  });

  test('modelClientProvider defaults to model-required state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(modelClientProvider),
      isA<ModelUnavailableModelClient>(),
    );
    expect(container.read(chatModelClientProvider), isNull);
  });

  test('modelClientProvider routes through saved default provider', () async {
    late String? authorizationHeader;
    final endpoint = await _serve((request) async {
      authorizationHeader = request.headers.value('authorization');
      await utf8.decodeStream(request);
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, Object?>{
            'id': 'provider-test',
            'model': 'local-provider-model',
            'choices': <Map<String, Object?>>[
              <String, Object?>{
                'message': <String, Object?>{
                  'role': 'assistant',
                  'content': 'Provider-backed memory.',
                },
              },
            ],
          }),
        );
      await request.response.close();
    });
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    _insertProvider(database, endpoint: endpoint);
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    final response = await container
        .read(modelClientProvider)
        .complete(
          const runtime.ModelRequest(
            prompt: 'Summarize capture for Memory: provider test',
          ),
        );

    expect(authorizationHeader, 'Bearer provider-secret');
    expect(response.text, 'Provider-backed memory.');
    expect(response.raw['provider_id'], 'provider-default');
  });

  test(
    'setting default refreshes model client dependents without app restart',
    () async {
      final oldEndpoint = await _providerEndpoint('Old provider memory.');
      final newEndpoint = await _providerEndpoint('New provider memory.');
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _insertProvider(
        database,
        id: 'provider-old',
        displayName: 'Old provider',
        endpoint: oldEndpoint,
        model: 'old-model',
        apiKey: 'old-secret',
      );
      _insertProvider(
        database,
        id: 'provider-new',
        displayName: 'New provider',
        endpoint: newEndpoint,
        model: 'new-model',
        apiKey: 'new-secret',
        isDefault: false,
      );
      final container = ProviderContainer(
        overrides: [localDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      await container.read(modelProviderSettingsControllerProvider.future);

      final oldClient = container.read(modelClientProvider);
      final oldChatAssistant = container.read(chatAssistantProvider);
      final oldCaptureOrchestrator = container.read(
        captureOrchestratorProvider,
      );
      final oldResponse = await oldClient.complete(
        const runtime.ModelRequest(
          prompt: 'Summarize capture for Memory: provider before switch',
        ),
      );
      expect(oldResponse.text, 'Old provider memory.');

      await container
          .read(modelProviderSettingsControllerProvider.notifier)
          .setDefaultProvider('provider-new');

      final newClient = container.read(modelClientProvider);
      expect(identical(newClient, oldClient), isFalse);
      final newResponse = await newClient.complete(
        const runtime.ModelRequest(
          prompt: 'Summarize capture for Memory: provider after switch',
        ),
      );
      expect(newResponse.text, 'New provider memory.');
      expect(newResponse.raw['provider_id'], 'provider-new');

      final newChatAssistant = container.read(chatAssistantProvider);
      expect(identical(newChatAssistant, oldChatAssistant), isFalse);
      final chatReply = await newChatAssistant.answer(
        ChatAssistantPrompt(
          question: 'What changed?',
          sources: <ChatSource>[
            ChatSource(
              id: 'memory-provider',
              kind: 'memory',
              title: 'Memory',
              excerpt: 'The default model provider changed.',
              sourceLabel: 'event: provider-test',
              createdAt: DateTime.utc(2026, 6, 26, 10),
            ),
          ],
        ),
      );
      expect(chatReply.body, 'New provider memory.');

      final newCaptureOrchestrator = container.read(
        captureOrchestratorProvider,
      );
      expect(
        identical(newCaptureOrchestrator, oldCaptureOrchestrator),
        isFalse,
      );
      final captureResult = await newCaptureOrchestrator.processCapture(
        'Capture should use the new provider.',
      );
      expect(captureResult.memoryItem.summary, 'New provider memory.');
    },
  );

  test('saving and deleting providers refreshes modelClientProvider', () async {
    final endpoint = await _providerEndpoint('Saved provider memory.');
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(modelClientProvider),
      isA<ModelUnavailableModelClient>(),
    );

    final saved = await container
        .read(modelProviderSettingsControllerProvider.notifier)
        .saveProvider(
          ModelProviderConfig(
            id: 'provider-saved',
            kind: ModelProviderKind.openAiCompatible,
            displayName: 'Saved provider',
            endpoint: endpoint,
            model: 'saved-model',
            apiKey: 'saved-secret',
          ),
        );
    expect(saved, isTrue);

    final providerResponse = await container
        .read(modelClientProvider)
        .complete(
          const runtime.ModelRequest(
            prompt: 'Summarize capture for Memory: provider after save',
          ),
        );
    expect(providerResponse.text, 'Saved provider memory.');
    expect(providerResponse.raw['provider_id'], 'provider-saved');

    await container
        .read(modelProviderSettingsControllerProvider.notifier)
        .deleteProvider('provider-saved');

    expect(database.modelProviderConfigs.readDefault(), isNull);
    expect(database.modelProviderConfigs.readAll(status: 'active'), isEmpty);
    final refreshed = container.read(modelClientProvider);
    expect(refreshed, isA<ModelUnavailableModelClient>());
    await expectLater(
      refreshed.complete(
        const runtime.ModelRequest(
          prompt: 'Summarize capture for Memory: provider deleted',
        ),
      ),
      throwsA(isA<ModelUnavailableException>()),
    );
  });

  test(
    'deleting default provider refreshes model client to fallback provider',
    () async {
      final oldEndpoint = await _providerEndpoint('Deleted provider memory.');
      final fallbackEndpoint = await _providerEndpoint(
        'Fallback provider memory.',
      );
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _insertProvider(
        database,
        id: 'provider-deleted',
        displayName: 'Deleted provider',
        endpoint: oldEndpoint,
        apiKey: 'deleted-secret',
      );
      _insertProvider(
        database,
        id: 'provider-fallback',
        displayName: 'Fallback provider',
        endpoint: fallbackEndpoint,
        apiKey: 'fallback-secret',
        isDefault: false,
      );
      final container = ProviderContainer(
        overrides: [localDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);
      await container.read(modelProviderSettingsControllerProvider.future);
      final oldClient = container.read(modelClientProvider);

      await container
          .read(modelProviderSettingsControllerProvider.notifier)
          .deleteProvider('provider-deleted');

      expect(
        database.modelProviderConfigs.readDefault()!.id,
        'provider-fallback',
      );
      final newClient = container.read(modelClientProvider);
      expect(identical(newClient, oldClient), isFalse);
      final response = await newClient.complete(
        const runtime.ModelRequest(
          prompt: 'Summarize capture for Memory: after default delete',
        ),
      );
      expect(response.text, 'Fallback provider memory.');
      expect(response.raw['provider_id'], 'provider-fallback');
    },
  );

  test(
    'backup import refreshes stale runtime client and keeps safe backup secret-free',
    () async {
      final staleEndpoint = await _providerEndpoint('Stale provider memory.');
      final importedEndpoint = await _providerEndpoint(
        'Imported provider memory.',
      );
      final source = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      _insertProvider(
        source,
        id: 'provider-imported',
        displayName: 'Imported provider',
        endpoint: importedEndpoint,
        apiKey: 'imported-secret',
        updatedAt: DateTime.utc(2026, 6, 26, 12),
      );
      final json = LocalBackupService(source).exportJson();
      expect(json, isNot(contains('imported-secret')));

      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(target.close);
      _insertProvider(
        target,
        id: 'provider-stale',
        displayName: 'Stale provider',
        endpoint: staleEndpoint,
        apiKey: 'stale-secret',
        updatedAt: DateTime.utc(2026, 6, 24, 12),
      );
      final container = ProviderContainer(
        overrides: [localDatabaseProvider.overrideWithValue(target)],
      );
      addTearDown(container.dispose);
      final staleResponse = await container
          .read(modelClientProvider)
          .complete(
            const runtime.ModelRequest(
              prompt: 'Summarize capture for Memory: before import',
            ),
          );
      expect(staleResponse.text, 'Stale provider memory.');

      final backupController = container.read(
        backupControllerProvider.notifier,
      );
      backupController.updateImportDraft(json);
      expect(backupController.importBackup(), isTrue);

      final imported = target.modelProviderConfigs.readDefault()!;
      expect(imported.id, 'provider-imported');
      expect(imported.hasApiKey, isTrue);
      expect(imported.apiKey, isEmpty);
      final refreshed = container.read(modelClientProvider);
      expect(refreshed, isA<ModelUnavailableModelClient>());
      await expectLater(
        refreshed.complete(
          const runtime.ModelRequest(
            prompt: 'Summarize capture for Memory: imported key omitted',
          ),
        ),
        throwsA(isA<ModelUnavailableException>()),
      );
    },
  );

  test(
    'modelClientProvider surfaces provider failure without local fallback',
    () async {
      final endpoint = await _serve((request) async {
        await utf8.decodeStream(request);
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('server failed');
        await request.response.close();
      });
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _insertProvider(database, endpoint: endpoint);
      final container = ProviderContainer(
        overrides: [localDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(modelClientProvider)
            .complete(
              const runtime.ModelRequest(
                prompt: 'Summarize capture for Memory: Provider fallback note.',
              ),
            ),
        throwsA(isA<RuntimeModelProviderException>()),
      );
    },
  );

  test(
    'chatModelClientProvider does not fall back locally when default provider fails',
    () async {
      final endpoint = await _serve((request) async {
        await utf8.decodeStream(request);
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('server failed');
        await request.response.close();
      });
      final database = WideNoteLocalDatabase.inMemory();
      addTearDown(database.close);
      _insertProvider(database, endpoint: endpoint);
      final container = ProviderContainer(
        overrides: [localDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(container.dispose);

      final client = container.read(chatModelClientProvider);
      expect(client, isNotNull);

      await expectLater(
        client!.complete(
          const runtime.ModelRequest(
            prompt: 'Chat should not use local summary fallback.',
          ),
        ),
        throwsA(isA<RuntimeModelProviderException>()),
      );
    },
  );

  test(
    'XiaomiMimoModelClient sends expected Anthropic-compatible request',
    () async {
      late String? apiKeyHeader;
      late String? versionHeader;
      late ContentType? contentType;
      late Map<String, Object?> requestBody;
      final endpoint = await _serve((request) async {
        apiKeyHeader = request.headers.value('x-api-key');
        versionHeader = request.headers.value('anthropic-version');
        contentType = request.headers.contentType;
        requestBody =
            jsonDecode(await utf8.decodeStream(request))
                as Map<String, Object?>;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'content': <Map<String, Object?>>[
                <String, Object?>{'type': 'thinking', 'thinking': 'ignored'},
                <String, Object?>{'type': 'text', 'text': 'First memory.'},
                <String, Object?>{'type': 'text', 'text': 'Second memory.'},
              ],
            }),
          );
        await request.response.close();
      });
      final client = XiaomiMimoModelClient(
        apiKey: 'secret-token',
        endpoint: endpoint,
      );
      addTearDown(() => client.close(force: true));

      final response = await client.complete(
        const runtime.ModelRequest(
          prompt:
              'Summarize capture for Memory: Save raw notes locally. 广记保留原文。',
        ),
      );

      expect(apiKeyHeader, 'secret-token');
      expect(versionHeader, '2023-06-01');
      expect(contentType?.mimeType, ContentType.json.mimeType);
      expect(requestBody['model'], 'mimo-v2.5-pro');
      expect(requestBody['max_tokens'], 128);
      expect(requestBody['thinking'], <String, Object?>{'type': 'disabled'});
      final messages = requestBody['messages']! as List<Object?>;
      final message = messages.single! as Map<String, Object?>;
      expect(message['role'], 'user');
      expect(
        message['content'],
        allOf(
          contains('WideNote QA capture model adapter'),
          contains(
            'Summarize capture for Memory: Save raw notes locally. 广记保留原文。',
          ),
        ),
      );
      expect(response.text, 'First memory.\nSecond memory.');
    },
  );

  test(
    'XiaomiMimoModelClient preserves chat prompts without capture instructions',
    () async {
      late Map<String, Object?> requestBody;
      final endpoint = await _serve((request) async {
        requestBody =
            jsonDecode(await utf8.decodeStream(request))
                as Map<String, Object?>;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'content': <Map<String, Object?>>[
                <String, Object?>{
                  'type': 'text',
                  'text': 'The local source says WideNote keeps raw captures.',
                },
              ],
            }),
          );
        await request.response.close();
      });
      final client = XiaomiMimoModelClient(
        apiKey: 'secret-token',
        endpoint: endpoint,
      );
      addTearDown(() => client.close(force: true));

      final response = await client.complete(
        const runtime.ModelRequest(
          prompt: '''
Answer the user's WideNote question using only the local sources below.

Question:
What did I capture?

Local sources:
- memory/memory-1: WideNote keeps raw captures.
''',
          context: <String, Object?>{'chat_mode': 'source_cited_local_context'},
        ),
      );

      expect(requestBody['max_tokens'], 512);
      expect(requestBody['thinking'], <String, Object?>{'type': 'disabled'});
      final messages = requestBody['messages']! as List<Object?>;
      final message = messages.single! as Map<String, Object?>;
      expect(message['role'], 'user');
      expect(
        message['content'],
        allOf(
          contains('WideNote QA chat model adapter'),
          contains('memory/memory-1'),
          isNot(contains('Return one concise, safe Memory sentence')),
        ),
      );
      expect(
        response.text,
        'The local source says WideNote keeps raw captures.',
      );
    },
  );

  test(
    'XiaomiMimoModelClient throws sanitized error for non-2xx responses',
    () async {
      final endpoint = await _serve((request) async {
        await utf8.decodeStream(request);
        request.response
          ..statusCode = HttpStatus.tooManyRequests
          ..write('rate limited');
        await request.response.close();
      });
      final client = XiaomiMimoModelClient(
        apiKey: 'secret-token',
        endpoint: endpoint,
        retryDelays: const <Duration>[],
      );
      addTearDown(() => client.close(force: true));

      await expectLater(
        client.complete(const runtime.ModelRequest(prompt: 'hello')),
        throwsA(
          isA<XiaomiMimoModelException>()
              .having(
                (exception) => exception.toString(),
                'message',
                contains('HTTP 429'),
              )
              .having(
                (exception) => exception.toString(),
                'secret',
                isNot(contains('secret-token')),
              ),
        ),
      );
    },
  );

  test('XiaomiMimoModelClient rejects malformed JSON responses', () async {
    final endpoint = await _serve((request) async {
      await utf8.decodeStream(request);
      request.response
        ..statusCode = HttpStatus.ok
        ..write('not-json');
      await request.response.close();
    });
    final client = XiaomiMimoModelClient(
      apiKey: 'secret-token',
      endpoint: endpoint,
    );
    addTearDown(() => client.close(force: true));

    await expectLater(
      client.complete(const runtime.ModelRequest(prompt: 'hello')),
      throwsA(
        isA<XiaomiMimoModelException>().having(
          (exception) => exception.toString(),
          'message',
          contains('Invalid MIMO response.'),
        ),
      ),
    );
  });

  test('XiaomiMimoModelClient retries rate limits before succeeding', () async {
    var calls = 0;
    final endpoint = await _serve((request) async {
      calls += 1;
      await utf8.decodeStream(request);
      if (calls == 1) {
        request.response
          ..statusCode = HttpStatus.tooManyRequests
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{'message': 'Too many requests'},
            }),
          );
        await request.response.close();
        return;
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, Object?>{
            'content': <Map<String, Object?>>[
              <String, Object?>{'type': 'text', 'text': 'Retried memory.'},
            ],
          }),
        );
      await request.response.close();
    });
    final client = XiaomiMimoModelClient(
      apiKey: 'secret-token',
      endpoint: endpoint,
      retryDelays: const <Duration>[Duration.zero],
    );
    addTearDown(() => client.close(force: true));

    final response = await client.complete(
      const runtime.ModelRequest(prompt: 'retry please'),
    );

    expect(response.text, 'Retried memory.');
    expect(calls, 2);
  });

  test(
    'XiaomiMimoModelClient rejects responses without text content',
    () async {
      final endpoint = await _serve((request) async {
        await utf8.decodeStream(request);
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              'content': <Map<String, Object?>>[
                <String, Object?>{'type': 'thinking', 'thinking': 'only'},
              ],
            }),
          );
        await request.response.close();
      });
      final client = XiaomiMimoModelClient(
        apiKey: 'secret-token',
        endpoint: endpoint,
      );
      addTearDown(() => client.close(force: true));

      await expectLater(
        client.complete(const runtime.ModelRequest(prompt: 'hello')),
        throwsA(
          isA<XiaomiMimoModelException>().having(
            (exception) => exception.toString(),
            'message',
            contains('MIMO response did not contain text.'),
          ),
        ),
      );
    },
  );
}

typedef _RequestHandler = Future<void> Function(HttpRequest request);

Future<Uri> _serve(_RequestHandler handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });
  unawaited(() async {
    await for (final request in server) {
      await handler(request);
    }
  }());
  return Uri.parse('http://${server.address.host}:${server.port}/messages');
}

Future<Uri> _providerEndpoint(String text) {
  return _serve((request) async {
    await utf8.decodeStream(request);
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode(<String, Object?>{
          'id': 'provider-test',
          'model': 'provider-model',
          'choices': <Map<String, Object?>>[
            <String, Object?>{
              'message': <String, Object?>{
                'role': 'assistant',
                'content': text,
              },
            },
          ],
        }),
      );
    await request.response.close();
  });
}

void _insertProvider(
  WideNoteLocalDatabase database, {
  required Uri endpoint,
  String id = 'provider-default',
  String displayName = 'Provider default',
  String model = 'local-provider-model',
  String apiKey = 'provider-secret',
  bool isDefault = true,
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime.utc(2026, 6, 24, 12);
  database.modelProviderConfigs.insert(
    ModelProviderConfigRecord(
      id: id,
      providerKind: 'openAiCompatible',
      displayName: displayName,
      endpoint: endpoint.toString(),
      model: model,
      isDefault: isDefault,
      hasApiKey: true,
      apiKey: apiKey,
      capabilities: const <Object?>['chat', 'completion'],
      createdAt: now,
      updatedAt: now,
    ),
  );
}
