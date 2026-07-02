enum ModelCapability {
  chat,
  completion,
  embedding,
  vision,
  audio,
  video,
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
      ModelCapability.video => 'video',
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
    'video' => ModelCapability.video,
    'streaming' => ModelCapability.streaming,
    'tool_use' || 'toolUse' => ModelCapability.toolUse,
    _ => throw StateError('Unknown model capability: $value'),
  };
}

enum ModelMessageRole { system, user, assistant, tool }

enum ModelContentPartKind { text, inlineImage }

final class ModelContentPart {
  const ModelContentPart.text(String text)
    : kind = ModelContentPartKind.text,
      text = text,
      mimeType = null,
      dataBase64 = null,
      sourceRef = const <String, Object?>{};

  const ModelContentPart.inlineImage({
    required String mimeType,
    required String dataBase64,
    Map<String, Object?> sourceRef = const <String, Object?>{},
  }) : kind = ModelContentPartKind.inlineImage,
       text = null,
       mimeType = mimeType,
       dataBase64 = dataBase64,
       sourceRef = sourceRef;

  final ModelContentPartKind kind;
  final String? text;
  final String? mimeType;
  final String? dataBase64;
  final Map<String, Object?> sourceRef;
}

final class ModelMessage {
  const ModelMessage({
    required this.role,
    required this.content,
    this.parts = const <ModelContentPart>[],
  });

  final ModelMessageRole role;
  final String content;
  final List<ModelContentPart> parts;

  bool get hasStructuredContent => parts.isNotEmpty;

  List<ModelContentPart> get contentParts {
    if (parts.isNotEmpty) {
      return parts;
    }
    return <ModelContentPart>[ModelContentPart.text(content)];
  }
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

  factory ModelRequest.multimodal(
    String prompt, {
    required List<ModelContentPart> parts,
    String? model,
    Set<ModelCapability> requiredCapabilities = const {},
    Map<String, Object?> metadata = const {},
  }) {
    final allParts = <ModelContentPart>[
      ModelContentPart.text(prompt),
      ...parts,
    ];
    final capabilities = <ModelCapability>{
      ModelCapability.completion,
      ...requiredCapabilities,
      if (parts.any((part) => part.kind == ModelContentPartKind.inlineImage))
        ModelCapability.vision,
    };
    return ModelRequest(
      model: model,
      requiredCapabilities: capabilities,
      metadata: metadata,
      messages: [
        ModelMessage(
          role: ModelMessageRole.user,
          content: prompt,
          parts: allParts,
        ),
      ],
    );
  }

  final List<ModelMessage> messages;
  final String? model;
  final Set<ModelCapability> requiredCapabilities;
  final Map<String, Object?> metadata;

  String get promptText {
    return messages
        .expand(
          (message) => message.contentParts
              .where((part) => part.kind == ModelContentPartKind.text)
              .map((part) => part.text ?? ''),
        )
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
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
