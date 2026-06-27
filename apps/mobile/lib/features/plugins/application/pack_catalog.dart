import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import '../../capture/application/capture_controller.dart';
import 'official_pack_manifests.dart';

final permissionGateControllerProvider =
    NotifierProvider<PermissionGateController, PermissionGateState>(
      PermissionGateController.new,
    );

final packLibraryControllerProvider =
    NotifierProvider<PackLibraryController, PackLibraryState>(
      PackLibraryController.new,
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
final class PackLibraryState {
  const PackLibraryState({required this.packs});

  final List<PackLibraryPack> packs;

  int get enabledCount => packs.where((pack) => pack.isEnabled).length;
  int get disabledCount => packs.where((pack) => !pack.isEnabled).length;
}

@immutable
final class PackLibraryPack {
  const PackLibraryPack({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.publisher,
    required this.edition,
    required this.status,
    required this.runtimeStatus,
    required this.entrypointKind,
    required this.permissions,
    required this.outputEvents,
    required this.marketplaceSource,
    required this.trustLevel,
    required this.categories,
    required this.capabilities,
    required this.replacementSlots,
    required this.additiveSlots,
    required this.enabledSubscriptionCount,
    required this.failureCount,
    required this.permissionDecisionCounts,
    this.lastFailure,
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final String publisher;
  final String edition;
  final String status;
  final String runtimeStatus;
  final String entrypointKind;
  final List<String> permissions;
  final List<String> outputEvents;
  final String marketplaceSource;
  final String trustLevel;
  final List<String> categories;
  final List<String> capabilities;
  final List<String> replacementSlots;
  final List<String> additiveSlots;
  final int enabledSubscriptionCount;
  final int failureCount;
  final PackPermissionDecisionCounts permissionDecisionCounts;
  final PackLibraryFailure? lastFailure;

  bool get isEnabled => status == 'enabled';
}

@immutable
final class PackPermissionDecisionCounts {
  const PackPermissionDecisionCounts({
    required this.granted,
    required this.denied,
    required this.revoked,
  });

  final int granted;
  final int denied;
  final int revoked;
}

@immutable
final class PackLibraryFailure {
  const PackLibraryFailure({
    required this.message,
    required this.isRedacted,
    required this.occurredAt,
  });

  final String message;
  final bool isRedacted;
  final DateTime occurredAt;
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

final class PackLibraryController extends Notifier<PackLibraryState> {
  @override
  PackLibraryState build() {
    final database = ref.watch(localDatabaseProvider);
    ensureBuiltInPackInstallations(database);
    return _load(database);
  }

  Future<void> setEnabled(String packId, bool enabled) async {
    final database = ref.read(localDatabaseProvider);
    ensureBuiltInPackInstallations(database);
    if (database.packInstallations.readById(packId) == null) {
      return;
    }
    database.packInstallations.updateStatus(
      packId,
      enabled ? 'enabled' : 'disabled',
      payloadUpdates: <String, Object?>{
        'last_mobile_control_action': enabled ? 'enabled' : 'disabled',
      },
    );
    ref.invalidate(captureOrchestratorProvider);
    state = _load(database);
  }

  PackLibraryState _load(WideNoteLocalDatabase database) {
    final installationsById = <String, PackInstallationRecord>{
      for (final installation in database.packInstallations.readAll())
        installation.packId: installation,
    };
    final ordered = <PackInstallationRecord>[
      for (final id in officialPackManifestIds)
        if (installationsById[id] != null) installationsById[id]!,
      ...installationsById.entries
          .where((entry) => !officialPackManifestIds.contains(entry.key))
          .map((entry) => entry.value),
    ];
    return PackLibraryState(
      packs: ordered
          .map((installation) => _packFromInstallation(database, installation))
          .toList(growable: false),
    );
  }

  PackLibraryPack _packFromInstallation(
    WideNoteLocalDatabase database,
    PackInstallationRecord installation,
  ) {
    final manifest = officialPackManifestSnapshotsById[installation.packId];
    final rawManifest = installation.manifest.isEmpty && manifest != null
        ? officialPackManifestMap(installation.packId)
        : installation.manifest;
    final marketplace = _mapValue(rawManifest['marketplace']);
    final requestedPermissions = installation.requestedPermissions
        .whereType<String>()
        .toList(growable: false);
    final permissionCounts = _permissionCounts(
      database.permissionGrants.readByPack(installation.packId),
    );
    final failures = _failureCandidates(database, installation.packId);
    final taskFailureCount = database.runtimeTasks
        .readByPack(installation.packId, status: 'failed')
        .length;
    final runFailureCount = database.runtimeRuns
        .readAll(status: 'failed')
        .where((run) => run.packId == installation.packId)
        .length;

    return PackLibraryPack(
      id: installation.packId,
      name: installation.name,
      description: manifest == null
          ? ''
          : officialPackManifestDescription(installation.packId),
      version: installation.version,
      publisher: installation.publisher,
      edition: installation.edition,
      status: installation.status,
      runtimeStatus: installation.runtimeStatus,
      entrypointKind: installation.entrypointKind,
      permissions: requestedPermissions.isEmpty && manifest != null
          ? manifest.requiredPermissions.toList(growable: false)
          : requestedPermissions,
      outputEvents: manifest == null
          ? const <String>[]
          : _manifestOutputEvents(manifest),
      marketplaceSource:
          _stringValue(marketplace['source']) ??
          _stringValue(installation.payload['marketplace_source']) ??
          'local',
      trustLevel:
          _stringValue(marketplace['trust_level']) ??
          _stringValue(installation.payload['trust_level']) ??
          installation.edition,
      categories: _stringListValue(marketplace['categories']),
      capabilities: _stringListValue(marketplace['capabilities']),
      replacementSlots: _slotIds(rawManifest['replacement_slots']),
      additiveSlots: _slotIds(rawManifest['additive_slots']),
      enabledSubscriptionCount: installation.enabledSubscriptionIds.length,
      failureCount: taskFailureCount == 0 ? runFailureCount : taskFailureCount,
      permissionDecisionCounts: permissionCounts,
      lastFailure: failures.isEmpty ? null : failures.first,
    );
  }
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
    ensureBuiltInPackInstallations(database);
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
    ensureBuiltInPackInstallations(database);
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
}

void ensureBuiltInPackInstallations(WideNoteLocalDatabase database) {
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
        payload: const <String, Object?>{'source': 'mobile_pack_control'},
        installedAt: now,
        updatedAt: now,
      ),
    );
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

Map<String, Object?> _mapValue(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return const <String, Object?>{};
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

List<String> _stringListValue(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}

List<String> _slotIds(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<Map>()
      .map((slot) => slot['id'])
      .whereType<String>()
      .toList(growable: false);
}

String _permissionRisk(String permission) {
  return switch (permission) {
    'model.complete' => 'medium',
    'artifact.write' => 'low',
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

PackPermissionDecisionCounts _permissionCounts(
  List<PermissionGrantRecord> grants,
) {
  return PackPermissionDecisionCounts(
    granted: grants.where((grant) => grant.status == 'granted').length,
    denied: grants.where((grant) => grant.status == 'denied').length,
    revoked: grants.where((grant) => grant.status == 'revoked').length,
  );
}

List<PackLibraryFailure> _failureCandidates(
  WideNoteLocalDatabase database,
  String packId,
) {
  final failures = <PackLibraryFailure>[
    for (final task in database.runtimeTasks.readByPack(
      packId,
      status: 'failed',
    ))
      if (task.error != null)
        _failureFromMessage(task.error!, occurredAt: task.updatedAt),
    for (final run
        in database.runtimeRuns
            .readAll(status: 'failed')
            .where((run) => run.packId == packId))
      if (run.error != null)
        _failureFromMessage(
          run.error!,
          occurredAt: run.completedAt ?? run.startedAt,
        ),
  ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return failures;
}

PackLibraryFailure _failureFromMessage(
  String message, {
  required DateTime occurredAt,
}) {
  final isRedacted = _isSensitiveText(message);
  return PackLibraryFailure(
    message: isRedacted ? '' : message,
    isRedacted: isRedacted,
    occurredAt: occurredAt,
  );
}

bool _isSensitiveText(String value) {
  return _sensitivePattern.hasMatch(value);
}

final _sensitivePattern = RegExp(
  r'(api[_-]?key|authorization|bearer|token|secret|credential)',
  caseSensitive: false,
);
