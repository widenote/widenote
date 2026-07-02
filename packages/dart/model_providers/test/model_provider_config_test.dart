import 'package:test/test.dart';
import 'package:widenote_model_providers/model_providers.dart';

void main() {
  group('ModelProviderConfig', () {
    test('validates required provider setup fields', () {
      final config = ModelProviderConfig(
        id: ' ',
        kind: ModelProviderKind.openAiCompatible,
        displayName: '',
        endpoint: Uri.parse('file:///tmp/provider'),
        model: ' ',
      );

      final validation = config.validate();

      expect(validation.isValid, isFalse);
      expect(
        validation.issues,
        containsAll(<ModelProviderConfigIssue>{
          ModelProviderConfigIssue.missingProviderId,
          ModelProviderConfigIssue.missingDisplayName,
          ModelProviderConfigIssue.unsupportedEndpointScheme,
          ModelProviderConfigIssue.missingModel,
          ModelProviderConfigIssue.missingApiKey,
        }),
      );
    });

    test('safe JSON and toString do not expose credentials', () {
      final credential = _runtimeCredential();
      final config = ModelProviderConfig.preset(
        id: 'kimi-main',
        kind: ModelProviderKind.kimi,
        apiKey: credential,
      );

      final safeJson = config.toSafeJson();

      expect(safeJson['kind'], 'kimi');
      expect(safeJson['capabilities'], <String>['chat', 'completion']);
      expect(safeJson['has_api_key'], isTrue);
      expect(safeJson.containsKey('api_key'), isFalse);
      expect(safeJson.containsValue(credential), isFalse);
      expect(config.toString(), isNot(contains(credential)));
    });

    test('maps public provider and capability wire names with aliases', () {
      expect(modelProviderKindFromWireName('openai'), ModelProviderKind.openAi);
      expect(
        modelProviderKindFromWireName('openAiCompatible'),
        ModelProviderKind.openAiCompatible,
      );
      expect(
        modelProviderKindFromWireName('deep_seek'),
        ModelProviderKind.deepSeek,
      );
      expect(
        modelProviderKindFromWireName('miniMax'),
        ModelProviderKind.miniMax,
      );
      expect(ModelProviderKind.openAiCompatible.wireName, 'openai_compatible');
      expect(ModelProviderKind.miniMax.wireName, 'minimax');

      expect(modelCapabilityFromWireName('tool_use'), ModelCapability.toolUse);
      expect(modelCapabilityFromWireName('toolUse'), ModelCapability.toolUse);
      expect(ModelCapability.toolUse.wireName, 'tool_use');
    });

    test('presets choose compatibility endpoints and models', () {
      final gemini = ModelProviderConfig.preset(
        id: 'gemini',
        kind: ModelProviderKind.gemini,
      );
      final deepSeek = ModelProviderConfig.preset(
        id: 'deepseek',
        kind: ModelProviderKind.deepSeek,
      );
      final mimo = ModelProviderConfig.preset(
        id: 'mimo',
        kind: ModelProviderKind.mimo,
      );
      final kimi = ModelProviderConfig.preset(
        id: 'kimi',
        kind: ModelProviderKind.kimi,
      );

      expect(gemini.kind.usesAnthropicMessages, isFalse);
      expect(gemini.endpoint.path, contains('/openai'));
      expect(gemini.model, 'gemini-3.5-flash');
      expect(deepSeek.kind.usesAnthropicMessages, isTrue);
      expect(deepSeek.endpoint.host, 'api.deepseek.com');
      expect(deepSeek.endpoint.path, '/anthropic');
      expect(deepSeek.model, 'deepseek-v4-flash');
      expect(mimo.kind.usesAnthropicMessages, isTrue);
      expect(mimo.endpoint.path, contains('/anthropic/'));
      expect(mimo.model, isNotEmpty);
      expect(kimi.kind.usesAnthropicMessages, isFalse);
      expect(kimi.endpoint.path, '/v1');
      expect(kimi.model, isNotEmpty);
    });

    test('does not require a key for local Ollama presets', () {
      final config = ModelProviderConfig.preset(
        id: 'ollama',
        kind: ModelProviderKind.ollama,
      );

      final validation = config.validate();

      expect(config.kind.requiresApiKey, isFalse);
      expect(validation.isValid, isTrue);
      expect(config.endpoint.scheme, 'http');
    });
  });
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
