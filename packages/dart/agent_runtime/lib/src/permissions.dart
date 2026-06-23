abstract interface class PermissionBroker {
  Future<bool> isGranted(String packId, String permission);
  Future<List<String>> missingPermissions(
    String packId,
    Iterable<String> permissions,
  );
}

final class InMemoryPermissionBroker implements PermissionBroker {
  final Map<String, Set<String>> _grants = <String, Set<String>>{};

  void grant(String packId, String permission) {
    _grants.putIfAbsent(packId, () => <String>{}).add(permission);
  }

  void grantAll(String packId, Iterable<String> permissions) {
    for (final permission in permissions) {
      grant(packId, permission);
    }
  }

  void revoke(String packId, String permission) {
    _grants[packId]?.remove(permission);
  }

  @override
  Future<bool> isGranted(String packId, String permission) async {
    return _grants[packId]?.contains(permission) ?? false;
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
