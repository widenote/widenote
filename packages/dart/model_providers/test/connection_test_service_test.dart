import 'dart:async';

import 'package:test/test.dart';
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  group('OfflineModelProviderConnectionTestService', () {
    test('validates config without sending a live request', () async {
      const service = OfflineModelProviderConnectionTestService();

      final result = await service.test(_config(ModelProviderKind.kimi));

      expect(result.succeeded, isTrue);
      expect(result.usedLiveAdapter, isFalse);
      expect(result.message, contains('Kimi validated offline'));
    });

    test('classifies incomplete config before a live request', () async {
      const service = OfflineModelProviderConnectionTestService();

      final result = await service.test(
        _config(ModelProviderKind.openAiCompatible).copyWith(apiKey: ''),
      );

      expect(result.succeeded, isFalse);
      expect(result.usedLiveAdapter, isFalse);
      expect(result.errorKind, ModelProviderErrorKind.invalidConfiguration);
      expect(result.message, contains('missingApiKey'));
    });
  });

  group('AdapterModelProviderConnectionTestService', () {
    test('sends an OpenAI-compatible probe through injected HTTP', () async {
      final http = FakeModelProviderHttpClient(
        responses: <ModelProviderHttpResponse>[
          ModelProviderHttpResponse(
            statusCode: 200,
            body: <String, Object?>{
              'model': 'probe-model',
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{'content': 'OK'},
                },
              ],
            },
          ),
        ],
      );
      final service = AdapterModelProviderConnectionTestService(
        httpClient: http,
      );

      final result = await service.test(
        _config(ModelProviderKind.openAiCompatible),
      );

      expect(result.succeeded, isTrue);
      expect(result.usedLiveAdapter, isTrue);
      expect(result.message, 'OpenAI-compatible connection test succeeded.');
      expect(http.requests.single.body['metadata'], <String, Object?>{
        'widenote_connection_test': true,
      });
    });

    test('classifies Kimi authentication failures', () async {
      final service = AdapterModelProviderConnectionTestService(
        httpClient: FakeModelProviderHttpClient(
          responses: const <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(statusCode: 401, body: null),
          ],
        ),
      );

      final result = await service.test(_config(ModelProviderKind.kimi));

      expect(result.succeeded, isFalse);
      expect(result.usedLiveAdapter, isTrue);
      expect(result.errorKind, ModelProviderErrorKind.authentication);
      expect(result.message, contains('Kimi authentication failed'));
      expect(result.message, contains('HTTP 401'));
    });

    test('classifies MIMO rate-limit failures', () async {
      final service = AdapterModelProviderConnectionTestService(
        httpClient: FakeModelProviderHttpClient(
          responses: const <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(statusCode: 429, body: null),
          ],
        ),
      );

      final result = await service.test(_config(ModelProviderKind.mimo));

      expect(result.succeeded, isFalse);
      expect(result.errorKind, ModelProviderErrorKind.rateLimited);
      expect(result.message, contains('Xiaomi MIMO is rate limited'));
    });

    test('classifies Anthropic-compatible server failures', () async {
      final service = AdapterModelProviderConnectionTestService(
        httpClient: FakeModelProviderHttpClient(
          responses: const <ModelProviderHttpResponse>[
            ModelProviderHttpResponse(statusCode: 503, body: null),
          ],
        ),
      );

      final result = await service.test(
        _config(ModelProviderKind.anthropicCompatible),
      );

      expect(result.succeeded, isFalse);
      expect(result.errorKind, ModelProviderErrorKind.server);
      expect(
        result.message,
        contains('Anthropic-compatible provider returned a server error'),
      );
    });

    test(
      'classifies OpenAI-compatible timeout and response failures',
      () async {
        final timeoutService = AdapterModelProviderConnectionTestService(
          httpClient: FakeModelProviderHttpClient()
            ..enqueueError(TimeoutException('slow')),
        );

        final timeout = await timeoutService.test(
          _config(ModelProviderKind.openAiCompatible),
        );

        expect(timeout.succeeded, isFalse);
        expect(timeout.errorKind, ModelProviderErrorKind.timeout);
        expect(
          timeout.message,
          contains('OpenAI-compatible connection timed out'),
        );

        final missingTextService = AdapterModelProviderConnectionTestService(
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

        final missingText = await missingTextService.test(
          _config(ModelProviderKind.openAiCompatible),
        );

        expect(missingText.succeeded, isFalse);
        expect(missingText.errorKind, ModelProviderErrorKind.missingText);
        expect(missingText.message, contains('responded without usable text'));
      },
    );
  });
}

ModelProviderConfig _config(ModelProviderKind kind) {
  return ModelProviderConfig.preset(
    id: kind.name,
    kind: kind,
    endpoint: kind.usesAnthropicMessages
        ? Uri.parse('https://example.invalid/v1/messages')
        : Uri.parse('https://example.invalid/v1/chat/completions'),
    model: 'provider-chat',
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
