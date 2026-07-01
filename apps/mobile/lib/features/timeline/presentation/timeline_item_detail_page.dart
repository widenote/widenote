import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../../../l10n/l10n.dart';
import '../../capture/presentation/attachment_artifact_widgets.dart';
import '../application/timeline_repository.dart';
import 'timeline_widgets.dart';

class TimelineItemDetailPage extends ConsumerWidget {
  const TimelineItemDetailPage({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(timelineItemDetailProvider(itemId));
    final l10n = context.l10n;
    return detail.when(
      loading: () => const Center(
        key: Key('timeline-item-detail-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => _DetailShell(
        title: l10n.timelineItemDetailTitle,
        child: TimelineSurface(
          icon: Icons.error_outline,
          title: l10n.timelineItemUnavailableTitle,
          child: Text(
            l10n.timelineItemFailed('$error'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
      data: (item) {
        if (item == null) {
          return _DetailShell(
            title: l10n.timelineItemDetailTitle,
            child: TimelineEmptyState(
              key: const Key('timeline-item-detail-not-found'),
              title: l10n.timelineSourceNotFoundTitle,
              body: l10n.timelineSourceNotFoundBody,
            ),
          );
        }
        return _TimelineItemDetailContent(item: item);
      },
    );
  }
}

class _TimelineItemDetailContent extends StatelessWidget {
  const _TimelineItemDetailContent({required this.item});

  final MemoryFirstTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final artifacts = timelineAttachmentArtifacts(item);
    final insightPayload = timelineInsightPayload(item);
    final visibleMetadata = <String, Object?>{...item.metadata}
      ..remove('attachment_artifacts')
      ..remove('insight_payload');
    return _DetailShell(
      title: l10n.timelineKindDetailTitle(_kindTitle(l10n, item.kind)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimelineSurface(
            icon: timelineIcon(item.kind),
            title: localizedTimelineItemTitle(l10n, item.title),
            child: Text(
              localizedTimelineItemTitle(l10n, item.body),
              key: const Key('timeline-item-detail-body'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (insightPayload != null) ...[
            const SizedBox(height: 12),
            TimelineSurface(
              icon: Icons.query_stats,
              title: localizedInsightKindLabel(
                l10n,
                '${item.metadata['insight_kind'] ?? item.title}',
              ),
              child: TimelineInsightPayloadView(
                payload: insightPayload,
                keyPrefix: 'timeline-detail-${item.id}',
                onOpenLink: (link) => _openSourceLink(context, link),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TimelineSurface(
            icon: Icons.info_outline,
            title: l10n.timelineStatusTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TimelineTag(
                      icon: Icons.category_outlined,
                      label: timelineKindSingularLabel(l10n, item.kind),
                    ),
                    TimelineTag(
                      icon: Icons.flag_outlined,
                      label: timelineStatusLabel(l10n, item.status),
                    ),
                    TimelineTag(
                      icon: Icons.schedule,
                      label: timeLabel(item.createdAt),
                    ),
                  ],
                ),
                if (artifacts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AttachmentDerivedArtifactList(
                    keyPrefix: 'timeline-detail-${item.id}',
                    artifacts: artifacts,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          TimelineSurface(
            icon: Icons.link,
            title: l10n.timelineSourceRefsTitle,
            child: TimelineSourceRefList(
              links: item.sourceLinks,
              onOpenLink: (link) => _openSourceLink(context, link),
            ),
          ),
          if (visibleMetadata.isNotEmpty) ...[
            const SizedBox(height: 12),
            TimelineSurface(
              icon: Icons.data_object_outlined,
              title: l10n.timelineMetadataTitle,
              child: _MetadataRows(metadata: visibleMetadata),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetadataRows extends StatelessWidget {
  const _MetadataRows({required this.metadata});

  final Map<String, Object?> metadata;

  @override
  Widget build(BuildContext context) {
    final entries = metadata.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          if (index > 0) const Divider(height: 16),
          Row(
            key: Key('timeline-item-metadata-${entries[index].key}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  entries[index].key,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entries[index].value}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DetailShell extends StatelessWidget {
  const _DetailShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('timeline-item-detail-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: title,
          subtitle: l10n.timelineItemDetailSubtitle,
          leading: IconButton(
            key: const Key('timeline-item-detail-back'),
            tooltip: l10n.timelineBackTooltip,
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

String _kindTitle(AppLocalizations l10n, MemoryFirstTimelineItemKind kind) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.capture => l10n.timelineKindCapture,
    MemoryFirstTimelineItemKind.card => l10n.timelineKindCard,
    MemoryFirstTimelineItemKind.insight => l10n.timelineKindInsight,
    MemoryFirstTimelineItemKind.memory => l10n.timelineKindMemory,
    MemoryFirstTimelineItemKind.todo => l10n.timelineKindTodo,
  };
}

void _openSourceLink(BuildContext context, SourceLink link) {
  context.push('/timeline/items/${Uri.encodeComponent(link.id)}');
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/timeline');
}
