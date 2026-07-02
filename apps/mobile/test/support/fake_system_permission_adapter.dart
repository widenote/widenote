import 'package:widenote_mobile/features/system_permissions/application/system_permissions_controller.dart';

final class FakeSystemPermissionAdapter implements SystemPermissionAdapter {
  FakeSystemPermissionAdapter({
    required this.platform,
    required Map<SystemPermissionKind, SystemPermissionStatus> statuses,
    Map<SystemPermissionKind, SystemPermissionServiceStatus>? serviceStatuses,
  }) : statuses = Map.of(statuses),
       serviceStatuses = Map.of(serviceStatuses ?? const {});

  factory FakeSystemPermissionAdapter.ready({
    SystemPermissionPlatform platform = SystemPermissionPlatform.android,
  }) {
    return FakeSystemPermissionAdapter(
      platform: platform,
      statuses: {
        SystemPermissionKind.camera: SystemPermissionStatus.granted,
        SystemPermissionKind.microphone: SystemPermissionStatus.granted,
        SystemPermissionKind.location: SystemPermissionStatus.granted,
        SystemPermissionKind.photos: platform == SystemPermissionPlatform.ios
            ? SystemPermissionStatus.granted
            : SystemPermissionStatus.notRequired,
        SystemPermissionKind.files: SystemPermissionStatus.notRequired,
        SystemPermissionKind.calendar: SystemPermissionStatus.notConfigured,
      },
      serviceStatuses: {
        SystemPermissionKind.location: SystemPermissionServiceStatus.enabled,
      },
    );
  }

  @override
  final SystemPermissionPlatform platform;

  final Map<SystemPermissionKind, SystemPermissionStatus> statuses;
  final Map<SystemPermissionKind, SystemPermissionServiceStatus>
  serviceStatuses;
  final List<SystemPermissionKind> requestedKinds = [];
  int openAppSettingsCount = 0;
  int openLocationSettingsCount = 0;

  @override
  Future<SystemPermissionStatus> status(SystemPermissionKind kind) async {
    return statuses[kind] ?? SystemPermissionStatus.notConfigured;
  }

  @override
  Future<SystemPermissionStatus> request(SystemPermissionKind kind) async {
    requestedKinds.add(kind);
    const next = SystemPermissionStatus.granted;
    statuses[kind] = next;
    return next;
  }

  @override
  Future<SystemPermissionServiceStatus> serviceStatus(
    SystemPermissionKind kind,
  ) async {
    return serviceStatuses[kind] ?? SystemPermissionServiceStatus.notApplicable;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCount += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCount += 1;
    serviceStatuses[SystemPermissionKind.location] =
        SystemPermissionServiceStatus.enabled;
    return true;
  }
}
