import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart' as geo;

import '../domain/location_context.dart';

abstract interface class LocationSettingsRepository {
  Future<LocationCaptureSettings> load();

  Future<void> save(LocationCaptureSettings settings);
}

abstract interface class DeviceLocationClient {
  Future<DeviceLocationSnapshot> getCurrentLocation({
    required Duration timeout,
  });
}

abstract interface class AmapReverseGeocodeHttpClient {
  Future<AmapHttpResponse> get(Uri uri, {required Duration timeout});
}

final class AmapHttpResponse {
  const AmapHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

final class LocationCaptureService {
  LocationCaptureService({
    required LocationSettingsRepository settingsRepository,
    required DeviceLocationClient deviceLocationClient,
    required AmapReverseGeocoder reverseGeocoder,
    DateTime Function()? clock,
    this.locationTimeout = const Duration(seconds: 4),
    this.reverseGeocodeTimeout = const Duration(seconds: 4),
  }) : _settingsRepository = settingsRepository,
       _deviceLocationClient = deviceLocationClient,
       _reverseGeocoder = reverseGeocoder,
       _clock = clock ?? DateTime.now;

  final LocationSettingsRepository _settingsRepository;
  final DeviceLocationClient _deviceLocationClient;
  final AmapReverseGeocoder _reverseGeocoder;
  final DateTime Function() _clock;
  final Duration locationTimeout;
  final Duration reverseGeocodeTimeout;

  Future<CapturedLocationContext?> captureForRecord() async {
    final settings = await _settingsRepository.load();
    if (!settings.saveGps) {
      return null;
    }

    final now = _clock().toUtc();
    DeviceLocationSnapshot deviceLocation;
    try {
      deviceLocation = await _deviceLocationClient.getCurrentLocation(
        timeout: locationTimeout,
      );
    } on LocationUnavailableException catch (error) {
      return CapturedLocationContext(
        status: LocationCaptureStatus.unavailable,
        displayGranularity: settings.displayGranularity,
        reason: error.reason,
        createdAt: now,
      );
    } catch (_) {
      return CapturedLocationContext(
        status: LocationCaptureStatus.unavailable,
        displayGranularity: settings.displayGranularity,
        reason: 'device_location_failed',
        createdAt: now,
      );
    }

    final reverseGeocode = await _reverseGeocoder.reverseGeocode(
      deviceLocation,
      settings: settings,
      timeout: reverseGeocodeTimeout,
    );
    return CapturedLocationContext(
      status: LocationCaptureStatus.available,
      deviceLocation: deviceLocation,
      reverseGeocode: reverseGeocode,
      displayGranularity: settings.displayGranularity,
      createdAt: now,
    );
  }
}

final class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.reason);

  final String reason;

  @override
  String toString() => 'LocationUnavailableException: $reason';
}

final class GeolocatorDeviceLocationClient implements DeviceLocationClient {
  GeolocatorDeviceLocationClient({
    LocationServiceEnabledReader? isLocationServiceEnabled,
    LocationPermissionReader? checkPermission,
    LocationPermissionReader? requestPermission,
    DevicePositionReader? getCurrentPosition,
    LastKnownDevicePositionReader? getLastKnownPosition,
    DateTime Function()? clock,
  }) : _isLocationServiceEnabled =
           isLocationServiceEnabled ?? geo.Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? geo.Geolocator.checkPermission,
       _requestPermission =
           requestPermission ?? geo.Geolocator.requestPermission,
       _getCurrentPosition = getCurrentPosition ?? _defaultGetCurrentPosition,
       _getLastKnownPosition =
           getLastKnownPosition ?? geo.Geolocator.getLastKnownPosition,
       _clock = clock ?? DateTime.now;

  static const _maxLastKnownAge = Duration(minutes: 2);

  final LocationServiceEnabledReader _isLocationServiceEnabled;
  final LocationPermissionReader _checkPermission;
  final LocationPermissionReader _requestPermission;
  final DevicePositionReader _getCurrentPosition;
  final LastKnownDevicePositionReader _getLastKnownPosition;
  final DateTime Function() _clock;

  @override
  Future<DeviceLocationSnapshot> getCurrentLocation({
    required Duration timeout,
  }) async {
    final serviceEnabled = await _isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationUnavailableException('location_service_disabled');
    }

    var permission = await _checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await _requestPermission();
    }
    if (!_isUsablePermission(permission)) {
      throw LocationUnavailableException(_permissionReason(permission));
    }

    try {
      final position = await _getCurrentPosition(
        geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: timeout,
        ),
      ).timeout(timeout);
      return _snapshotFromPosition(position);
    } on TimeoutException {
      final lastKnown = await _recentLastKnownLocation();
      if (lastKnown != null) {
        return lastKnown;
      }
      throw const LocationUnavailableException('location_timeout');
    } catch (_) {
      final lastKnown = await _recentLastKnownLocation();
      if (lastKnown != null) {
        return lastKnown;
      }
      throw const LocationUnavailableException('device_location_failed');
    }
  }

  Future<DeviceLocationSnapshot?> _recentLastKnownLocation() async {
    final position = await _getLastKnownPosition().timeout(
      const Duration(milliseconds: 700),
      onTimeout: () => null,
    );
    if (position == null) {
      return null;
    }
    final age = _clock().difference(position.timestamp);
    if (age > _maxLastKnownAge) {
      return null;
    }
    return _snapshotFromPosition(
      position,
      source: DeviceLocationSnapshot.lastKnownDeviceGpsSource,
    );
  }

  DeviceLocationSnapshot _snapshotFromPosition(
    geo.Position position, {
    String source = DeviceLocationSnapshot.deviceGpsSource,
  }) {
    return DeviceLocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      source: source,
      capturedAt: position.timestamp.toUtc(),
    );
  }

  bool _isUsablePermission(geo.LocationPermission permission) {
    return permission == geo.LocationPermission.whileInUse ||
        permission == geo.LocationPermission.always;
  }

  String _permissionReason(geo.LocationPermission permission) {
    return switch (permission) {
      geo.LocationPermission.denied => 'location_permission_denied',
      geo.LocationPermission.deniedForever =>
        'location_permission_denied_forever',
      geo.LocationPermission.unableToDetermine => 'location_permission_unknown',
      _ => 'location_permission_unavailable',
    };
  }
}

typedef LocationServiceEnabledReader = Future<bool> Function();
typedef LocationPermissionReader = Future<geo.LocationPermission> Function();
typedef DevicePositionReader =
    Future<geo.Position> Function(geo.LocationSettings settings);
typedef LastKnownDevicePositionReader = Future<geo.Position?> Function();

Future<geo.Position> _defaultGetCurrentPosition(geo.LocationSettings settings) {
  return geo.Geolocator.getCurrentPosition(locationSettings: settings);
}

final class DartIoAmapReverseGeocodeHttpClient
    implements AmapReverseGeocodeHttpClient {
  const DartIoAmapReverseGeocodeHttpClient({HttpClient? httpClient})
    : _httpClient = httpClient;

  final HttpClient? _httpClient;

  @override
  Future<AmapHttpResponse> get(Uri uri, {required Duration timeout}) async {
    final client = _httpClient ?? HttpClient();
    final request = await client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);
    if (_httpClient == null) {
      client.close(force: true);
    }
    return AmapHttpResponse(statusCode: response.statusCode, body: body);
  }
}

final class AmapReverseGeocoder {
  AmapReverseGeocoder({
    required AmapReverseGeocodeHttpClient httpClient,
    DateTime Function()? clock,
  }) : _httpClient = httpClient,
       _clock = clock ?? DateTime.now;

  final AmapReverseGeocodeHttpClient _httpClient;
  final DateTime Function() _clock;

  Future<ReverseGeocodeSnapshot> reverseGeocode(
    DeviceLocationSnapshot location, {
    required LocationCaptureSettings settings,
    required Duration timeout,
  }) async {
    if (!settings.useAmapReverseGeocode) {
      return _status(ReverseGeocodeStatus.disabled, 'amap_disabled');
    }
    final key = settings.amapApiKey.trim();
    if (key.isEmpty) {
      return _status(
        ReverseGeocodeStatus.skippedMissingKey,
        'amap_api_key_missing',
      );
    }

    final gcj = wgs84ToGcj02(location.latitude, location.longitude);
    final uri = Uri.parse('https://restapi.amap.com/v3/geocode/regeo').replace(
      queryParameters: <String, String>{
        'key': key,
        'location':
            '${_sixDecimals(gcj.longitude)},${_sixDecimals(gcj.latitude)}',
        'extensions': 'base',
        'output': 'json',
        'radius': '1000',
        'roadlevel': '1',
      },
    );

    try {
      final response = await _httpClient.get(uri, timeout: timeout);
      if (response.statusCode != HttpStatus.ok) {
        return _status(
          ReverseGeocodeStatus.failed,
          'amap_http_${response.statusCode}',
        );
      }
      return _parseResponse(response.body);
    } on TimeoutException {
      return _status(ReverseGeocodeStatus.failed, 'amap_timeout');
    } catch (_) {
      return _status(ReverseGeocodeStatus.failed, 'amap_request_failed');
    }
  }

  ReverseGeocodeSnapshot _parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return _status(ReverseGeocodeStatus.failed, 'amap_invalid_json');
    }
    final data = decoded.cast<String, Object?>();
    if (data['status'] != '1') {
      return ReverseGeocodeSnapshot(
        provider: ReverseGeocodeSnapshot.amapProvider,
        status: ReverseGeocodeStatus.failed,
        reason: _string(data['info']) ?? 'amap_rejected',
        errorCode: _string(data['infocode']),
        updatedAt: _clock().toUtc(),
      );
    }

    final regeocode = _map(data['regeocode']);
    final component = _map(regeocode['addressComponent']);
    final streetNumber = _map(component['streetNumber']);
    final neighborhood = _map(component['neighborhood']);
    return ReverseGeocodeSnapshot(
      provider: ReverseGeocodeSnapshot.amapProvider,
      status: ReverseGeocodeStatus.success,
      address: GeocodedAddress(
        country: _string(component['country']),
        province: _string(component['province']),
        city: _string(component['city']) ?? _string(component['province']),
        district: _string(component['district']),
        township: _string(component['township']),
        neighborhood: _string(neighborhood['name']),
        street: _string(streetNumber['street']),
        formattedAddress: _string(regeocode['formatted_address']),
        adcode: _string(component['adcode']),
        citycode: _string(component['citycode']),
      ),
      updatedAt: _clock().toUtc(),
    );
  }

  ReverseGeocodeSnapshot _status(ReverseGeocodeStatus status, String reason) {
    return ReverseGeocodeSnapshot(
      provider: ReverseGeocodeSnapshot.amapProvider,
      status: status,
      reason: reason,
      updatedAt: _clock().toUtc(),
    );
  }
}

({double latitude, double longitude}) wgs84ToGcj02(
  double latitude,
  double longitude,
) {
  if (_outOfChina(latitude, longitude)) {
    return (latitude: latitude, longitude: longitude);
  }

  var dLat = _transformLat(longitude - 105.0, latitude - 35.0);
  var dLon = _transformLon(longitude - 105.0, latitude - 35.0);
  final radLat = latitude / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - 0.00669342162296594323 * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  dLat =
      (dLat * 180.0) /
      ((6378245.0 * (1 - 0.00669342162296594323)) /
          (magic * sqrtMagic) *
          math.pi);
  dLon = (dLon * 180.0) / (6378245.0 / sqrtMagic * math.cos(radLat) * math.pi);
  return (latitude: latitude + dLat, longitude: longitude + dLon);
}

bool _outOfChina(double latitude, double longitude) {
  return longitude < 72.004 ||
      longitude > 137.8347 ||
      latitude < 0.8293 ||
      latitude > 55.8271;
}

double _transformLat(double x, double y) {
  var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y;
  ret += 0.2 * math.sqrt(x.abs());
  ret +=
      (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (160.0 * math.sin(y / 12.0 * math.pi) +
          320 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLon(double x, double y) {
  var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y;
  ret += 0.1 * math.sqrt(x.abs());
  ret +=
      (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (150.0 * math.sin(x / 12.0 * math.pi) +
          300.0 * math.sin(x / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return ret;
}

String _sixDecimals(double value) {
  return value.toStringAsFixed(6);
}

Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  if (value is List && value.isNotEmpty) {
    return _string(value.first);
  }
  return null;
}
