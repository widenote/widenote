import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

enum LocalTranscriptionModelState {
  notDownloaded('not_downloaded'),
  checking('checking'),
  downloading('downloading'),
  pausedOrInterrupted('paused_or_interrupted'),
  verifying('verifying'),
  ready('ready'),
  failed('failed'),
  corrupted('corrupted'),
  deleting('deleting');

  const LocalTranscriptionModelState(this.wireName);

  final String wireName;
}

enum VoiceTranscriptionProviderMode {
  localOnly('local_only'),
  localFirstRemoteAuto('local_first_remote_auto'),
  remoteDisabled('remote_disabled');

  const VoiceTranscriptionProviderMode(this.wireName);

  final String wireName;
}

enum VoiceTranscriptionEngine {
  localSenseVoice('local_sensevoice'),
  xiaomiMimo('xiaomi_mimo'),
  disabled('disabled');

  const VoiceTranscriptionEngine(this.wireName);

  final String wireName;
}

enum TranscriptCorrectionMode {
  disabled('disabled'),
  suggestOnly('suggest_only'),
  autoApplyHighConfidence('auto_apply_high_confidence');

  const TranscriptCorrectionMode(this.wireName);

  final String wireName;
}

final class VoiceTranscriptionSettings {
  const VoiceTranscriptionSettings({
    this.localModelState = LocalTranscriptionModelState.notDownloaded,
    this.downloadProgress = 0,
    this.providerMode = VoiceTranscriptionProviderMode.localOnly,
    this.engine = VoiceTranscriptionEngine.localSenseVoice,
    this.realtimePreviewEnabled = true,
    this.language = 'auto',
    this.autoTranscribeMaxDurationMs = 5 * 60 * 1000,
    this.remoteChunkMaxDurationMs = 120 * 1000,
    this.wifiOnlyModelDownload = true,
    this.remoteConsentGranted = false,
    this.mimoAsrProviderId = 'mimo_asr',
    this.mimoAsrEndpoint = 'https://api.xiaomimimo.com/v1/chat/completions',
    this.mimoAsrModel = 'mimo-v2.5-asr',
    this.correctionMode = TranscriptCorrectionMode.autoApplyHighConfidence,
    this.lastErrorCode,
    this.lastErrorMessage,
  });

  factory VoiceTranscriptionSettings.fromJson(Map<String, Object?> json) {
    final rawEngine = _stringValue(json['engine']);
    final oldProviderMode = _enumByWireName(
      VoiceTranscriptionProviderMode.values,
      json['provider_mode'],
      fallback: VoiceTranscriptionProviderMode.localOnly,
    );
    final engine = rawEngine == null
        ? _engineFromLegacyProviderMode(oldProviderMode)
        : _enumByWireName(
            VoiceTranscriptionEngine.values,
            rawEngine,
            fallback: VoiceTranscriptionEngine.localSenseVoice,
          );
    final remoteConsentGranted = rawEngine == null
        ? false
        : json['remote_consent_granted'] == true;
    return VoiceTranscriptionSettings(
      localModelState: _enumByWireName(
        LocalTranscriptionModelState.values,
        json['local_model_state'],
        fallback: LocalTranscriptionModelState.notDownloaded,
      ),
      downloadProgress: _intValue(json['download_progress']) ?? 0,
      providerMode: _providerModeForEngine(engine),
      engine: engine,
      realtimePreviewEnabled: json['realtime_preview_enabled'] != false,
      language: _stringValue(json['language']) ?? 'auto',
      autoTranscribeMaxDurationMs:
          _intValue(json['auto_transcribe_max_duration_ms']) ?? 5 * 60 * 1000,
      remoteChunkMaxDurationMs:
          _intValue(json['remote_chunk_max_duration_ms']) ?? 120 * 1000,
      wifiOnlyModelDownload: json['wifi_only_model_download'] != false,
      remoteConsentGranted: remoteConsentGranted,
      mimoAsrProviderId:
          _stringValue(json['mimo_asr_provider_id']) ?? 'mimo_asr',
      mimoAsrEndpoint:
          _stringValue(json['mimo_asr_endpoint']) ??
          'https://api.xiaomimimo.com/v1/chat/completions',
      mimoAsrModel: _stringValue(json['mimo_asr_model']) ?? 'mimo-v2.5-asr',
      correctionMode: _enumByWireName(
        TranscriptCorrectionMode.values,
        json['correction_mode'],
        fallback: TranscriptCorrectionMode.autoApplyHighConfidence,
      ),
      lastErrorCode: _stringValue(json['last_error_code']),
      lastErrorMessage: _stringValue(json['last_error_message']),
    );
  }

  final LocalTranscriptionModelState localModelState;
  final int downloadProgress;
  final VoiceTranscriptionProviderMode providerMode;
  final VoiceTranscriptionEngine engine;
  final bool realtimePreviewEnabled;
  final String language;
  final int autoTranscribeMaxDurationMs;
  final int remoteChunkMaxDurationMs;
  final bool wifiOnlyModelDownload;
  final bool remoteConsentGranted;
  final String mimoAsrProviderId;
  final String mimoAsrEndpoint;
  final String mimoAsrModel;
  final TranscriptCorrectionMode correctionMode;
  final String? lastErrorCode;
  final String? lastErrorMessage;

  bool get remoteAsrEnabled =>
      remoteConsentGranted && engine == VoiceTranscriptionEngine.xiaomiMimo;

  bool get mimoAsrEnabled => remoteAsrEnabled;

  bool get localSenseVoiceEnabled =>
      engine == VoiceTranscriptionEngine.localSenseVoice;

  VoiceTranscriptionSettings copyWith({
    LocalTranscriptionModelState? localModelState,
    int? downloadProgress,
    VoiceTranscriptionProviderMode? providerMode,
    VoiceTranscriptionEngine? engine,
    bool? realtimePreviewEnabled,
    String? language,
    int? autoTranscribeMaxDurationMs,
    int? remoteChunkMaxDurationMs,
    bool? wifiOnlyModelDownload,
    bool? remoteConsentGranted,
    String? mimoAsrProviderId,
    String? mimoAsrEndpoint,
    String? mimoAsrModel,
    TranscriptCorrectionMode? correctionMode,
    String? lastErrorCode,
    String? lastErrorMessage,
    bool clearError = false,
  }) {
    final nextEngine =
        engine ??
        (providerMode == null
            ? this.engine
            : _engineFromLegacyProviderMode(providerMode));
    return VoiceTranscriptionSettings(
      localModelState: localModelState ?? this.localModelState,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      providerMode: _providerModeForEngine(nextEngine),
      engine: nextEngine,
      realtimePreviewEnabled:
          realtimePreviewEnabled ?? this.realtimePreviewEnabled,
      language: language ?? this.language,
      autoTranscribeMaxDurationMs:
          autoTranscribeMaxDurationMs ?? this.autoTranscribeMaxDurationMs,
      remoteChunkMaxDurationMs:
          remoteChunkMaxDurationMs ?? this.remoteChunkMaxDurationMs,
      wifiOnlyModelDownload:
          wifiOnlyModelDownload ?? this.wifiOnlyModelDownload,
      remoteConsentGranted: remoteConsentGranted ?? this.remoteConsentGranted,
      mimoAsrProviderId: mimoAsrProviderId ?? this.mimoAsrProviderId,
      mimoAsrEndpoint: mimoAsrEndpoint ?? this.mimoAsrEndpoint,
      mimoAsrModel: mimoAsrModel ?? this.mimoAsrModel,
      correctionMode: correctionMode ?? this.correctionMode,
      lastErrorCode: clearError ? null : lastErrorCode ?? this.lastErrorCode,
      lastErrorMessage: clearError
          ? null
          : lastErrorMessage ?? this.lastErrorMessage,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'local_model_state': localModelState.wireName,
      'download_progress': downloadProgress,
      'engine': engine.wireName,
      'provider_mode': providerMode.wireName,
      'realtime_preview_enabled': realtimePreviewEnabled,
      'language': language,
      'auto_transcribe_max_duration_ms': autoTranscribeMaxDurationMs,
      'remote_chunk_max_duration_ms': remoteChunkMaxDurationMs,
      'wifi_only_model_download': wifiOnlyModelDownload,
      'remote_consent_granted': remoteConsentGranted,
      'mimo_asr_provider_id': mimoAsrProviderId,
      'mimo_asr_endpoint': mimoAsrEndpoint,
      'mimo_asr_model': mimoAsrModel,
      'correction_mode': correctionMode.wireName,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (lastErrorMessage != null) 'last_error_message': lastErrorMessage,
    };
  }
}

abstract interface class VoiceTranscriptionSettingsRepository {
  Future<VoiceTranscriptionSettings> load();

  Future<void> save(VoiceTranscriptionSettings settings);
}

final class JsonFileVoiceTranscriptionSettingsRepository
    implements VoiceTranscriptionSettingsRepository {
  const JsonFileVoiceTranscriptionSettingsRepository({
    required Directory supportDirectory,
  }) : _supportDirectory = supportDirectory;

  final Directory _supportDirectory;

  File get _settingsFile {
    return File(
      p.join(
        _supportDirectory.path,
        'local-data',
        'voice-transcription-settings.json',
      ),
    );
  }

  @override
  Future<VoiceTranscriptionSettings> load() async {
    final file = _settingsFile;
    if (!file.existsSync()) {
      return const VoiceTranscriptionSettings();
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) {
        return VoiceTranscriptionSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return VoiceTranscriptionSettings.fromJson(
          decoded.cast<String, Object?>(),
        );
      }
    } on Object {
      return const VoiceTranscriptionSettings(
        localModelState: LocalTranscriptionModelState.failed,
        lastErrorCode: 'settings_decode_failed',
        lastErrorMessage: 'Voice transcription settings could not be read.',
      );
    }
    return const VoiceTranscriptionSettings();
  }

  @override
  Future<void> save(VoiceTranscriptionSettings settings) async {
    final file = _settingsFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}

final class MemoryVoiceTranscriptionSettingsRepository
    implements VoiceTranscriptionSettingsRepository {
  MemoryVoiceTranscriptionSettingsRepository([
    VoiceTranscriptionSettings? initial,
  ]) : _settings = initial ?? const VoiceTranscriptionSettings();

  VoiceTranscriptionSettings _settings;

  @override
  Future<VoiceTranscriptionSettings> load() async => _settings;

  @override
  Future<void> save(VoiceTranscriptionSettings settings) async {
    _settings = settings;
  }
}

abstract interface class TranscriptionCredentialStore {
  Future<String?> readMimoAsrApiKey();

  Future<void> writeMimoAsrApiKey(String value);

  Future<void> deleteMimoAsrApiKey();
}

final class SecureTranscriptionCredentialStore
    implements TranscriptionCredentialStore {
  const SecureTranscriptionCredentialStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  static const _mimoKey = 'voice_transcription.mimo_asr.api_key';

  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> readMimoAsrApiKey() => _secureStorage.read(key: _mimoKey);

  @override
  Future<void> writeMimoAsrApiKey(String value) {
    return _secureStorage.write(key: _mimoKey, value: value);
  }

  @override
  Future<void> deleteMimoAsrApiKey() {
    return _secureStorage.delete(key: _mimoKey);
  }
}

final class MemoryTranscriptionCredentialStore
    implements TranscriptionCredentialStore {
  MemoryTranscriptionCredentialStore([this._apiKey]);

  String? _apiKey;

  @override
  Future<String?> readMimoAsrApiKey() async => _apiKey;

  @override
  Future<void> writeMimoAsrApiKey(String value) async {
    _apiKey = value;
  }

  @override
  Future<void> deleteMimoAsrApiKey() async {
    _apiKey = null;
  }
}

VoiceTranscriptionEngine _engineFromLegacyProviderMode(
  VoiceTranscriptionProviderMode mode,
) {
  return switch (mode) {
    VoiceTranscriptionProviderMode.localOnly ||
    VoiceTranscriptionProviderMode.localFirstRemoteAuto ||
    VoiceTranscriptionProviderMode.remoteDisabled =>
      VoiceTranscriptionEngine.localSenseVoice,
  };
}

VoiceTranscriptionProviderMode _providerModeForEngine(
  VoiceTranscriptionEngine engine,
) {
  return switch (engine) {
    VoiceTranscriptionEngine.localSenseVoice =>
      VoiceTranscriptionProviderMode.localOnly,
    VoiceTranscriptionEngine.xiaomiMimo =>
      VoiceTranscriptionProviderMode.localFirstRemoteAuto,
    VoiceTranscriptionEngine.disabled =>
      VoiceTranscriptionProviderMode.remoteDisabled,
  };
}

T _enumByWireName<T extends Enum>(
  Iterable<T> values,
  Object? value, {
  required T fallback,
}) {
  final text = _stringValue(value);
  if (text == null) {
    return fallback;
  }
  for (final item in values) {
    final dynamic candidate = item;
    if (candidate.wireName == text || item.name == text) {
      return item;
    }
  }
  return fallback;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _intValue(Object? value) {
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
