import 'package:flutter/foundation.dart';

enum LocationDisplayGranularity { city, district, neighborhood, street, full }

enum LocationCaptureStatus { available, unavailable }

enum ReverseGeocodeStatus { disabled, skippedMissingKey, success, failed }

@immutable
final class LocationCaptureSettings {
  const LocationCaptureSettings({
    this.saveGps = false,
    this.useAmapReverseGeocode = false,
    this.amapApiKey = '',
    this.displayGranularity = LocationDisplayGranularity.district,
  });

  factory LocationCaptureSettings.fromJson(Map<String, Object?> json) {
    return LocationCaptureSettings(
      saveGps: json['save_gps'] as bool? ?? false,
      useAmapReverseGeocode: json['use_amap_reverse_geocode'] as bool? ?? false,
      amapApiKey: _string(json['amap_api_key']) ?? '',
      displayGranularity: _enumByName(
        LocationDisplayGranularity.values,
        _string(json['display_granularity']),
        LocationDisplayGranularity.district,
      ),
    );
  }

  final bool saveGps;
  final bool useAmapReverseGeocode;
  final String amapApiKey;
  final LocationDisplayGranularity displayGranularity;

  Map<String, Object?> toJson({bool includeSecrets = true}) {
    return <String, Object?>{
      'save_gps': saveGps,
      'use_amap_reverse_geocode': useAmapReverseGeocode,
      if (includeSecrets) 'amap_api_key': amapApiKey,
      'display_granularity': displayGranularity.name,
    };
  }

  LocationCaptureSettings copyWith({
    bool? saveGps,
    bool? useAmapReverseGeocode,
    String? amapApiKey,
    LocationDisplayGranularity? displayGranularity,
  }) {
    final nextSaveGps = saveGps ?? this.saveGps;
    return LocationCaptureSettings(
      saveGps: nextSaveGps,
      useAmapReverseGeocode: nextSaveGps
          ? useAmapReverseGeocode ?? this.useAmapReverseGeocode
          : false,
      amapApiKey: amapApiKey ?? this.amapApiKey,
      displayGranularity: displayGranularity ?? this.displayGranularity,
    );
  }
}

@immutable
final class DeviceLocationSnapshot {
  const DeviceLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.accuracyMeters,
    this.source = deviceGpsSource,
    this.coordinateSystem = wgs84CoordinateSystem,
  });

  factory DeviceLocationSnapshot.fromJson(Map<String, Object?> json) {
    return DeviceLocationSnapshot(
      latitude: _double(json['latitude']) ?? _double(json['lat']) ?? 0,
      longitude: _double(json['longitude']) ?? _double(json['lng']) ?? 0,
      accuracyMeters: _double(json['accuracy_meters']),
      source: _string(json['source']) ?? deviceGpsSource,
      coordinateSystem:
          _string(json['coordinate_system']) ?? wgs84CoordinateSystem,
      capturedAt:
          DateTime.tryParse(_string(json['captured_at']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static const deviceGpsSource = 'device_gps';
  static const lastKnownDeviceGpsSource = 'last_known_device_gps';
  static const wgs84CoordinateSystem = 'WGS-84';

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final String source;
  final String coordinateSystem;
  final DateTime capturedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      'source': source,
      'coordinate_system': coordinateSystem,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> toFactJson() {
    return <String, Object?>{
      'fact_role': 'source_coordinate',
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      'coordinate_system': coordinateSystem,
      'source': source,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    };
  }

  String coordinateLabel() {
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }
}

@immutable
final class GeocodedAddress {
  const GeocodedAddress({
    this.country,
    this.province,
    this.city,
    this.district,
    this.township,
    this.neighborhood,
    this.street,
    this.formattedAddress,
    this.adcode,
    this.citycode,
  });

  factory GeocodedAddress.fromJson(Map<String, Object?> json) {
    return GeocodedAddress(
      country: _string(json['country']),
      province: _string(json['province']),
      city: _string(json['city']),
      district: _string(json['district']),
      township: _string(json['township']),
      neighborhood: _string(json['neighborhood']),
      street: _string(json['street']),
      formattedAddress: _string(json['formatted_address']),
      adcode: _string(json['adcode']),
      citycode: _string(json['citycode']),
    );
  }

  final String? country;
  final String? province;
  final String? city;
  final String? district;
  final String? township;
  final String? neighborhood;
  final String? street;
  final String? formattedAddress;
  final String? adcode;
  final String? citycode;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (country != null) 'country': country,
      if (province != null) 'province': province,
      if (city != null) 'city': city,
      if (district != null) 'district': district,
      if (township != null) 'township': township,
      if (neighborhood != null) 'neighborhood': neighborhood,
      if (street != null) 'street': street,
      if (formattedAddress != null) 'formatted_address': formattedAddress,
      if (adcode != null) 'adcode': adcode,
      if (citycode != null) 'citycode': citycode,
    };
  }

  String summary(LocationDisplayGranularity granularity) {
    if (granularity == LocationDisplayGranularity.full) {
      final full = formattedAddress?.trim();
      if (full != null && full.isNotEmpty) {
        return full;
      }
    }

    final parts = <String>[];
    void add(String? value) {
      final trimmed = value?.trim();
      if (trimmed == null || trimmed.isEmpty || parts.contains(trimmed)) {
        return;
      }
      parts.add(trimmed);
    }

    add(city ?? province);
    if (granularity.index >= LocationDisplayGranularity.district.index) {
      add(district);
    }
    if (granularity.index >= LocationDisplayGranularity.neighborhood.index) {
      add(neighborhood ?? township);
    }
    if (granularity.index >= LocationDisplayGranularity.street.index) {
      add(street);
    }
    if (parts.isEmpty) {
      return formattedAddress ?? '';
    }
    return parts.join(' · ');
  }

  String coarseSummary() {
    return summary(LocationDisplayGranularity.district);
  }

  String? placeName() {
    final candidates = <String?>[
      formattedAddress,
      summary(LocationDisplayGranularity.full),
      summary(LocationDisplayGranularity.street),
      summary(LocationDisplayGranularity.neighborhood),
      summary(LocationDisplayGranularity.district),
    ];
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}

@immutable
final class ReverseGeocodeSnapshot {
  const ReverseGeocodeSnapshot({
    required this.provider,
    required this.status,
    required this.updatedAt,
    this.address,
    this.reason,
    this.errorCode,
    this.coordinateSystem = gcj02CoordinateSystem,
  });

  factory ReverseGeocodeSnapshot.fromJson(Map<String, Object?> json) {
    final rawAddress = json['address'];
    return ReverseGeocodeSnapshot(
      provider: _string(json['provider']) ?? 'amap',
      status: _enumByName(
        ReverseGeocodeStatus.values,
        _string(json['status']),
        ReverseGeocodeStatus.failed,
      ),
      address: rawAddress is Map
          ? GeocodedAddress.fromJson(rawAddress.cast<String, Object?>())
          : null,
      reason: _string(json['reason']),
      errorCode: _string(json['error_code']),
      coordinateSystem:
          _string(json['coordinate_system']) ?? gcj02CoordinateSystem,
      updatedAt:
          DateTime.tryParse(_string(json['updated_at']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static const amapProvider = 'amap';
  static const gcj02CoordinateSystem = 'GCJ-02';

  final String provider;
  final ReverseGeocodeStatus status;
  final GeocodedAddress? address;
  final String? reason;
  final String? errorCode;
  final String coordinateSystem;
  final DateTime updatedAt;

  bool get isSuccess => status == ReverseGeocodeStatus.success;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'provider': provider,
      'status': status.name,
      if (address != null) 'address': address!.toJson(),
      if (reason != null) 'reason': reason,
      if (errorCode != null) 'error_code': errorCode,
      'coordinate_system': coordinateSystem,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> toFactJson(LocationDisplayGranularity granularity) {
    final placeName = address?.placeName();
    final displayName = address?.summary(granularity);
    final providerSpecific = <String, Object?>{
      if (address?.adcode != null) 'adcode': address!.adcode,
      if (address?.citycode != null) 'citycode': address!.citycode,
    };
    return <String, Object?>{
      'fact_role': 'derived_place',
      'derived_from': 'fact_metadata.location.coordinate',
      'provider': provider,
      'status': status.name,
      'coordinate_system': coordinateSystem,
      'place_name': ?placeName,
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName,
      if (address?.formattedAddress != null)
        'formatted_address': address!.formattedAddress,
      if (address?.country != null) 'country': address!.country,
      if (address?.province != null) 'province': address!.province,
      if (address?.city != null) 'city': address!.city,
      if (address?.district != null) 'district': address!.district,
      if (address?.township != null) 'township': address!.township,
      if (address?.neighborhood != null) 'neighborhood': address!.neighborhood,
      if (address?.street != null) 'street': address!.street,
      if (providerSpecific.isNotEmpty)
        'provider_specific': <String, Object?>{provider: providerSpecific},
      if (reason != null) 'reason': reason,
      if (errorCode != null) 'error_code': errorCode,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

@immutable
final class CapturedLocationContext {
  const CapturedLocationContext({
    required this.status,
    required this.createdAt,
    required this.displayGranularity,
    this.deviceLocation,
    this.reverseGeocode,
    this.reason,
  });

  factory CapturedLocationContext.fromJson(Map<String, Object?> json) {
    final rawDevice = json['device_location'];
    final rawReverse = json['reverse_geocode'];
    return CapturedLocationContext(
      status: _enumByName(
        LocationCaptureStatus.values,
        _string(json['status']),
        LocationCaptureStatus.unavailable,
      ),
      deviceLocation: rawDevice is Map
          ? DeviceLocationSnapshot.fromJson(rawDevice.cast<String, Object?>())
          : null,
      reverseGeocode: rawReverse is Map
          ? ReverseGeocodeSnapshot.fromJson(rawReverse.cast<String, Object?>())
          : null,
      displayGranularity: _enumByName(
        LocationDisplayGranularity.values,
        _string(json['display_granularity']),
        LocationDisplayGranularity.district,
      ),
      reason: _string(json['reason']),
      createdAt:
          DateTime.tryParse(_string(json['created_at']) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final LocationCaptureStatus status;
  final DeviceLocationSnapshot? deviceLocation;
  final ReverseGeocodeSnapshot? reverseGeocode;
  final LocationDisplayGranularity displayGranularity;
  final String? reason;
  final DateTime createdAt;

  bool get hasCoordinates => deviceLocation != null;

  String? get placeName {
    final reverse = reverseGeocode;
    if (reverse == null || !reverse.isSuccess) {
      return null;
    }
    return reverse.address?.placeName();
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': 'widenote.location_context',
      'schema_version': 1,
      'status': status.name,
      if (deviceLocation != null) 'device_location': deviceLocation!.toJson(),
      if (reverseGeocode != null) 'reverse_geocode': reverseGeocode!.toJson(),
      'display_granularity': displayGranularity.name,
      if (reason != null) 'reason': reason,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  String? displaySummary({bool coarseOnly = false}) {
    final address = reverseGeocode?.address;
    if (address != null && reverseGeocode?.isSuccess == true) {
      final summary = coarseOnly
          ? address.coarseSummary()
          : address.summary(displayGranularity);
      if (summary.trim().isNotEmpty) {
        return summary;
      }
    }
    return null;
  }

  Map<String, Object?> toFactMetadata({
    String? sourceCaptureId,
    String? sourceEventId,
  }) {
    final sourceRefs = <Map<String, Object?>>[
      if (sourceCaptureId != null)
        <String, Object?>{
          'kind': 'capture',
          'id': sourceCaptureId,
          'path': 'payload.location_context',
        },
      if (sourceEventId != null)
        <String, Object?>{'kind': 'event', 'id': sourceEventId},
    ];
    return <String, Object?>{
      'kind': 'location',
      'schema_version': 1,
      'sensitivity': 'high',
      'status': status.name,
      if (sourceRefs.isNotEmpty) 'source_refs': sourceRefs,
      if (deviceLocation != null) 'coordinate': deviceLocation!.toFactJson(),
      if (reverseGeocode != null)
        'place': reverseGeocode!.toFactJson(displayGranularity),
      'display_granularity': displayGranularity.name,
      if (reason != null) 'reason': reason,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> toTimelineFactMetadata() {
    final fact = toFactMetadata();
    final coordinate = fact['coordinate'];
    final place = fact['place'];
    return <String, Object?>{
      'location': fact,
      'location_status': status.name,
      if (displaySummary(coarseOnly: true) != null)
        'location_summary': displaySummary(coarseOnly: true),
      if (deviceLocation != null) ...<String, Object?>{
        'location_coordinates_saved': true,
        'location_latitude': deviceLocation!.latitude,
        'location_longitude': deviceLocation!.longitude,
        if (deviceLocation!.accuracyMeters != null)
          'location_accuracy_meters': deviceLocation!.accuracyMeters,
        'location_coordinate_system': deviceLocation!.coordinateSystem,
        'location_captured_at': deviceLocation!.capturedAt
            .toUtc()
            .toIso8601String(),
      },
      if (placeName != null) 'location_place_name': placeName,
      if (place is Map && place['display_name'] is String)
        'location_display_name': place['display_name'],
      if (place is Map && place['formatted_address'] is String)
        'location_formatted_address': place['formatted_address'],
      if (reverseGeocode != null) ...<String, Object?>{
        'location_reverse_geocode_provider': reverseGeocode!.provider,
        'location_reverse_geocode_status': reverseGeocode!.status.name,
      },
      if (coordinate is Map && coordinate['source'] is String)
        'location_source': coordinate['source'],
    };
  }
}

T _enumByName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
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

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
