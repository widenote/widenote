import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/usage_stats_controller.dart';

class UsageStatsPage extends ConsumerStatefulWidget {
  const UsageStatsPage({super.key});

  @override
  ConsumerState<UsageStatsPage> createState() => _UsageStatsPageState();
}

class _UsageStatsPageState extends ConsumerState<UsageStatsPage> {
  UsageStatsPeriod _period = UsageStatsPeriod.day;
  String? _agentId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = ref.watch(usageStatsControllerProvider);
    final controller = ref.read(usageStatsControllerProvider.notifier);
    final agentId = _validAgentId(snapshot, _agentId);
    final metrics = snapshot.metricsFor(agentId: agentId);
    final buckets = snapshot.bucketsFor(period: _period, agentId: agentId);
    return ListView(
      key: const Key('usage-stats-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.usageStatsTitle,
          subtitle: l10n.usageStatsSubtitle(usageStatsLookbackDays),
          onRefresh: controller.refresh,
        ),
        const SizedBox(height: 16),
        _ScopeSurface(
          period: _period,
          selectedAgentId: agentId,
          agents: snapshot.agentSummaries,
          onPeriodChanged: (period) => setState(() => _period = period),
          onAgentChanged: (agent) => setState(() => _agentId = agent),
        ),
        const SizedBox(height: 16),
        if (snapshot.isEmpty)
          const _EmptySurface()
        else ...[
          _SummarySurface(metrics: metrics),
          const SizedBox(height: 16),
          _TokenSurface(metrics: metrics),
          const SizedBox(height: 16),
          _ToolCacheSurface(metrics: metrics),
          const SizedBox(height: 16),
          _TrendSurface(period: _period, buckets: buckets),
          const SizedBox(height: 16),
          _AgentSurface(agents: snapshot.agentSummaries),
        ],
      ],
    );
  }

  String? _validAgentId(UsageStatsSnapshot snapshot, String? agentId) {
    if (agentId == null) {
      return null;
    }
    final exists = snapshot.agentSummaries.any(
      (agent) => agent.agentId == agentId,
    );
    return exists ? agentId : null;
  }
}

class _ScopeSurface extends StatelessWidget {
  const _ScopeSurface({
    required this.period,
    required this.selectedAgentId,
    required this.agents,
    required this.onPeriodChanged,
    required this.onAgentChanged,
  });

  final UsageStatsPeriod period;
  final String? selectedAgentId;
  final List<UsageStatsAgentSummary> agents;
  final ValueChanged<UsageStatsPeriod> onPeriodChanged;
  final ValueChanged<String?> onAgentChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.tune_outlined,
      title: l10n.usageStatsScopeTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<UsageStatsPeriod>(
            key: const Key('usage-stats-period-selector'),
            segments: [
              ButtonSegment<UsageStatsPeriod>(
                value: UsageStatsPeriod.day,
                icon: const Icon(Icons.calendar_view_day_outlined),
                label: Text(l10n.usageStatsPeriodDaily),
              ),
              ButtonSegment<UsageStatsPeriod>(
                value: UsageStatsPeriod.week,
                icon: const Icon(Icons.calendar_view_week_outlined),
                label: Text(l10n.usageStatsPeriodWeekly),
              ),
            ],
            selected: <UsageStatsPeriod>{period},
            onSelectionChanged: (selection) =>
                onPeriodChanged(selection.single),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.usageStatsAgentFilterTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('usage-stats-agent-all'),
                selected: selectedAgentId == null,
                label: Text(l10n.usageStatsAllAgents),
                onSelected: (_) => onAgentChanged(null),
              ),
              for (final agent in agents.take(8))
                ChoiceChip(
                  key: Key('usage-stats-agent-${agent.agentId}'),
                  selected: selectedAgentId == agent.agentId,
                  label: Text(_agentLabel(l10n, agent.agentId)),
                  onSelected: (_) => onAgentChanged(agent.agentId),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummarySurface extends StatelessWidget {
  const _SummarySurface({required this.metrics});

  final UsageStatsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.query_stats_outlined,
      title: l10n.usageStatsSummaryTitle,
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          _MetricBlock(
            key: const Key('usage-stat-input-count'),
            label: l10n.usageStatsInputCountLabel,
            value: _formatInt(metrics.inputCount),
          ),
          _MetricBlock(
            key: const Key('usage-stat-input-characters'),
            label: l10n.usageStatsInputCharactersLabel,
            value: _formatInt(metrics.inputCharacters),
          ),
          _MetricBlock(
            key: const Key('usage-stat-memory-produced'),
            label: l10n.usageStatsMemoryProducedLabel,
            value: _formatInt(metrics.memoryProducedCount),
          ),
          _MetricBlock(
            key: const Key('usage-stat-model-calls'),
            label: l10n.usageStatsModelCallsLabel,
            value: _formatInt(metrics.modelCallCount),
            detail: metrics.modelFailureCount == 0
                ? null
                : l10n.usageStatsModelFailures(metrics.modelFailureCount),
          ),
          _MetricBlock(
            key: const Key('usage-stat-total-tokens'),
            label: l10n.usageStatsTotalTokensLabel,
            value: _formatInt(metrics.totalTokens),
          ),
          _MetricBlock(
            key: const Key('usage-stat-estimated-cost'),
            label: l10n.usageStatsEstimatedCostLabel,
            value: _formatUsd(metrics.estimatedCostUsd),
          ),
        ],
      ),
    );
  }
}

class _TokenSurface extends StatelessWidget {
  const _TokenSurface({required this.metrics});

  final UsageStatsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final maxTokens = [
      metrics.inputTokens,
      metrics.outputTokens,
      metrics.cachedTokens,
      metrics.thoughtTokens,
    ].fold<int>(0, (max, value) => value > max ? value : max);
    return _Surface(
      icon: Icons.memory_outlined,
      title: l10n.usageStatsTokensTitle,
      child: Column(
        children: [
          _ProgressRow(
            key: const Key('usage-stat-input-tokens'),
            label: l10n.usageStatsInputTokensLabel,
            value: _formatInt(metrics.inputTokens),
            ratio: _ratio(metrics.inputTokens, maxTokens),
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            key: const Key('usage-stat-output-tokens'),
            label: l10n.usageStatsOutputTokensLabel,
            value: _formatInt(metrics.outputTokens),
            ratio: _ratio(metrics.outputTokens, maxTokens),
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            key: const Key('usage-stat-cached-tokens'),
            label: l10n.usageStatsCachedTokensLabel,
            value: metrics.cachedTokenReportedCount == 0
                ? l10n.usageStatsNotReported
                : l10n.usageStatsCachedTokensValue(
                    _formatInt(metrics.cachedTokens),
                    _formatPercent(metrics.cachedInputTokenRatio),
                  ),
            ratio: _ratio(metrics.cachedTokens, maxTokens),
          ),
          const SizedBox(height: 12),
          _ProgressRow(
            key: const Key('usage-stat-thought-tokens'),
            label: l10n.usageStatsThoughtTokensLabel,
            value: metrics.thoughtTokens == 0
                ? l10n.usageStatsNotReported
                : _formatInt(metrics.thoughtTokens),
            ratio: _ratio(metrics.thoughtTokens, maxTokens),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.usageStatsProviderCacheNote,
              style: _mutedStyle(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCacheSurface extends StatelessWidget {
  const _ToolCacheSurface({required this.metrics});

  final UsageStatsMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.construction_outlined,
      title: l10n.usageStatsToolsCacheTitle,
      child: Column(
        children: [
          _InlineStats(
            key: const Key('usage-stat-tool-calls'),
            title: l10n.usageStatsToolCallsLabel,
            value: _formatInt(metrics.toolRequestCount),
            detail: l10n.usageStatsToolBreakdown(
              metrics.toolCompletedCount,
              metrics.toolFailedCount,
            ),
          ),
          const Divider(height: 20),
          _InlineStats(
            key: const Key('usage-stat-context-reuse'),
            title: l10n.usageStatsContextReuseLabel,
            value: metrics.contextPacketReuseRatio == null
                ? l10n.usageStatsNotReported
                : _formatPercent(metrics.contextPacketReuseRatio),
            detail: l10n.usageStatsContextReuseDetail(
              metrics.contextPacketReuseHitCount,
              metrics.contextPacketCallCount,
            ),
          ),
          const Divider(height: 20),
          _InlineStats(
            key: const Key('usage-stat-context-cache-rows'),
            title: l10n.usageStatsContextCacheRowsLabel,
            value: _formatInt(metrics.contextCacheRowCount),
            detail: l10n.usageStatsContextCacheRowsDetail(
              metrics.contextCacheActiveCount,
              metrics.contextCacheInvalidatedCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendSurface extends StatelessWidget {
  const _TrendSurface({required this.period, required this.buckets});

  final UsageStatsPeriod period;
  final List<UsageStatsBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = buckets.take(8).toList(growable: false);
    final maxTokens = visible.fold<int>(
      0,
      (max, bucket) =>
          bucket.metrics.totalTokens > max ? bucket.metrics.totalTokens : max,
    );
    return _Surface(
      icon: Icons.bar_chart_outlined,
      title: period == UsageStatsPeriod.day
          ? l10n.usageStatsDailyTrendTitle
          : l10n.usageStatsWeeklyTrendTitle,
      child: visible.isEmpty
          ? Text(l10n.usageStatsTrendEmpty, key: const Key('usage-trend-empty'))
          : Column(
              children: [
                for (var index = 0; index < visible.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  _TrendRow(bucket: visible[index], maxTokens: maxTokens),
                ],
              ],
            ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.bucket, required this.maxTokens});

  final UsageStatsBucket bucket;
  final int maxTokens;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: Key('usage-trend-${bucket.key}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                bucket.label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              l10n.usageStatsTrendTokenValue(
                _formatInt(bucket.metrics.totalTokens),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: _ratio(bucket.metrics.totalTokens, maxTokens),
          minHeight: 6,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Tag(label: l10n.usageStatsTrendInputs(bucket.metrics.inputCount)),
            _Tag(
              label: l10n.usageStatsTrendTools(bucket.metrics.toolRequestCount),
            ),
            _Tag(
              label: l10n.usageStatsTrendMemory(
                bucket.metrics.memoryProducedCount,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgentSurface extends StatelessWidget {
  const _AgentSurface({required this.agents});

  final List<UsageStatsAgentSummary> agents;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = agents.take(8).toList(growable: false);
    return _Surface(
      icon: Icons.account_tree_outlined,
      title: l10n.usageStatsAgentBreakdownTitle,
      child: visible.isEmpty
          ? Text(l10n.usageStatsAgentEmpty)
          : Column(
              children: [
                for (var index = 0; index < visible.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  _AgentRow(agent: visible[index]),
                ],
              ],
            ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({required this.agent});

  final UsageStatsAgentSummary agent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      key: Key('usage-agent-row-${agent.agentId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.smart_toy_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _agentLabel(l10n, agent.agentId),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(
                    label: l10n.usageStatsAgentTokens(
                      _formatInt(agent.metrics.totalTokens),
                    ),
                  ),
                  _Tag(
                    label: l10n.usageStatsAgentModelCalls(
                      agent.metrics.modelCallCount,
                    ),
                  ),
                  _Tag(
                    label: l10n.usageStatsAgentToolCalls(
                      agent.metrics.toolRequestCount,
                    ),
                  ),
                  _Tag(
                    label: l10n.usageStatsAgentMemory(
                      agent.metrics.memoryProducedCount,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptySurface extends StatelessWidget {
  const _EmptySurface();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.insights_outlined,
      title: l10n.usageStatsEmptyTitle,
      child: Text(l10n.usageStatsEmptyBody),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.detail,
    super.key,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: _mutedStyle(context)),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.ratio,
    super.key,
  });

  final String label;
  final String value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(value, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 6,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }
}

class _InlineStats extends StatelessWidget {
  const _InlineStats({
    required this.title,
    required this.value,
    required this.detail,
    super.key,
  });

  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(detail, style: _mutedStyle(context)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.outlined(
          key: const Key('usage-stats-back-button'),
          tooltip: l10n.usageStatsBackTooltip,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: _mutedStyle(context)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          key: const Key('usage-stats-refresh-button'),
          tooltip: l10n.usageStatsRefreshTooltip,
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

TextStyle? _mutedStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

String _agentLabel(AppLocalizations l10n, String agentId) {
  if (agentId == usageStatsUnknownAgentId) {
    return l10n.usageStatsUnknownAgent;
  }
  return agentId;
}

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    final remaining = text.length - index;
    buffer.write(text[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _formatUsd(double value) {
  if (value <= 0) {
    return r'$0.00';
  }
  if (value < 0.01) {
    return '<\$0.01';
  }
  return '\$${value.toStringAsFixed(2)}';
}

String _formatPercent(double? value) {
  if (value == null) {
    return '--';
  }
  return '${(value * 100).clamp(0, 999).toStringAsFixed(0)}%';
}

double _ratio(int value, int max) {
  if (max <= 0 || value <= 0) {
    return 0;
  }
  return (value / max).clamp(0.0, 1.0);
}
