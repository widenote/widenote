import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/capture/application/capture_agent_prompts.dart';
import 'package:widenote_mobile/features/location/application/location_capture_service.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/features/location/domain/location_context.dart';
import 'package:widenote_mobile/features/location/presentation/location_settings_page.dart';
import 'package:widenote_mobile/features/timeline/application/timeline_repository.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  group('AMap reverse geocoding', () {
    test('builds official regeo request and stores returned address', () async {
      final httpClient = _FakeAmapClient(_amapSuccessBody);
      final geocoder = AmapReverseGeocoder(
        httpClient: httpClient,
        clock: () => DateTime.utc(2026, 7, 1, 10),
      );

      final snapshot = await geocoder.reverseGeocode(
        _sampleDeviceLocation(),
        settings: const LocationCaptureSettings(
          saveGps: true,
          useAmapReverseGeocode: true,
          amapApiKey: 'test-key',
        ),
        timeout: const Duration(seconds: 2),
      );

      final uri = httpClient.requestedUri!;
      expect(uri.scheme, 'https');
      expect(uri.host, 'restapi.amap.com');
      expect(uri.path, '/v3/geocode/regeo');
      expect(uri.queryParameters['key'], 'test-key');
      expect(uri.queryParameters['extensions'], 'base');
      expect(uri.queryParameters['output'], 'json');
      expect(uri.queryParameters['roadlevel'], '1');

      final locationParts = uri.queryParameters['location']!.split(',');
      expect(locationParts, hasLength(2));
      expect(double.parse(locationParts.first), isNot(121.473701));
      expect(double.parse(locationParts.last), isNot(31.230416));

      expect(snapshot.status, ReverseGeocodeStatus.success);
      expect(snapshot.coordinateSystem, 'GCJ-02');
      expect(snapshot.address!.city, '上海市');
      expect(snapshot.address!.district, '黄浦区');
      expect(
        snapshot.address!.summary(LocationDisplayGranularity.district),
        '上海市 · 黄浦区',
      );
    });

    test(
      'skips AMap when key is missing and preserves WGS-84 coordinates',
      () async {
        final httpClient = _FakeAmapClient(_amapSuccessBody);
        final geocoder = AmapReverseGeocoder(httpClient: httpClient);

        final snapshot = await geocoder.reverseGeocode(
          _sampleDeviceLocation(),
          settings: const LocationCaptureSettings(
            saveGps: true,
            useAmapReverseGeocode: true,
          ),
          timeout: const Duration(seconds: 2),
        );

        expect(snapshot.status, ReverseGeocodeStatus.skippedMissingKey);
        expect(snapshot.reason, 'amap_api_key_missing');
        expect(httpClient.requestedUri, isNull);

        final sanFrancisco = wgs84ToGcj02(37.7749, -122.4194);
        expect(sanFrancisco.latitude, 37.7749);
        expect(sanFrancisco.longitude, -122.4194);
      },
    );
  });

  test(
    'service returns unavailable context without blocking capture',
    () async {
      final repository = InMemoryLocationSettingsRepository(
        const LocationCaptureSettings(saveGps: true),
      );
      final service = LocationCaptureService(
        settingsRepository: repository,
        deviceLocationClient: const _UnavailableDeviceLocationClient(
          'location_permission_denied',
        ),
        reverseGeocoder: AmapReverseGeocoder(
          httpClient: _FakeAmapClient(_amapSuccessBody),
        ),
        clock: () => DateTime.utc(2026, 7, 1, 10),
      );

      final context = await service.captureForRecord();

      expect(context, isNotNull);
      expect(context!.status, LocationCaptureStatus.unavailable);
      expect(context.reason, 'location_permission_denied');
      expect(context.deviceLocation, isNull);
    },
  );

  testWidgets('settings page separates GPS, AMap, preview, and clearing', (
    tester,
  ) async {
    final database = localdb.WideNoteLocalDatabase.inMemory();
    final repository = InMemoryLocationSettingsRepository();
    final httpClient = _FakeAmapClient(_amapSuccessBody);
    addTearDown(database.close);

    database.captures.save(
      localdb.CaptureRecord(
        id: 'capture-with-location',
        sourceType: 'manual',
        payload: <String, Object?>{
          'text': 'Keep the record, clear only location.',
          'location_context': _availableLocationContext().toJson(),
          'fact_metadata': <String, Object?>{
            'location': _availableLocationContext().toFactMetadata(),
          },
        },
        createdAt: DateTime.utc(2026, 7, 1, 10),
        updatedAt: DateTime.utc(2026, 7, 1, 10),
      ),
    );

    await _pumpLocationSettingsPage(
      tester,
      database: database,
      repository: repository,
      httpClient: httpClient,
    );

    expect(find.text('GPS capture off'), findsOneWidget);
    expect(find.text('AMap lookup off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('location-save-gps-switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('location-amap-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-amap-switch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('location-amap-key-field')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('location-amap-key-field')),
      'test-key',
    );
    await tester.pumpAndSettle();

    final saved = await repository.load();
    expect(saved.saveGps, isTrue);
    expect(saved.useAmapReverseGeocode, isTrue);
    expect(saved.amapApiKey, 'test-key');
    expect(find.text('GPS capture on'), findsOneWidget);
    expect(find.text('AMap lookup on'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('location-test-button')));
    await tester.tap(find.byKey(const Key('location-test-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location-test-result')), findsOneWidget);
    expect(find.text('Location captured.'), findsOneWidget);
    expect(find.text('Area: 上海市 · 黄浦区'), findsOneWidget);
    expect(
      find.text('GPS coordinates saved on the local record.'),
      findsOneWidget,
    );
    expect(find.textContaining('人民大道'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const Key('location-clear-saved-button')),
    );
    await tester.tap(find.byKey(const Key('location-clear-saved-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-clear-confirm-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Cleared location metadata from 1 records.'),
      findsOneWidget,
    );
    expect(
      database.captures.readAll().single.payload.containsKey(
        'location_context',
      ),
      isFalse,
    );
    expect(
      database.captures.readAll().single.payload.containsKey('fact_metadata'),
      isFalse,
    );
  });

  testWidgets(
    'quick capture persists location payload and shows coarse row text',
    (tester) async {
      final database = localdb.WideNoteLocalDatabase.inMemory();
      final repository = InMemoryLocationSettingsRepository(
        const LocationCaptureSettings(
          saveGps: true,
          useAmapReverseGeocode: true,
          amapApiKey: 'test-key',
        ),
      );
      addTearDown(database.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(database),
            modelClientProvider.overrideWithValue(const _CaptureTestModel()),
            locationSettingsRepositoryProvider.overrideWithValue(repository),
            deviceLocationClientProvider.overrideWithValue(
              const _FakeDeviceLocationClient(),
            ),
            amapReverseGeocodeHttpClientProvider.overrideWithValue(
              _FakeAmapClient(_amapSuccessBody),
            ),
          ],
          child: const WideNoteApp(locale: Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      await _submitQuickCapture(tester, 'Lunch near the office.');

      final capture = database.captures.readAll().single;
      final location = capture.payload['location_context']! as Map;
      expect(location['status'], 'available');
      final device = location['device_location']! as Map;
      expect(device['latitude'], 31.230416);
      expect(device['longitude'], 121.473701);
      expect(device['coordinate_system'], 'WGS-84');

      final factMetadata = capture.payload['fact_metadata']! as Map;
      final locationFact = factMetadata['location']! as Map;
      expect(locationFact['kind'], 'location');
      expect(locationFact['sensitivity'], 'high');
      expect(locationFact['status'], 'available');
      final sourceRefs = locationFact['source_refs']! as List;
      expect(sourceRefs.first, containsPair('kind', 'capture'));
      expect(sourceRefs.first, containsPair('id', capture.id));
      expect(
        sourceRefs.first,
        containsPair('path', 'payload.location_context'),
      );
      final factCoordinate = locationFact['coordinate']! as Map;
      expect(factCoordinate['fact_role'], 'source_coordinate');
      expect(factCoordinate['latitude'], 31.230416);
      expect(factCoordinate['longitude'], 121.473701);
      expect(factCoordinate['coordinate_system'], 'WGS-84');
      final factPlace = locationFact['place']! as Map;
      expect(factPlace['fact_role'], 'derived_place');
      expect(factPlace['derived_from'], 'fact_metadata.location.coordinate');
      expect(factPlace['provider'], 'amap');
      expect(factPlace['place_name'], '上海市黄浦区人民大道');
      expect(factPlace['display_name'], '上海市 · 黄浦区');
      expect(
        ((factPlace['provider_specific']! as Map)['amap']! as Map)['adcode'],
        '310101',
      );

      final captureEvent = database.eventLog
          .readByType(runtime.WnEventTypes.captureCreated)
          .single;
      expect(captureEvent.payload.containsKey('location_context'), isFalse);
      expect(jsonEncode(captureEvent.payload), isNot(contains('31.230416')));

      final timelineItem = (await LocalDbTimelineRepository(
        database,
      ).loadSnapshot()).itemById(capture.id)!;
      expect(timelineItem.metadata['location_latitude'], 31.230416);
      expect(timelineItem.metadata['location_longitude'], 121.473701);
      expect(timelineItem.metadata['location_coordinate_system'], 'WGS-84');
      expect(timelineItem.metadata['location_place_name'], '上海市黄浦区人民大道');
      expect(timelineItem.metadata['location_display_name'], '上海市 · 黄浦区');
      expect((timelineItem.metadata['location']! as Map)['kind'], 'location');

      final locationLabel = find.textContaining('Location: 上海市 · 黄浦区');
      if (locationLabel.evaluate().isEmpty &&
          find.byType(Scrollable).evaluate().isNotEmpty) {
        final scrollable = find.byType(Scrollable).first;
        for (var i = 0; i < 8 && locationLabel.evaluate().isEmpty; i++) {
          await tester.drag(scrollable, const Offset(0, -220));
          await tester.pumpAndSettle();
        }
      }
      expect(locationLabel, findsOneWidget);
    },
  );
}

Future<void> _pumpLocationSettingsPage(
  WidgetTester tester, {
  required localdb.WideNoteLocalDatabase database,
  required InMemoryLocationSettingsRepository repository,
  required AmapReverseGeocodeHttpClient httpClient,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        locationSettingsRepositoryProvider.overrideWithValue(repository),
        deviceLocationClientProvider.overrideWithValue(
          const _FakeDeviceLocationClient(),
        ),
        amapReverseGeocodeHttpClientProvider.overrideWithValue(httpClient),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LocationSettingsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitQuickCapture(WidgetTester tester, String text) async {
  await tester.tap(find.byKey(const Key('tab-record-action')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('quick-capture-field')), text);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('record-capture-button')));
  await tester.tap(find.byKey(const Key('record-capture-button')));
  await tester.pumpAndSettle();
}

CapturedLocationContext _availableLocationContext() {
  return CapturedLocationContext(
    status: LocationCaptureStatus.available,
    deviceLocation: _sampleDeviceLocation(),
    reverseGeocode: ReverseGeocodeSnapshot(
      provider: ReverseGeocodeSnapshot.amapProvider,
      status: ReverseGeocodeStatus.success,
      address: const GeocodedAddress(
        province: '上海市',
        city: '上海市',
        district: '黄浦区',
        formattedAddress: '上海市黄浦区人民大道',
      ),
      updatedAt: DateTime.utc(2026, 7, 1, 10),
    ),
    displayGranularity: LocationDisplayGranularity.district,
    createdAt: DateTime.utc(2026, 7, 1, 10),
  );
}

DeviceLocationSnapshot _sampleDeviceLocation() {
  return DeviceLocationSnapshot(
    latitude: 31.230416,
    longitude: 121.473701,
    accuracyMeters: 12,
    capturedAt: DateTime.utc(2026, 7, 1, 10),
  );
}

const _amapSuccessBody = '''
{
  "status": "1",
  "info": "OK",
  "infocode": "10000",
  "regeocode": {
    "formatted_address": "上海市黄浦区人民大道",
    "addressComponent": {
      "country": "中国",
      "province": "上海市",
      "city": [],
      "district": "黄浦区",
      "township": "南京东路街道",
      "adcode": "310101",
      "citycode": "021",
      "neighborhood": {"name": "人民广场"},
      "streetNumber": {"street": "人民大道"}
    }
  }
}
''';

final class _FakeAmapClient implements AmapReverseGeocodeHttpClient {
  _FakeAmapClient(this.body);

  final String body;
  Uri? requestedUri;

  @override
  Future<AmapHttpResponse> get(Uri uri, {required Duration timeout}) async {
    requestedUri = uri;
    return AmapHttpResponse(statusCode: 200, body: body);
  }
}

final class _FakeDeviceLocationClient implements DeviceLocationClient {
  const _FakeDeviceLocationClient();

  @override
  Future<DeviceLocationSnapshot> getCurrentLocation({
    required Duration timeout,
  }) async {
    return _sampleDeviceLocation();
  }
}

final class _UnavailableDeviceLocationClient implements DeviceLocationClient {
  const _UnavailableDeviceLocationClient(this.reason);

  final String reason;

  @override
  Future<DeviceLocationSnapshot> getCurrentLocation({
    required Duration timeout,
  }) {
    throw LocationUnavailableException(reason);
  }
}

final class _CaptureTestModel implements runtime.ModelClient {
  const _CaptureTestModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    return runtime.ModelResponse(
      text: _captureText(request.prompt),
      raw: const <String, Object?>{
        'memory_type': 'task_context',
        'confidence': 'high',
        'sensitivity': 'low',
        'durability': 'durable',
      },
    );
  }
}

String _captureText(String prompt) {
  final markerIndex = prompt.indexOf(captureMemoryPromptCaptureTextMarker);
  if (markerIndex == -1) {
    return prompt.replaceFirst('Summarize capture for Memory: ', '').trim();
  }
  return prompt
      .substring(markerIndex + captureMemoryPromptCaptureTextMarker.length)
      .trim();
}
