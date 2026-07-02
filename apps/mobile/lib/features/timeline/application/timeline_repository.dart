import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_cards/widenote_cards.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';
import '../../capture/media/capture_media.dart';
import '../../location/domain/location_context.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>((ref) {
  return LocalDbTimelineRepository(ref.watch(localDatabaseProvider));
});

final timelineSnapshotProvider = FutureProvider.autoDispose<TimelineSnapshot>((
  ref,
) {
  return ref.watch(timelineRepositoryProvider).loadSnapshot();
});

final timelineCardDetailProvider = FutureProvider.autoDispose
    .family<MemoryFirstCardDetail?, String>((ref, cardId) async {
      final snapshot = await ref
          .watch(timelineRepositoryProvider)
          .loadSnapshot();
      return snapshot.cardDetail(cardId);
    });

final timelineItemDetailProvider = FutureProvider.autoDispose
    .family<MemoryFirstTimelineItem?, String>((ref, itemId) async {
      final snapshot = await ref
          .watch(timelineRepositoryProvider)
          .loadSnapshot();
      return snapshot.itemById(itemId);
    });

abstract interface class TimelineRepository {
  Future<TimelineSnapshot> loadSnapshot();
}

final class TimelineSnapshot {
  const TimelineSnapshot(this.index);

  factory TimelineSnapshot.fromItems(Iterable<MemoryFirstTimelineItem> items) {
    return TimelineSnapshot(MemoryFirstBrowseIndex.build(items));
  }

  final MemoryFirstBrowseIndex index;

  bool get isEmpty => index.isEmpty;

  List<MemoryFirstTimelineDay> timeline([
    MemoryFirstTimelineFilter filter = const MemoryFirstTimelineFilter(),
  ]) {
    return index.timeline(filter);
  }

  List<MemoryFirstTimelineItem> search([
    MemoryFirstTimelineFilter filter = const MemoryFirstTimelineFilter(),
  ]) {
    return index.search(filter);
  }

  MemoryFirstTimelineItem? itemById(String itemId) {
    final direct = index.itemById(itemId);
    if (direct != null) {
      return direct;
    }
    for (final item in index.items) {
      if (item.sourceLinks.any((link) => link.id == itemId)) {
        return item;
      }
    }
    return null;
  }

  MemoryFirstCardDetail? cardDetail(String cardId) {
    return index.cardDetail(cardId);
  }
}

final class LocalDbTimelineRepository implements TimelineRepository {
  const LocalDbTimelineRepository(this._database);

  final WideNoteLocalDatabase _database;

  @override
  Future<TimelineSnapshot> loadSnapshot() async {
    return TimelineSnapshot.fromItems(<MemoryFirstTimelineItem>[
      ..._captureItems(),
      ..._cardItems(),
      ..._insightItems(),
      ..._memoryItems(),
      ..._todoRecordItems(),
    ]);
  }

  List<MemoryFirstTimelineItem> _captureItems() {
    final captureRecords = _database.captures.readAll(limit: 200);
    final captureIds = captureRecords.map((capture) => capture.id).toSet();
    final items = <MemoryFirstTimelineItem>[
      for (final capture in captureRecords) _captureItemFromRecord(capture),
      for (final event in _database.eventLog.readByType(
        runtime.WnEventTypes.captureCreated,
        limit: 200,
      ))
        if (!captureIds.contains(event.subjectRefId ?? event.id))
          _captureItemFromEvent(event),
    ];
    return items;
  }

  MemoryFirstTimelineItem _captureItemFromRecord(CaptureRecord capture) {
    final body = _string(capture.payload['text']) ?? 'Untitled capture';
    final eventId =
        _string(capture.payload['source_event_id']) ?? capture.sourceId;
    final event = eventId == null ? null : _database.eventLog.readById(eventId);
    final location = _locationFromCapture(capture);
    final locationMetadata = _locationTimelineMetadata(capture, location);
    final attachments = _database.attachments.readByCapture(capture.id);
    final artifactPayloads = _attachmentArtifactPayloads(
      capture.id,
      attachments,
    );
    return MemoryFirstTimelineItem(
      id: capture.id,
      kind: MemoryFirstTimelineItemKind.capture,
      title: 'Capture',
      body: body,
      createdAt: capture.createdAt,
      status: capture.status,
      sourceLinks: _linksWithSelf(
        kind: 'capture',
        id: capture.id,
        excerpt: body,
        links: <SourceLink>[
          if (event != null)
            SourceLink(kind: 'event', id: event.id, excerpt: body),
          for (final attachment in attachments)
            SourceLink(
              kind: 'capture_attachment',
              id: attachment.id,
              excerpt: _safeAttachmentExcerpt(attachment),
            ),
          for (final artifact in _database.derivedArtifacts.readByCapture(
            capture.id,
          ))
            SourceLink(
              kind: 'artifact',
              id: artifact.id,
              excerpt: _excerpt(artifact.body),
            ),
        ],
      ),
      metadata: <String, Object?>{
        if (event != null) 'event_type': event.type,
        if (event != null) 'event_id': event.id,
        if (capture.payload['memory_generated'] is bool)
          'memory_generated': capture.payload['memory_generated'],
        ...locationMetadata,
        if (attachments.isNotEmpty) 'attachment_count': attachments.length,
        if (artifactPayloads.isNotEmpty)
          'attachment_artifacts': artifactPayloads,
      },
    );
  }

  MemoryFirstTimelineItem _captureItemFromEvent(EventLogEntry event) {
    final body = _string(event.payload['text']) ?? 'Untitled capture';
    final captureId = event.subjectRefId ?? event.id;
    return MemoryFirstTimelineItem(
      id: captureId,
      kind: MemoryFirstTimelineItemKind.capture,
      title: 'Capture',
      body: body,
      createdAt: event.createdAt,
      status: event.status,
      sourceLinks: _linksWithSelf(
        kind: 'capture',
        id: captureId,
        excerpt: body,
        links: <SourceLink>[
          SourceLink(kind: 'event', id: event.id, excerpt: body),
        ],
      ),
      metadata: <String, Object?>{
        'event_type': event.type,
        'event_id': event.id,
      },
    );
  }

  List<MemoryFirstTimelineItem> _cardItems() {
    return _database.cards
        .readAll(status: 'active', limit: 200)
        .map(
          (card) => MemoryFirstTimelineItem(
            id: card.id,
            kind: MemoryFirstTimelineItemKind.card,
            title: card.title,
            body: card.body,
            createdAt: card.createdAt,
            status: card.status,
            sourceLinks: sourceLinksOrSelf(
              kind: 'card',
              id: card.id,
              excerpt: card.body,
              links: sourceLinksFromJsonList(card.sourceRefs),
            ),
            metadata: <String, Object?>{'card_kind': card.cardKind},
          ),
        )
        .toList(growable: false);
  }

  List<MemoryFirstTimelineItem> _insightItems() {
    return _database.insights
        .readAll(status: 'active', limit: 200)
        .map((insight) {
          final payload = MemoryFirstInsightPayload.fromJson(
            Map<Object?, Object?>.from(insight.payload),
          );
          final sourceLinks = dedupeSourceLinks(<SourceLink>[
            ...sourceLinksFromJsonList(insight.sourceRefs),
            ...payload.sourceLinks,
          ]);
          return MemoryFirstTimelineItem(
            id: insight.id,
            kind: MemoryFirstTimelineItemKind.insight,
            title: insight.title,
            body: insight.summary,
            createdAt: insight.createdAt,
            status: insight.status,
            sourceLinks: sourceLinksOrSelf(
              kind: 'insight',
              id: insight.id,
              excerpt: insight.summary,
              links: sourceLinks,
            ),
            metadata: <String, Object?>{
              'insight_kind': insight.insightKind,
              if (insight.metricLabel != null)
                'metric_label': insight.metricLabel,
              if (insight.metricValue != null)
                'metric_value': insight.metricValue,
              if (!payload.isEmpty) 'insight_payload': payload.toJson(),
            },
          );
        })
        .toList(growable: false);
  }

  List<MemoryFirstTimelineItem> _memoryItems() {
    return _database.memoryItems
        .readAll(status: 'active', limit: 200)
        .where((item) => !item.tombstone && item.body.trim().isNotEmpty)
        .map(
          (item) => MemoryFirstTimelineItem(
            id: item.id,
            kind: MemoryFirstTimelineItemKind.memory,
            title: 'Memory',
            body: item.body,
            createdAt: item.updatedAt,
            status: item.status,
            sourceLinks: _linksWithSelf(
              kind: 'memory',
              id: item.id,
              excerpt: item.body,
              links: <SourceLink>[
                ...sourceLinksFromJsonList(item.sourceRefs),
                if (item.sourceEventId != null)
                  SourceLink(kind: 'event', id: item.sourceEventId!),
                if (item.sourceCaptureId != null)
                  SourceLink(kind: 'capture', id: item.sourceCaptureId!),
              ],
            ),
            metadata: <String, Object?>{
              'memory_key': item.key,
              'memory_type': item.memoryType,
              'confidence': item.confidence,
              'sensitivity': item.sensitivity,
            },
          ),
        )
        .toList(growable: false);
  }

  List<MemoryFirstTimelineItem> _todoRecordItems() {
    return _database.todos
        .readAll(limit: 200)
        .map((todo) {
          final body =
              _string(todo.payload['title']) ??
              _string(todo.payload['text']) ??
              'Untitled todo';
          return MemoryFirstTimelineItem(
            id: todo.id,
            kind: MemoryFirstTimelineItemKind.todo,
            title: 'Todo',
            body: body,
            createdAt: todo.updatedAt,
            status: todo.status,
            sourceLinks: _linksWithSelf(
              kind: 'todo',
              id: todo.id,
              excerpt: body,
              links: <SourceLink>[
                if (todo.sourceEventId != null)
                  SourceLink(kind: 'event', id: todo.sourceEventId!),
                if (todo.sourceCaptureId != null)
                  SourceLink(kind: 'capture', id: todo.sourceCaptureId!),
              ],
            ),
            metadata: <String, Object?>{'record_type': 'todo'},
          );
        })
        .toList(growable: false);
  }

  List<Map<String, Object?>> _attachmentArtifactPayloads(
    String captureId,
    List<AttachmentRecord> attachments,
  ) {
    final payloads = <Map<String, Object?>>[];
    for (final attachment in attachments) {
      final artifacts = _database.derivedArtifacts.readByAttachment(
        attachment.id,
      );
      if (artifacts.isEmpty) {
        final status = AttachmentDerivedArtifactStatus.fromWire(
          attachment.status,
        );
        if (status == AttachmentDerivedArtifactStatus.blocked ||
            status == AttachmentDerivedArtifactStatus.needsReview) {
          payloads.add(
            AttachmentDerivedArtifact(
              artifactKind: _fallbackArtifactKind(attachment.assetKind),
              status: status,
              sourceLabel: 'source: capture_attachment:${attachment.id}',
              excerpt: _safeAttachmentExcerpt(attachment),
              reason: _string(attachment.payload['review_reason']),
            ).toPayload(),
          );
        }
        continue;
      }
      for (final artifact in artifacts) {
        payloads.add(_artifactPayload(captureId, attachment, artifact));
      }
    }
    return payloads;
  }
}

CapturedLocationContext? _locationFromCapture(CaptureRecord? capture) {
  final rawLocation = capture?.payload['location_context'];
  if (rawLocation is! Map) {
    return null;
  }
  return CapturedLocationContext.fromJson(rawLocation.cast<String, Object?>());
}

Map<String, Object?> _locationTimelineMetadata(
  CaptureRecord? capture,
  CapturedLocationContext? location,
) {
  final fact = _locationFactFromCapture(capture) ?? location?.toFactMetadata();
  if (fact == null) {
    return const <String, Object?>{};
  }
  final coordinate = _map(fact['coordinate']);
  final place = _map(fact['place']);
  final metadata = <String, Object?>{
    'location': fact,
    if (_string(fact['status']) != null)
      'location_status': _string(fact['status']),
  };

  final displayName =
      _string(place?['display_name']) ??
      location?.displaySummary(coarseOnly: true);
  if (displayName != null) {
    metadata['location_summary'] = displayName;
    metadata['location_display_name'] = displayName;
  }
  final placeName = _string(place?['place_name']) ?? location?.placeName;
  if (placeName != null) {
    metadata['location_place_name'] = placeName;
  }
  final formattedAddress = _string(place?['formatted_address']);
  if (formattedAddress != null) {
    metadata['location_formatted_address'] = formattedAddress;
  }
  final provider = _string(place?['provider']);
  if (provider != null) {
    metadata['location_reverse_geocode_provider'] = provider;
  }
  final geocodeStatus = _string(place?['status']);
  if (geocodeStatus != null) {
    metadata['location_reverse_geocode_status'] = geocodeStatus;
  }
  if (coordinate != null) {
    final latitude = _double(coordinate['latitude']);
    final longitude = _double(coordinate['longitude']);
    if (latitude != null && longitude != null) {
      metadata['location_coordinates_saved'] = true;
      metadata['location_latitude'] = latitude;
      metadata['location_longitude'] = longitude;
    }
    final accuracy = _double(coordinate['accuracy_meters']);
    if (accuracy != null) {
      metadata['location_accuracy_meters'] = accuracy;
    }
    final coordinateSystem = _string(coordinate['coordinate_system']);
    if (coordinateSystem != null) {
      metadata['location_coordinate_system'] = coordinateSystem;
    }
    final capturedAt = _string(coordinate['captured_at']);
    if (capturedAt != null) {
      metadata['location_captured_at'] = capturedAt;
    }
    final source = _string(coordinate['source']);
    if (source != null) {
      metadata['location_source'] = source;
    }
  }
  return metadata;
}

Map<String, Object?>? _locationFactFromCapture(CaptureRecord? capture) {
  final rawFacts = capture?.payload['fact_metadata'];
  if (rawFacts is! Map) {
    return null;
  }
  final rawLocation = rawFacts['location'];
  if (rawLocation is! Map) {
    return null;
  }
  return rawLocation.cast<String, Object?>();
}

Map<String, Object?> _artifactPayload(
  String captureId,
  AttachmentRecord attachment,
  DerivedArtifactRecord artifact,
) {
  return AttachmentDerivedArtifact(
      id: artifact.id,
      artifactKind: artifact.artifactKind,
      status: AttachmentDerivedArtifactStatus.fromWire(artifact.status),
      sourceLabel: 'source: capture_attachment:${attachment.id}',
      excerpt: _excerpt(artifact.body),
      reason: _string(artifact.payload['reason']),
    ).toPayload()
    ..['capture_id'] = captureId
    ..['attachment_id'] = attachment.id;
}

String _fallbackArtifactKind(String assetKind) {
  return switch (assetKind) {
    'voice' => 'audio_transcript',
    'photo' => 'image_derivatives',
    'share' => 'shared_text',
    _ => 'attachment_artifact',
  };
}

String _safeAttachmentExcerpt(AttachmentRecord attachment) {
  final preview = _string(attachment.payload['preview_text']);
  if (preview == null || preview == 'preview_hidden') {
    return '';
  }
  return _excerpt(preview);
}

List<SourceLink> _linksWithSelf({
  required String kind,
  required String id,
  String? excerpt,
  List<SourceLink> links = const <SourceLink>[],
}) {
  return dedupeSourceLinks(<SourceLink>[
    SourceLink(kind: kind, id: id, excerpt: excerpt),
    ...links,
  ]);
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

Map<String, Object?>? _map(Object? value) {
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  return null;
}

String _excerpt(String value) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= 160) {
    return text;
  }
  return '${text.substring(0, 157)}...';
}
