import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';
import '../../plugins/application/official_pack_manifests.dart';
import 'capture_orchestrator.dart';
import 'local_capture_read_model.dart';
import 'local_knowledge_sink.dart';
import '../domain/capture_models.dart';
import '../media/capture_media.dart';

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
    knowledgeSink: LocalDbCaptureKnowledgeSink(database),
    model: ref.watch(modelClientProvider),
  );
});

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);

class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() {
    return _readModelStore().hydrate();
  }

  Future<void> submitCapture(
    String value, {
    List<CaptureAttachment> attachments = const <CaptureAttachment>[],
  }) async {
    final body = value.trim();
    if (body.isEmpty && attachments.isEmpty) {
      return;
    }
    if (state.isProcessing) {
      return;
    }
    if (attachments.any((attachment) => !attachment.isReady)) {
      state = state.copyWith(
        errorMessage: 'Review or remove pending attachments before saving.',
      );
      return;
    }

    final recordBody = body.isEmpty ? _attachmentRecordBody(attachments) : body;

    final pendingRecord = CaptureRecord(
      id: 'local-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      body: recordBody,
      createdAt: DateTime.now().toUtc(),
      status: 'Saved locally, processing',
    );
    _readModelStore().saveCapture(pendingRecord, attachments: attachments);

    state = state.copyWith(
      records: [pendingRecord, ...state.records],
      isProcessing: true,
      clearError: true,
    );

    try {
      final result = await ref
          .read(captureOrchestratorProvider)
          .processCapture(
            body,
            attachments: attachments,
            captureId: pendingRecord.id,
          );
      final readModel = _readModelStore()
        ..saveCapture(result.record, attachments: attachments);
      if (result.todo.isSuggested) {
        readModel.saveTodo(result.todo);
      }
      final nextTodos = result.todo.isSuggested
          ? [result.todo, ...state.todos]
          : state.todos;

      state = state.copyWith(
        records: _replaceRecord(state.records, pendingRecord.id, result.record),
        memories: result.memoryItem.needsReview
            ? state.memories
            : [result.memoryItem, ...state.memories],
        reviewCandidates: result.reviewCandidate == null
            ? state.reviewCandidates
            : [result.reviewCandidate!, ...state.reviewCandidates],
        cards: result.cards,
        insights: result.insights,
        todos: nextTodos,
        traces: [...result.traces, ...state.traces],
        isProcessing: false,
        clearError: true,
      );
    } catch (error) {
      final failedRecord = pendingRecord.copyWith(
        status: 'Saved locally, agent failed',
      );
      _readModelStore().saveCapture(failedRecord, attachments: attachments);
      state = state.copyWith(
        records: _replaceRecord(state.records, pendingRecord.id, failedRecord),
        isProcessing: false,
        errorMessage: _captureFailureMessage(error),
      );
    }
  }

  Future<void> acceptReviewCandidate(String id) async {
    try {
      final memory = await ref
          .read(captureOrchestratorProvider)
          .acceptMemoryProposal(id);
      final knowledgeLayer = await ref
          .read(captureOrchestratorProvider)
          .buildKnowledgeLayer();
      state = state.copyWith(
        memories: [memory, ...state.memories],
        reviewCandidates: _removeReviewCandidate(state.reviewCandidates, id),
        cards: knowledgeLayer.cards,
        insights: knowledgeLayer.insights,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'Memory review failed: $error');
    }
  }

  Future<void> editAndAcceptReviewCandidate(String id, String body) async {
    try {
      final memory = await ref
          .read(captureOrchestratorProvider)
          .acceptMemoryProposal(id, editedBody: body);
      final knowledgeLayer = await ref
          .read(captureOrchestratorProvider)
          .buildKnowledgeLayer();
      state = state.copyWith(
        memories: [memory, ...state.memories],
        reviewCandidates: _removeReviewCandidate(state.reviewCandidates, id),
        cards: knowledgeLayer.cards,
        insights: knowledgeLayer.insights,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'Memory review failed: $error');
    }
  }

  Future<void> rejectReviewCandidate(String id) async {
    try {
      await ref.read(captureOrchestratorProvider).rejectMemoryProposal(id);
      state = state.copyWith(
        reviewCandidates: _removeReviewCandidate(state.reviewCandidates, id),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: 'Memory review failed: $error');
    }
  }

  List<CaptureRecord> _replaceRecord(
    List<CaptureRecord> records,
    String id,
    CaptureRecord replacement,
  ) {
    return [
      for (final record in records)
        if (record.id == id) replacement else record,
    ];
  }

  List<MemoryReviewCandidate> _removeReviewCandidate(
    List<MemoryReviewCandidate> candidates,
    String id,
  ) {
    return [
      for (final candidate in candidates)
        if (candidate.id != id) candidate,
    ];
  }

  String _attachmentRecordBody(List<CaptureAttachment> attachments) {
    return attachments
        .map((attachment) {
          final preview = attachment.previewText.trim();
          if (preview.isNotEmpty) {
            return preview;
          }
          return '${attachment.kind.wireName}: ${attachment.displayName}';
        })
        .where((preview) => preview.isNotEmpty)
        .join('\n');
  }

  LocalCaptureReadModelStore _readModelStore() {
    return LocalCaptureReadModelStore(ref.read(localDatabaseProvider));
  }
}

String _captureFailureMessage(Object error) {
  if (error is CapturePipelineException) {
    return 'Record saved locally. Configure a model provider or retry after agent recovery to generate Memory, cards, insights, and todos.';
  }
  return 'Record saved locally, but agent processing failed. Retry after model or permission recovery.';
}

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
