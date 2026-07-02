import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';
import '../../plugins/application/official_pack_manifests.dart';
import 'capture_orchestrator.dart';
import 'local_knowledge_sink.dart';

final captureOrchestratorProvider = Provider<CaptureOrchestrator>((ref) {
  final database = ref.watch(localDatabaseProvider);
  _seedDefaultOfficialPermissionGrants(database);
  return CaptureOrchestrator.local(
    eventStore: ref.watch(localEventStoreProvider),
    traceSink: ref.watch(localTraceSinkProvider),
    memoryRepository: ref.watch(localMemoryRepositoryProvider),
    permissionBroker: runtime.InMemoryPermissionBroker(
      store: localdb.LocalDbPermissionStore(database),
    ),
    runtimeStore: localdb.LocalDbRuntimeStore(database),
    autoGrantOfficialPermissions: false,
    enabledPackIds: _enabledOfficialPackIds(database),
    knowledgeSink: LocalDbCaptureKnowledgeSink(database),
    model: ref.watch(modelClientProvider),
  );
});

void _seedDefaultOfficialPermissionGrants(
  localdb.WideNoteLocalDatabase database,
) {
  final now = DateTime.now().toUtc();
  for (final manifest in officialPackManifestSnapshots) {
    if (database.packInstallations.readById(manifest.id) == null) {
      database.packInstallations.insert(
        localdb.PackInstallationRecord(
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
          payload: const <String, Object?>{'source': 'mobile_capture_runtime'},
          installedAt: now,
          updatedAt: now,
        ),
      );
    }
    for (final permission in manifest.requiredPermissions) {
      if (database.permissionGrants.readByPackAndPermission(
            manifest.id,
            permission,
          ) !=
          null) {
        continue;
      }
      database.permissionGrants.insert(
        localdb.PermissionGrantRecord(
          id: 'permission:${manifest.id}:$permission',
          packId: manifest.id,
          permissionId: permission,
          status: runtime.PermissionDecisionState.granted.name,
          grantKind: 'built_in_default',
          grantedAt: now,
          reason: 'built_in_default',
          payload: const <String, Object?>{'source': 'mobile_capture_runtime'},
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
}

List<String> _enabledOfficialPackIds(localdb.WideNoteLocalDatabase database) {
  return <String>[
    for (final manifest in officialPackManifestSnapshots)
      if (database.packInstallations.readById(manifest.id)?.status !=
          'disabled')
        manifest.id,
  ];
}
