import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;

import '../../../app/local_database.dart';
import '../../../app/model_client.dart';
import '../../plugins/application/official_pack_manifests.dart';
import '../../location/application/location_settings_controller.dart';
import '../../location/domain/location_context.dart';
import '../../transcription/transcription_service.dart';
import '../../transcription/transcription_types.dart';
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
    enabledPackIds: _enabledOfficialPackIds(database),
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

    var processingAttachments = attachments;
    var recordBody = body.isEmpty ? _attachmentRecordBody(attachments) : body;
    state = state.copyWith(isProcessing: true, clearError: true);
    final locationContext = await _captureLocationContext();

    final pendingRecord = CaptureRecord(
      id: 'local-${DateTime.now().toUtc().microsecondsSinceEpoch}',
      body: recordBody,
      createdAt: DateTime.now().toUtc(),
      status: 'Saved locally, processing',
      locationContext: locationContext,
    );
    _readModelStore().saveCapture(pendingRecord, attachments: attachments);

    state = state.copyWith(
      records: [pendingRecord, ...state.records],
      clearError: true,
    );

    try {
      processingAttachments = await _transcribeVoiceAttachments(
        pendingRecord,
        attachments,
      );
      final transcriptText = _transcriptText(processingAttachments);
      final processingBody = _processingBody(
        typedText: body,
        transcriptText: transcriptText,
        fallbackText: recordBody,
      );
      if (processingBody != recordBody) {
        final transcriptReadyRecord = pendingRecord.copyWith(
          body: processingBody,
          status: 'Saved locally, transcript ready',
        );
        _readModelStore().saveCapture(
          transcriptReadyRecord,
          attachments: processingAttachments,
        );
        state = state.copyWith(
          records: _replaceRecord(
            state.records,
            pendingRecord.id,
            transcriptReadyRecord,
          ),
        );
        recordBody = processingBody;
      }
      final result = await ref
          .read(captureOrchestratorProvider)
          .processCapture(
            recordBody,
            attachments: processingAttachments,
            captureId: pendingRecord.id,
          );
      final resultRecord = result.record.copyWith(
        locationContext: locationContext,
      );
      final readModel = _readModelStore()
        ..saveCapture(resultRecord, attachments: processingAttachments);
      if (result.todo.isSuggested) {
        readModel.saveTodo(result.todo);
      }
      final nextTodos = result.todo.isSuggested
          ? [result.todo, ...state.todos]
          : state.todos;

      state = state.copyWith(
        records: _replaceRecord(state.records, pendingRecord.id, resultRecord),
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
      _readModelStore().saveCapture(
        failedRecord,
        attachments: processingAttachments,
      );
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

  Future<CapturedLocationContext?> _captureLocationContext() async {
    try {
      return await ref.read(locationCaptureServiceProvider).captureForRecord();
    } catch (_) {
      return null;
    }
  }

  Future<List<CaptureAttachment>> _transcribeVoiceAttachments(
    CaptureRecord record,
    List<CaptureAttachment> attachments,
  ) async {
    final updated = <CaptureAttachment>[];
    for (final attachment in attachments) {
      if (attachment.kind != CaptureAssetKind.voice || !attachment.isReady) {
        updated.add(attachment);
        continue;
      }
      final result = await ref
          .read(transcriptionServiceProvider)
          .transcribeAttachment(attachment.id);
      updated.add(_attachmentWithTranscript(attachment, result));
    }
    return List<CaptureAttachment>.unmodifiable(updated);
  }

  CaptureAttachment _attachmentWithTranscript(
    CaptureAttachment attachment,
    TranscriptionResult result,
  ) {
    if (result.status != TranscriptStatus.active ||
        result.text.trim().isEmpty) {
      return attachment.copyWith(
        rawMetadata: <String, Object?>{
          ...attachment.rawMetadata,
          'transcript_status': result.status.wireName,
          if (result.errorCode != null)
            'last_error_code': result.errorCode!.wireName,
        },
      );
    }
    return attachment.copyWith(
      previewText: result.text,
      rawMetadata: <String, Object?>{
        ...attachment.rawMetadata,
        'transcript': result.text,
        'transcript_status': result.status.wireName,
        'transcription_provider_id': result.providerId,
        'transcription_provider_kind': result.providerKind.wireName,
      },
    );
  }

  String _transcriptText(List<CaptureAttachment> attachments) {
    final transcripts = <String>[];
    for (final attachment in attachments) {
      if (attachment.kind != CaptureAssetKind.voice) {
        continue;
      }
      final transcript = _metadataText(attachment.rawMetadata, 'transcript');
      if (transcript != null) {
        transcripts.add(transcript);
      }
    }
    return transcripts.join('\n');
  }

  String _processingBody({
    required String typedText,
    required String transcriptText,
    required String fallbackText,
  }) {
    final parts = <String>[
      if (typedText.trim().isNotEmpty) typedText.trim(),
      if (transcriptText.trim().isNotEmpty) transcriptText.trim(),
    ];
    if (parts.isEmpty) {
      return fallbackText;
    }
    return parts.join('\n');
  }
}

String? _metadataText(Map<String, Object?> metadata, String key) {
  final value = metadata[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  final nested = metadata['adapter_metadata'];
  if (nested is Map) {
    final nestedValue = nested[key];
    if (nestedValue is String && nestedValue.trim().isNotEmpty) {
      return nestedValue.trim();
    }
  }
  return null;
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

List<String> _enabledOfficialPackIds(localdb.WideNoteLocalDatabase database) {
  return <String>[
    for (final manifest in officialPackManifestSnapshots)
      if (database.packInstallations.readById(manifest.id)?.status !=
          'disabled')
        manifest.id,
  ];
}
