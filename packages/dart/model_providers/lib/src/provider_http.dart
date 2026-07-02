import 'dart:async';
import 'dart:collection';

abstract interface class ModelProviderHttpClient {
  Future<ModelProviderHttpResponse> getJson(
    Uri endpoint, {
    required Map<String, String> headers,
    Duration timeout,
  });

  Future<ModelProviderHttpResponse> postJson(
    Uri endpoint, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    Duration timeout,
  });
}

final class ModelProviderHttpResponse {
  const ModelProviderHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final Object? body;
  final Map<String, String> headers;
}

final class RecordedModelProviderHttpRequest {
  const RecordedModelProviderHttpRequest({
    required this.method,
    required this.endpoint,
    required this.headers,
    required this.body,
    required this.timeout,
  });

  final String method;
  final Uri endpoint;
  final Map<String, String> headers;
  final Map<String, Object?> body;
  final Duration timeout;

  Map<String, String> get redactedHeaders {
    return headers.map((key, value) {
      final lowerKey = key.toLowerCase();
      if (lowerKey == 'authorization' ||
          lowerKey == 'x-api-key' ||
          lowerKey.contains('token')) {
        return MapEntry(key, '<redacted>');
      }
      return MapEntry(key, value);
    });
  }

  Uri get redactedEndpoint {
    if (endpoint.queryParametersAll.isEmpty) {
      return endpoint;
    }
    final redactedQuery = <String, Object>{};
    for (final entry in endpoint.queryParametersAll.entries) {
      final values = _isSensitiveQueryParameter(entry.key)
          ? List<String>.filled(entry.value.length, '<redacted>')
          : entry.value;
      redactedQuery[entry.key] = values.length == 1 ? values.single : values;
    }
    return endpoint.replace(queryParameters: redactedQuery);
  }

  @override
  String toString() {
    return 'RecordedModelProviderHttpRequest(method: $method, '
        'endpoint: $redactedEndpoint, '
        'headers: $redactedHeaders, body: $body, timeout: $timeout)';
  }
}

bool _isSensitiveQueryParameter(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return normalized == 'key' ||
      normalized == 'apikey' ||
      normalized == 'token' ||
      normalized == 'accesstoken' ||
      normalized == 'authorization';
}

final class FakeModelProviderHttpClient implements ModelProviderHttpClient {
  FakeModelProviderHttpClient({
    Iterable<ModelProviderHttpResponse> responses =
        const <ModelProviderHttpResponse>[],
  }) : _responses = Queue<ModelProviderHttpResponse>.of(responses);

  final Queue<ModelProviderHttpResponse> _responses;
  final Queue<Object> _errors = Queue<Object>();
  final List<RecordedModelProviderHttpRequest> _requests =
      <RecordedModelProviderHttpRequest>[];

  List<RecordedModelProviderHttpRequest> get requests {
    return List.unmodifiable(_requests);
  }

  void enqueueResponse(ModelProviderHttpResponse response) {
    _responses.add(response);
  }

  void enqueueError(Object error) {
    _errors.add(error);
  }

  @override
  Future<ModelProviderHttpResponse> getJson(
    Uri endpoint, {
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _send(
      method: 'GET',
      endpoint: endpoint,
      headers: headers,
      body: const <String, Object?>{},
      timeout: timeout,
    );
  }

  @override
  Future<ModelProviderHttpResponse> postJson(
    Uri endpoint, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return _send(
      method: 'POST',
      endpoint: endpoint,
      headers: headers,
      body: body,
      timeout: timeout,
    );
  }

  Future<ModelProviderHttpResponse> _send({
    required String method,
    required Uri endpoint,
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required Duration timeout,
  }) async {
    _requests.add(
      RecordedModelProviderHttpRequest(
        method: method,
        endpoint: endpoint,
        headers: Map.unmodifiable(headers),
        body: Map.unmodifiable(body),
        timeout: timeout,
      ),
    );

    if (_errors.isNotEmpty) {
      final error = _errors.removeFirst();
      if (error is Exception) {
        throw error;
      }
      if (error is Error) {
        throw error;
      }
      throw StateError(error.toString());
    }

    if (_responses.isEmpty) {
      throw TimeoutException('No fake model provider response was queued.');
    }
    return _responses.removeFirst();
  }
}
