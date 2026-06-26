abstract interface class PermissionBroker {
  Future<bool> isGranted(String packId, String permission);
  Future<List<PermissionDecision>> decisionsForPack(String packId);
  Future<List<String>> missingPermissions(
    String packId,
    Iterable<String> permissions,
  );
}

enum PermissionDecisionState { granted, denied, revoked }

final class PermissionDecision {
  const PermissionDecision({
    required this.packId,
    required this.permission,
    required this.state,
    required this.updatedAt,
    this.reason,
  });

  final String packId;
  final String permission;
  final PermissionDecisionState state;
  final DateTime updatedAt;
  final String? reason;

  bool get isGranted => state == PermissionDecisionState.granted;
}

abstract interface class PermissionStore {
  Future<void> upsert(PermissionDecision decision);
  Future<PermissionDecision?> read(String packId, String permission);
  Future<List<PermissionDecision>> readForPack(String packId);
}

final class InMemoryPermissionStore implements PermissionStore {
  final Map<String, PermissionDecision> _decisions =
      <String, PermissionDecision>{};

  @override
  Future<void> upsert(PermissionDecision decision) async {
    _decisions[_key(decision.packId, decision.permission)] = decision;
  }

  @override
  Future<PermissionDecision?> read(String packId, String permission) async {
    return _decisions[_key(packId, permission)];
  }

  @override
  Future<List<PermissionDecision>> readForPack(String packId) async {
    return List<PermissionDecision>.unmodifiable(
      _decisions.values.where((decision) => decision.packId == packId),
    );
  }

  String _key(String packId, String permission) {
    return '$packId::$permission';
  }
}

final class InMemoryPermissionBroker implements PermissionBroker {
  InMemoryPermissionBroker({PermissionStore? store})
    : store = store ?? InMemoryPermissionStore();

  final PermissionStore store;

  void grant(String packId, String permission) {
    store.upsert(
      PermissionDecision(
        packId: packId,
        permission: permission,
        state: PermissionDecisionState.granted,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  void grantAll(String packId, Iterable<String> permissions) {
    for (final permission in permissions) {
      grant(packId, permission);
    }
  }

  void deny(String packId, String permission, {String? reason}) {
    store.upsert(
      PermissionDecision(
        packId: packId,
        permission: permission,
        state: PermissionDecisionState.denied,
        updatedAt: DateTime.now().toUtc(),
        reason: reason,
      ),
    );
  }

  void revoke(String packId, String permission, {String? reason}) {
    store.upsert(
      PermissionDecision(
        packId: packId,
        permission: permission,
        state: PermissionDecisionState.revoked,
        updatedAt: DateTime.now().toUtc(),
        reason: reason,
      ),
    );
  }

  Future<PermissionDecision?> readDecision(String packId, String permission) {
    return store.read(packId, permission);
  }

  @override
  Future<List<PermissionDecision>> decisionsForPack(String packId) {
    return store.readForPack(packId);
  }

  @override
  Future<bool> isGranted(String packId, String permission) async {
    return (await store.read(packId, permission))?.isGranted ?? false;
  }

  @override
  Future<List<String>> missingPermissions(
    String packId,
    Iterable<String> permissions,
  ) async {
    final missing = <String>[];
    for (final permission in permissions) {
      if (!await isGranted(packId, permission)) {
        missing.add(permission);
      }
    }
    return List<String>.unmodifiable(missing);
  }
}

final class PermissionRevocationResult {
  const PermissionRevocationResult({
    required this.packId,
    required this.permission,
    required this.affectedTaskIds,
    required this.contextCacheInvalidationRequested,
  });

  final String packId;
  final String permission;
  final List<String> affectedTaskIds;
  final bool contextCacheInvalidationRequested;
}
