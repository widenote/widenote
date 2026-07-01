import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../domain/location_context.dart';
import 'location_capture_service.dart';

final locationSettingsRepositoryProvider = Provider<LocationSettingsRepository>(
  (ref) {
    return const SecureStorageLocationSettingsRepository();
  },
);

final deviceLocationClientProvider = Provider<DeviceLocationClient>((ref) {
  return GeolocatorDeviceLocationClient();
});

final amapReverseGeocodeHttpClientProvider =
    Provider<AmapReverseGeocodeHttpClient>((ref) {
      return const DartIoAmapReverseGeocodeHttpClient();
    });

final amapReverseGeocoderProvider = Provider<AmapReverseGeocoder>((ref) {
  return AmapReverseGeocoder(
    httpClient: ref.watch(amapReverseGeocodeHttpClientProvider),
  );
});

final locationCaptureServiceProvider = Provider<LocationCaptureService>((ref) {
  return LocationCaptureService(
    settingsRepository: ref.watch(locationSettingsRepositoryProvider),
    deviceLocationClient: ref.watch(deviceLocationClientProvider),
    reverseGeocoder: ref.watch(amapReverseGeocoderProvider),
  );
});

final locationSettingsControllerProvider =
    AsyncNotifierProvider<LocationSettingsController, LocationSettingsState>(
      LocationSettingsController.new,
    );

final class LocationSettingsState {
  const LocationSettingsState({
    required this.settings,
    this.testContext,
    this.isTesting = false,
    this.clearedLocationCount,
    this.errorMessage,
  });

  final LocationCaptureSettings settings;
  final CapturedLocationContext? testContext;
  final bool isTesting;
  final int? clearedLocationCount;
  final String? errorMessage;

  LocationSettingsState copyWith({
    LocationCaptureSettings? settings,
    CapturedLocationContext? testContext,
    bool clearTestContext = false,
    bool? isTesting,
    int? clearedLocationCount,
    bool clearClearedLocationCount = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LocationSettingsState(
      settings: settings ?? this.settings,
      testContext: clearTestContext ? null : testContext ?? this.testContext,
      isTesting: isTesting ?? this.isTesting,
      clearedLocationCount: clearClearedLocationCount
          ? null
          : clearedLocationCount ?? this.clearedLocationCount,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final class LocationSettingsController
    extends AsyncNotifier<LocationSettingsState> {
  @override
  FutureOr<LocationSettingsState> build() async {
    final settings = await ref.watch(locationSettingsRepositoryProvider).load();
    return LocationSettingsState(settings: settings);
  }

  Future<void> setSaveGps(bool enabled) async {
    final current = await _currentState();
    final nextSettings = current.settings.copyWith(saveGps: enabled);
    await _save(nextSettings);
    state = AsyncData(
      current.copyWith(
        settings: nextSettings,
        clearTestContext: true,
        clearClearedLocationCount: true,
        clearError: true,
      ),
    );
  }

  Future<void> setUseAmapReverseGeocode(bool enabled) async {
    final current = await _currentState();
    final nextSettings = current.settings.copyWith(
      saveGps: enabled ? true : current.settings.saveGps,
      useAmapReverseGeocode: enabled,
    );
    await _save(nextSettings);
    state = AsyncData(
      current.copyWith(
        settings: nextSettings,
        clearTestContext: true,
        clearClearedLocationCount: true,
        clearError: true,
      ),
    );
  }

  Future<void> setAmapApiKey(String value) async {
    final current = await _currentState();
    final nextSettings = current.settings.copyWith(amapApiKey: value.trim());
    await _save(nextSettings);
    state = AsyncData(
      current.copyWith(
        settings: nextSettings,
        clearTestContext: true,
        clearClearedLocationCount: true,
        clearError: true,
      ),
    );
  }

  Future<void> setDisplayGranularity(
    LocationDisplayGranularity granularity,
  ) async {
    final current = await _currentState();
    final nextSettings = current.settings.copyWith(
      displayGranularity: granularity,
    );
    await _save(nextSettings);
    state = AsyncData(
      current.copyWith(
        settings: nextSettings,
        clearTestContext: true,
        clearClearedLocationCount: true,
        clearError: true,
      ),
    );
  }

  Future<void> testCurrentLocation() async {
    final current = await _currentState();
    state = AsyncData(
      current.copyWith(
        isTesting: true,
        clearTestContext: true,
        clearClearedLocationCount: true,
        clearError: true,
      ),
    );
    try {
      final context = await ref
          .read(locationCaptureServiceProvider)
          .captureForRecord();
      state = AsyncData(
        current.copyWith(
          testContext: context,
          isTesting: false,
          clearClearedLocationCount: true,
          errorMessage: context == null ? 'location_disabled' : null,
          clearError: context != null,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isTesting: false,
          clearTestContext: true,
          clearClearedLocationCount: true,
          errorMessage: '$error',
        ),
      );
    }
  }

  Future<void> clearSavedCaptureLocations() async {
    final current = await _currentState();
    final database = ref.read(localDatabaseProvider);
    var cleared = 0;
    for (final capture in database.captures.readAll()) {
      final payload = <String, Object?>{...capture.payload};
      final removedLocationContext = payload.remove('location_context') != null;
      final removedLocationFact = _removeLocationFact(payload);
      if (!removedLocationContext && !removedLocationFact) {
        continue;
      }
      database.captures.save(
        localdb.CaptureRecord(
          id: capture.id,
          schemaVersion: capture.schemaVersion,
          sourceType: capture.sourceType,
          sourceId: capture.sourceId,
          status: capture.status,
          payload: payload,
          createdAt: capture.createdAt,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      cleared++;
    }
    state = AsyncData(
      current.copyWith(
        clearedLocationCount: cleared,
        clearTestContext: true,
        clearError: true,
      ),
    );
  }

  Future<LocationSettingsState> _currentState() async {
    final value = state.valueOrNull;
    if (value != null) {
      return value;
    }
    final settings = await ref.read(locationSettingsRepositoryProvider).load();
    return LocationSettingsState(settings: settings);
  }

  Future<void> _save(LocationCaptureSettings settings) {
    return ref.read(locationSettingsRepositoryProvider).save(settings);
  }
}

bool _removeLocationFact(Map<String, Object?> payload) {
  final rawFacts = payload['fact_metadata'];
  if (rawFacts is! Map) {
    return false;
  }
  final facts = Map<String, Object?>.from(rawFacts.cast<String, Object?>());
  if (!facts.containsKey('location')) {
    return false;
  }
  facts.remove('location');
  if (facts.isEmpty) {
    payload.remove('fact_metadata');
  } else {
    payload['fact_metadata'] = Map<String, Object?>.unmodifiable(facts);
  }
  return true;
}

final class SecureStorageLocationSettingsRepository
    implements LocationSettingsRepository {
  const SecureStorageLocationSettingsRepository({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _settingsKey = 'widenote.location_context.settings.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<LocationCaptureSettings> load() async {
    try {
      final raw = await _storage.read(key: _settingsKey);
      if (raw == null || raw.trim().isEmpty) {
        return const LocationCaptureSettings();
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return LocationCaptureSettings.fromJson(
          decoded.cast<String, Object?>(),
        );
      }
    } catch (_) {
      return const LocationCaptureSettings();
    }
    return const LocationCaptureSettings();
  }

  @override
  Future<void> save(LocationCaptureSettings settings) {
    return _storage.write(
      key: _settingsKey,
      value: jsonEncode(settings.toJson()),
    );
  }
}

final class InMemoryLocationSettingsRepository
    implements LocationSettingsRepository {
  InMemoryLocationSettingsRepository([LocationCaptureSettings? initial])
    : _settings = initial ?? const LocationCaptureSettings();

  LocationCaptureSettings _settings;

  @override
  Future<LocationCaptureSettings> load() async => _settings;

  @override
  Future<void> save(LocationCaptureSettings settings) async {
    _settings = settings;
  }
}
