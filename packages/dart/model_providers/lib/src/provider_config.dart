import 'model_provider.dart';

enum ModelProviderKind {
  openAi,
  anthropic,
  gemini,
  openRouter,
  deepSeek,
  kimi,
  qwen,
  doubao,
  zhipu,
  miniMax,
  mimo,
  ollama,
  openAiCompatible,
  anthropicCompatible,
}

enum ModelProviderConfigIssue {
  missingProviderId,
  missingDisplayName,
  missingEndpoint,
  unsupportedEndpointScheme,
  missingModel,
  missingApiKey,
}

ModelProviderKind modelProviderKindFromWireName(String value) {
  final normalized = value.replaceAll('-', '_');
  return switch (normalized) {
    'openai' || 'open_ai' || 'openAi' => ModelProviderKind.openAi,
    'anthropic' => ModelProviderKind.anthropic,
    'gemini' => ModelProviderKind.gemini,
    'openrouter' ||
    'open_router' ||
    'openRouter' => ModelProviderKind.openRouter,
    'deepseek' || 'deep_seek' || 'deepSeek' => ModelProviderKind.deepSeek,
    'kimi' => ModelProviderKind.kimi,
    'qwen' => ModelProviderKind.qwen,
    'doubao' => ModelProviderKind.doubao,
    'zhipu' => ModelProviderKind.zhipu,
    'minimax' || 'mini_max' || 'miniMax' => ModelProviderKind.miniMax,
    'mimo' => ModelProviderKind.mimo,
    'ollama' => ModelProviderKind.ollama,
    'openai_compatible' ||
    'open_ai_compatible' ||
    'openAiCompatible' => ModelProviderKind.openAiCompatible,
    'anthropic_compatible' ||
    'anthropicCompatible' => ModelProviderKind.anthropicCompatible,
    _ => throw StateError('Unknown model provider kind: $value'),
  };
}

extension ModelProviderKindDetails on ModelProviderKind {
  String get wireName {
    return switch (this) {
      ModelProviderKind.openAi => 'openai',
      ModelProviderKind.anthropic => 'anthropic',
      ModelProviderKind.gemini => 'gemini',
      ModelProviderKind.openRouter => 'openrouter',
      ModelProviderKind.deepSeek => 'deepseek',
      ModelProviderKind.kimi => 'kimi',
      ModelProviderKind.qwen => 'qwen',
      ModelProviderKind.doubao => 'doubao',
      ModelProviderKind.zhipu => 'zhipu',
      ModelProviderKind.miniMax => 'minimax',
      ModelProviderKind.mimo => 'mimo',
      ModelProviderKind.ollama => 'ollama',
      ModelProviderKind.openAiCompatible => 'openai_compatible',
      ModelProviderKind.anthropicCompatible => 'anthropic_compatible',
    };
  }

  String get label {
    return switch (this) {
      ModelProviderKind.openAiCompatible => 'OpenAI-compatible',
      ModelProviderKind.openAi => 'OpenAI',
      ModelProviderKind.anthropicCompatible => 'Anthropic-compatible',
      ModelProviderKind.anthropic => 'Anthropic Claude',
      ModelProviderKind.gemini => 'Google Gemini',
      ModelProviderKind.openRouter => 'OpenRouter',
      ModelProviderKind.deepSeek => 'DeepSeek',
      ModelProviderKind.qwen => 'Alibaba Qwen',
      ModelProviderKind.doubao => 'Volcengine Doubao',
      ModelProviderKind.zhipu => 'Zhipu GLM',
      ModelProviderKind.miniMax => 'MiniMax',
      ModelProviderKind.mimo => 'Xiaomi MIMO',
      ModelProviderKind.kimi => 'Kimi',
      ModelProviderKind.ollama => 'Ollama',
    };
  }

  Uri get defaultEndpoint {
    return switch (this) {
      ModelProviderKind.openAi => Uri.parse('https://api.openai.com/v1'),
      ModelProviderKind.openAiCompatible => Uri.parse(
        'https://api.openai.com/v1/chat/completions',
      ),
      ModelProviderKind.anthropic => Uri.parse('https://api.anthropic.com'),
      ModelProviderKind.anthropicCompatible => Uri.parse(
        'https://api.anthropic.com/v1/messages',
      ),
      ModelProviderKind.gemini => Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/openai',
      ),
      ModelProviderKind.openRouter => Uri.parse('https://openrouter.ai/api/v1'),
      ModelProviderKind.deepSeek => Uri.parse('https://api.deepseek.com'),
      ModelProviderKind.mimo => Uri.parse(
        'https://token-plan-sgp.xiaomimimo.com/anthropic/v1/messages',
      ),
      ModelProviderKind.kimi => Uri.parse('https://api.moonshot.ai/v1'),
      ModelProviderKind.qwen => Uri.parse(
        'https://dashscope.aliyuncs.com/compatible-mode/v1',
      ),
      ModelProviderKind.doubao => Uri.parse(
        'https://ark.cn-beijing.volces.com/api/v3',
      ),
      ModelProviderKind.zhipu => Uri.parse('https://api.z.ai/api/paas/v4'),
      ModelProviderKind.miniMax => Uri.parse(
        'https://api.minimax.io/anthropic',
      ),
      ModelProviderKind.ollama => Uri.parse('http://localhost:11434/v1'),
    };
  }

  String get defaultModel {
    return switch (this) {
      ModelProviderKind.openAi => 'gpt-4.1-mini',
      ModelProviderKind.openAiCompatible => 'openai-compatible-chat',
      ModelProviderKind.anthropic => 'claude-sonnet-5',
      ModelProviderKind.anthropicCompatible => 'anthropic-compatible-chat',
      ModelProviderKind.gemini => 'gemini-3.5-flash',
      ModelProviderKind.openRouter => 'openrouter/auto',
      ModelProviderKind.deepSeek => 'deepseek-v4-pro',
      ModelProviderKind.mimo => 'mimo-v2.5-pro',
      ModelProviderKind.kimi => 'kimi-k2.6',
      ModelProviderKind.qwen => 'qwen-plus',
      ModelProviderKind.doubao => 'doubao-seed-2-0-lite-260428',
      ModelProviderKind.zhipu => 'glm-5.2',
      ModelProviderKind.miniMax => 'MiniMax-M3',
      ModelProviderKind.ollama => 'qwen2.5:7b',
    };
  }

  bool get usesAnthropicMessages {
    return switch (this) {
      ModelProviderKind.anthropic ||
      ModelProviderKind.anthropicCompatible ||
      ModelProviderKind.miniMax ||
      ModelProviderKind.mimo => true,
      ModelProviderKind.openAi ||
      ModelProviderKind.openAiCompatible ||
      ModelProviderKind.gemini ||
      ModelProviderKind.openRouter ||
      ModelProviderKind.deepSeek ||
      ModelProviderKind.kimi ||
      ModelProviderKind.qwen ||
      ModelProviderKind.doubao ||
      ModelProviderKind.zhipu ||
      ModelProviderKind.ollama => false,
    };
  }

  bool get requiresApiKey {
    return switch (this) {
      ModelProviderKind.ollama => false,
      _ => true,
    };
  }

  bool get usesAnthropicBearerAuthorization {
    return switch (this) {
      ModelProviderKind.miniMax => true,
      _ => false,
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
    if (requireApiKey && kind.requiresApiKey && apiKey.trim().isEmpty) {
      issues.add(ModelProviderConfigIssue.missingApiKey);
    }
    return ModelProviderConfigValidation(issues: Set.unmodifiable(issues));
  }

  Map<String, Object?> toSafeJson() {
    return <String, Object?>{
      'id': id,
      'kind': kind.wireName,
      'display_name': displayName,
      'endpoint': endpoint.toString(),
      'model': model,
      'max_output_tokens': maxOutputTokens,
      'capabilities': capabilities
          .map((capability) => capability.wireName)
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
