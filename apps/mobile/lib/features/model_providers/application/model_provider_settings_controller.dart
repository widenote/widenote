import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_model_providers/model_providers.dart';

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';

final modelProviderSettingsRepositoryProvider =
    Provider<ModelProviderSettingsRepository>((ref) {
      return LocalModelProviderSettingsRepository(
        ref.watch(localDatabaseProvider),
        clock: () => DateTime.now().toUtc(),
      );
    });

final modelProviderConnectionTestServiceProvider =
    Provider<ModelProviderConnectionTestService>((ref) {
      final httpClient = ref.watch(modelProviderConnectionHttpClientProvider);
      if (httpClient == null) {
        return const OfflineModelProviderConnectionTestService();
      }
      return AdapterModelProviderConnectionTestService(httpClient: httpClient);
    });

final modelProviderConnectionHttpClientProvider =
    Provider<ModelProviderHttpClient?>((ref) {
      if (!liveProviderConnectionTestsEnabled()) {
        return null;
      }
      final client = DartIoModelProviderHttpClient();
      ref.onDispose(client.close);
      return client;
    });

final modelProviderModelListServiceProvider =
    Provider<ModelProviderModelListService>((ref) {
      final client = DartIoModelProviderHttpClient();
      ref.onDispose(client.close);
      return AdapterModelProviderModelListService(httpClient: client);
    });

final modelProviderSettingsControllerProvider =
    AsyncNotifierProvider<
      ModelProviderSettingsController,
      ModelProviderSettingsState
    >(ModelProviderSettingsController.new);

enum ProviderConnectionStatus { idle, testing, succeeded, failed }

final class ProviderConnectionSnapshot {
  const ProviderConnectionSnapshot({
    this.status = ProviderConnectionStatus.idle,
    this.message = '',
  });

  final ProviderConnectionStatus status;
  final String message;
}

final class ModelProviderSettingsState {
  const ModelProviderSettingsState({
    this.providers = const <ModelProviderConfig>[],
    this.defaultProviderId,
    this.connectionResults = const <String, ProviderConnectionSnapshot>{},
    this.errorMessage,
  });

  final List<ModelProviderConfig> providers;
  final String? defaultProviderId;
  final Map<String, ProviderConnectionSnapshot> connectionResults;
  final String? errorMessage;

  ModelProviderConfig? get defaultProvider {
    final id = defaultProviderId;
    if (id == null) {
      return null;
    }
    for (final provider in providers) {
      if (provider.id == id) {
        return provider;
      }
    }
    return null;
  }

  ProviderConnectionSnapshot connectionFor(String providerId) {
    return connectionResults[providerId] ?? const ProviderConnectionSnapshot();
  }

  ModelProviderSettingsState copyWith({
    List<ModelProviderConfig>? providers,
    String? defaultProviderId,
    bool clearDefaultProvider = false,
    Map<String, ProviderConnectionSnapshot>? connectionResults,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ModelProviderSettingsState(
      providers: providers ?? this.providers,
      defaultProviderId: clearDefaultProvider
          ? null
          : defaultProviderId ?? this.defaultProviderId,
      connectionResults: connectionResults ?? this.connectionResults,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

abstract interface class ModelProviderSettingsRepository {
  Future<ModelProviderSettingsSnapshot> load();

  Future<void> save({
    required List<ModelProviderConfig> providers,
    required String? defaultProviderId,
  });
}

final class ModelProviderSettingsSnapshot {
  const ModelProviderSettingsSnapshot({
    required this.providers,
    required this.defaultProviderId,
  });

  final List<ModelProviderConfig> providers;
  final String? defaultProviderId;
}

final class LocalModelProviderSettingsRepository
    implements ModelProviderSettingsRepository {
  const LocalModelProviderSettingsRepository(
    this._database, {
    required DateTime Function() clock,
  }) : _clock = clock;

  final WideNoteLocalDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<ModelProviderSettingsSnapshot> load() async {
    final records = _database.modelProviderConfigs.readAll(status: 'active');
    final providers = records
        .map(_configFromRecord)
        .whereType<ModelProviderConfig>()
        .toList(growable: false);
    final defaultRecord = _database.modelProviderConfigs.readDefault();
    final defaultProvider = defaultRecord == null
        ? null
        : _configFromRecord(defaultRecord);
    return ModelProviderSettingsSnapshot(
      providers: providers,
      defaultProviderId: _defaultProviderIdFor(
        providers,
        requestedDefaultId: defaultProvider?.id,
      ),
    );
  }

  @override
  Future<void> save({
    required List<ModelProviderConfig> providers,
    required String? defaultProviderId,
  }) async {
    final now = _clock();
    final providerIds = providers.map((provider) => provider.id).toSet();
    final persistedDefaultId = _defaultProviderIdFor(
      providers,
      requestedDefaultId: defaultProviderId,
    );
    final records = <ModelProviderConfigRecord>[];
    for (final provider in providers) {
      final existing = _database.modelProviderConfigs.readById(provider.id);
      records.add(
        _recordFromConfig(
          provider,
          hasApiKey: provider.apiKey.trim().isNotEmpty,
          isDefault: provider.id == persistedDefaultId,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
    }
    for (final existing in _database.modelProviderConfigs.readAll(
      status: 'active',
    )) {
      if (providerIds.contains(existing.id)) {
        continue;
      }
      records.add(_deletedRecordFrom(existing, updatedAt: now));
    }
    _database.modelProviderConfigs.saveAll(
      records,
      defaultId: persistedDefaultId,
    );
  }
}

class ModelProviderSettingsController
    extends AsyncNotifier<ModelProviderSettingsState> {
  @override
  FutureOr<ModelProviderSettingsState> build() async {
    final snapshot = await ref
        .watch(modelProviderSettingsRepositoryProvider)
        .load();
    return ModelProviderSettingsState(
      providers: snapshot.providers,
      defaultProviderId: snapshot.defaultProviderId,
    );
  }

  Future<bool> saveProvider(
    ModelProviderConfig config, {
    bool requireApiKey = true,
  }) async {
    final current = await _currentState();
    final validation = config.validate(requireApiKey: requireApiKey);
    if (!validation.isValid) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Provider config invalid: ${validation.summary}.',
        ),
      );
      return false;
    }

    final providers = <ModelProviderConfig>[];
    var replaced = false;
    for (final provider in current.providers) {
      providers.add(provider.id == config.id ? config : provider);
      replaced = replaced || provider.id == config.id;
    }
    if (!replaced) {
      providers.add(config);
    }

    final defaultProviderId = _defaultProviderIdFor(
      providers,
      requestedDefaultId: current.defaultProviderId ?? config.id,
    );
    final connectionResults = _connectionResultsAfterSave(
      current,
      config,
      replaced: replaced,
    );
    await ref
        .read(modelProviderSettingsRepositoryProvider)
        .save(providers: providers, defaultProviderId: defaultProviderId);
    _refreshRuntimeModelClient();
    state = AsyncData(
      current.copyWith(
        providers: providers,
        defaultProviderId: defaultProviderId,
        connectionResults: connectionResults,
        clearError: true,
      ),
    );
    return true;
  }

  Future<void> setDefaultProvider(String providerId) async {
    final current = await _currentState();
    final exists = current.providers.any(
      (provider) => provider.id == providerId,
    );
    if (!exists) {
      state = AsyncData(current.copyWith(errorMessage: 'Provider not found.'));
      return;
    }
    await ref
        .read(modelProviderSettingsRepositoryProvider)
        .save(providers: current.providers, defaultProviderId: providerId);
    _refreshRuntimeModelClient();
    state = AsyncData(
      current.copyWith(defaultProviderId: providerId, clearError: true),
    );
  }

  Future<void> deleteProvider(String providerId) async {
    final current = await _currentState();
    final provider = _findProvider(current, providerId);
    if (provider == null) {
      state = AsyncData(current.copyWith(errorMessage: 'Provider not found.'));
      return;
    }

    final providers = current.providers
        .where((provider) => provider.id != providerId)
        .toList(growable: false);
    final defaultProviderId = _defaultProviderIdAfterDelete(
      providers,
      currentDefaultId: current.defaultProviderId,
      deletedProviderId: providerId,
    );
    final connectionResults = Map<String, ProviderConnectionSnapshot>.of(
      current.connectionResults,
    )..remove(providerId);

    await ref
        .read(modelProviderSettingsRepositoryProvider)
        .save(providers: providers, defaultProviderId: defaultProviderId);
    _refreshRuntimeModelClient();
    state = AsyncData(
      current.copyWith(
        providers: providers,
        defaultProviderId: defaultProviderId,
        clearDefaultProvider: defaultProviderId == null,
        connectionResults: connectionResults,
        clearError: true,
      ),
    );
  }

  Future<void> testProvider(String providerId) async {
    final current = await _currentState();
    final provider = _findProvider(current, providerId);
    if (provider == null) {
      state = AsyncData(current.copyWith(errorMessage: 'Provider not found.'));
      return;
    }

    await _setConnection(
      providerId,
      const ProviderConnectionSnapshot(
        status: ProviderConnectionStatus.testing,
        message: 'Testing connection...',
      ),
    );

    final result = await _testConnection(provider);
    await _setConnection(
      providerId,
      ProviderConnectionSnapshot(
        status: result.succeeded
            ? ProviderConnectionStatus.succeeded
            : ProviderConnectionStatus.failed,
        message: result.message,
      ),
    );
  }

  Future<ModelProviderConnectionTestResult> testDraftProvider(
    ModelProviderConfig provider,
  ) {
    return _testConnection(provider);
  }

  Future<ModelProviderConnectionTestResult> _testConnection(
    ModelProviderConfig provider,
  ) async {
    try {
      return await ref
          .read(modelProviderConnectionTestServiceProvider)
          .test(provider);
    } catch (_) {
      return ModelProviderConnectionTestResult.failure(
        usedLiveAdapter: false,
        errorKind: ModelProviderErrorKind.unknown,
        message: 'Provider connection test failed unexpectedly.',
      );
    }
  }

  Map<String, ProviderConnectionSnapshot> _connectionResultsAfterSave(
    ModelProviderSettingsState current,
    ModelProviderConfig config, {
    required bool replaced,
  }) {
    if (!replaced && config.apiKey.trim().isNotEmpty) {
      return current.connectionResults;
    }
    return <String, ProviderConnectionSnapshot>{
      ...current.connectionResults,
      config.id: ProviderConnectionSnapshot(
        message: config.apiKey.trim().isEmpty
            ? 'Saved API key cleared. Add a key before testing.'
            : 'Connection test has not run for these saved settings.',
      ),
    };
  }

  ModelProviderConfig? _findProvider(
    ModelProviderSettingsState state,
    String providerId,
  ) {
    for (final provider in state.providers) {
      if (provider.id == providerId) {
        return provider;
      }
    }
    return null;
  }

  Future<void> _setConnection(
    String providerId,
    ProviderConnectionSnapshot snapshot,
  ) async {
    final current = await _currentState();
    state = AsyncData(
      current.copyWith(
        connectionResults: <String, ProviderConnectionSnapshot>{
          ...current.connectionResults,
          providerId: snapshot,
        },
        clearError: true,
      ),
    );
  }

  Future<ModelProviderSettingsState> _currentState() async {
    final current = state.valueOrNull;
    if (current != null) {
      return current;
    }
    return future;
  }

  void _refreshRuntimeModelClient() {
    ref
      ..invalidate(modelClientProvider)
      ..invalidate(chatModelClientProvider);
  }
}

bool liveProviderConnectionTestsEnabled({
  String flag = const String.fromEnvironment('WIDENOTE_LIVE_PROVIDER_TESTS'),
}) {
  final normalized = flag.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'live';
}

final class DartIoModelProviderHttpClient implements ModelProviderHttpClient {
  DartIoModelProviderHttpClient({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  void close() {
    _httpClient.close(force: true);
  }

  @override
  Future<ModelProviderHttpResponse> getJson(
    Uri endpoint, {
    required Map<String, String> headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final request = await _httpClient.getUrl(endpoint).timeout(timeout);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }

    final response = await request.close().timeout(timeout);
    final responseBody = await utf8.decodeStream(response);
    return ModelProviderHttpResponse(
      statusCode: response.statusCode,
      headers: _responseHeaders(response),
      body: _decodeResponseBody(responseBody),
    );
  }

  @override
  Future<ModelProviderHttpResponse> postJson(
    Uri endpoint, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final request = await _httpClient.postUrl(endpoint).timeout(timeout);
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
    request.add(utf8.encode(jsonEncode(body)));

    final response = await request.close().timeout(timeout);
    final responseBody = await utf8.decodeStream(response);
    return ModelProviderHttpResponse(
      statusCode: response.statusCode,
      headers: _responseHeaders(response),
      body: _decodeResponseBody(responseBody),
    );
  }
}

Map<String, String> _responseHeaders(HttpClientResponse response) {
  final headers = <String, String>{};
  response.headers.forEach((name, values) {
    headers[name] = values.join(',');
  });
  return headers;
}

Object? _decodeResponseBody(String body) {
  if (body.trim().isEmpty) {
    return null;
  }
  try {
    return jsonDecode(body) as Object?;
  } on FormatException {
    return body;
  }
}

ModelProviderConfig? _configFromRecord(ModelProviderConfigRecord record) {
  final kind = _kindFromRecord(record);
  if (kind == null) {
    return null;
  }
  return ModelProviderConfig(
    id: record.id,
    kind: kind,
    displayName: record.displayName,
    endpoint: Uri.parse(record.endpoint),
    model: record.model,
    apiKey: record.apiKey,
    capabilities: _capabilitiesFromRecord(record),
  );
}

String? _defaultProviderIdFor(
  List<ModelProviderConfig> providers, {
  required String? requestedDefaultId,
}) {
  if (requestedDefaultId != null &&
      providers.any((provider) => provider.id == requestedDefaultId)) {
    return requestedDefaultId;
  }
  if (providers.isEmpty) {
    return null;
  }
  return providers.first.id;
}

String? _defaultProviderIdAfterDelete(
  List<ModelProviderConfig> providers, {
  required String? currentDefaultId,
  required String deletedProviderId,
}) {
  if (currentDefaultId != deletedProviderId) {
    return _defaultProviderIdFor(
      providers,
      requestedDefaultId: currentDefaultId,
    );
  }
  return _defaultProviderIdFor(
    providers,
    requestedDefaultId: _preferredFallbackProviderId(providers),
  );
}

String? _preferredFallbackProviderId(List<ModelProviderConfig> providers) {
  for (final provider in providers) {
    if (provider.apiKey.trim().isNotEmpty) {
      return provider.id;
    }
  }
  return providers.isEmpty ? null : providers.first.id;
}

ModelProviderKind? _kindFromRecord(ModelProviderConfigRecord record) {
  for (final kind in ModelProviderKind.values) {
    if (kind.name == record.providerKind) {
      return kind;
    }
  }
  return null;
}

Set<ModelCapability> _capabilitiesFromRecord(ModelProviderConfigRecord record) {
  final capabilities = <ModelCapability>{};
  for (final name in record.capabilities.whereType<String>()) {
    for (final capability in ModelCapability.values) {
      if (capability.name == name) {
        capabilities.add(capability);
        break;
      }
    }
  }
  return capabilities;
}

ModelProviderConfigRecord _recordFromConfig(
  ModelProviderConfig config, {
  required bool hasApiKey,
  required bool isDefault,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return ModelProviderConfigRecord(
    id: config.id,
    providerKind: config.kind.name,
    displayName: config.displayName,
    endpoint: config.endpoint.toString(),
    model: config.model,
    isDefault: isDefault,
    hasApiKey: hasApiKey,
    apiKey: config.apiKey,
    capabilities: config.capabilities
        .map((capability) => capability.name)
        .toList(),
    payload: const <String, Object?>{'secret_storage': 'local_db_backup'},
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

ModelProviderConfigRecord _deletedRecordFrom(
  ModelProviderConfigRecord record, {
  required DateTime updatedAt,
}) {
  return ModelProviderConfigRecord(
    id: record.id,
    schemaVersion: record.schemaVersion,
    providerKind: record.providerKind,
    displayName: record.displayName,
    endpoint: record.endpoint,
    model: record.model,
    status: 'deleted',
    isDefault: false,
    hasApiKey: false,
    apiKey: '',
    capabilities: record.capabilities,
    payload: const <String, Object?>{'deleted': true},
    createdAt: record.createdAt,
    updatedAt: updatedAt,
  );
}
