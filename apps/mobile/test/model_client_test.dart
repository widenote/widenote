import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';

void main() {
  test('LocalSummaryModelClient returns deterministic local summary', () async {
    const client = LocalSummaryModelClient();

    final response = await client.complete(
      const runtime.ModelRequest(
        prompt: 'Summarize capture for Memory: Keep WideNote local-first.',
      ),
    );

    expect(response.text, 'Keep WideNote local-first.');
  });

  test('XiaomiMimoModelException does not expose request secrets', () {
    const exception = XiaomiMimoModelException('MIMO request failed.');

    expect(
      exception.toString(),
      'XiaomiMimoModelException: MIMO request failed.',
    );
  });

  test('modelClientProvider defaults to local offline model', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(modelClientProvider), isA<LocalSummaryModelClient>());
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
    'modelClientProvider falls back locally when default provider fails',
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

      final response = await container
          .read(modelClientProvider)
          .complete(
            const runtime.ModelRequest(
              prompt: 'Summarize capture for Memory: Provider fallback note.',
            ),
          );

      expect(response.text, 'Provider fallback note.');
      expect(response.raw['model_fallback'], isTrue);
      expect(response.raw['model_fallback_provider_id'], 'provider-default');
      expect(response.raw.toString(), isNot(contains('provider-secret')));
    },
  );

  test('qaMimoModelClientFromKey ignores blank keys and trims valid keys', () {
    expect(qaMimoModelClientFromKey(''), isNull);
    expect(qaMimoModelClientFromKey('   '), isNull);

    final client = qaMimoModelClientFromKey(' secret-token ');
    addTearDown(() {
      if (client is XiaomiMimoModelClient) {
        client.close(force: true);
      }
    });

    expect(client, isA<XiaomiMimoModelClient>());
    expect((client! as XiaomiMimoModelClient).apiKey, 'secret-token');
  });

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
      final messages = requestBody['messages']! as List<Object?>;
      final message = messages.single! as Map<String, Object?>;
      expect(message['role'], 'user');
      expect(
        message['content'],
        allOf(
          contains('WideNote Android QA model adapter'),
          contains(
            'Summarize capture for Memory: Save raw notes locally. 广记保留原文。',
          ),
        ),
      );
      expect(response.text, 'First memory.\nSecond memory.');
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

void _insertProvider(WideNoteLocalDatabase database, {required Uri endpoint}) {
  final now = DateTime.utc(2026, 6, 24, 12);
  database.modelProviderConfigs.insert(
    ModelProviderConfigRecord(
      id: 'provider-default',
      providerKind: 'openAiCompatible',
      displayName: 'Provider default',
      endpoint: endpoint.toString(),
      model: 'local-provider-model',
      isDefault: true,
      hasApiKey: true,
      apiKey: 'provider-secret',
      capabilities: const <Object?>['chat', 'completion'],
      createdAt: now,
      updatedAt: now,
    ),
  );
}
