import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../shared/text_preview.dart';
import '../domain/chat_models.dart';
import 'chat_context.dart';

typedef ChatContextClock = DateTime Function();

final class LocalChatContextSource implements ChatContextSource {
  LocalChatContextSource(
    this._database, {
    this.labels = const ChatContextLabels.english(),
    ChatContextClock? clock,
    this.maxItems = 12,
  }) : _clock = clock ?? DateTime.now;

  final WideNoteLocalDatabase _database;
  final ChatContextLabels labels;
  final ChatContextClock _clock;
  final int maxItems;

  @override
  Future<List<ChatSource>> loadSources() async {
    final result = ContextPacketBuilder(_database).build(
      ContextPacketBuildRequest(
        surface: 'chat',
        cacheKey: 'mobile.chat.context_sources',
        maxItems: maxItems,
        permissionMode: 'local_only',
        permissions: const <String>['memory.read', 'record.read', 'todo.read'],
        redactionPolicy: 'redact_sensitive',
        disclosureLevel: 'targeted_excerpt',
        localDate: _dateOnly(_clock()),
        privacyProfile: 'chat_local',
        includeAttachmentMetadata: false,
        allowAttachmentExpansion: false,
      ),
    );
    return _packetSources(result.packet, labels: labels);
  }
}

final class ChatContextLabels {
  const ChatContextLabels({
    required this.memoryTitle,
    required this.recordTitle,
    required this.todoTitle,
    this.cardTitle = 'Card',
    this.insightTitle = 'Insight',
    this.redactedTitle = 'Redacted source',
    required this.untitledCapture,
    required this.untitledTodo,
    this.eventSourceLabel = 'event',
    this.memorySourceLabel = 'memory',
    this.captureSourceLabel = 'capture',
    this.cardSourceLabel = 'card',
    this.insightSourceLabel = 'insight',
    this.todoSourceLabel = 'todo',
    this.fileSourceLabel = 'file',
    this.genericSourceLabel = 'source',
  });

  const ChatContextLabels.english()
    : memoryTitle = 'Memory',
      recordTitle = 'Record',
      todoTitle = 'Todo',
      cardTitle = 'Card',
      insightTitle = 'Insight',
      redactedTitle = 'Redacted source',
      untitledCapture = 'Untitled local capture',
      untitledTodo = 'Untitled todo suggestion',
      eventSourceLabel = 'event',
      memorySourceLabel = 'memory',
      captureSourceLabel = 'capture',
      cardSourceLabel = 'card',
      insightSourceLabel = 'insight',
      todoSourceLabel = 'todo',
      fileSourceLabel = 'file',
      genericSourceLabel = 'source';

  final String memoryTitle;
  final String recordTitle;
  final String todoTitle;
  final String cardTitle;
  final String insightTitle;
  final String redactedTitle;
  final String untitledCapture;
  final String untitledTodo;
  final String eventSourceLabel;
  final String memorySourceLabel;
  final String captureSourceLabel;
  final String cardSourceLabel;
  final String insightSourceLabel;
  final String todoSourceLabel;
  final String fileSourceLabel;
  final String genericSourceLabel;

  String titleForKind(String kind, {String? packetTitle}) {
    final title = _safeDisplayText(packetTitle);
    if (kind == 'memory') {
      return title == 'Memory redacted' ? redactedTitle : memoryTitle;
    }
    if (kind == 'capture') {
      return recordTitle;
    }
    if (kind == 'todo') {
      return todoTitle;
    }
    if (title != null) {
      return title;
    }
    return switch (kind) {
      'card' => cardTitle,
      'insight' => insightTitle,
      _ => redactedTitle,
    };
  }

  String sourceKindLabel(String kind) {
    return switch (kind) {
      'memory' => memorySourceLabel,
      'capture' => captureSourceLabel,
      'card' => cardSourceLabel,
      'insight' => insightSourceLabel,
      'todo' => todoSourceLabel,
      'file' => fileSourceLabel,
      _ => genericSourceLabel,
    };
  }
}

List<ChatSource> _packetSources(
  JsonMap packet, {
  required ChatContextLabels labels,
}) {
  final sections = packet['sections'];
  if (sections is! List) {
    return const <ChatSource>[];
  }

  final packetCreatedAt = _parseDateTime(packet['created_at']) ?? _epoch;
  final sources = <ChatSource>[];
  final seen = <String>{};
  var order = 0;

  for (final sectionValue in sections) {
    if (sectionValue is! Map) {
      continue;
    }
    final section = sectionValue.cast<String, Object?>();
    if (!_isSourceBackedSection(section)) {
      continue;
    }
    final citations = section['citations'];
    if (citations is! List) {
      continue;
    }
    for (final citationValue in citations) {
      if (citationValue is! Map) {
        continue;
      }
      final citation = citationValue.cast<String, Object?>();
      final sourceRef = _sourceRef(citation);
      if (sourceRef == null) {
        continue;
      }
      final kind = _sourceKind(sourceRef, section);
      final id = _string(sourceRef['id']);
      if (kind == null || id == null || kind == 'manual') {
        continue;
      }
      if (kind == 'todo' && _isCompletedTodoSection(section)) {
        continue;
      }

      final dedupeKey = '$kind\u0000$id';
      if (!seen.add(dedupeKey)) {
        continue;
      }
      final excerpt = _sourceExcerpt(citation, section, labels, kind);
      if (excerpt == null) {
        continue;
      }
      sources.add(
        ChatSource(
          id: id,
          kind: kind,
          title: labels.titleForKind(
            kind,
            packetTitle: _string(section['title']),
          ),
          excerpt: excerpt,
          sourceLabel: _sourceLabel(sourceRef, labels),
          // Preserve builder disclosure order through ChatContextSelector recency sorting.
          createdAt: packetCreatedAt.subtract(Duration(microseconds: order++)),
        ),
      );
    }
  }

  return List<ChatSource>.unmodifiable(sources);
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool _isSourceBackedSection(JsonMap section) {
  final kind = _string(section['kind']);
  if (kind == null ||
      kind == 'visible_context' ||
      section['id'] == 'section_empty_context') {
    return false;
  }
  return true;
}

JsonMap? _sourceRef(JsonMap citation) {
  final value = citation['source_ref'];
  if (value is! Map) {
    return null;
  }
  final ref = value.cast<String, Object?>();
  if (_string(ref['kind']) == null || _string(ref['id']) == null) {
    return null;
  }
  return ref;
}

String? _sourceKind(JsonMap sourceRef, JsonMap section) {
  final kind = _string(sourceRef['kind']);
  if (kind == null) {
    return null;
  }
  if (kind == 'record') {
    return 'capture';
  }
  if (kind == 'file') {
    return null;
  }
  final sectionKind = _string(section['kind']);
  if (sectionKind == 'raw_excerpt') {
    return 'capture';
  }
  return kind;
}

bool _isCompletedTodoSection(JsonMap section) {
  final content = _string(section['content'])?.toLowerCase();
  return content != null && content.startsWith('todo (completed)');
}

String? _sourceExcerpt(
  JsonMap citation,
  JsonMap section,
  ChatContextLabels labels,
  String kind,
) {
  final text =
      _safeDisplayText(_string(citation['excerpt'])) ??
      _safeDisplayText(_string(section['content']));
  if (text == null) {
    return switch (kind) {
      'capture' => labels.untitledCapture,
      'todo' => labels.untitledTodo,
      _ => labels.redactedTitle,
    };
  }
  return previewText(text, maxLength: 240);
}

String _sourceLabel(JsonMap sourceRef, ChatContextLabels labels) {
  final eventId = _safeLabelValue(_string(sourceRef['event_id']));
  if (eventId != null) {
    return '${labels.eventSourceLabel}: $eventId';
  }
  final kind = _sourceKind(sourceRef, const <String, Object?>{}) ?? 'source';
  final id = _safeLabelValue(_string(sourceRef['id'])) ?? 'unknown';
  return '${labels.sourceKindLabel(kind)}: $id';
}

String? _safeDisplayText(String? value) {
  final sanitized = _sanitizeForChat(value);
  if (sanitized == null || sanitized.isEmpty) {
    return null;
  }
  return sanitized;
}

String? _safeLabelValue(String? value) {
  final sanitized = _sanitizeForChat(value);
  if (sanitized == null || sanitized.isEmpty) {
    return null;
  }
  return sanitized.replaceAll(RegExp(r'\s+'), ' ');
}

String? _sanitizeForChat(String? value) {
  var result = value?.trim();
  if (result == null || result.isEmpty) {
    return null;
  }
  result = result.replaceAll(
    RegExp(r'\bsk-[A-Za-z0-9_\-]{8,}\b'),
    '[redacted_secret]',
  );
  result = result.replaceAllMapped(_secretAssignmentPattern, (match) {
    return '${match.group(1)}: [redacted_secret]';
  });
  result = result.replaceAll(
    RegExp(
      r'\b(ignore|disregard) previous instructions\b',
      caseSensitive: false,
    ),
    '[redacted_instruction]',
  );
  result = result.replaceAll(
    RegExp(r'\bfile://[^\s,;]+', caseSensitive: false),
    '[redacted_path]',
  );
  result = result.replaceAll(
    RegExp(r'\b[A-Za-z]:\\(?:Users|Temp|Windows|ProgramData)\\[^\s,;]+'),
    '[redacted_path]',
  );
  result = result.replaceAll(
    RegExp(r'(?<![\w:])/(?:private|var|tmp|Users|Volumes|home|data)/[^\s,;]+'),
    '[redacted_path]',
  );
  return result.trim();
}

final _secretAssignmentPattern = RegExp(
  '\\b(api[_ -]?key|token|secret|password)\\s*[:=]\\s*["\\\']?'
  '[^\\s,"\\\']{6,}',
  caseSensitive: false,
);

DateTime? _parseDateTime(Object? value) {
  final text = _string(value);
  if (text == null) {
    return null;
  }
  return DateTime.tryParse(text)?.toUtc();
}

String _dateOnly(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
