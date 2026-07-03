import 'package:test/test.dart';
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  group('OpenAiCompatibleEmbeddingProvider', () {
    test(
      'uses OpenRouter Qwen embedding defaults and parses vectors',
      () async {
        final http = FakeModelProviderHttpClient(
          responses: <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(
              statusCode: 200,
              body: <String, Object?>{
                'model': 'qwen/qwen3-embedding-0.6b',
                'data': <Object?>[
                  <String, Object?>{
                    'index': 0,
                    'embedding': <Object?>[0.1, 0.2, 0.3],
                  },
                  <String, Object?>{
                    'index': 1,
                    'embedding': <Object?>[0.4, 0.5, 0.6],
                  },
                ],
                'usage': <String, Object?>{'prompt_tokens': 12},
              },
            ),
          ],
        );
        final config = EmbeddingProviderConfig.preset(
          id: 'embedding.openrouter',
          apiKey: 'credential',
        );
        final provider = embeddingProviderFromConfig(
          config: config,
          httpClient: http,
        );

        final response = await provider.embed(
          const EmbeddingRequest(input: <String>['alpha', 'beta']),
        );

        expect(config.kind, EmbeddingProviderKind.openRouter);
        expect(config.model, 'qwen/qwen3-embedding-0.6b');
        expect(response.embeddings, <List<double>>[
          <double>[0.1, 0.2, 0.3],
          <double>[0.4, 0.5, 0.6],
        ]);
        expect(response.usage.inputTokens, 12);
        expect(
          http.requests.single.endpoint.toString(),
          'https://openrouter.ai/api/v1/embeddings',
        );
        expect(
          http.requests.single.headers['authorization'],
          'Bearer credential',
        );
        expect(http.requests.single.body['model'], 'qwen/qwen3-embedding-0.6b');
        expect(http.requests.single.body['input'], <String>['alpha', 'beta']);
        expect(http.requests.single.toString(), isNot(contains('credential')));
      },
    );

    test('classifies malformed embedding responses', () async {
      final http = FakeModelProviderHttpClient(
        responses: const <ModelProviderHttpResponse>[
          ModelProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{'data': <Object?>[]},
          ),
        ],
      );
      final provider = OpenAiCompatibleEmbeddingProvider(
        config: EmbeddingProviderConfig.preset(
          id: 'embedding.openrouter',
          apiKey: 'credential',
        ),
        httpClient: http,
      );

      await expectLater(
        provider.embed(const EmbeddingRequest(input: <String>['alpha'])),
        throwsA(
          isA<ModelProviderException>().having(
            (error) => error.kind,
            'kind',
            ModelProviderErrorKind.malformedResponse,
          ),
        ),
      );
    });
  });
}
