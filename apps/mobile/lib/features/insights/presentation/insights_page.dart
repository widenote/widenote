import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../../../l10n/l10n.dart';
import '../../timeline/presentation/timeline_widgets.dart';
import '../application/insights_controller.dart';

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(insightsControllerProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(insightsControllerProvider.notifier).refresh();
      },
      child: ListView(
        key: const Key('insights-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PageHeader(
            title: l10n.insightsPageTitle,
            subtitle: l10n.insightsPageSubtitle,
            onBack: () => _goBack(context),
            trailing: IconButton(
              key: const Key('insights-refresh-button'),
              tooltip: l10n.insightsRefreshTooltip,
              onPressed: () =>
                  ref.read(insightsControllerProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorLine(text: localizedInsightError(l10n, state.errorMessage!)),
          ],
          const SizedBox(height: 16),
          _InsightSection(
            key: const Key('insights-active-section'),
            title: l10n.insightsActiveSectionTitle,
            icon: Icons.auto_awesome_outlined,
            emptyText: l10n.insightsActiveEmpty,
            items: state.activeItems,
            isArchived: false,
            onArchive: (item) => ref
                .read(insightsControllerProvider.notifier)
                .archiveInsight(item.id),
            onRestore: (item) => ref
                .read(insightsControllerProvider.notifier)
                .restoreInsight(item.id),
          ),
          if (state.archivedItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InsightSection(
              key: const Key('insights-archived-section'),
              title: l10n.insightsArchivedSectionTitle,
              icon: Icons.archive_outlined,
              emptyText: l10n.insightsArchivedEmpty,
              items: state.archivedItems,
              isArchived: true,
              onArchive: (item) => ref
                  .read(insightsControllerProvider.notifier)
                  .archiveInsight(item.id),
              onRestore: (item) => ref
                  .read(insightsControllerProvider.notifier)
                  .restoreInsight(item.id),
            ),
          ],
        ],
      ),
    );
  }
}

class InsightDetailPage extends ConsumerWidget {
  const InsightDetailPage({required this.insightId, super.key});

  final String insightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(insightsControllerProvider);
    final insight =
        state.itemById(insightId) ??
        ref
            .read(insightsControllerProvider.notifier)
            .readInsightById(insightId);
    if (insight == null) {
      return ListView(
        key: const Key('insight-detail-missing'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PageHeader(
            title: l10n.insightDetailTitle,
            subtitle: l10n.insightDetailSubtitle,
            onBack: () => _goBack(context),
          ),
          const SizedBox(height: 16),
          _Surface(
            icon: Icons.search_off_outlined,
            title: l10n.insightMissingTitle,
            child: Text(l10n.insightMissingBody, style: _mutedStyle(context)),
          ),
        ],
      );
    }

    return ListView(
      key: const Key('insight-detail-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.insightDetailTitle,
          subtitle: l10n.insightDetailSubtitle,
          onBack: () => _goBack(context),
        ),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.lightbulb_outline,
          title: insight.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                insight.summary,
                key: const Key('insight-detail-summary'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              _InsightTags(insight: insight),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: Key('insight-detail-open-timeline-${insight.id}'),
                    onPressed: () => context.push(
                      '/timeline/items/${Uri.encodeComponent(insight.id)}',
                    ),
                    icon: const Icon(Icons.timeline_outlined),
                    label: Text(l10n.insightOpenTimelineAction),
                  ),
                  if (insight.isArchived)
                    FilledButton.icon(
                      key: Key('insight-detail-restore-${insight.id}'),
                      onPressed: () => ref
                          .read(insightsControllerProvider.notifier)
                          .restoreInsight(insight.id),
                      icon: const Icon(Icons.unarchive_outlined),
                      label: Text(l10n.insightActionRestore),
                    )
                  else
                    TextButton.icon(
                      key: Key('insight-detail-archive-${insight.id}'),
                      onPressed: () => ref
                          .read(insightsControllerProvider.notifier)
                          .archiveInsight(insight.id),
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(l10n.insightActionArchive),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (!insight.payload.isEmpty) ...[
          const SizedBox(height: 12),
          _Surface(
            icon: Icons.query_stats,
            title: l10n.insightPayloadSectionTitle,
            child: TimelineInsightPayloadView(
              payload: insight.payload,
              keyPrefix: 'insight-detail-${insight.id}',
              onOpenLink: (link) => _openSourceLink(context, link),
            ),
          ),
        ],
        if (insight.evidence.isNotEmpty) ...[
          const SizedBox(height: 12),
          _EvidenceSection(
            key: const Key('insight-evidence-section'),
            title: l10n.insightEvidenceSectionTitle,
            icon: Icons.fact_check_outlined,
            items: insight.evidence,
            onOpenLink: (link) => _openSourceLink(context, link),
          ),
        ],
        if (insight.counterEvidence.isNotEmpty) ...[
          const SizedBox(height: 12),
          _EvidenceSection(
            key: const Key('insight-counter-evidence-section'),
            title: l10n.insightCounterEvidenceSectionTitle,
            icon: Icons.balance_outlined,
            items: insight.counterEvidence,
            onOpenLink: (link) => _openSourceLink(context, link),
          ),
        ],
        const SizedBox(height: 12),
        _Surface(
          icon: Icons.link,
          title: l10n.timelineSourceRefsTitle,
          child: TimelineSourceRefList(
            links: insight.sourceLinks,
            onOpenLink: (link) => _openSourceLink(context, link),
          ),
        ),
      ],
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.items,
    required this.isArchived,
    required this.onArchive,
    required this.onRestore,
    super.key,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final List<InsightListItem> items;
  final bool isArchived;
  final ValueChanged<InsightListItem> onArchive;
  final ValueChanged<InsightListItem> onRestore;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: icon,
      title: title,
      child: items.isEmpty
          ? Text(emptyText, style: _mutedStyle(context))
          : Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  if (index > 0) const Divider(height: 20),
                  _InsightRow(
                    item: items[index],
                    isArchived: isArchived,
                    onArchive: onArchive,
                    onRestore: onRestore,
                  ),
                ],
              ],
            ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.item,
    required this.isArchived,
    required this.onArchive,
    required this.onRestore,
  });

  final InsightListItem item;
  final bool isArchived;
  final ValueChanged<InsightListItem> onArchive;
  final ValueChanged<InsightListItem> onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return InkWell(
      key: Key('insight-row-${item.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push('/insights/${Uri.encodeComponent(item.id)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isArchived ? Icons.archive_outlined : Icons.lightbulb_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle(context),
                  ),
                  const SizedBox(height: 8),
                  _InsightTags(insight: item),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: Key(
                isArchived
                    ? 'insight-row-restore-${item.id}'
                    : 'insight-row-archive-${item.id}',
              ),
              tooltip: isArchived
                  ? l10n.insightActionRestore
                  : l10n.insightActionArchive,
              onPressed: () => isArchived ? onRestore(item) : onArchive(item),
              icon: Icon(
                isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightTags extends StatelessWidget {
  const _InsightTags({required this.insight});

  final InsightListItem insight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        TimelineTag(
          icon: Icons.category_outlined,
          label: localizedInsightKindLabel(l10n, insight.insightKind),
        ),
        TimelineTag(
          key: Key('insight-source-count-${insight.id}'),
          icon: Icons.link,
          label: l10n.sourceLinkCount(insight.sourceRefCount),
        ),
        if (insight.metricLabel != null && insight.metricValue != null)
          TimelineTag(
            icon: Icons.query_stats,
            label: _metricLabel(l10n, insight),
          ),
        if (insight.confidence != null)
          TimelineTag(
            icon: Icons.speed_outlined,
            label: l10n.insightConfidenceLabel(
              _percentLabel(insight.confidence!),
            ),
          ),
        if (insight.sensitivity != null)
          TimelineTag(
            icon: Icons.privacy_tip_outlined,
            label: localizedSensitivityValue(l10n, insight.sensitivity!),
          ),
        if (insight.requiresReview)
          TimelineTag(
            icon: Icons.rate_review_outlined,
            label: l10n.statusNeedsReview,
          ),
        if (insight.isArchived)
          TimelineTag(
            icon: Icons.archive_outlined,
            label: timelineStatusLabel(l10n, insight.status),
          ),
      ],
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.title,
    required this.icon,
    required this.items,
    required this.onOpenLink,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<InsightEvidenceItem> items;
  final ValueChanged<SourceLink> onOpenLink;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: icon,
      title: title,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const Divider(height: 18),
            _EvidenceRow(item: items[index], onOpenLink: onOpenLink),
          ],
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.item, required this.onOpenLink});

  final InsightEvidenceItem item;
  final ValueChanged<SourceLink> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: Key('insight-evidence-${item.id ?? item.text.hashCode}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.label != null) ...[
          Text(
            item.label!,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(item.text, style: Theme.of(context).textTheme.bodyMedium),
        if (item.confidence != null || item.sourceLinks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (item.confidence != null)
                TimelineTag(
                  icon: Icons.speed_outlined,
                  label: l10n.insightConfidenceLabel(
                    _percentLabel(item.confidence!),
                  ),
                ),
              for (final link in item.sourceLinks)
                ActionChip(
                  key: Key('insight-evidence-source-${link.kind}-${link.id}'),
                  avatar: const Icon(Icons.link, size: 16),
                  label: Text(_sourceRefLabel(l10n, link)),
                  onPressed: () => onOpenLink(link),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          key: const Key('insights-back-button'),
          tooltip: context.l10n.insightsBackTooltip,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 8),
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
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
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

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: const Key('insights-error-line'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

String _metricLabel(AppLocalizations l10n, InsightListItem insight) {
  final label = localizedMetricLabel(l10n, insight.metricLabel!);
  final value = insight.metricValue;
  return value == null ? label : '$value $label';
}

String _sourceRefLabel(AppLocalizations l10n, SourceLink link) {
  final sourceId = safeSourceIdOrNull(link.id) ?? l10n.sourceUnknownLabel;
  return '${sourceKindLabel(l10n, link.kind)}: $sourceId';
}

String _percentLabel(num value) {
  if (value > 1) {
    return '${value.round()}%';
  }
  return '${(value * 100).round()}%';
}

TextStyle? _mutedStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

void _openSourceLink(BuildContext context, SourceLink link) {
  context.push('/timeline/items/${Uri.encodeComponent(link.id)}');
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/');
}
