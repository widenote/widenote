import 'dart:async';
import 'dart:collection';

import 'model_provider.dart';

typedef FakeModelResponder =
    FutureOr<ModelResponse> Function(ModelRequest request);

final class FakeModelProvider implements ModelProvider {
  FakeModelProvider({
    this.id = 'fake',
    this.displayName = 'Fake Model Provider',
    this.model = 'fake-model',
    Set<ModelCapability>? capabilities,
    Iterable<String> responses = const <String>[],
    FakeModelResponder? responder,
  }) : capabilities =
           capabilities ??
           const {ModelCapability.chat, ModelCapability.completion},
       _responses = Queue<String>.of(responses),
       _responder = responder;

  @override
  final String id;

  @override
  final String displayName;

  final String model;

  @override
  final Set<ModelCapability> capabilities;

  final Queue<String> _responses;
  final FakeModelResponder? _responder;
  final List<ModelRequest> _requests = <ModelRequest>[];

  List<ModelRequest> get requests => List.unmodifiable(_requests);

  void enqueue(String response) {
    _responses.add(response);
  }

  @override
  bool supports(ModelCapability capability) {
    return capabilities.contains(capability);
  }

  @override
  Future<ModelResponse> complete(ModelRequest request) async {
    _assertCapabilities(request);
    _requests.add(request);

    final responder = _responder;
    if (responder != null) {
      return responder(request);
    }

    return ModelResponse(
      providerId: id,
      model: request.model ?? model,
      text: _responses.isEmpty ? request.promptText : _responses.removeFirst(),
    );
  }

  void _assertCapabilities(ModelRequest request) {
    final missing = request.requiredCapabilities.difference(capabilities);
    if (missing.isEmpty) {
      return;
    }

    throw UnsupportedModelCapabilityException(
      providerId: id,
      missingCapabilities: missing,
    );
  }
}
