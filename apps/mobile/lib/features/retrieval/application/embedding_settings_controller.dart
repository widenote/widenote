import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_model_providers/model_providers.dart';

import '../../../app/local_database.dart';
import '../../model_providers/application/model_provider_settings_controller.dart';

const defaultEmbeddingProviderId = 'embedding.openrouter';

final embeddingSettingsRepositoryProvider =
    Provider<EmbeddingSettingsRepository>((ref) {
      return LocalEmbeddingSettingsRepository(
        ref.watch(localDatabaseProvider),
        clock: () => DateTime.now().toUtc(),
      );
    });

final embeddingConnectionHttpClientProvider = Provider<ModelProviderHttpClient>(
  (ref) {
    final client = DartIoModelProviderHttpClient();
    ref.onDispose(client.close);
    return client;
  },
);

final embeddingSettingsControllerProvider =
    AsyncNotifierProvider<EmbeddingSettingsController, EmbeddingSettingsState>(
      EmbeddingSettingsController.new,
    );

enum EmbeddingConnectionStatus { idle, testing, succeeded, failed }

final class EmbeddingConnectionSnapshot {
  const EmbeddingConnectionSnapshot({
    this.status = EmbeddingConnectionStatus.idle,
    this.message = '',
  });

  final EmbeddingConnectionStatus status;
  final String message;
}

final class EmbeddingSettingsState {
  const EmbeddingSettingsState({
    this.provider,
    this.connection = const EmbeddingConnectionSnapshot(),
    this.errorMessage,
  });

  final EmbeddingProviderConfig? provider;
  final EmbeddingConnectionSnapshot connection;
  final String? errorMessage;

  bool get isConfigured =>
      provider != null && provider!.apiKey.trim().isNotEmpty;

  EmbeddingSettingsState copyWith({
    EmbeddingProviderConfig? provider,
    bool clearProvider = false,
    EmbeddingConnectionSnapshot? connection,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EmbeddingSettingsState(
      provider: clearProvider ? null : provider ?? this.provider,
      connection: connection ?? this.connection,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

abstract interface class EmbeddingSettingsRepository {
  Future<EmbeddingProviderConfig?> loadDefault();

  Future<void> saveDefault(EmbeddingProviderConfig config);

  Future<void> deleteDefault();
}

final class LocalEmbeddingSettingsRepository
    implements EmbeddingSettingsRepository {
  const LocalEmbeddingSettingsRepository(
    this._database, {
    required DateTime Function() clock,
  }) : _clock = clock;

  final WideNoteLocalDatabase _database;
  final DateTime Function() _clock;

  @override
  Future<EmbeddingProviderConfig?> loadDefault() async {
    final record = _database.embeddingProviderConfigs.readDefault();
    if (record == null) {
      return null;
    }
    return embeddingConfigFromRecord(record);
  }

  @override
  Future<void> saveDefault(EmbeddingProviderConfig config) async {
    final now = _clock();
    final existing = _database.embeddingProviderConfigs.readById(config.id);
    _database.embeddingProviderConfigs.saveAll(<EmbeddingProviderConfigRecord>[
      embeddingRecordFromConfig(
        config,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        isDefault: true,
      ),
    ], defaultId: config.id);
  }

  @override
  Future<void> deleteDefault() async {
    final existing = _database.embeddingProviderConfigs.readDefault();
    if (existing == null) {
      return;
    }
    _database.embeddingProviderConfigs.save(
      EmbeddingProviderConfigRecord(
        id: existing.id,
        schemaVersion: existing.schemaVersion,
        providerKind: existing.providerKind,
        displayName: existing.displayName,
        endpoint: existing.endpoint,
        model: existing.model,
        status: 'deleted',
        isDefault: false,
        hasApiKey: false,
        apiKey: '',
        dimensions: existing.dimensions,
        batchSize: existing.batchSize,
        payload: const <String, Object?>{'deleted': true},
        createdAt: existing.createdAt,
        updatedAt: _clock(),
      ),
    );
  }
}

class EmbeddingSettingsController
    extends AsyncNotifier<EmbeddingSettingsState> {
  @override
  FutureOr<EmbeddingSettingsState> build() async {
    final provider = await ref
        .watch(embeddingSettingsRepositoryProvider)
        .loadDefault();
    return EmbeddingSettingsState(provider: provider);
  }

  Future<bool> saveProvider(EmbeddingProviderConfig config) async {
    final current = await _currentState();
    final validation = config.validate();
    if (!validation.isValid) {
      state = AsyncData(
        current.copyWith(
          errorMessage: 'Embedding config invalid: ${validation.summary}.',
        ),
      );
      return false;
    }
    await ref.read(embeddingSettingsRepositoryProvider).saveDefault(config);
    state = AsyncData(
      current.copyWith(
        provider: config,
        connection: EmbeddingConnectionSnapshot(
          message: config.apiKey.trim().isEmpty
              ? 'Saved without an API key.'
              : 'Embedding connection test has not run yet.',
        ),
        clearError: true,
      ),
    );
    return true;
  }

  Future<void> deleteProvider() async {
    final current = await _currentState();
    await ref.read(embeddingSettingsRepositoryProvider).deleteDefault();
    state = AsyncData(current.copyWith(clearProvider: true, clearError: true));
  }

  Future<void> testProvider([EmbeddingProviderConfig? draft]) async {
    final current = await _currentState();
    final provider = draft ?? current.provider;
    if (provider == null) {
      state = AsyncData(
        current.copyWith(errorMessage: 'Embedding provider not configured.'),
      );
      return;
    }
    state = AsyncData(
      current.copyWith(
        connection: const EmbeddingConnectionSnapshot(
          status: EmbeddingConnectionStatus.testing,
          message: 'Testing embedding provider...',
        ),
        clearError: true,
      ),
    );
    final result = await _test(provider);
    state = AsyncData(
      (state.valueOrNull ?? current).copyWith(
        connection: result,
        clearError: result.status != EmbeddingConnectionStatus.failed,
        errorMessage: result.status == EmbeddingConnectionStatus.failed
            ? result.message
            : null,
      ),
    );
  }

  Future<EmbeddingConnectionSnapshot> _test(
    EmbeddingProviderConfig provider,
  ) async {
    try {
      final adapter = embeddingProviderFromConfig(
        config: provider,
        httpClient: ref.read(embeddingConnectionHttpClientProvider),
      );
      final response = await adapter.embed(
        const EmbeddingRequest(input: <String>['WideNote connection test']),
      );
      final dimensions = response.embeddings.isEmpty
          ? 0
          : response.embeddings.first.length;
      if (dimensions <= 0) {
        return const EmbeddingConnectionSnapshot(
          status: EmbeddingConnectionStatus.failed,
          message: 'Embedding provider returned an empty vector.',
        );
      }
      return EmbeddingConnectionSnapshot(
        status: EmbeddingConnectionStatus.succeeded,
        message: 'Connected. Vector dimensions: $dimensions.',
      );
    } catch (error) {
      return EmbeddingConnectionSnapshot(
        status: EmbeddingConnectionStatus.failed,
        message: 'Embedding test failed: $error',
      );
    }
  }

  Future<EmbeddingSettingsState> _currentState() async {
    final current = state.valueOrNull;
    if (current != null) {
      return current;
    }
    return future;
  }
}

EmbeddingProviderConfig? embeddingConfigFromRecord(
  EmbeddingProviderConfigRecord record,
) {
  final kind = _embeddingKindFromRecord(record);
  if (kind == null) {
    return null;
  }
  final endpoint = Uri.tryParse(record.endpoint);
  if (endpoint == null) {
    return null;
  }
  return EmbeddingProviderConfig(
    id: record.id,
    kind: kind,
    displayName: record.displayName,
    endpoint: endpoint,
    model: record.model,
    apiKey: record.apiKey,
    dimensions: record.dimensions,
    batchSize: record.batchSize,
  );
}

EmbeddingProviderConfigRecord embeddingRecordFromConfig(
  EmbeddingProviderConfig config, {
  required DateTime createdAt,
  required DateTime updatedAt,
  required bool isDefault,
}) {
  return EmbeddingProviderConfigRecord(
    id: config.id,
    providerKind: config.kind.wireName,
    displayName: config.displayName,
    endpoint: config.endpoint.toString(),
    model: config.model,
    isDefault: isDefault,
    hasApiKey: config.apiKey.trim().isNotEmpty,
    apiKey: config.apiKey,
    dimensions: config.dimensions,
    batchSize: config.batchSize,
    payload: const <String, Object?>{
      'secret_storage': 'local_db_backup',
      'purpose': 'retrieval_embedding',
    },
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

EmbeddingProviderKind? _embeddingKindFromRecord(
  EmbeddingProviderConfigRecord record,
) {
  try {
    return embeddingProviderKindFromWireName(record.providerKind);
  } on StateError {
    return null;
  }
}
