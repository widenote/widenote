import 'package:flutter/material.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../../../l10n/l10n.dart';
import '../../capture/media/capture_media.dart';
import '../../capture/presentation/attachment_artifact_widgets.dart';

class TimelinePageHeader extends StatelessWidget {
  const TimelinePageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

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
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class TimelineSurface extends StatelessWidget {
  const TimelineSurface({
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

class TimelineEmptyState extends StatelessWidget {
  const TimelineEmptyState({
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return TimelineSurface(
      icon: Icons.inbox_outlined,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

class TimelineItemRows extends StatelessWidget {
  const TimelineItemRows({
    required this.items,
    required this.onOpenItem,
    super.key,
  });

  final List<MemoryFirstTimelineItem> items;
  final ValueChanged<MemoryFirstTimelineItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Divider(height: 20),
          TimelineItemRow(item: items[index], onOpenItem: onOpenItem),
        ],
      ],
    );
  }
}

class TimelineItemRow extends StatelessWidget {
  const TimelineItemRow({
    required this.item,
    required this.onOpenItem,
    super.key,
  });

  final MemoryFirstTimelineItem item;
  final ValueChanged<MemoryFirstTimelineItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final title = localizedTimelineItemTitle(context.l10n, item.title);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          timelineIcon(item.kind),
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: _TimelineItemText(item: item)),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, size: 20),
      ],
    );

    return Semantics(
      button: true,
      enabled: true,
      excludeSemantics: true,
      label: '${kindLabel(context, item)}. $title',
      onTap: () => onOpenItem(item),
      child: InkWell(
        key: Key('timeline-item-${item.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOpenItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

class TimelineSourceRefList extends StatelessWidget {
  const TimelineSourceRefList({
    required this.links,
    this.onOpenLink,
    super.key,
  });

  final List<SourceLink> links;
  final ValueChanged<SourceLink>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < links.length; index++) ...[
          if (index > 0) const Divider(height: 16),
          _SourceRefRow(link: links[index], onOpenLink: onOpenLink),
        ],
      ],
    );
  }
}

class _SourceRefRow extends StatelessWidget {
  const _SourceRefRow({required this.link, required this.onOpenLink});

  final SourceLink link;
  final ValueChanged<SourceLink>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sourceId = safeSourceIdOrNull(link.id) ?? l10n.sourceUnknownLabel;
    return Row(
      key: Key('source-ref-${link.kind}-${link.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.link, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${sourceKindLabel(l10n, link.kind)}: $sourceId',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (link.excerpt != null) ...[
                const SizedBox(height: 2),
                Text(
                  link.excerpt!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onOpenLink != null) ...[
          const SizedBox(width: 8),
          IconButton(
            key: Key('open-source-ref-${link.kind}-${link.id}'),
            tooltip: l10n.timelineOpenSourceTooltip,
            onPressed: () => onOpenLink!(link),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ],
    );
  }
}

class TimelineInsightPayloadView extends StatelessWidget {
  const TimelineInsightPayloadView({
    required this.payload,
    required this.keyPrefix,
    this.compact = false,
    this.showSourceRefs = true,
    this.onOpenLink,
    super.key,
  });

  final MemoryFirstInsightPayload payload;
  final String keyPrefix;
  final bool compact;
  final bool showSourceRefs;
  final ValueChanged<SourceLink>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final claims = compact
        ? payload.claims.take(1).toList(growable: false)
        : payload.claims;
    final metrics = compact
        ? payload.metrics.take(2).toList(growable: false)
        : payload.metrics;
    final sourceLinks = compact
        ? insightPayloadSourceLinks(payload).take(2).toList(growable: false)
        : insightPayloadSourceLinks(payload);

    return Column(
      key: Key('$keyPrefix-insight-payload'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < claims.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _InsightClaimRow(
            keyPrefix: keyPrefix,
            index: index,
            claim: claims[index],
            compact: compact,
          ),
        ],
        if (metrics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final metric in metrics)
                TimelineTag(
                  key: Key('$keyPrefix-insight-metric-${metric.label}'),
                  icon: Icons.query_stats,
                  label: _metricLabel(context.l10n, metric),
                ),
            ],
          ),
        ],
        if (showSourceRefs && sourceLinks.isNotEmpty) ...[
          const SizedBox(height: 8),
          compact
              ? Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final link in sourceLinks)
                      TimelineTag(
                        key: Key(
                          '$keyPrefix-insight-source-${link.kind}-${link.id}',
                        ),
                        icon: Icons.link,
                        label: _sourceRefLabel(context.l10n, link),
                      ),
                  ],
                )
              : TimelineSourceRefList(
                  links: sourceLinks,
                  onOpenLink: onOpenLink,
                ),
        ],
      ],
    );
  }
}

class _InsightClaimRow extends StatelessWidget {
  const _InsightClaimRow({
    required this.keyPrefix,
    required this.index,
    required this.claim,
    required this.compact,
  });

  final String keyPrefix;
  final int index;
  final MemoryFirstInsightClaim claim;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final claimId = claim.id ?? '$index';
    return Row(
      key: Key('$keyPrefix-insight-claim-$claimId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                claim.text,
                maxLines: compact ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (!compact && claim.sourceLinks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final link in claim.sourceLinks)
                      TimelineTag(
                        key: Key(
                          '$keyPrefix-insight-claim-source-${link.kind}-${link.id}',
                        ),
                        icon: Icons.link,
                        label: _sourceRefLabel(context.l10n, link),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

MemoryFirstInsightPayload? timelineInsightPayload(
  MemoryFirstTimelineItem item,
) {
  if (item.kind != MemoryFirstTimelineItemKind.insight) {
    return null;
  }
  final payload = item.metadata['insight_payload'];
  if (payload is! Map) {
    return null;
  }
  final parsed = MemoryFirstInsightPayload.fromJson(
    Map<Object?, Object?>.from(payload),
  );
  return parsed.isEmpty ? null : parsed;
}

List<SourceLink> insightPayloadSourceLinks(MemoryFirstInsightPayload payload) {
  return dedupeSourceLinks(<SourceLink>[
    ...payload.sourceLinks,
    for (final claim in payload.claims) ...claim.sourceLinks,
    for (final metric in payload.metrics) ...metric.sourceLinks,
  ]);
}

String safeSourceId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('/') ||
      trimmed.startsWith('file:') ||
      trimmed.contains('\\')) {
    return '';
  }
  return trimmed;
}

String? safeSourceIdOrNull(String value) {
  final safe = safeSourceId(value);
  return safe.isEmpty ? null : safe;
}

String _sourceRefLabel(AppLocalizations l10n, SourceLink link) {
  final sourceId = safeSourceIdOrNull(link.id) ?? l10n.sourceUnknownLabel;
  return '${sourceKindLabel(l10n, link.kind)}: $sourceId';
}

String _metricLabel(AppLocalizations l10n, MemoryFirstInsightMetric metric) {
  final label = localizedMetricLabel(l10n, metric.label);
  final unit = metric.unit == null ? '' : ' ${metric.unit}';
  return '${metric.value}$unit $label';
}

class _TimelineItemText extends StatelessWidget {
  const _TimelineItemText({required this.item});

  final MemoryFirstTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = localizedTimelineItemTitle(l10n, item.title);
    final artifacts = timelineAttachmentArtifacts(item);
    final insightPayload = timelineInsightPayload(item);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          localizedTimelineItemTitle(l10n, item.body),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (insightPayload != null) ...[
          const SizedBox(height: 8),
          TimelineInsightPayloadView(
            payload: insightPayload,
            keyPrefix: 'timeline-${item.id}',
            compact: true,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TimelineTag(
              icon: Icons.category_outlined,
              label: kindLabel(context, item),
            ),
            TimelineTag(
              icon: Icons.link,
              label: context.l10n.timelineSourceRefCount(
                item.sourceLinks.length,
              ),
            ),
            TimelineTag(icon: Icons.schedule, label: timeLabel(item.createdAt)),
          ],
        ),
        if (artifacts.isNotEmpty) ...[
          const SizedBox(height: 8),
          AttachmentDerivedArtifactChips(
            keyPrefix: 'timeline-${item.id}',
            artifacts: artifacts,
          ),
        ],
      ],
    );
  }
}

class TimelineTag extends StatelessWidget {
  const TimelineTag({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

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
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
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

IconData timelineIcon(MemoryFirstTimelineItemKind kind) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.capture => Icons.notes_outlined,
    MemoryFirstTimelineItemKind.card => Icons.dashboard_customize_outlined,
    MemoryFirstTimelineItemKind.insight => Icons.lightbulb_outline,
    MemoryFirstTimelineItemKind.memory => Icons.psychology_alt_outlined,
    MemoryFirstTimelineItemKind.todo => Icons.task_alt_outlined,
  };
}

String kindLabel(BuildContext context, MemoryFirstTimelineItem item) {
  final l10n = context.l10n;
  final label = timelineKindSingularLabel(l10n, item.kind);
  final status = timelineStatusLabel(l10n, item.status);
  return '$label · $status';
}

String timelineKindSingularLabel(
  AppLocalizations l10n,
  MemoryFirstTimelineItemKind kind,
) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.capture => l10n.timelineKindCapture,
    MemoryFirstTimelineItemKind.card => l10n.timelineKindCard,
    MemoryFirstTimelineItemKind.insight => l10n.timelineKindInsight,
    MemoryFirstTimelineItemKind.memory => l10n.timelineKindMemory,
    MemoryFirstTimelineItemKind.todo => l10n.timelineKindTodo,
  };
}

String timelineStatusLabel(AppLocalizations l10n, String status) {
  return switch (status) {
    'active' => l10n.timelineStatusActive,
    'Saved locally, processing' => l10n.recordStatusSavedProcessing,
    'Processed locally' || 'processed' => l10n.recordStatusProcessed,
    'Saved locally, agent failed' => l10n.recordStatusAgentFailed,
    'open' => l10n.todoStatusOpen,
    'completed' => l10n.todoStatusCompleted,
    'suggested' => l10n.todoStatusSuggestedByAgent,
    'suggested_by_agent' => l10n.todoStatusSuggestedByAgent,
    'needs_explicit_permission' => l10n.todoStatusNeedsExplicitPermission,
    'deleted' => l10n.timelineStatusDeleted,
    'review' => l10n.statusNeedsReview,
    'accepted' => l10n.statusAccepted,
    _ => status,
  };
}

String sourceKindLabel(AppLocalizations l10n, String kind) {
  return switch (kind) {
    'capture' => l10n.timelineKindCapture,
    'card' => l10n.timelineKindCard,
    'insight' => l10n.timelineKindInsight,
    'memory' => l10n.timelineKindMemory,
    'todo' => l10n.timelineKindTodo,
    'event' => l10n.timelineKindEvent,
    'artifact' || 'capture_attachment' => l10n.sourceKindAttachment,
    _ => kind,
  };
}

String timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

List<AttachmentDerivedArtifact> timelineAttachmentArtifacts(
  MemoryFirstTimelineItem item,
) {
  final values = item.metadata['attachment_artifacts'];
  if (values is! List) {
    return const <AttachmentDerivedArtifact>[];
  }
  final artifacts = <AttachmentDerivedArtifact>[];
  for (final value in values) {
    if (value is! Map) {
      continue;
    }
    try {
      artifacts.add(
        AttachmentDerivedArtifact.fromPayload(
          Map<Object?, Object?>.from(value),
        ),
      );
    } on ArgumentError {
      continue;
    }
  }
  return artifacts;
}
