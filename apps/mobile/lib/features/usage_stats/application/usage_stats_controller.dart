import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widenote_local_db/widenote_local_db.dart';

import '../../../app/local_database.dart';

const usageStatsLookbackDays = 90;
const usageStatsUnknownAgentId = 'agent.unknown';

typedef UsageStatsClock = DateTime Function();

final usageStatsClockProvider = Provider<UsageStatsClock>(
  (ref) => DateTime.now,
);

final usageStatsControllerProvider =
    NotifierProvider<UsageStatsController, UsageStatsSnapshot>(
      UsageStatsController.new,
    );

enum UsageStatsPeriod { day, week }

final class UsageStatsController extends Notifier<UsageStatsSnapshot> {
  @override
  UsageStatsSnapshot build() {
    final database = ref.watch(localDatabaseProvider);
    final now = ref.watch(usageStatsClockProvider)().toUtc();
    return _load(database, now: now);
  }

  void refresh() {
    final now = ref.read(usageStatsClockProvider)().toUtc();
    state = _load(ref.read(localDatabaseProvider), now: now);
  }

  UsageStatsSnapshot _load(
    WideNoteLocalDatabase database, {
    required DateTime now,
  }) {
    final endExclusive = now.add(const Duration(seconds: 1));
    final startInclusive = endExclusive.subtract(
      const Duration(days: usageStatsLookbackDays),
    );
    final builder = _UsageStatsBuilder(
      windowStart: startInclusive,
      windowEnd: endExclusive,
      generatedAt: now,
      database: database,
    );

    for (final capture in database.captures.readByCreatedAtRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    )) {
      builder.addCapture(capture);
    }
    for (final item in database.memoryItems.readByCreatedAtRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    )) {
      builder.addMemoryItem(item);
    }
    for (final candidate in database.memoryCandidates.readByCreatedAtRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    )) {
      builder.addMemoryCandidate(candidate);
    }
    for (final trace in database.traceEvents.readByCreatedAtRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    )) {
      builder.addTrace(trace);
    }
    for (final cache in database.contextPacketCaches.readByCreatedAtRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    )) {
      builder.addContextCache(cache);
    }

    return builder.build();
  }
}

@immutable
final class UsageStatsSnapshot {
  const UsageStatsSnapshot({
    required this.windowStart,
    required this.windowEnd,
    required this.generatedAt,
    required this.total,
    required this.dailyBuckets,
    required this.weeklyBuckets,
    required this.dailyBucketsByAgent,
    required this.weeklyBucketsByAgent,
    required this.agentSummaries,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime generatedAt;
  final UsageStatsMetrics total;
  final List<UsageStatsBucket> dailyBuckets;
  final List<UsageStatsBucket> weeklyBuckets;
  final Map<String, List<UsageStatsBucket>> dailyBucketsByAgent;
  final Map<String, List<UsageStatsBucket>> weeklyBucketsByAgent;
  final List<UsageStatsAgentSummary> agentSummaries;

  bool get isEmpty => total.isEmpty;

  UsageStatsMetrics metricsFor({String? agentId}) {
    if (agentId == null) {
      return total;
    }
    for (final agent in agentSummaries) {
      if (agent.agentId == agentId) {
        return agent.metrics;
      }
    }
    return UsageStatsMetrics.empty;
  }

  List<UsageStatsBucket> bucketsFor({
    required UsageStatsPeriod period,
    String? agentId,
  }) {
    if (agentId == null) {
      return switch (period) {
        UsageStatsPeriod.day => dailyBuckets,
        UsageStatsPeriod.week => weeklyBuckets,
      };
    }
    return switch (period) {
          UsageStatsPeriod.day => dailyBucketsByAgent[agentId],
          UsageStatsPeriod.week => weeklyBucketsByAgent[agentId],
        } ??
        const <UsageStatsBucket>[];
  }
}

@immutable
final class UsageStatsBucket {
  const UsageStatsBucket({
    required this.key,
    required this.label,
    required this.startsAt,
    required this.metrics,
  });

  final String key;
  final String label;
  final DateTime startsAt;
  final UsageStatsMetrics metrics;
}

@immutable
final class UsageStatsAgentSummary {
  const UsageStatsAgentSummary({required this.agentId, required this.metrics});

  final String agentId;
  final UsageStatsMetrics metrics;
}

@immutable
final class UsageStatsMetrics {
  const UsageStatsMetrics({
    required this.inputCount,
    required this.inputCharacters,
    required this.modelCallCount,
    required this.modelFailureCount,
    required this.modelUsageReportedCount,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.cachedTokens,
    required this.cachedTokenReportedCount,
    required this.thoughtTokens,
    required this.estimatedCostUsd,
    required this.toolRequestCount,
    required this.toolCompletedCount,
    required this.toolFailedCount,
    required this.contextPacketCallCount,
    required this.contextPacketReuseHitCount,
    required this.contextPacketReuseMissCount,
    required this.contextCacheRowCount,
    required this.contextCacheActiveCount,
    required this.contextCacheInvalidatedCount,
    required this.memoryProducedCount,
    required this.acceptedMemoryCount,
    required this.memoryCandidateCount,
  });

  static const empty = UsageStatsMetrics(
    inputCount: 0,
    inputCharacters: 0,
    modelCallCount: 0,
    modelFailureCount: 0,
    modelUsageReportedCount: 0,
    inputTokens: 0,
    outputTokens: 0,
    totalTokens: 0,
    cachedTokens: 0,
    cachedTokenReportedCount: 0,
    thoughtTokens: 0,
    estimatedCostUsd: 0,
    toolRequestCount: 0,
    toolCompletedCount: 0,
    toolFailedCount: 0,
    contextPacketCallCount: 0,
    contextPacketReuseHitCount: 0,
    contextPacketReuseMissCount: 0,
    contextCacheRowCount: 0,
    contextCacheActiveCount: 0,
    contextCacheInvalidatedCount: 0,
    memoryProducedCount: 0,
    acceptedMemoryCount: 0,
    memoryCandidateCount: 0,
  );

  final int inputCount;
  final int inputCharacters;
  final int modelCallCount;
  final int modelFailureCount;
  final int modelUsageReportedCount;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int cachedTokens;
  final int cachedTokenReportedCount;
  final int thoughtTokens;
  final double estimatedCostUsd;
  final int toolRequestCount;
  final int toolCompletedCount;
  final int toolFailedCount;
  final int contextPacketCallCount;
  final int contextPacketReuseHitCount;
  final int contextPacketReuseMissCount;
  final int contextCacheRowCount;
  final int contextCacheActiveCount;
  final int contextCacheInvalidatedCount;
  final int memoryProducedCount;
  final int acceptedMemoryCount;
  final int memoryCandidateCount;

  bool get isEmpty {
    return inputCount == 0 &&
        modelCallCount == 0 &&
        toolRequestCount == 0 &&
        memoryProducedCount == 0 &&
        contextCacheRowCount == 0;
  }

  double? get cachedInputTokenRatio {
    if (cachedTokenReportedCount == 0 || inputTokens == 0) {
      return null;
    }
    return cachedTokens / inputTokens;
  }

  double? get contextPacketReuseRatio {
    if (contextPacketCallCount == 0) {
      return null;
    }
    return contextPacketReuseHitCount / contextPacketCallCount;
  }

  UsageStatsMetrics plus(UsageStatsMetrics other) {
    return UsageStatsMetrics(
      inputCount: inputCount + other.inputCount,
      inputCharacters: inputCharacters + other.inputCharacters,
      modelCallCount: modelCallCount + other.modelCallCount,
      modelFailureCount: modelFailureCount + other.modelFailureCount,
      modelUsageReportedCount:
          modelUsageReportedCount + other.modelUsageReportedCount,
      inputTokens: inputTokens + other.inputTokens,
      outputTokens: outputTokens + other.outputTokens,
      totalTokens: totalTokens + other.totalTokens,
      cachedTokens: cachedTokens + other.cachedTokens,
      cachedTokenReportedCount:
          cachedTokenReportedCount + other.cachedTokenReportedCount,
      thoughtTokens: thoughtTokens + other.thoughtTokens,
      estimatedCostUsd: estimatedCostUsd + other.estimatedCostUsd,
      toolRequestCount: toolRequestCount + other.toolRequestCount,
      toolCompletedCount: toolCompletedCount + other.toolCompletedCount,
      toolFailedCount: toolFailedCount + other.toolFailedCount,
      contextPacketCallCount:
          contextPacketCallCount + other.contextPacketCallCount,
      contextPacketReuseHitCount:
          contextPacketReuseHitCount + other.contextPacketReuseHitCount,
      contextPacketReuseMissCount:
          contextPacketReuseMissCount + other.contextPacketReuseMissCount,
      contextCacheRowCount: contextCacheRowCount + other.contextCacheRowCount,
      contextCacheActiveCount:
          contextCacheActiveCount + other.contextCacheActiveCount,
      contextCacheInvalidatedCount:
          contextCacheInvalidatedCount + other.contextCacheInvalidatedCount,
      memoryProducedCount: memoryProducedCount + other.memoryProducedCount,
      acceptedMemoryCount: acceptedMemoryCount + other.acceptedMemoryCount,
      memoryCandidateCount: memoryCandidateCount + other.memoryCandidateCount,
    );
  }
}

final class _UsageStatsBuilder {
  _UsageStatsBuilder({
    required this.windowStart,
    required this.windowEnd,
    required this.generatedAt,
    required this.database,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime generatedAt;
  final WideNoteLocalDatabase database;
  final _MetricAccumulator _total = _MetricAccumulator();
  final Map<String, _BucketAccumulator> _daily = <String, _BucketAccumulator>{};
  final Map<String, _BucketAccumulator> _weekly =
      <String, _BucketAccumulator>{};
  final Map<String, _MetricAccumulator> _agents =
      <String, _MetricAccumulator>{};
  final Map<String, Map<String, _BucketAccumulator>> _dailyByAgent =
      <String, Map<String, _BucketAccumulator>>{};
  final Map<String, Map<String, _BucketAccumulator>> _weeklyByAgent =
      <String, Map<String, _BucketAccumulator>>{};

  void addCapture(CaptureRecord capture) {
    final text = _captureText(capture.payload);
    _add(capture.createdAt, null, (metrics) {
      metrics.inputCount += 1;
      metrics.inputCharacters += text.length;
    });
  }

  void addMemoryItem(MemoryItemRecord item) {
    final agentId = _memoryAgentId(item.payload, item.sourceEventId);
    _add(item.createdAt, agentId, (metrics) {
      metrics.acceptedMemoryIds.add(item.id);
      metrics.memoryIds.add(item.id);
    });
  }

  void addMemoryCandidate(MemoryCandidateRecord candidate) {
    final agentId = _memoryAgentId(candidate.payload, candidate.sourceEventId);
    _add(candidate.createdAt, agentId, (metrics) {
      metrics.memoryCandidateIds.add(candidate.id);
      metrics.memoryIds.add(candidate.id);
    });
  }

  void addTrace(TraceEventRecord trace) {
    final agentId = _traceAgentId(trace);
    if (_isModelTrace(trace)) {
      _add(trace.createdAt, agentId, (metrics) {
        metrics.modelCallCount += 1;
        if (trace.status.toLowerCase() != 'ok' ||
            trace.name.endsWith('.failed')) {
          metrics.modelFailureCount += 1;
        }
        final inputTokens =
            _intValue(trace.payload['input_tokens']) ??
            _intValue(trace.payload['prompt_tokens']);
        final outputTokens =
            _intValue(trace.payload['output_tokens']) ??
            _intValue(trace.payload['completion_tokens']);
        final totalTokens = _intValue(trace.payload['total_tokens']);
        if (inputTokens != null ||
            outputTokens != null ||
            totalTokens != null) {
          metrics.modelUsageReportedCount += 1;
        }
        metrics.inputTokens += inputTokens ?? 0;
        metrics.outputTokens += outputTokens ?? 0;
        metrics.totalTokens +=
            totalTokens ?? ((inputTokens ?? 0) + (outputTokens ?? 0));
        final cachedTokens = _intValue(trace.payload['cached_tokens']);
        if (cachedTokens != null) {
          metrics.cachedTokenReportedCount += 1;
          metrics.cachedTokens += cachedTokens;
        }
        metrics.thoughtTokens +=
            _intValue(trace.payload['thought_tokens']) ?? 0;
        metrics.estimatedCostUsd +=
            _numValue(trace.payload['estimated_cost_usd'])?.toDouble() ?? 0;
      });
      return;
    }

    if (_isToolTrace(trace)) {
      _add(trace.createdAt, agentId, (metrics) {
        if (trace.name == 'runtime.tool.requested') {
          metrics.toolRequestCount += 1;
        } else if (trace.name == 'runtime.tool.completed') {
          metrics.toolCompletedCount += 1;
        } else if (trace.name == 'runtime.tool.failed' ||
            trace.name == 'runtime.tool.permission_denied' ||
            trace.name == 'runtime.tool.undeclared' ||
            trace.name == 'runtime.tool.unsupported' ||
            trace.name == 'runtime.tool.run_mode_denied') {
          metrics.toolFailedCount += 1;
        }

        if (_toolName(trace.payload) == 'context_packet.build') {
          final reused = _contextPacketReused(trace.payload);
          if (reused != null) {
            metrics.contextPacketCallCount += 1;
            if (reused) {
              metrics.contextPacketReuseHitCount += 1;
            } else {
              metrics.contextPacketReuseMissCount += 1;
            }
          }
        }
      });
    }
  }

  void addContextCache(ContextPacketCacheRecord cache) {
    _add(cache.createdAt, cache.agentId, (metrics) {
      metrics.contextCacheRowCount += 1;
      if (cache.status == 'active') {
        metrics.contextCacheActiveCount += 1;
      } else if (cache.status == 'invalidated') {
        metrics.contextCacheInvalidatedCount += 1;
      }
    });
  }

  UsageStatsSnapshot build() {
    return UsageStatsSnapshot(
      windowStart: windowStart,
      windowEnd: windowEnd,
      generatedAt: generatedAt,
      total: _total.toMetrics(),
      dailyBuckets: _buckets(_daily),
      weeklyBuckets: _buckets(_weekly),
      dailyBucketsByAgent: _agentBuckets(_dailyByAgent),
      weeklyBucketsByAgent: _agentBuckets(_weeklyByAgent),
      agentSummaries:
          _agents.entries
              .map(
                (entry) => UsageStatsAgentSummary(
                  agentId: entry.key,
                  metrics: entry.value.toMetrics(),
                ),
              )
              .where((agent) => !agent.metrics.isEmpty)
              .toList(growable: false)
            ..sort(_compareAgentSummary),
    );
  }

  void _add(
    DateTime createdAt,
    String? agentId,
    void Function(_MetricAccumulator metrics) update,
  ) {
    update(_total);
    update(_bucket(_daily, _dayKey(createdAt)));
    update(_bucket(_weekly, _weekKey(createdAt)));
    if (agentId == null || agentId.trim().isEmpty) {
      return;
    }
    update(_agents.putIfAbsent(agentId, _MetricAccumulator.new));
    update(_agentBucket(_dailyByAgent, agentId, _dayKey(createdAt)));
    update(_agentBucket(_weeklyByAgent, agentId, _weekKey(createdAt)));
  }

  _BucketAccumulator _bucket(
    Map<String, _BucketAccumulator> buckets,
    _BucketKey key,
  ) {
    return buckets.putIfAbsent(
      key.key,
      () => _BucketAccumulator(
        key: key.key,
        label: key.label,
        startsAt: key.startsAt,
      ),
    );
  }

  _BucketAccumulator _agentBucket(
    Map<String, Map<String, _BucketAccumulator>> buckets,
    String agentId,
    _BucketKey key,
  ) {
    final agentBuckets = buckets.putIfAbsent(
      agentId,
      () => <String, _BucketAccumulator>{},
    );
    return _bucket(agentBuckets, key);
  }

  String? _memoryAgentId(JsonMap payload, String? sourceEventId) {
    return _agentIdFromPayload(payload) ??
        (sourceEventId == null
            ? null
            : database.eventLog.readById(sourceEventId)?.agentId);
  }
}

final class _MetricAccumulator {
  int inputCount = 0;
  int inputCharacters = 0;
  int modelCallCount = 0;
  int modelFailureCount = 0;
  int modelUsageReportedCount = 0;
  int inputTokens = 0;
  int outputTokens = 0;
  int totalTokens = 0;
  int cachedTokens = 0;
  int cachedTokenReportedCount = 0;
  int thoughtTokens = 0;
  double estimatedCostUsd = 0;
  int toolRequestCount = 0;
  int toolCompletedCount = 0;
  int toolFailedCount = 0;
  int contextPacketCallCount = 0;
  int contextPacketReuseHitCount = 0;
  int contextPacketReuseMissCount = 0;
  int contextCacheRowCount = 0;
  int contextCacheActiveCount = 0;
  int contextCacheInvalidatedCount = 0;
  final Set<String> memoryIds = <String>{};
  final Set<String> acceptedMemoryIds = <String>{};
  final Set<String> memoryCandidateIds = <String>{};

  UsageStatsMetrics toMetrics() {
    return UsageStatsMetrics(
      inputCount: inputCount,
      inputCharacters: inputCharacters,
      modelCallCount: modelCallCount,
      modelFailureCount: modelFailureCount,
      modelUsageReportedCount: modelUsageReportedCount,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
      cachedTokens: cachedTokens,
      cachedTokenReportedCount: cachedTokenReportedCount,
      thoughtTokens: thoughtTokens,
      estimatedCostUsd: estimatedCostUsd,
      toolRequestCount: toolRequestCount,
      toolCompletedCount: toolCompletedCount,
      toolFailedCount: toolFailedCount,
      contextPacketCallCount: contextPacketCallCount,
      contextPacketReuseHitCount: contextPacketReuseHitCount,
      contextPacketReuseMissCount: contextPacketReuseMissCount,
      contextCacheRowCount: contextCacheRowCount,
      contextCacheActiveCount: contextCacheActiveCount,
      contextCacheInvalidatedCount: contextCacheInvalidatedCount,
      memoryProducedCount: memoryIds.length,
      acceptedMemoryCount: acceptedMemoryIds.length,
      memoryCandidateCount: memoryCandidateIds.length,
    );
  }
}

final class _BucketAccumulator extends _MetricAccumulator {
  _BucketAccumulator({
    required this.key,
    required this.label,
    required this.startsAt,
  });

  final String key;
  final String label;
  final DateTime startsAt;

  UsageStatsBucket toBucket() {
    return UsageStatsBucket(
      key: key,
      label: label,
      startsAt: startsAt,
      metrics: toMetrics(),
    );
  }
}

Map<String, List<UsageStatsBucket>> _agentBuckets(
  Map<String, Map<String, _BucketAccumulator>> source,
) {
  return <String, List<UsageStatsBucket>>{
    for (final entry in source.entries) entry.key: _buckets(entry.value),
  };
}

List<UsageStatsBucket> _buckets(Map<String, _BucketAccumulator> buckets) {
  return buckets.values
      .map((bucket) => bucket.toBucket())
      .toList(growable: false)
    ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
}

int _compareAgentSummary(UsageStatsAgentSummary a, UsageStatsAgentSummary b) {
  final byTokens = b.metrics.totalTokens.compareTo(a.metrics.totalTokens);
  if (byTokens != 0) {
    return byTokens;
  }
  final byCalls = b.metrics.modelCallCount.compareTo(a.metrics.modelCallCount);
  if (byCalls != 0) {
    return byCalls;
  }
  return a.agentId.compareTo(b.agentId);
}

String _captureText(JsonMap payload) {
  return _stringValue(payload['text']) ??
      _stringValue(payload['raw_text']) ??
      '';
}

bool _isModelTrace(TraceEventRecord trace) {
  return trace.name.startsWith('runtime.model.') ||
      trace.name.startsWith('chat.model.') ||
      trace.payload['trace_type'] == 'model';
}

bool _isToolTrace(TraceEventRecord trace) {
  return trace.name.startsWith('runtime.tool.') ||
      trace.payload['trace_type'] == 'tool';
}

String? _traceAgentId(TraceEventRecord trace) {
  return trace.agentId ??
      _agentIdFromPayload(trace.payload) ??
      (trace.runId == null ? null : usageStatsUnknownAgentId);
}

String? _agentIdFromPayload(JsonMap payload) {
  return _stringValue(payload['agent_id']) ?? _stringValue(payload['agentId']);
}

String? _toolName(JsonMap payload) {
  return _stringValue(payload['tool_name']);
}

bool? _contextPacketReused(JsonMap payload) {
  final direct = payload['reused_cache'];
  if (direct is bool) {
    return direct;
  }
  final result = payload['raw_tool_result'];
  if (result is Map) {
    final reused = result['reused_cache'];
    if (reused is bool) {
      return reused;
    }
  }
  return null;
}

int? _intValue(Object? value) {
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

num? _numValue(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value);
  }
  return null;
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

_BucketKey _dayKey(DateTime utc) {
  final local = utc.toLocal();
  final startsAt = DateTime(local.year, local.month, local.day);
  final key = _dateKey(startsAt);
  return _BucketKey(key: key, label: key, startsAt: startsAt);
}

_BucketKey _weekKey(DateTime utc) {
  final local = utc.toLocal();
  final localDay = DateTime(local.year, local.month, local.day);
  final startsAt = localDay.subtract(Duration(days: localDay.weekday - 1));
  final key = _dateKey(startsAt);
  return _BucketKey(key: key, label: key, startsAt: startsAt);
}

String _dateKey(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

final class _BucketKey {
  const _BucketKey({
    required this.key,
    required this.label,
    required this.startsAt,
  });

  final String key;
  final String label;
  final DateTime startsAt;
}
