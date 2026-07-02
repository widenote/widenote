import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

final systemPermissionAdapterProvider = Provider<SystemPermissionAdapter>((
  ref,
) {
  return PermissionHandlerSystemPermissionAdapter(
    platform: systemPermissionPlatformFromTarget(defaultTargetPlatform),
  );
});

final systemPermissionsControllerProvider =
    AsyncNotifierProvider<SystemPermissionsController, SystemPermissionsState>(
      SystemPermissionsController.new,
    );

enum SystemPermissionPlatform { android, ios, other }

enum SystemPermissionKind {
  camera,
  microphone,
  location,
  photos,
  files,
  calendar,
}

enum SystemPermissionStatus {
  unknown,
  granted,
  limited,
  denied,
  permanentlyDenied,
  restricted,
  notRequired,
  notConfigured,
  notSupported,
}

enum SystemPermissionServiceStatus { notApplicable, enabled, disabled, unknown }

enum SystemPermissionAction {
  none,
  request,
  openAppSettings,
  openLocationSettings,
}

SystemPermissionPlatform systemPermissionPlatformFromTarget(
  TargetPlatform platform,
) {
  return switch (platform) {
    TargetPlatform.android => SystemPermissionPlatform.android,
    TargetPlatform.iOS => SystemPermissionPlatform.ios,
    _ => SystemPermissionPlatform.other,
  };
}

final class SystemPermissionsState {
  const SystemPermissionsState({
    required this.platform,
    required this.items,
    required this.isRefreshing,
  });

  final SystemPermissionPlatform platform;
  final List<SystemPermissionItem> items;
  final bool isRefreshing;

  int get grantedCount {
    return items
        .where(
          (item) =>
              item.status == SystemPermissionStatus.granted ||
              item.status == SystemPermissionStatus.limited ||
              item.status == SystemPermissionStatus.notRequired,
        )
        .length;
  }

  int get reviewCount {
    return items.where((item) => item.needsReview).length;
  }

  SystemPermissionsState copyWith({
    List<SystemPermissionItem>? items,
    bool? isRefreshing,
  }) {
    return SystemPermissionsState(
      platform: platform,
      items: items ?? this.items,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

final class SystemPermissionItem {
  const SystemPermissionItem({
    required this.kind,
    required this.status,
    required this.serviceStatus,
    required this.action,
  });

  final SystemPermissionKind kind;
  final SystemPermissionStatus status;
  final SystemPermissionServiceStatus serviceStatus;
  final SystemPermissionAction action;

  bool get needsReview {
    if (kind == SystemPermissionKind.calendar) {
      return false;
    }
    return switch (status) {
          SystemPermissionStatus.denied ||
          SystemPermissionStatus.permanentlyDenied ||
          SystemPermissionStatus.restricted ||
          SystemPermissionStatus.notSupported ||
          SystemPermissionStatus.unknown => true,
          SystemPermissionStatus.granted ||
          SystemPermissionStatus.limited ||
          SystemPermissionStatus.notRequired ||
          SystemPermissionStatus.notConfigured => false,
        } ||
        serviceStatus == SystemPermissionServiceStatus.disabled;
  }
}

abstract interface class SystemPermissionAdapter {
  SystemPermissionPlatform get platform;

  Future<SystemPermissionStatus> status(SystemPermissionKind kind);

  Future<SystemPermissionStatus> request(SystemPermissionKind kind);

  Future<SystemPermissionServiceStatus> serviceStatus(
    SystemPermissionKind kind,
  );

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

final class PermissionHandlerSystemPermissionAdapter
    implements SystemPermissionAdapter {
  const PermissionHandlerSystemPermissionAdapter({required this.platform});

  @override
  final SystemPermissionPlatform platform;

  @override
  Future<SystemPermissionStatus> status(SystemPermissionKind kind) async {
    final permission = _permissionFor(kind);
    if (permission == null) {
      return _nonRuntimeStatus(kind);
    }
    return _mapStatus(await permission.status);
  }

  @override
  Future<SystemPermissionStatus> request(SystemPermissionKind kind) async {
    final permission = _permissionFor(kind);
    if (permission == null) {
      return _nonRuntimeStatus(kind);
    }
    return _mapStatus(await permission.request());
  }

  @override
  Future<SystemPermissionServiceStatus> serviceStatus(
    SystemPermissionKind kind,
  ) async {
    if (kind != SystemPermissionKind.location ||
        platform == SystemPermissionPlatform.other) {
      return SystemPermissionServiceStatus.notApplicable;
    }
    final status = await permissions.Permission.locationWhenInUse.serviceStatus;
    if (status.isEnabled) {
      return SystemPermissionServiceStatus.enabled;
    }
    if (status.isDisabled) {
      return SystemPermissionServiceStatus.disabled;
    }
    return SystemPermissionServiceStatus.unknown;
  }

  @override
  Future<bool> openAppSettings() {
    return permissions.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() async {
    final opened = await Geolocator.openLocationSettings();
    if (opened) {
      return true;
    }
    return permissions.openAppSettings();
  }

  permissions.Permission? _permissionFor(SystemPermissionKind kind) {
    if (platform == SystemPermissionPlatform.other) {
      return null;
    }
    return switch (kind) {
      SystemPermissionKind.camera => permissions.Permission.camera,
      SystemPermissionKind.microphone => permissions.Permission.microphone,
      SystemPermissionKind.location => permissions.Permission.locationWhenInUse,
      SystemPermissionKind.photos
          when platform == SystemPermissionPlatform.ios =>
        permissions.Permission.photos,
      SystemPermissionKind.photos ||
      SystemPermissionKind.files ||
      SystemPermissionKind.calendar => null,
    };
  }

  SystemPermissionStatus _nonRuntimeStatus(SystemPermissionKind kind) {
    if (platform == SystemPermissionPlatform.other) {
      return SystemPermissionStatus.notSupported;
    }
    return switch (kind) {
      SystemPermissionKind.files => SystemPermissionStatus.notRequired,
      SystemPermissionKind.photos
          when platform == SystemPermissionPlatform.android =>
        SystemPermissionStatus.notRequired,
      SystemPermissionKind.calendar => SystemPermissionStatus.notConfigured,
      _ => SystemPermissionStatus.notSupported,
    };
  }

  SystemPermissionStatus _mapStatus(permissions.PermissionStatus status) {
    if (status.isGranted) {
      return SystemPermissionStatus.granted;
    }
    if (status.isLimited) {
      return SystemPermissionStatus.limited;
    }
    if (status.isPermanentlyDenied) {
      return SystemPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return SystemPermissionStatus.restricted;
    }
    if (status.isDenied) {
      return SystemPermissionStatus.denied;
    }
    return SystemPermissionStatus.unknown;
  }
}

class SystemPermissionsController
    extends AsyncNotifier<SystemPermissionsState> {
  SystemPermissionAdapter get _adapter =>
      ref.read(systemPermissionAdapterProvider);

  @override
  FutureOr<SystemPermissionsState> build() {
    return _load(isRefreshing: false);
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(isRefreshing: true));
    }
    state = await AsyncValue.guard(() => _load(isRefreshing: false));
  }

  Future<void> activate(SystemPermissionKind kind) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    SystemPermissionItem? item;
    for (final candidate in current.items) {
      if (candidate.kind == kind) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      return;
    }
    final action = item.action;
    state = AsyncData(current.copyWith(isRefreshing: true));
    state = await AsyncValue.guard(() async {
      switch (action) {
        case SystemPermissionAction.request:
          await _adapter.request(kind);
        case SystemPermissionAction.openAppSettings:
          await _adapter.openAppSettings();
        case SystemPermissionAction.openLocationSettings:
          await _adapter.openLocationSettings();
        case SystemPermissionAction.none:
          break;
      }
      return _load(isRefreshing: false);
    });
  }

  Future<SystemPermissionsState> _load({required bool isRefreshing}) async {
    final adapter = _adapter;
    final items = <SystemPermissionItem>[];
    for (final kind in SystemPermissionKind.values) {
      final status = await adapter.status(kind);
      final serviceStatus = await adapter.serviceStatus(kind);
      items.add(
        SystemPermissionItem(
          kind: kind,
          status: status,
          serviceStatus: serviceStatus,
          action: _actionFor(
            kind: kind,
            status: status,
            serviceStatus: serviceStatus,
          ),
        ),
      );
    }
    return SystemPermissionsState(
      platform: adapter.platform,
      items: items,
      isRefreshing: isRefreshing,
    );
  }

  SystemPermissionAction _actionFor({
    required SystemPermissionKind kind,
    required SystemPermissionStatus status,
    required SystemPermissionServiceStatus serviceStatus,
  }) {
    if (kind == SystemPermissionKind.location &&
        serviceStatus == SystemPermissionServiceStatus.disabled &&
        (status == SystemPermissionStatus.granted ||
            status == SystemPermissionStatus.limited)) {
      return SystemPermissionAction.openLocationSettings;
    }
    return switch (status) {
      SystemPermissionStatus.denied => SystemPermissionAction.request,
      SystemPermissionStatus.granted ||
      SystemPermissionStatus.limited => SystemPermissionAction.openAppSettings,
      SystemPermissionStatus.permanentlyDenied ||
      SystemPermissionStatus.restricted =>
        SystemPermissionAction.openAppSettings,
      SystemPermissionStatus.unknown ||
      SystemPermissionStatus.notRequired ||
      SystemPermissionStatus.notConfigured ||
      SystemPermissionStatus.notSupported => SystemPermissionAction.none,
    };
  }
}
