import 'package:test/test.dart';
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  group('OfflineModelProviderModelListService', () {
    test('returns local model defaults without network access', () async {
      final service = OfflineModelProviderModelListService();

      final result = await service.listModels(
        ModelProviderConfig.preset(
          id: 'openai',
          kind: ModelProviderKind.openAi,
          model: 'team-chat',
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.models, containsAll(<String>['team-chat', 'gpt-4.1-mini']));
    });
  });

  group('AdapterModelProviderModelListService', () {
    test('fetches OpenAI-compatible models from base endpoint', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          _openAiModelsResponse(<String>['gpt-4.1-mini', 'gpt-5']),
        ],
      );
      final service = AdapterModelProviderModelListService(httpClient: http);

      final result = await service.listModels(
        ModelProviderConfig.preset(
          id: 'openai',
          kind: ModelProviderKind.openAi,
          apiKey: _runtimeCredential(),
        ),
      );

      expect(result.succeeded, isTrue);
      expect(result.models, <String>['gpt-4.1-mini', 'gpt-5']);
      expect(http.requests.single.method, 'GET');
      expect(
        http.requests.single.endpoint.toString(),
        'https://api.openai.com/v1/models',
      );
      expect(
        http.requests.single.headers['authorization'],
        startsWith('Bearer'),
      );
    });

    test('derives DeepSeek Anthropic models endpoints', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          _openAiModelsResponse(<String>['deepseek-v4-flash']),
          _openAiModelsResponse(<String>['deepseek-v4-flash']),
        ],
      );
      final service = AdapterModelProviderModelListService(httpClient: http);

      final result = await service.listModels(
        ModelProviderConfig.preset(
          id: 'deepseek',
          kind: ModelProviderKind.deepSeek,
          apiKey: _runtimeCredential(),
        ),
      );
      final legacyRootResult = await service.listModels(
        ModelProviderConfig.preset(
          id: 'deepseek-legacy',
          kind: ModelProviderKind.deepSeek,
          endpoint: Uri.parse('https://api.deepseek.com'),
          apiKey: _runtimeCredential(),
        ),
      );

      expect(result.models, <String>['deepseek-v4-flash']);
      expect(legacyRootResult.models, <String>['deepseek-v4-flash']);
      expect(
        http.requests[0].endpoint.toString(),
        'https://api.deepseek.com/anthropic/v1/models',
      );
      expect(
        http.requests[1].endpoint.toString(),
        'https://api.deepseek.com/anthropic/v1/models',
      );
      expect(
        http.requests[0].headers['authorization'],
        'Bearer ${_runtimeCredential()}',
      );
      expect(http.requests[0].headers.containsKey('x-api-key'), isFalse);
      expect(http.requests[0].headers['anthropic-version'], '2023-06-01');
    });

    test('fetches Gemini models through native list endpoint', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          ModelProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'models': <Object?>[
                <String, Object?>{
                  'name': 'models/gemini-3.5-flash',
                  'supportedGenerationMethods': <Object?>['generateContent'],
                },
                <String, Object?>{
                  'baseModelId': 'gemini-embedding-001',
                  'supportedGenerationMethods': <Object?>['embedContent'],
                },
              ],
            },
          ),
        ],
      );
      final service = AdapterModelProviderModelListService(httpClient: http);

      final result = await service.listModels(
        ModelProviderConfig.preset(
          id: 'gemini',
          kind: ModelProviderKind.gemini,
          apiKey: _runtimeCredential(),
        ),
      );

      expect(result.models, <String>['gemini-3.5-flash']);
      expect(
        http.requests.single.endpoint.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models?key=credential',
      );
      expect(
        http.requests.single.redactedEndpoint.queryParameters['key'],
        '<redacted>',
      );
      expect(http.requests.single.toString(), isNot(contains('credential')));
      expect(
        http.requests.single.headers.containsKey('authorization'),
        isFalse,
      );
    });

    test('fetches Anthropic-compatible models with provider headers', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          _openAiModelsResponse(<String>['claude-sonnet-5']),
          _openAiModelsResponse(<String>['MiniMax-M3']),
        ],
      );
      final service = AdapterModelProviderModelListService(httpClient: http);

      final anthropic = await service.listModels(
        ModelProviderConfig.preset(
          id: 'anthropic',
          kind: ModelProviderKind.anthropic,
          apiKey: _runtimeCredential(),
        ),
      );
      final miniMax = await service.listModels(
        ModelProviderConfig.preset(
          id: 'minimax',
          kind: ModelProviderKind.miniMax,
          apiKey: _runtimeCredential(),
        ),
      );

      expect(anthropic.models, <String>['claude-sonnet-5']);
      expect(
        http.requests[0].endpoint.toString(),
        'https://api.anthropic.com/v1/models',
      );
      expect(http.requests[0].headers['x-api-key'], _runtimeCredential());
      expect(http.requests[0].headers['anthropic-version'], '2023-06-01');
      expect(miniMax.models, <String>['MiniMax-M3']);
      expect(
        http.requests[1].endpoint.toString(),
        'https://api.minimax.io/anthropic/v1/models',
      );
      expect(http.requests[1].headers['X-Api-Key'], _runtimeCredential());
    });

    test(
      'fetches Responses and MIMO Token Plan models with official headers',
      () async {
        final http = FakeModelProviderHttpClient(
          responses: <ModelProviderHttpResponse>[
            _openAiModelsResponse(<String>['gpt-4.1-mini']),
            _openAiModelsResponse(<String>['mimo-v2.5-pro']),
            _openAiModelsResponse(<String>['mimo-v2.5-pro']),
          ],
        );
        final service = AdapterModelProviderModelListService(httpClient: http);

        final responses = await service.listModels(
          ModelProviderConfig.preset(
            id: 'openai-responses',
            kind: ModelProviderKind.openAiResponses,
            endpoint: Uri.parse('https://api.openai.com/v1/responses'),
            apiKey: _runtimeCredential(),
          ),
        );
        final mimoOpenAi = await service.listModels(
          ModelProviderConfig.preset(
            id: 'mimo-openai',
            kind: ModelProviderKind.openAiCompatible,
            endpoint: Uri.parse('https://token-plan-cn.xiaomimimo.com/v1'),
            model: 'mimo-v2.5-pro',
            apiKey: _runtimeCredential(),
            accessMode: ModelProviderAccessMode.tokenPlan,
          ),
        );
        final mimoAnthropic = await service.listModels(
          ModelProviderConfig.preset(
            id: 'mimo-anthropic',
            kind: ModelProviderKind.mimo,
            endpoint: Uri.parse(
              'https://token-plan-cn.xiaomimimo.com/anthropic',
            ),
            apiKey: _runtimeCredential(),
            accessMode: ModelProviderAccessMode.tokenPlan,
          ),
        );

        expect(responses.models, <String>['gpt-4.1-mini']);
        expect(mimoOpenAi.models, <String>['mimo-v2.5-pro']);
        expect(mimoAnthropic.models, <String>['mimo-v2.5-pro']);
        expect(
          http.requests[0].endpoint.toString(),
          'https://api.openai.com/v1/models',
        );
        expect(
          http.requests[1].endpoint.toString(),
          'https://token-plan-cn.xiaomimimo.com/v1/models',
        );
        expect(http.requests[1].headers['api-key'], _runtimeCredential());
        expect(
          http.requests[2].endpoint.toString(),
          'https://token-plan-cn.xiaomimimo.com/anthropic/v1/models',
        );
        expect(http.requests[2].headers['api-key'], _runtimeCredential());
      },
    );

    test('allows no-key local model listing', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          _openAiModelsResponse(<String>['llama3.1:8b', 'qwen2.5:7b']),
        ],
      );
      final service = AdapterModelProviderModelListService(httpClient: http);

      final result = await service.listModels(
        ModelProviderConfig.preset(
          id: 'ollama',
          kind: ModelProviderKind.ollama,
        ),
      );

      expect(result.models, <String>['llama3.1:8b', 'qwen2.5:7b']);
      expect(
        http.requests.single.endpoint.toString(),
        'http://localhost:11434/v1/models',
      );
      expect(
        http.requests.single.headers.containsKey('authorization'),
        isFalse,
      );
    });

    test('classifies status and missing key failures', () async {
      final missingKey =
          await AdapterModelProviderModelListService(
            httpClient: FakeModelProviderHttpClient(),
          ).listModels(
            ModelProviderConfig.preset(
              id: 'kimi',
              kind: ModelProviderKind.kimi,
            ),
          );

      expect(missingKey.succeeded, isFalse);
      expect(missingKey.errorKind, ModelProviderErrorKind.authentication);

      final http = FakeModelProviderHttpClient(
        responses: const <ModelProviderHttpResponse>[
          ModelProviderHttpResponse(statusCode: 429, body: null),
        ],
      );
      final result =
          await AdapterModelProviderModelListService(
            httpClient: http,
          ).listModels(
            ModelProviderConfig.preset(
              id: 'openrouter',
              kind: ModelProviderKind.openRouter,
              apiKey: _runtimeCredential(),
            ),
          );

      expect(result.succeeded, isFalse);
      expect(result.errorKind, ModelProviderErrorKind.rateLimited);
      expect(result.statusCode, 429);
    });
  });
}

ModelProviderHttpResponse _openAiModelsResponse(List<String> ids) {
  return ModelProviderHttpResponse(
    statusCode: 200,
    body: <String, Object?>{
      'data': <Object?>[
        for (final id in ids) <String, Object?>{'id': id},
      ],
    },
  );
}

String _runtimeCredential() => 'credential';
