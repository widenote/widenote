import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;
import 'package:widenote_model_providers/model_providers.dart';

import '../../app/local_database.dart';
import '../../app/model_client.dart';
import '../model_providers/application/model_provider_settings_controller.dart';
import 'local_sensevoice_provider.dart';
import 'mimo_asr_provider.dart';
import 'transcript_correction_controller.dart';
import 'transcription_download_manager.dart';
import 'transcription_settings.dart';
import 'transcription_types.dart';

final voiceTranscriptionSettingsRepositoryProvider =
    Provider<VoiceTranscriptionSettingsRepository>((ref) {
      final supportDirectory = ref.watch(appSupportDirectoryProvider);
      if (supportDirectory == null) {
        return MemoryVoiceTranscriptionSettingsRepository();
      }
      return JsonFileVoiceTranscriptionSettingsRepository(
        supportDirectory: supportDirectory,
      );
    });

final transcriptionCredentialStoreProvider =
    Provider<TranscriptionCredentialStore>((ref) {
      return const SecureTranscriptionCredentialStore();
    });

final transcriptionHttpClientProvider = Provider<ModelProviderHttpClient?>((
  ref,
) {
  final client = DartIoModelProviderHttpClient();
  ref.onDispose(client.close);
  return client;
});

final voiceTranscriptionSettingsControllerProvider =
    AsyncNotifierProvider<
      VoiceTranscriptionSettingsController,
      VoiceTranscriptionSettings
    >(VoiceTranscriptionSettingsController.new);

final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  return TranscriptionService(
    database: ref.watch(localDatabaseProvider),
    supportDirectory: ref.watch(appSupportDirectoryProvider),
    settingsRepository: ref.watch(voiceTranscriptionSettingsRepositoryProvider),
    credentialStore: ref.watch(transcriptionCredentialStoreProvider),
    httpClient: ref.watch(transcriptionHttpClientProvider),
    modelClient: ref.watch(modelClientProvider),
  );
});

final transcriptionDownloadManagerProvider =
    Provider<TranscriptionDownloadManager?>((ref) {
      final supportDirectory = ref.watch(appSupportDirectoryProvider);
      if (supportDirectory == null) {
        return null;
      }
      return TranscriptionDownloadManager(
        supportDirectory: supportDirectory,
        settingsRepository: ref.watch(
          voiceTranscriptionSettingsRepositoryProvider,
        ),
      );
    });

final class VoiceTranscriptionSettingsController
    extends AsyncNotifier<VoiceTranscriptionSettings> {
  @override
  Future<VoiceTranscriptionSettings> build() {
    return ref.watch(voiceTranscriptionSettingsRepositoryProvider).load();
  }

  Future<void> saveSettings(VoiceTranscriptionSettings settings) async {
    await ref.read(voiceTranscriptionSettingsRepositoryProvider).save(settings);
    state = AsyncData(settings);
  }

  Future<void> setRemoteConsent(bool granted) async {
    final current = await future;
    await saveSettings(current.copyWith(remoteConsentGranted: granted));
  }

  Future<void> saveMimoApiKey(String value) async {
    await ref
        .read(transcriptionCredentialStoreProvider)
        .writeMimoAsrApiKey(value.trim());
    final current = await future;
    await saveSettings(
      current.copyWith(remoteConsentGranted: true, clearError: true),
    );
  }

  Future<void> clearMimoApiKey() async {
    await ref.read(transcriptionCredentialStoreProvider).deleteMimoAsrApiKey();
    final current = await future;
    await saveSettings(current.copyWith(remoteConsentGranted: false));
  }

  Future<void> reload() async {
    state = AsyncData(
      await ref.read(voiceTranscriptionSettingsRepositoryProvider).load(),
    );
  }
}

final class TranscriptionService {
  const TranscriptionService({
    required localdb.WideNoteLocalDatabase database,
    required Directory? supportDirectory,
    required VoiceTranscriptionSettingsRepository settingsRepository,
    required TranscriptionCredentialStore credentialStore,
    required ModelProviderHttpClient? httpClient,
    required runtime.ModelClient modelClient,
    AudioTranscriptionProvider? localProvider,
    AudioTranscriptionProvider? remoteProvider,
  }) : _database = database,
       _supportDirectory = supportDirectory,
       _settingsRepository = settingsRepository,
       _credentialStore = credentialStore,
       _httpClient = httpClient,
       _modelClient = modelClient,
       _localProviderOverride = localProvider,
       _remoteProviderOverride = remoteProvider;

  final localdb.WideNoteLocalDatabase _database;
  final Directory? _supportDirectory;
  final VoiceTranscriptionSettingsRepository _settingsRepository;
  final TranscriptionCredentialStore _credentialStore;
  final ModelProviderHttpClient? _httpClient;
  final runtime.ModelClient _modelClient;
  final AudioTranscriptionProvider? _localProviderOverride;
  final AudioTranscriptionProvider? _remoteProviderOverride;

  Future<TranscriptionResult> transcribeAttachment(
    String attachmentId, {
    bool manualRemoteRetry = false,
  }) async {
    final attachment = _attachmentRef(attachmentId);
    final settings = await _settingsRepository.load();
    final engine = manualRemoteRetry
        ? VoiceTranscriptionEngine.xiaomiMimo
        : settings.engine;
    _markTranscribing(
      attachment,
      providerKind: _providerKindForEngine(engine).wireName,
    );
    final result = await _transcribeWithEngine(
      attachment,
      settings,
      engine: engine,
      manualRemoteRetry: manualRemoteRetry,
    );

    final corrected = await _maybeCorrect(result, settings);
    _saveTranscriptArtifact(
      attachment,
      result: corrected.result,
      correction: corrected.correction,
    );
    return corrected.result;
  }

  Future<TranscriptionResult> retryRemote(String attachmentId) {
    return transcribeAttachment(attachmentId, manualRemoteRetry: true);
  }

  Future<TranscriptionResult> _transcribeWithEngine(
    AudioAttachmentRef attachment,
    VoiceTranscriptionSettings settings, {
    required VoiceTranscriptionEngine engine,
    required bool manualRemoteRetry,
  }) async {
    if (engine == VoiceTranscriptionEngine.disabled) {
      return _failedResult(
        attachment,
        const TranscriptionException(
          code: TranscriptionFailureCode.providerDisabled,
          message: 'Voice transcription is disabled.',
        ),
        providerId: 'disabled',
        providerKind: TranscriptionProviderKind.disabled,
      );
    }
    if (engine == VoiceTranscriptionEngine.xiaomiMimo) {
      try {
        return await _remoteProvider(
          settings.copyWith(engine: VoiceTranscriptionEngine.xiaomiMimo),
        ).transcribeAttachment(
          attachment,
          options: TranscriptionOptions(
            language: settings.language,
            manualRemoteRetry: manualRemoteRetry,
          ),
        );
      } on TranscriptionException catch (remoteError) {
        return _failedResult(
          attachment,
          remoteError,
          providerId: 'mimo_asr',
          providerKind: TranscriptionProviderKind.mimoAsr,
        );
      }
    }

    try {
      return await _localProvider(settings).transcribeAttachment(
        attachment,
        options: TranscriptionOptions(
          language: settings.language,
          allowRemoteFallback: false,
          manualRemoteRetry: manualRemoteRetry,
        ),
      );
    } on TranscriptionException catch (localError) {
      return _failedResult(
        attachment,
        localError,
        providerId: 'local_sensevoice',
      );
    }
  }

  Future<TranscriptRetrySummary> retryFailedTranscripts({
    int limit = 10,
  }) async {
    final candidates = _database.derivedArtifacts
        .readAll(artifactKind: 'audio_transcript', limit: 100)
        .where(_isRetryableTranscript)
        .take(limit)
        .toList(growable: false);
    var succeeded = 0;
    var failed = 0;
    for (final artifact in candidates) {
      final attachmentId = artifact.sourceAttachmentId;
      if (attachmentId == null) {
        failed += 1;
        continue;
      }
      try {
        final result = await retryRemote(attachmentId);
        if (result.status == TranscriptStatus.active) {
          succeeded += 1;
        } else {
          failed += 1;
        }
      } on Object {
        failed += 1;
      }
    }
    return TranscriptRetrySummary(
      attempted: candidates.length,
      succeeded: succeeded,
      failed: failed,
    );
  }

  Stream<TranscriptionPreview> preview(Stream<AudioPcmChunk> samples) async* {
    final settings = await _settingsRepository.load();
    if (settings.engine != VoiceTranscriptionEngine.localSenseVoice) {
      yield const TranscriptionPreview(
        status: TranscriptStatus.pending,
        errorCode: TranscriptionFailureCode.streamUnavailable,
      );
      return;
    }
    yield* _localProvider(settings).transcribeSamples(
      samples,
      options: TranscriptionOptions(language: settings.language),
    );
  }

  AudioTranscriptionProvider _localProvider(
    VoiceTranscriptionSettings settings,
  ) {
    final override = _localProviderOverride;
    if (override != null) {
      return override;
    }
    return LocalSenseVoiceProvider(
      settings: settings,
      modelResolver: () async {
        final supportDirectory = _supportDirectory;
        if (supportDirectory == null) {
          return null;
        }
        final modelRoot = p.join(
          supportDirectory.path,
          'local-data',
          'models',
          'sensevoice',
          defaultSenseVoiceModelDirectory,
        );
        final modelPath = p.join(modelRoot, 'model.int8.onnx');
        final tokensPath = p.join(modelRoot, 'tokens.txt');
        if (settings.localModelState != LocalTranscriptionModelState.ready) {
          return null;
        }
        return LocalSenseVoiceModelFiles(
          modelPath: modelPath,
          tokensPath: tokensPath,
        );
      },
    );
  }

  AudioTranscriptionProvider _remoteProvider(
    VoiceTranscriptionSettings settings,
  ) {
    final override = _remoteProviderOverride;
    if (override != null) {
      return override;
    }
    final httpClient = _httpClient;
    if (httpClient == null) {
      return _UnavailableRemoteTranscriptionProvider();
    }
    return MimoAsrProvider(
      settings: settings,
      credentialStore: _credentialStore,
      httpClient: httpClient,
    );
  }

  Future<_CorrectedTranscription> _maybeCorrect(
    TranscriptionResult result,
    VoiceTranscriptionSettings settings,
  ) async {
    if (result.status != TranscriptStatus.active ||
        settings.correctionMode == TranscriptCorrectionMode.disabled) {
      return _CorrectedTranscription(result: result);
    }
    final TranscriptCorrectionResult correction;
    try {
      correction = await TranscriptCorrectionController(model: _modelClient)
          .correct(
            transcript: result.text,
            glossaryTerms: _glossaryTerms(),
            mode: settings.correctionMode,
          );
    } on Object {
      return _CorrectedTranscription(result: result);
    }
    if (!correction.autoApplied) {
      return _CorrectedTranscription(result: result, correction: correction);
    }
    return _CorrectedTranscription(
      result: TranscriptionResult(
        text: correction.correctedText,
        status: TranscriptStatus.active,
        providerId: result.providerId,
        providerKind: result.providerKind,
        model: result.model,
        durationMs: result.durationMs,
        segments: result.segments,
        confidence: result.confidence,
        language: result.language,
        rawAsrText: result.rawAsrText,
        chunkCount: result.chunkCount,
        metadata: <String, Object?>{
          ...result.metadata,
          'correction_auto_applied': true,
        },
      ),
      correction: correction,
    );
  }

  Iterable<String> _glossaryTerms() {
    return _database.memoryItems
        .readAll(status: 'active', limit: 50)
        .map((memory) => memory.body);
  }

  void _markTranscribing(
    AudioAttachmentRef attachment, {
    required String providerKind,
  }) {
    final existing = _database.derivedArtifacts.readById(
      _artifactId(attachment.captureId, attachment.id, 'audio_transcript'),
    );
    if (existing == null) {
      return;
    }
    _database.derivedArtifacts.save(
      existing.copyWith(
        status: TranscriptStatus.transcribing.wireName,
        body: 'Transcribing ${p.basename(attachment.localPath)}.',
        payload: <String, Object?>{
          ...existing.payload,
          'transcript_status': TranscriptStatus.transcribing.wireName,
          'provider_kind': providerKind,
        },
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _saveTranscriptArtifact(
    AudioAttachmentRef attachment, {
    required TranscriptionResult result,
    TranscriptCorrectionResult? correction,
  }) {
    final now = DateTime.now().toUtc();
    final artifactId = _artifactId(
      attachment.captureId,
      attachment.id,
      'audio_transcript',
    );
    final transcriptEventId =
        'transcript.${_safeId(attachment.id)}.${_safeId(result.providerId)}';
    final correctionEventId = correction == null
        ? null
        : 'correction.${_safeId(attachment.id)}';
    final sourceRefs = <Object?>[
      <String, Object?>{'kind': 'capture', 'id': attachment.captureId},
      <String, Object?>{'kind': 'attachment', 'id': attachment.id},
      if (attachment.sourceEventId != null)
        <String, Object?>{'kind': 'event', 'id': attachment.sourceEventId},
      <String, Object?>{'kind': 'event', 'id': transcriptEventId},
      if (correctionEventId != null)
        <String, Object?>{'kind': 'event', 'id': correctionEventId},
    ];
    final body = result.text.trim().isNotEmpty
        ? result.text.trim()
        : result.errorMessageSafe ?? 'Transcript failed.';
    final artifact = localdb.DerivedArtifactRecord(
      id: artifactId,
      sourceCaptureId: attachment.captureId,
      sourceAttachmentId: attachment.id,
      sourceEventId: attachment.sourceEventId,
      artifactKind: 'audio_transcript',
      status: result.status.wireName,
      title: result.status == TranscriptStatus.active
          ? 'Audio transcript'
          : 'Audio transcript ${result.status.wireName}',
      body: body,
      mimeType: attachment.mimeType,
      storagePath: attachment.storagePath,
      contentHash: _stableContentHash(<String, Object?>{
        'capture_id': attachment.captureId,
        'attachment_id': attachment.id,
        'transcript': body,
        'status': result.status.wireName,
      }),
      sourceRefs: sourceRefs,
      sensitivity: 'medium',
      confidence: result.confidence == null ? 'medium' : 'high',
      generatorId: result.providerId,
      generatorVersion: result.model,
      payload: <String, Object?>{
        ...result.toPayload(
          sourceAttachmentSha256: attachment.sha256,
          correctionStatus: correction == null
              ? 'not_run'
              : correction.autoApplied
              ? 'auto_applied'
              : 'needs_review',
          correctionPatches:
              correction?.patches.map((patch) => patch.toJson()).toList() ??
              const <Object?>[],
        ),
        'source_refs': sourceRefs,
        'transcript_event_id': transcriptEventId,
        if (correctionEventId != null) ...<String, Object?>{
          'correction_event_id': correctionEventId,
          'correction_revision_kind': 'inline_audio_transcript_artifact',
        },
      },
      createdAt: now,
      updatedAt: now,
    );
    _database.derivedArtifacts.save(artifact);
    final storedAttachment = _database.attachments.readById(attachment.id);
    if (storedAttachment != null) {
      _database.attachments.save(
        storedAttachment.copyWith(
          payload: <String, Object?>{
            ...storedAttachment.payload,
            'transcript_status': result.status.wireName,
            'transcript_id': artifact.id,
            'duration_ms': attachment.durationMs,
            'provider_kind': result.providerKind.wireName,
            if (result.errorCode != null)
              'last_error_code': result.errorCode!.wireName,
          },
          updatedAt: now,
        ),
      );
    }
  }

  TranscriptionResult _failedResult(
    AudioAttachmentRef attachment,
    TranscriptionException error, {
    required String providerId,
    TranscriptionProviderKind providerKind =
        TranscriptionProviderKind.localSenseVoice,
    String? fallbackFrom,
  }) {
    return TranscriptionResult(
      text: '',
      status: error.code == TranscriptionFailureCode.noSpeech
          ? TranscriptStatus.noSpeech
          : TranscriptStatus.failed,
      providerId: providerId,
      providerKind: providerKind,
      model: providerId,
      durationMs: attachment.durationMs,
      errorCode: error.code,
      errorMessageSafe: error.message,
      metadata: fallbackFrom == null
          ? const <String, Object?>{}
          : <String, Object?>{'fallback_from': fallbackFrom},
    );
  }

  AudioAttachmentRef _attachmentRef(String attachmentId) {
    final record = _database.attachments.readById(attachmentId);
    if (record == null) {
      throw ArgumentError.value(attachmentId, 'attachmentId', 'not found');
    }
    final rawMetadata = record.payload['raw_metadata'];
    final metadata = rawMetadata is Map
        ? rawMetadata.cast<String, Object?>()
        : const <String, Object?>{};
    final adapterMetadata = metadata['adapter_metadata'];
    final nested = adapterMetadata is Map
        ? adapterMetadata.cast<String, Object?>()
        : metadata;
    final localPath = _string(nested['local_path']);
    final sha256 = record.sha256 ?? _string(nested['sha256']);
    if (localPath == null || sha256 == null) {
      throw ArgumentError.value(
        attachmentId,
        'attachmentId',
        'attachment missing local path or sha256',
      );
    }
    return AudioAttachmentRef(
      id: record.id,
      captureId: record.captureId,
      sourceEventId: record.sourceEventId,
      storagePath: record.storagePath,
      mimeType: record.mimeType ?? 'application/octet-stream',
      sha256: sha256,
      byteLength: record.byteLength ?? _int(nested['byte_length']) ?? 0,
      durationMs: _int(nested['duration_ms']) ?? 0,
      localPath: localPath,
    );
  }
}

TranscriptionProviderKind _providerKindForEngine(
  VoiceTranscriptionEngine engine,
) {
  return switch (engine) {
    VoiceTranscriptionEngine.localSenseVoice =>
      TranscriptionProviderKind.localSenseVoice,
    VoiceTranscriptionEngine.xiaomiMimo => TranscriptionProviderKind.mimoAsr,
    VoiceTranscriptionEngine.disabled => TranscriptionProviderKind.disabled,
  };
}

bool _isRetryableTranscript(localdb.DerivedArtifactRecord artifact) {
  return artifact.status == TranscriptStatus.failed.wireName ||
      artifact.status == TranscriptStatus.noSpeech.wireName ||
      artifact.status == TranscriptStatus.needsReview.wireName;
}

final class TranscriptRetrySummary {
  const TranscriptRetrySummary({
    required this.attempted,
    required this.succeeded,
    required this.failed,
  });

  final int attempted;
  final int succeeded;
  final int failed;
}

final class _CorrectedTranscription {
  const _CorrectedTranscription({required this.result, this.correction});

  final TranscriptionResult result;
  final TranscriptCorrectionResult? correction;
}

final class _UnavailableRemoteTranscriptionProvider
    implements AudioTranscriptionProvider {
  @override
  String get id => 'mimo_asr';

  @override
  String get displayName => 'Xiaomi MiMo ASR';

  @override
  TranscriptionProviderKind get kind => TranscriptionProviderKind.mimoAsr;

  @override
  bool get supportsFileTranscription => true;

  @override
  bool get supportsRemoteUpload => true;

  @override
  bool get supportsStreamingPreview => false;

  @override
  Future<void> prepare() async {
    throw const TranscriptionException(
      code: TranscriptionFailureCode.remoteDisabled,
      message: 'Remote ASR HTTP client is disabled.',
    );
  }

  @override
  Future<TranscriptionResult> transcribeAttachment(
    AudioAttachmentRef attachment, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    await prepare();
    throw StateError('unreachable');
  }

  @override
  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async* {
    yield const TranscriptionPreview(
      status: TranscriptStatus.pending,
      errorCode: TranscriptionFailureCode.remoteDisabled,
    );
  }

  @override
  Future<void> dispose() async {}
}

String _artifactId(String captureId, String attachmentId, String artifactKind) {
  return 'artifact.${_safeId(captureId)}.${_safeId(attachmentId)}.$artifactKind';
}

String _stableContentHash(Map<String, Object?> value) {
  return sha256.convert(utf8.encode(jsonEncode(value))).toString();
}

String _safeId(String value) {
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
