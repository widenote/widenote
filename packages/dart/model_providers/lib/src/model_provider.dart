enum ModelCapability {
  chat,
  completion,
  embedding,
  vision,
  audio,
  streaming,
  toolUse,
}

extension ModelCapabilityWireName on ModelCapability {
  String get wireName {
    return switch (this) {
      ModelCapability.chat => 'chat',
      ModelCapability.completion => 'completion',
      ModelCapability.embedding => 'embedding',
      ModelCapability.vision => 'vision',
      ModelCapability.audio => 'audio',
      ModelCapability.streaming => 'streaming',
      ModelCapability.toolUse => 'tool_use',
    };
  }
}

ModelCapability modelCapabilityFromWireName(String value) {
  final normalized = value.replaceAll('-', '_');
  return switch (normalized) {
    'chat' => ModelCapability.chat,
    'completion' => ModelCapability.completion,
    'embedding' => ModelCapability.embedding,
    'vision' => ModelCapability.vision,
    'audio' => ModelCapability.audio,
    'streaming' => ModelCapability.streaming,
    'tool_use' || 'toolUse' => ModelCapability.toolUse,
    _ => throw StateError('Unknown model capability: $value'),
  };
}

enum ModelMessageRole { system, user, assistant, tool }

final class ModelMessage {
  const ModelMessage({required this.role, required this.content});

  final ModelMessageRole role;
  final String content;
}

final class ModelRequest {
  const ModelRequest({
    required this.messages,
    this.model,
    this.requiredCapabilities = const {},
    this.metadata = const {},
  });

  factory ModelRequest.text(
    String prompt, {
    String? model,
    Set<ModelCapability> requiredCapabilities = const {},
    Map<String, Object?> metadata = const {},
  }) {
    return ModelRequest(
      model: model,
      requiredCapabilities: requiredCapabilities,
      metadata: metadata,
      messages: [ModelMessage(role: ModelMessageRole.user, content: prompt)],
    );
  }

  final List<ModelMessage> messages;
  final String? model;
  final Set<ModelCapability> requiredCapabilities;
  final Map<String, Object?> metadata;

  String get promptText {
    return messages.map((message) => message.content).join('\n');
  }
}

final class ModelUsage {
  const ModelUsage({this.inputTokens = 0, this.outputTokens = 0});

  final int inputTokens;
  final int outputTokens;

  int get totalTokens => inputTokens + outputTokens;
}

final class ModelResponse {
  const ModelResponse({
    required this.providerId,
    required this.model,
    required this.text,
    this.usage = const ModelUsage(),
    this.metadata = const {},
  });

  final String providerId;
  final String model;
  final String text;
  final ModelUsage usage;
  final Map<String, Object?> metadata;
}

abstract interface class ModelProvider {
  String get id;

  String get displayName;

  Set<ModelCapability> get capabilities;

  bool supports(ModelCapability capability) {
    return capabilities.contains(capability);
  }

  Future<ModelResponse> complete(ModelRequest request);
}

final class UnsupportedModelCapabilityException implements Exception {
  const UnsupportedModelCapabilityException({
    required this.providerId,
    required this.missingCapabilities,
  });

  final String providerId;
  final Set<ModelCapability> missingCapabilities;

  @override
  String toString() {
    return 'Provider $providerId does not support $missingCapabilities.';
  }
}
