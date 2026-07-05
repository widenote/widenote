import 'package:widenote_cards/widenote_cards.dart' as cards;
import 'package:widenote_local_db/widenote_local_db.dart';

import 'capture_orchestrator.dart';

final class LocalDbCaptureKnowledgeSink implements CaptureKnowledgeSink {
  const LocalDbCaptureKnowledgeSink(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<void> save(cards.MemoryFirstCardBundle bundle) async {
    final savedAt = _savedAt(bundle);
    for (final card in bundle.cards) {
      _database.cards.save(_cardRecord(card, savedAt));
    }
  }

  @override
  Future<void> saveArtifacts(List<CaptureDerivedArtifact> artifacts) async {
    final savedAt = DateTime.now().toUtc();
    for (final artifact in artifacts) {
      if (_hasDuplicateArtifact(artifact)) {
        continue;
      }
      _database.derivedArtifacts.save(_artifactRecord(artifact, savedAt));
    }
  }

  bool _hasDuplicateArtifact(CaptureDerivedArtifact artifact) {
    return _database.derivedArtifacts
        .readByCapture(artifact.sourceCaptureId, status: 'active')
        .any(
          (record) =>
              record.artifactKind == artifact.artifactKind &&
              record.sourceEventId == artifact.sourceEventId &&
              record.title.trim() == artifact.title.trim(),
        );
  }
}

CardRecord _cardRecord(cards.MemoryFirstCard card, DateTime savedAt) {
  return CardRecord(
    id: card.id,
    cardKind: _cardKindName(card.kind),
    title: card.title,
    body: card.body,
    sourceRefs: _sourceRefs(card.sourceLinks),
    payload: card.metadata,
    createdAt: card.createdAt,
    updatedAt: savedAt,
  );
}

DerivedArtifactRecord _artifactRecord(
  CaptureDerivedArtifact artifact,
  DateTime savedAt,
) {
  return DerivedArtifactRecord(
    id: artifact.id,
    sourceCaptureId: artifact.sourceCaptureId,
    sourceEventId: artifact.sourceEventId,
    artifactKind: artifact.artifactKind,
    title: artifact.title,
    body: artifact.body,
    sourceRefs: artifact.sourceRefs,
    sensitivity: artifact.sensitivity,
    confidence: artifact.confidence,
    generatorId: artifact.generatorId,
    generatorVersion: artifact.generatorVersion,
    payload: artifact.payload,
    createdAt: artifact.createdAt,
    updatedAt: savedAt,
  );
}

List<Object?> _sourceRefs(List<cards.SourceLink> links) {
  return links.map((link) => link.toJson()).toList(growable: false);
}

DateTime _savedAt(cards.MemoryFirstCardBundle bundle) {
  if (bundle.cards.isNotEmpty) {
    return bundle.cards.first.createdAt;
  }
  return DateTime.now().toUtc();
}

String _cardKindName(cards.MemoryFirstCardKind kind) {
  return switch (kind) {
    cards.MemoryFirstCardKind.captureSummary => 'capture_summary',
    cards.MemoryFirstCardKind.memorySummary => 'memory_summary',
  };
}
