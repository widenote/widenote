import 'package:widenote_core/widenote_core.dart';

import 'event.dart';

enum ArtifactLifecycleState { draft, active, archived, deleted }

enum ArtifactRetentionPolicy {
  keepUntilDeleted,
  deleteWithSource,
  expireAfterReview,
  ephemeralRun,
}

final class ArtifactDraft {
  ArtifactDraft({
    required this.kind,
    required this.title,
    required this.creatorRunId,
    required Iterable<SubjectRef> sourceRefs,
    required this.privacyClass,
    required this.retentionPolicy,
    JsonMap metadata = const <String, Object?>{},
  }) : sourceRefs = List<SubjectRef>.unmodifiable(sourceRefs),
       metadata = immutableJsonMap(metadata);

  final String kind;
  final String title;
  final String creatorRunId;
  final List<SubjectRef> sourceRefs;
  final WnPrivacy privacyClass;
  final ArtifactRetentionPolicy retentionPolicy;
  final JsonMap metadata;
}

final class ArtifactRecord {
  ArtifactRecord({
    required this.id,
    required this.kind,
    required this.title,
    required this.creatorRunId,
    required Iterable<SubjectRef> sourceRefs,
    required this.privacyClass,
    required this.retentionPolicy,
    required this.state,
    required this.createdAt,
    required this.updatedAt,
    JsonMap metadata = const <String, Object?>{},
  }) : sourceRefs = List<SubjectRef>.unmodifiable(sourceRefs),
       metadata = immutableJsonMap(metadata);

  final String id;
  final String kind;
  final String title;
  final String creatorRunId;
  final List<SubjectRef> sourceRefs;
  final WnPrivacy privacyClass;
  final ArtifactRetentionPolicy retentionPolicy;
  final ArtifactLifecycleState state;
  final DateTime createdAt;
  final DateTime updatedAt;
  final JsonMap metadata;

  ArtifactRecord copyWith({
    ArtifactLifecycleState? state,
    DateTime? updatedAt,
  }) {
    return ArtifactRecord(
      id: id,
      kind: kind,
      title: title,
      creatorRunId: creatorRunId,
      sourceRefs: sourceRefs,
      privacyClass: privacyClass,
      retentionPolicy: retentionPolicy,
      state: state ?? this.state,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata,
    );
  }
}

abstract interface class ArtifactRegistry {
  Future<WnResult<ArtifactRecord>> create(ArtifactDraft draft);
  Future<ArtifactRecord?> readById(String id);
  Future<List<ArtifactRecord>> readAll();
}

final class InMemoryArtifactRegistry implements ArtifactRegistry {
  InMemoryArtifactRegistry({required this.idGenerator, required this.clock});

  final WnIdGenerator idGenerator;
  final WnClock clock;
  final Map<String, ArtifactRecord> _records = <String, ArtifactRecord>{};

  @override
  Future<WnResult<ArtifactRecord>> create(ArtifactDraft draft) async {
    final failure = validateArtifactDraft(draft);
    if (failure != null) {
      return WnResult<ArtifactRecord>.err(failure);
    }

    final now = clock.now();
    final record = ArtifactRecord(
      id: idGenerator.nextId('artifact'),
      kind: draft.kind,
      title: draft.title,
      creatorRunId: draft.creatorRunId,
      sourceRefs: draft.sourceRefs,
      privacyClass: draft.privacyClass,
      retentionPolicy: draft.retentionPolicy,
      state: ArtifactLifecycleState.draft,
      createdAt: now,
      updatedAt: now,
      metadata: draft.metadata,
    );
    _records[record.id] = record;
    return WnResult<ArtifactRecord>.ok(record);
  }

  @override
  Future<ArtifactRecord?> readById(String id) async => _records[id];

  @override
  Future<List<ArtifactRecord>> readAll() async {
    return List<ArtifactRecord>.unmodifiable(_records.values);
  }
}

WnFailure? validateArtifactDraft(ArtifactDraft draft) {
  if (draft.creatorRunId.trim().isEmpty) {
    return const WnFailure(
      code: 'artifact_creator_run_required',
      message: 'Artifact metadata requires a creator run id.',
    );
  }
  if (draft.kind.trim().isEmpty) {
    return const WnFailure(
      code: 'artifact_kind_required',
      message: 'Artifact metadata requires a kind.',
    );
  }
  if (draft.title.trim().isEmpty) {
    return const WnFailure(
      code: 'artifact_title_required',
      message: 'Artifact metadata requires a title.',
    );
  }
  if (draft.sourceRefs.isEmpty) {
    return const WnFailure(
      code: 'artifact_source_refs_required',
      message: 'Artifact metadata requires at least one source ref.',
    );
  }
  for (final ref in draft.sourceRefs) {
    if (ref.kind.trim().isEmpty || ref.id.trim().isEmpty) {
      return const WnFailure(
        code: 'artifact_source_ref_invalid',
        message: 'Artifact source refs require non-empty kind and id.',
      );
    }
  }
  return null;
}
