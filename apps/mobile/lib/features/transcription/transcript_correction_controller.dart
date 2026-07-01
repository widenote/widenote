import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

import 'transcription_settings.dart';

final class TranscriptCorrectionPatch {
  const TranscriptCorrectionPatch({
    required this.from,
    required this.to,
    required this.start,
    required this.end,
    required this.confidence,
    required this.reason,
    required this.requiresReview,
  });

  final String from;
  final String to;
  final int start;
  final int end;
  final String confidence;
  final String reason;
  final bool requiresReview;

  bool get canAutoApply =>
      confidence == 'high' &&
      !requiresReview &&
      !_meaningSensitive(from) &&
      !_meaningSensitive(to);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'from': from,
      'to': to,
      'span': <String, Object?>{'start': start, 'end': end},
      'confidence': confidence,
      'reason': reason,
      'requires_review': requiresReview,
    };
  }
}

final class TranscriptCorrectionResult {
  const TranscriptCorrectionResult({
    required this.originalText,
    required this.correctedText,
    required this.patches,
    required this.autoApplied,
    required this.evidence,
  });

  final String originalText;
  final String correctedText;
  final List<TranscriptCorrectionPatch> patches;
  final bool autoApplied;
  final Map<String, Object?> evidence;
}

final class TranscriptCorrectionController {
  const TranscriptCorrectionController({
    required runtime.ModelClient model,
    this.packId = 'pack.transcript_correction',
    this.agentId = 'agent.transcript_correction',
  }) : _model = model;

  final runtime.ModelClient _model;
  final String packId;
  final String agentId;

  Future<TranscriptCorrectionResult> correct({
    required String transcript,
    required Iterable<String> glossaryTerms,
    required TranscriptCorrectionMode mode,
  }) async {
    if (mode == TranscriptCorrectionMode.disabled ||
        transcript.trim().isEmpty) {
      return TranscriptCorrectionResult(
        originalText: transcript,
        correctedText: transcript,
        patches: const <TranscriptCorrectionPatch>[],
        autoApplied: false,
        evidence: _evidence(
          transcript: transcript,
          patches: const <TranscriptCorrectionPatch>[],
          rawModelText: '',
          status: 'disabled',
        ),
      );
    }

    final response = await _model.complete(
      runtime.ModelRequest(
        prompt: _prompt(transcript: transcript, glossaryTerms: glossaryTerms),
        context: const <String, Object?>{
          'pack_id': 'pack.transcript_correction',
          'agent_id': 'agent.transcript_correction',
          'prompt_ref': 'transcript.correction.v1',
        },
      ),
    );
    final patches = _parsePatches(response.text, transcript);
    final autoApplied =
        mode == TranscriptCorrectionMode.autoApplyHighConfidence &&
        patches.isNotEmpty &&
        patches.every((patch) => patch.canAutoApply);
    final corrected = autoApplied
        ? _applyPatches(transcript, patches)
        : transcript;
    return TranscriptCorrectionResult(
      originalText: transcript,
      correctedText: corrected,
      patches: patches,
      autoApplied: autoApplied,
      evidence: _evidence(
        transcript: transcript,
        patches: patches,
        rawModelText: response.text,
        status: autoApplied ? 'auto_applied' : 'needs_review',
      ),
    );
  }
}

String _prompt({
  required String transcript,
  required Iterable<String> glossaryTerms,
}) {
  final terms = glossaryTerms
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .take(80)
      .join('\n');
  return '''
You are WideNote transcript correction agent.
Return JSON only: {"patches":[{"from":"...","to":"...","span":{"start":0,"end":0},"confidence":"high|medium|low","reason":"term_memory|user_glossary|context_consistency|model_guess","requires_review":true}]}
Only correct names, domain terms, homophones, and near-terms.
Do not summarize or rewrite meaning. Numbers, dates, credentials, medical, legal, or financial content require review.

Glossary:
$terms

Glossary lines may include explicit correction mappings such as "wrong -> correct".

Transcript:
$transcript
''';
}

List<TranscriptCorrectionPatch> _parsePatches(String value, String transcript) {
  try {
    final decoded = _decodePatchJson(value);
    final patches = decoded is Map ? decoded['patches'] : null;
    if (patches is! List) {
      return const <TranscriptCorrectionPatch>[];
    }
    final result = <TranscriptCorrectionPatch>[];
    for (final item in patches) {
      if (item is! Map) {
        continue;
      }
      final from = _string(item['from']);
      final to = _string(item['to']);
      final span = item['span'];
      final start = span is Map ? _int(span['start']) : null;
      final end = span is Map ? _int(span['end']) : null;
      final confidence = _string(item['confidence']) ?? 'low';
      final reason = _string(item['reason']) ?? 'model_guess';
      final requiresReview = item['requires_review'] != false;
      if (from == null || to == null) {
        continue;
      }
      var resolvedStart = start;
      var resolvedEnd = end;
      if (resolvedStart == null ||
          resolvedEnd == null ||
          resolvedStart < 0 ||
          resolvedEnd < resolvedStart ||
          resolvedEnd > transcript.length ||
          transcript.substring(resolvedStart, resolvedEnd) != from) {
        final fallbackStart = transcript.indexOf(from);
        if (fallbackStart < 0) {
          continue;
        }
        resolvedStart = fallbackStart;
        resolvedEnd = fallbackStart + from.length;
      }
      result.add(
        TranscriptCorrectionPatch(
          from: from,
          to: to,
          start: resolvedStart,
          end: resolvedEnd,
          confidence: confidence,
          reason: reason,
          requiresReview: requiresReview,
        ),
      );
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return _withoutOverlaps(result);
  } on Object {
    return const <TranscriptCorrectionPatch>[];
  }
}

Object? _decodePatchJson(String value) {
  try {
    return jsonDecode(value);
  } on FormatException {
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start < 0 || end <= start) {
      rethrow;
    }
    return jsonDecode(value.substring(start, end + 1));
  }
}

List<TranscriptCorrectionPatch> _withoutOverlaps(
  List<TranscriptCorrectionPatch> patches,
) {
  final result = <TranscriptCorrectionPatch>[];
  var lastEnd = -1;
  for (final patch in patches) {
    if (patch.start < lastEnd) {
      continue;
    }
    result.add(patch);
    lastEnd = patch.end;
  }
  return result;
}

String _applyPatches(
  String transcript,
  List<TranscriptCorrectionPatch> patches,
) {
  if (patches.isEmpty) {
    return transcript;
  }
  final buffer = StringBuffer();
  var cursor = 0;
  for (final patch in patches) {
    buffer
      ..write(transcript.substring(cursor, patch.start))
      ..write(patch.to);
    cursor = patch.end;
  }
  buffer.write(transcript.substring(cursor));
  return buffer.toString();
}

Map<String, Object?> _evidence({
  required String transcript,
  required List<TranscriptCorrectionPatch> patches,
  required String rawModelText,
  required String status,
}) {
  return <String, Object?>{
    'pack_id': 'pack.transcript_correction',
    'agent_id': 'agent.transcript_correction',
    'status': status,
    'transcript_hash': sha256.convert(utf8.encode(transcript)).toString(),
    'patches': patches.map((patch) => patch.toJson()).toList(),
    if (rawModelText.trim().isNotEmpty) 'raw_model_output': rawModelText,
  };
}

bool _meaningSensitive(String text) {
  return RegExp(r'\d|sk-|AKIA|password|密码|金额|诊断|合同').hasMatch(text);
}

String? _string(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
