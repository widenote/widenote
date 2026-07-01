import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../../../l10n/l10n.dart';
import '../application/daily_recap_repository.dart';
import '../domain/daily_recap_models.dart';

class DailyRecapPage extends ConsumerWidget {
  const DailyRecapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(dailyRecapProvider);
    return snapshot.when(
      loading: () => const Center(
        key: Key('recap-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => _RecapError(
        message: '$error',
        onRetry: () => ref.invalidate(dailyRecapProvider),
      ),
      data: (snapshot) => _RecapContent(snapshot: snapshot),
    );
  }
}

class _RecapContent extends StatelessWidget {
  const _RecapContent({required this.snapshot});

  final DailyRecapSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('recap-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.recapTitle,
          subtitle: l10n.recapSubtitle(_dateLabel(snapshot.localDate)),
          onBack: () => _goBack(context),
        ),
        const SizedBox(height: 16),
        _MetricGrid(snapshot: snapshot),
        if (snapshot.isEmpty) ...[
          const SizedBox(height: 16),
          _EmptyState(title: l10n.recapEmptyTitle, body: l10n.recapEmptyBody),
        ] else ...[
          const SizedBox(height: 16),
          _EntrySection(
            key: const Key('recap-records-section'),
            icon: Icons.notes_outlined,
            title: l10n.recapRecordsTitle,
            emptyText: l10n.recapSectionEmpty,
            entries: snapshot.records,
          ),
          const SizedBox(height: 12),
          _EntrySection(
            key: const Key('recap-memory-section'),
            icon: Icons.psychology_alt_outlined,
            title: l10n.recapMemoryTitle,
            emptyText: l10n.recapSectionEmpty,
            entries: snapshot.memories,
          ),
          const SizedBox(height: 12),
          _EntrySection(
            key: const Key('recap-todos-section'),
            icon: Icons.task_alt_outlined,
            title: l10n.recapTodosTitle,
            emptyText: l10n.recapSectionEmpty,
            entries: snapshot.todos,
          ),
          const SizedBox(height: 12),
          _EntrySection(
            key: const Key('recap-cards-section'),
            icon: Icons.dashboard_customize_outlined,
            title: l10n.recapCardsTitle,
            emptyText: l10n.recapSectionEmpty,
            entries: snapshot.cards,
          ),
          const SizedBox(height: 12),
          _EntrySection(
            key: const Key('recap-insights-section'),
            icon: Icons.lightbulb_outline,
            title: l10n.recapInsightsTitle,
            emptyText: l10n.recapSectionEmpty,
            entries: snapshot.insights,
          ),
          const SizedBox(height: 12),
          _EvidenceLine(snapshot: snapshot),
        ],
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.snapshot});

  final DailyRecapSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = [
      _MetricData(
        key: 'captures',
        label: l10n.recapCapturesMetric,
        value: snapshot.captureCount,
        icon: Icons.article_outlined,
        color: const Color(0xFF2367C9),
      ),
      _MetricData(
        key: 'memory',
        label: l10n.recapMemoryMetric,
        value: snapshot.memoryCount,
        icon: Icons.psychology_alt_outlined,
        color: const Color(0xFF178D66),
      ),
      _MetricData(
        key: 'todo-open',
        label: l10n.recapTodoOpenMetric,
        value: snapshot.todoOpenCount,
        icon: Icons.radio_button_unchecked,
        color: const Color(0xFFC94A3A),
      ),
      _MetricData(
        key: 'todo-completed',
        label: l10n.recapTodoCompletedMetric,
        value: snapshot.todoCompletedCount,
        icon: Icons.check_circle_outline,
        color: const Color(0xFF178D66),
      ),
      _MetricData(
        key: 'cards',
        label: l10n.recapCardsMetric,
        value: snapshot.cardCount,
        icon: Icons.dashboard_customize_outlined,
        color: const Color(0xFF7A5AF8),
      ),
      _MetricData(
        key: 'insights',
        label: l10n.recapInsightsMetric,
        value: snapshot.insightCount,
        icon: Icons.lightbulb_outline,
        color: const Color(0xFFB7791F),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        return GridView.count(
          key: const Key('recap-metric-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isWide ? 2.3 : 1.7,
          children: [
            for (final metric in metrics)
              _MetricTile(key: Key('recap-stat-${metric.key}'), data: metric),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data, super.key});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(data.icon, color: data.color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value.toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntrySection extends StatelessWidget {
  const _EntrySection({
    required this.icon,
    required this.title,
    required this.emptyText,
    required this.entries,
    super.key,
  });

  final IconData icon;
  final String title;
  final String emptyText;
  final List<DailyRecapEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: icon,
      title: title,
      child: entries.isEmpty
          ? Text(
              emptyText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < entries.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  _EntryRow(entry: entries[index]),
                ],
              ],
            ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final DailyRecapEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.timeLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizedRecapEntryTitle(l10n, entry.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                localizedRecapEntryTitle(l10n, entry.body),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _SourceTag(label: localizedSourceLabel(l10n, entry.sourceLabel)),
              if (entry.insightPayload != null) ...[
                const SizedBox(height: 8),
                _RecapInsightPayload(
                  entryId: entry.id,
                  payload: entry.insightPayload!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecapInsightPayload extends StatelessWidget {
  const _RecapInsightPayload({required this.entryId, required this.payload});

  final String entryId;
  final MemoryFirstInsightPayload payload;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sourceLinks = _insightPayloadSourceLinks(payload);
    return Column(
      key: Key('recap-$entryId-insight-payload'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < payload.claims.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          _RecapInsightClaim(
            entryId: entryId,
            index: index,
            claim: payload.claims[index],
          ),
        ],
        if (payload.metrics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final metric in payload.metrics)
                _SourceTag(
                  key: Key('recap-$entryId-insight-metric-${metric.label}'),
                  icon: Icons.query_stats,
                  label: _metricLabel(l10n, metric),
                ),
            ],
          ),
        ],
        if (sourceLinks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final link in sourceLinks.take(3))
                _SourceTag(
                  key: Key(
                    'recap-$entryId-insight-source-${link.kind}-${link.id}',
                  ),
                  label: _sourceRefLabel(l10n, link),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RecapInsightClaim extends StatelessWidget {
  const _RecapInsightClaim({
    required this.entryId,
    required this.index,
    required this.claim,
  });

  final String entryId;
  final int index;
  final MemoryFirstInsightClaim claim;

  @override
  Widget build(BuildContext context) {
    final claimId = claim.id ?? '$index';
    return Row(
      key: Key('recap-$entryId-insight-claim-$claimId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            claim.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

List<SourceLink> _insightPayloadSourceLinks(MemoryFirstInsightPayload payload) {
  return dedupeSourceLinks(<SourceLink>[
    ...payload.sourceLinks,
    for (final claim in payload.claims) ...claim.sourceLinks,
    for (final metric in payload.metrics) ...metric.sourceLinks,
  ]);
}

String _sourceRefLabel(AppLocalizations l10n, SourceLink link) {
  final sourceId = _safeSourceId(link.id) ?? l10n.sourceUnknownLabel;
  return '${localizedSourceKind(l10n, link.kind)}: $sourceId';
}

String _metricLabel(AppLocalizations l10n, MemoryFirstInsightMetric metric) {
  final label = localizedMetricLabel(l10n, metric.label);
  final unit = metric.unit == null ? '' : ' ${metric.unit}';
  return '${metric.value}$unit $label';
}

String? _safeSourceId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('/') ||
      trimmed.startsWith('file:') ||
      trimmed.contains('\\')) {
    return null;
  }
  return trimmed;
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.label, this.icon = Icons.link, super.key});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceLine extends StatelessWidget {
  const _EvidenceLine({required this.snapshot});

  final DailyRecapSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.account_tree_outlined,
      title: l10n.recapEvidenceTitle,
      child: Text(
        l10n.recapEvidenceBody(snapshot.eventCount, snapshot.traceCount),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      key: const Key('recap-empty-state'),
      icon: Icons.today_outlined,
      title: title,
      child: Text(
        body,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RecapError extends StatelessWidget {
  const _RecapError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('recap-error'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.recapTitle,
          subtitle: l10n.recapUnavailableTitle,
          onBack: () => _goBack(context),
        ),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.error_outline,
          title: l10n.recapUnavailableTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('recap-retry-button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retryButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.outlined(
          key: const Key('recap-back-button'),
          tooltip: context.l10n.recapBackTooltip,
          onPressed: onBack,
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
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/');
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.icon,
    required this.title,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6)),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _MetricData {
  const _MetricData({
    required this.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String key;
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

String _dateLabel(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
