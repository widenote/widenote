import 'model_provider.dart';

enum ModelProviderKind { openAiCompatible, anthropicCompatible, mimo, kimi }

enum ModelProviderConfigIssue {
  missingProviderId,
  missingDisplayName,
  missingEndpoint,
  unsupportedEndpointScheme,
  missingModel,
  missingApiKey,
}

extension ModelProviderKindDetails on ModelProviderKind {
  String get label {
    return switch (this) {
      ModelProviderKind.openAiCompatible => 'OpenAI-compatible',
      ModelProviderKind.anthropicCompatible => 'Anthropic-compatible',
      ModelProviderKind.mimo => 'Xiaomi MIMO',
      ModelProviderKind.kimi => 'Kimi',
    };
  }

  Uri get defaultEndpoint {
    return switch (this) {
      ModelProviderKind.openAiCompatible => Uri.parse(
        'https://api.openai.com/v1/chat/completions',
      ),
      ModelProviderKind.anthropicCompatible => Uri.parse(
        'https://api.anthropic.com/v1/messages',
      ),
      ModelProviderKind.mimo => Uri.parse(
        'https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages',
      ),
      ModelProviderKind.kimi => Uri.parse(
        'https://api.moonshot.cn/v1/chat/completions',
      ),
    };
  }

  String get defaultModel {
    return switch (this) {
      ModelProviderKind.openAiCompatible => 'openai-compatible-chat',
      ModelProviderKind.anthropicCompatible => 'anthropic-compatible-chat',
      ModelProviderKind.mimo => 'mimo-v2.5-pro',
      ModelProviderKind.kimi => 'moonshot-v1-8k',
    };
  }

  bool get usesAnthropicMessages {
    return switch (this) {
      ModelProviderKind.anthropicCompatible || ModelProviderKind.mimo => true,
      ModelProviderKind.openAiCompatible || ModelProviderKind.kimi => false,
    };
  }
}

final class ModelProviderConfig {
  const ModelProviderConfig({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.endpoint,
    required this.model,
    this.apiKey = '',
    this.maxOutputTokens = 1024,
    this.capabilities = const <ModelCapability>{
      ModelCapability.chat,
      ModelCapability.completion,
    },
  });

  factory ModelProviderConfig.preset({
    required String id,
    required ModelProviderKind kind,
    String? displayName,
    Uri? endpoint,
    String? model,
    String apiKey = '',
    int maxOutputTokens = 1024,
  }) {
    return ModelProviderConfig(
      id: id,
      kind: kind,
      displayName: displayName ?? kind.label,
      endpoint: endpoint ?? kind.defaultEndpoint,
      model: model ?? kind.defaultModel,
      apiKey: apiKey,
      maxOutputTokens: maxOutputTokens,
    );
  }

  final String id;
  final ModelProviderKind kind;
  final String displayName;
  final Uri endpoint;
  final String model;
  final String apiKey;
  final int maxOutputTokens;
  final Set<ModelCapability> capabilities;

  ModelProviderConfig copyWith({
    String? id,
    ModelProviderKind? kind,
    String? displayName,
    Uri? endpoint,
    String? model,
    String? apiKey,
    int? maxOutputTokens,
    Set<ModelCapability>? capabilities,
  }) {
    return ModelProviderConfig(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      displayName: displayName ?? this.displayName,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      capabilities: capabilities ?? this.capabilities,
    );
  }

  ModelProviderConfigValidation validate({bool requireApiKey = true}) {
    final issues = <ModelProviderConfigIssue>[];
    if (id.trim().isEmpty) {
      issues.add(ModelProviderConfigIssue.missingProviderId);
    }
    if (displayName.trim().isEmpty) {
      issues.add(ModelProviderConfigIssue.missingDisplayName);
    }
    if (endpoint.toString().trim().isEmpty) {
      issues.add(ModelProviderConfigIssue.missingEndpoint);
    } else if (endpoint.scheme != 'https' && endpoint.scheme != 'http') {
      issues.add(ModelProviderConfigIssue.unsupportedEndpointScheme);
    }
    if (model.trim().isEmpty) {
      issues.add(ModelProviderConfigIssue.missingModel);
    }
    if (requireApiKey && apiKey.trim().isEmpty) {
      issues.add(ModelProviderConfigIssue.missingApiKey);
    }
    return ModelProviderConfigValidation(issues: Set.unmodifiable(issues));
  }

  Map<String, Object?> toSafeJson() {
    return <String, Object?>{
      'id': id,
      'kind': kind.name,
      'display_name': displayName,
      'endpoint': endpoint.toString(),
      'model': model,
      'max_output_tokens': maxOutputTokens,
      'capabilities': capabilities
          .map((capability) => capability.name)
          .toList(),
      'has_api_key': apiKey.trim().isNotEmpty,
    };
  }

  @override
  String toString() {
    return 'ModelProviderConfig(${toSafeJson()})';
  }
}

final class ModelProviderConfigValidation {
  const ModelProviderConfigValidation({required this.issues});

  final Set<ModelProviderConfigIssue> issues;

  bool get isValid => issues.isEmpty;

  String get summary {
    if (isValid) {
      return 'valid';
    }
    return issues.map((issue) => issue.name).join(', ');
  }
}
