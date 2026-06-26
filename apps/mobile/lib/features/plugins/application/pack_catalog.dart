import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import 'official_pack_manifests.dart';

final permissionGateControllerProvider =
    NotifierProvider<PermissionGateController, PermissionGateState>(
      PermissionGateController.new,
    );

@immutable
final class BuiltInPackInfo {
  const BuiltInPackInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.status,
    required this.permissions,
    required this.outputEvents,
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final String status;
  final List<String> permissions;
  final List<String> outputEvents;
}

@immutable
final class PermissionInfo {
  const PermissionInfo({
    required this.permission,
    required this.packId,
    required this.risk,
    required this.status,
  });

  final String permission;
  final String packId;
  final String risk;
  final String status;
}

enum PermissionGateDecisionState {
  available,
  granted,
  denied,
  revoked,
  deferred,
}

@immutable
final class PermissionGatePermission {
  const PermissionGatePermission({
    required this.info,
    required this.decisionState,
    this.updatedAt,
    this.reason,
  });

  final PermissionInfo info;
  final PermissionGateDecisionState decisionState;
  final DateTime? updatedAt;
  final String? reason;

  String get permission => info.permission;
  String get packId => info.packId;
  String get risk => info.risk;
  String get fallbackStatus => info.status;
  bool get isDeferred => decisionState == PermissionGateDecisionState.deferred;

  bool get canGrant {
    return switch (decisionState) {
      PermissionGateDecisionState.available ||
      PermissionGateDecisionState.denied ||
      PermissionGateDecisionState.revoked => true,
      PermissionGateDecisionState.granted ||
      PermissionGateDecisionState.deferred => false,
    };
  }

  bool get canDeny {
    return switch (decisionState) {
      PermissionGateDecisionState.available ||
      PermissionGateDecisionState.granted => true,
      PermissionGateDecisionState.denied ||
      PermissionGateDecisionState.revoked ||
      PermissionGateDecisionState.deferred => false,
    };
  }

  bool get canRevoke {
    return decisionState == PermissionGateDecisionState.granted;
  }
}

@immutable
final class PermissionGateState {
  const PermissionGateState({
    required this.builtInPermissions,
    required this.deferredPermissions,
  });

  final List<PermissionGatePermission> builtInPermissions;
  final List<PermissionGatePermission> deferredPermissions;

  int get availableCount {
    return builtInPermissions
        .where(
          (permission) =>
              permission.decisionState == PermissionGateDecisionState.available,
        )
        .length;
  }

  int get grantedCount {
    return builtInPermissions
        .where(
          (permission) =>
              permission.decisionState == PermissionGateDecisionState.granted,
        )
        .length;
  }

  int get deferredCount => deferredPermissions.length;
}

final class PermissionGateController extends Notifier<PermissionGateState> {
  @override
  PermissionGateState build() {
    return _load(ref.watch(localDatabaseProvider));
  }

  Future<void> grant(PermissionGatePermission permission) async {
    await _writeDecision(
      permission,
      runtime.PermissionDecisionState.granted,
      reason: null,
    );
  }

  Future<void> deny(PermissionGatePermission permission) async {
    await _writeDecision(
      permission,
      runtime.PermissionDecisionState.denied,
      reason: 'user_denied_from_permission_gate',
    );
  }

  Future<void> revoke(PermissionGatePermission permission) async {
    await _writeDecision(
      permission,
      runtime.PermissionDecisionState.revoked,
      reason: 'user_revoked_from_permission_gate',
    );
  }

  Future<void> _writeDecision(
    PermissionGatePermission permission,
    runtime.PermissionDecisionState decisionState, {
    required String? reason,
  }) async {
    if (permission.isDeferred) {
      return;
    }
    final database = ref.read(localDatabaseProvider);
    _ensureBuiltInPackInstallations(database);
    await LocalDbPermissionStore(database).upsert(
      runtime.PermissionDecision(
        packId: permission.packId,
        permission: permission.permission,
        state: decisionState,
        updatedAt: DateTime.now().toUtc(),
        reason: reason,
      ),
    );
    state = _load(database);
  }

  PermissionGateState _load(WideNoteLocalDatabase database) {
    return PermissionGateState(
      builtInPermissions: builtInPermissions
          .map((permission) {
            final record = database.permissionGrants.readByPackAndPermission(
              permission.packId,
              permission.permission,
            );
            return PermissionGatePermission(
              info: permission,
              decisionState: _stateFromRecord(record),
              updatedAt: record?.updatedAt,
              reason: record?.reason,
            );
          })
          .toList(growable: false),
      deferredPermissions: deferredHighRiskPermissions
          .map(
            (permission) => PermissionGatePermission(
              info: permission,
              decisionState: PermissionGateDecisionState.deferred,
            ),
          )
          .toList(growable: false),
    );
  }

  void _ensureBuiltInPackInstallations(WideNoteLocalDatabase database) {
    final now = DateTime.now().toUtc();
    for (final manifest in officialPackManifestSnapshots) {
      if (database.packInstallations.readById(manifest.id) != null) {
        continue;
      }
      database.packInstallations.insert(
        PackInstallationRecord(
          packId: manifest.id,
          name: manifest.name,
          version: manifest.version,
          publisher: manifest.publisher,
          edition: manifest.edition,
          status: 'enabled',
          runtimeStatus: 'idle',
          entrypointKind: 'native',
          requestedPermissions: <Object?>[...manifest.requiredPermissions],
          enabledSubscriptionIds: <Object?>[
            for (final subscription in manifest.subscriptions) subscription.id,
          ],
          manifest: officialPackManifestMap(manifest.id),
          payload: const <String, Object?>{'source': 'mobile_permission_gate'},
          installedAt: now,
          updatedAt: now,
        ),
      );
    }
  }
}

final builtInPacks = List<BuiltInPackInfo>.unmodifiable(
  officialPackManifestSnapshots.map(
    (manifest) => BuiltInPackInfo(
      id: manifest.id,
      name: manifest.name,
      description: officialPackManifestDescription(manifest.id),
      version: manifest.version,
      status: 'enabled',
      permissions: manifest.requiredPermissions.toList(growable: false),
      outputEvents: _manifestOutputEvents(manifest),
    ),
  ),
);

final builtInPermissions = List<PermissionInfo>.unmodifiable(
  officialPackManifestSnapshots.expand(
    (manifest) => manifest.requiredPermissions.map(
      (permission) => PermissionInfo(
        permission: permission,
        packId: manifest.id,
        risk: _permissionRisk(permission),
        status: 'built-in / available',
      ),
    ),
  ),
);

const deferredHighRiskPermissions = <PermissionInfo>[
  PermissionInfo(
    permission: 'file.read.broad',
    packId: 'community packs',
    risk: 'high',
    status: 'deferred until sandbox approval',
  ),
  PermissionInfo(
    permission: 'network.call.arbitrary_host',
    packId: 'community packs',
    risk: 'high',
    status: 'deferred until permission ADR',
  ),
  PermissionInfo(
    permission: 'script.execute',
    packId: 'community packs',
    risk: 'high',
    status: 'deferred until sandbox approval',
  ),
  PermissionInfo(
    permission: 'audio.capture.continuous',
    packId: 'media packs',
    risk: 'high',
    status: 'deferred until platform permission slice',
  ),
  PermissionInfo(
    permission: 'location.read.background',
    packId: 'context packs',
    risk: 'high',
    status: 'deferred until privacy decision',
  ),
];

List<String> _manifestOutputEvents(runtime.AgentPackManifestSnapshot manifest) {
  return manifest.agentDefinitions.values
      .expand((definition) => definition.outputEvents)
      .toList(growable: false);
}

String _permissionRisk(String permission) {
  return switch (permission) {
    'model.complete' => 'medium',
    _ => 'low',
  };
}

PermissionGateDecisionState _stateFromRecord(PermissionGrantRecord? record) {
  return switch (record?.status) {
    'granted' => PermissionGateDecisionState.granted,
    'denied' => PermissionGateDecisionState.denied,
    'revoked' => PermissionGateDecisionState.revoked,
    _ => PermissionGateDecisionState.available,
  };
}
