import 'dart:async';

import 'package:test/test.dart';
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  group('OpenAiCompatibleModelProvider', () {
    test('constructs chat-completions request and parses text usage', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          ModelProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'id': 'request-1',
              'model': 'provider-model',
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{'content': 'Hello WideNote'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': <String, Object?>{
                'prompt_tokens': 8,
                'completion_tokens': 3,
              },
            },
          ),
        ],
      );
      final provider = OpenAiCompatibleModelProvider(
        config: _config(ModelProviderKind.openAiCompatible),
        httpClient: http,
      );

      final response = await provider.complete(
        const ModelRequest(
          model: 'selected-model',
          requiredCapabilities: <ModelCapability>{ModelCapability.chat},
          messages: <ModelMessage>[
            ModelMessage(role: ModelMessageRole.system, content: 'Be brief.'),
            ModelMessage(role: ModelMessageRole.user, content: 'Say hello.'),
          ],
          metadata: <String, Object?>{'source': 'settings-test'},
        ),
      );

      final request = http.requests.single;
      expect(request.endpoint.path, '/v1/chat/completions');
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers['authorization'], startsWith('Bearer '));
      expect(request.redactedHeaders['authorization'], '<redacted>');
      expect(request.body['model'], 'selected-model');
      expect(request.body['max_tokens'], 1024);
      expect(request.body['metadata'], <String, Object?>{
        'source': 'settings-test',
      });
      expect(request.body['messages'], <Map<String, Object?>>[
        <String, Object?>{'role': 'system', 'content': 'Be brief.'},
        <String, Object?>{'role': 'user', 'content': 'Say hello.'},
      ]);
      expect(response.providerId, 'openai-compatible');
      expect(response.model, 'provider-model');
      expect(response.text, 'Hello WideNote');
      expect(response.usage.totalTokens, 11);
      expect(response.metadata['finish_reason'], 'stop');
    });

    test('classifies authentication, rate limit, and server errors', () async {
      for (final item in <({int status, ModelProviderErrorKind kind})>[
        (status: 401, kind: ModelProviderErrorKind.authentication),
        (status: 408, kind: ModelProviderErrorKind.timeout),
        (status: 429, kind: ModelProviderErrorKind.rateLimited),
        (status: 503, kind: ModelProviderErrorKind.server),
      ]) {
        final http = FakeModelProviderHttpClient(
          responses: <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(
              statusCode: item.status,
              body: <String, Object?>{'error': 'ignored'},
            ),
          ],
        );
        final provider = OpenAiCompatibleModelProvider(
          config: _config(ModelProviderKind.openAiCompatible),
          httpClient: http,
        );

        await expectLater(
          provider.complete(ModelRequest.text('hello')),
          throwsA(
            isA<ModelProviderException>()
                .having((error) => error.kind, 'kind', item.kind)
                .having((error) => error.statusCode, 'statusCode', item.status),
          ),
        );
      }
    });

    test(
      'classifies network exceptions before a response is received',
      () async {
        final http = FakeModelProviderHttpClient()
          ..enqueueError(TimeoutException('slow network'));
        final provider = OpenAiCompatibleModelProvider(
          config: _config(ModelProviderKind.openAiCompatible),
          httpClient: http,
        );

        await expectLater(
          provider.complete(ModelRequest.text('hello')),
          throwsA(
            isA<ModelProviderException>().having(
              (error) => error.kind,
              'kind',
              ModelProviderErrorKind.timeout,
            ),
          ),
        );

        final networkHttp = FakeModelProviderHttpClient()
          ..enqueueError(StateError('socket closed'));
        final networkProvider = OpenAiCompatibleModelProvider(
          config: _config(ModelProviderKind.openAiCompatible),
          httpClient: networkHttp,
        );

        await expectLater(
          networkProvider.complete(ModelRequest.text('hello')),
          throwsA(
            isA<ModelProviderException>().having(
              (error) => error.kind,
              'kind',
              ModelProviderErrorKind.network,
            ),
          ),
        );
      },
    );

    test('classifies malformed and missing text responses', () async {
      final malformed = OpenAiCompatibleModelProvider(
        config: _config(ModelProviderKind.openAiCompatible),
        httpClient: FakeModelProviderHttpClient(
          responses: const <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(statusCode: 200, body: <Object?>[]),
          ],
        ),
      );
      final missingText = OpenAiCompatibleModelProvider(
        config: _config(ModelProviderKind.openAiCompatible),
        httpClient: FakeModelProviderHttpClient(
          responses: <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'choices': <Object?>[
                  <String, Object?>{
                    'message': <String, Object?>{'content': '  '},
                  },
                ],
              },
            ),
          ],
        ),
      );

      await expectLater(
        malformed.complete(ModelRequest.text('hello')),
        throwsA(
          isA<ModelProviderException>().having(
            (error) => error.kind,
            'kind',
            ModelProviderErrorKind.malformedResponse,
          ),
        ),
      );
      await expectLater(
        missingText.complete(ModelRequest.text('hello')),
        throwsA(
          isA<ModelProviderException>().having(
            (error) => error.kind,
            'kind',
            ModelProviderErrorKind.missingText,
          ),
        ),
      );
    });

    test('accepts base endpoints by appending chat completions path', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          _openAiTextResponse('OpenAI OK'),
          _openAiTextResponse('Gemini OK'),
          _openAiTextResponse('OpenAI DeepSeek gateway OK'),
        ],
      );
      final openAiProvider = OpenAiCompatibleModelProvider(
        config: ModelProviderConfig.preset(
          id: 'openai',
          kind: ModelProviderKind.openAi,
          apiKey: _runtimeCredential(),
        ),
        httpClient: http,
      );
      final geminiProvider = OpenAiCompatibleModelProvider(
        config: ModelProviderConfig.preset(
          id: 'gemini',
          kind: ModelProviderKind.gemini,
          apiKey: _runtimeCredential(),
        ),
        httpClient: http,
      );
      final openAiDeepSeekGatewayProvider = OpenAiCompatibleModelProvider(
        config: ModelProviderConfig.preset(
          id: 'deepseek-openai-gateway',
          kind: ModelProviderKind.openAiCompatible,
          endpoint: Uri.parse('https://api.deepseek.com/v1'),
          apiKey: _runtimeCredential(),
        ),
        httpClient: http,
      );

      expect(
        (await openAiProvider.complete(ModelRequest.text('hello'))).text,
        'OpenAI OK',
      );
      expect(
        (await geminiProvider.complete(ModelRequest.text('hello'))).text,
        'Gemini OK',
      );
      expect(
        (await openAiDeepSeekGatewayProvider.complete(
          ModelRequest.text('hello'),
        )).text,
        'OpenAI DeepSeek gateway OK',
      );

      expect(
        http.requests[0].endpoint.toString(),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        http.requests[1].endpoint.toString(),
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
      );
      expect(
        http.requests[2].endpoint.toString(),
        'https://api.deepseek.com/v1/chat/completions',
      );
    });

    test('omits authorization header for no-key local providers', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[_openAiTextResponse('Local OK')],
      );
      final provider = OpenAiCompatibleModelProvider(
        config: ModelProviderConfig.preset(
          id: 'ollama',
          kind: ModelProviderKind.ollama,
        ),
        httpClient: http,
      );

      final response = await provider.complete(ModelRequest.text('hello'));

      expect(response.text, 'Local OK');
      expect(
        http.requests.single.headers.containsKey('authorization'),
        isFalse,
      );
    });
  });

  group('AnthropicCompatibleModelProvider', () {
    test('constructs messages request and parses multi-part text', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          ModelProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'id': 'message-1',
              'model': 'anthropic-model',
              'stop_reason': 'end_turn',
              'content': <Object?>[
                <String, Object?>{'type': 'thinking', 'text': 'ignored'},
                <String, Object?>{'type': 'text', 'text': 'First'},
                <String, Object?>{'type': 'text', 'text': 'Second'},
              ],
              'usage': <String, Object?>{'input_tokens': 5, 'output_tokens': 2},
            },
          ),
        ],
      );
      final provider = AnthropicCompatibleModelProvider(
        config: _config(ModelProviderKind.mimo),
        httpClient: http,
      );

      final response = await provider.complete(
        const ModelRequest(
          messages: <ModelMessage>[
            ModelMessage(role: ModelMessageRole.system, content: 'Be useful.'),
            ModelMessage(role: ModelMessageRole.user, content: 'Draft note.'),
            ModelMessage(role: ModelMessageRole.assistant, content: 'Drafted.'),
          ],
        ),
      );

      final request = http.requests.single;
      expect(request.headers['anthropic-version'], '2023-06-01');
      expect(request.headers['x-api-key'], isNotEmpty);
      expect(request.redactedHeaders['x-api-key'], '<redacted>');
      expect(request.body['thinking'], <String, Object?>{'type': 'disabled'});
      expect(request.body['max_tokens'], 1024);
      expect(request.body['system'], 'Be useful.');
      expect(request.body['messages'], <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': 'Draft note.'},
        <String, Object?>{'role': 'assistant', 'content': 'Drafted.'},
      ]);
      expect(response.providerId, 'mimo');
      expect(response.model, 'anthropic-model');
      expect(response.text, 'First\nSecond');
      expect(response.usage.inputTokens, 5);
      expect(response.metadata['finish_reason'], 'end_turn');
    });

    test(
      'accepts Anthropic-compatible base endpoints by appending messages path',
      () async {
        final http = FakeModelProviderHttpClient(
          responses: <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'content': <Object?>[
                  <String, Object?>{'type': 'text', 'text': 'DeepSeek OK'},
                ],
              },
            ),
            ModelProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'content': <Object?>[
                  <String, Object?>{'type': 'text', 'text': 'MIMO OK'},
                ],
              },
            ),
            ModelProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'content': <Object?>[
                  <String, Object?>{'type': 'text', 'text': 'V1 OK'},
                ],
              },
            ),
          ],
        );
        final deepSeekProvider = AnthropicCompatibleModelProvider(
          config: _config(
            ModelProviderKind.anthropicCompatible,
            endpoint: Uri.parse('https://api.deepseek.com/anthropic'),
            model: 'deepseek-v4-flash',
          ),
          httpClient: http,
        );
        final mimoProvider = AnthropicCompatibleModelProvider(
          config: _config(
            ModelProviderKind.mimo,
            endpoint: Uri.parse(
              'https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages',
            ),
          ),
          httpClient: http,
        );
        final versionedProvider = AnthropicCompatibleModelProvider(
          config: _config(
            ModelProviderKind.anthropicCompatible,
            endpoint: Uri.parse('https://example.invalid/anthropic/v1'),
          ),
          httpClient: http,
        );

        expect(
          (await deepSeekProvider.complete(ModelRequest.text('hello'))).text,
          'DeepSeek OK',
        );
        expect(
          (await mimoProvider.complete(ModelRequest.text('hello'))).text,
          'MIMO OK',
        );
        expect(
          (await versionedProvider.complete(ModelRequest.text('hello'))).text,
          'V1 OK',
        );

        expect(
          http.requests[0].endpoint.toString(),
          'https://api.deepseek.com/anthropic/v1/messages',
        );
        expect(
          http.requests[1].endpoint.toString(),
          'https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages',
        );
        expect(
          http.requests[2].endpoint.toString(),
          'https://example.invalid/anthropic/v1/messages',
        );
        expect(http.requests[0].body['thinking'], <String, Object?>{
          'type': 'disabled',
        });
        expect(http.requests[1].body['thinking'], <String, Object?>{
          'type': 'disabled',
        });
        expect(http.requests[2].body.containsKey('thinking'), isFalse);
      },
    );

    test(
      'routes DeepSeek preset and legacy root endpoint through Anthropic messages',
      () async {
        final http = FakeModelProviderHttpClient(
          responses: <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'model': 'deepseek-v4-flash',
                'content': <Object?>[
                  <String, Object?>{'type': 'text', 'text': 'Preset OK'},
                ],
              },
            ),
            ModelProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'model': 'deepseek-v4-flash',
                'content': <Object?>[
                  <String, Object?>{'type': 'text', 'text': 'Legacy OK'},
                ],
              },
            ),
          ],
        );
        final presetProvider = AnthropicCompatibleModelProvider(
          config: ModelProviderConfig.preset(
            id: 'deepseek',
            kind: ModelProviderKind.deepSeek,
            apiKey: _runtimeCredential(),
          ),
          httpClient: http,
        );
        final legacyRootProvider = AnthropicCompatibleModelProvider(
          config: ModelProviderConfig.preset(
            id: 'deepseek-legacy',
            kind: ModelProviderKind.deepSeek,
            endpoint: Uri.parse('https://api.deepseek.com'),
            model: 'deepseek-v4-flash',
            apiKey: _runtimeCredential(),
          ),
          httpClient: http,
        );

        expect(
          (await presetProvider.complete(ModelRequest.text('hello'))).text,
          'Preset OK',
        );
        expect(
          (await legacyRootProvider.complete(ModelRequest.text('hello'))).text,
          'Legacy OK',
        );

        for (final request in http.requests) {
          expect(
            request.endpoint.toString(),
            'https://api.deepseek.com/anthropic/v1/messages',
          );
          expect(request.headers['x-api-key'], _runtimeCredential());
          expect(request.headers['authorization'], isNull);
          expect(request.headers['anthropic-version'], '2023-06-01');
          expect(request.body['model'], 'deepseek-v4-flash');
          expect(request.body['thinking'], <String, Object?>{
            'type': 'disabled',
          });
        }
      },
    );

    test(
      'uses Bearer authorization for MiniMax Anthropic-compatible API',
      () async {
        final http = FakeModelProviderHttpClient(
          responses: <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'content': <Object?>[
                  <String, Object?>{'type': 'text', 'text': 'MiniMax OK'},
                ],
              },
            ),
          ],
        );
        final provider = AnthropicCompatibleModelProvider(
          config: ModelProviderConfig.preset(
            id: 'minimax',
            kind: ModelProviderKind.miniMax,
            apiKey: _runtimeCredential(),
          ),
          httpClient: http,
        );

        final response = await provider.complete(ModelRequest.text('hello'));

        expect(response.text, 'MiniMax OK');
        expect(
          http.requests.single.endpoint.toString(),
          'https://api.minimax.io/anthropic/v1/messages',
        );
        expect(
          http.requests.single.headers['authorization'],
          startsWith('Bearer '),
        );
        expect(http.requests.single.headers.containsKey('x-api-key'), isFalse);
        expect(
          http.requests.single.redactedHeaders['authorization'],
          '<redacted>',
        );
      },
    );
  });

  group('modelProviderFromConfig', () {
    test(
      'routes OpenAI-compatible provider presets through OpenAI adapter',
      () {
        for (final kind in <ModelProviderKind>[
          ModelProviderKind.openAi,
          ModelProviderKind.gemini,
          ModelProviderKind.openRouter,
          ModelProviderKind.kimi,
          ModelProviderKind.qwen,
          ModelProviderKind.doubao,
          ModelProviderKind.zhipu,
          ModelProviderKind.ollama,
        ]) {
          final provider = modelProviderFromConfig(
            config: _config(kind),
            httpClient: FakeModelProviderHttpClient(),
          );

          expect(provider, isA<OpenAiCompatibleModelProvider>());
        }
      },
    );

    test(
      'routes Anthropic-compatible provider presets through Anthropic adapter',
      () {
        for (final kind in <ModelProviderKind>[
          ModelProviderKind.anthropic,
          ModelProviderKind.deepSeek,
          ModelProviderKind.miniMax,
          ModelProviderKind.mimo,
        ]) {
          final provider = modelProviderFromConfig(
            config: _config(kind),
            httpClient: FakeModelProviderHttpClient(),
          );

          expect(provider, isA<AnthropicCompatibleModelProvider>());
        }
      },
    );
  });
}

ModelProviderHttpResponse _openAiTextResponse(String text) {
  return ModelProviderHttpResponse(
    statusCode: 200,
    body: <String, Object?>{
      'choices': <Object?>[
        <String, Object?>{
          'message': <String, Object?>{'content': text},
        },
      ],
    },
  );
}

ModelProviderConfig _config(
  ModelProviderKind kind, {
  Uri? endpoint,
  String model = 'provider-chat',
}) {
  return ModelProviderConfig.preset(
    id: kind == ModelProviderKind.mimo ? 'mimo' : 'openai-compatible',
    kind: kind,
    endpoint:
        endpoint ??
        (kind.usesAnthropicMessages
            ? Uri.parse('https://example.invalid/v1/messages')
            : Uri.parse('https://example.invalid/v1/chat/completions')),
    model: model,
    apiKey: _runtimeCredential(),
  );
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
