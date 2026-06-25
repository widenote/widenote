import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../application/timeline_repository.dart';
import 'timeline_widgets.dart';

class TimelineItemDetailPage extends ConsumerWidget {
  const TimelineItemDetailPage({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(timelineItemDetailProvider(itemId));
    return detail.when(
      loading: () => const Center(
        key: Key('timeline-item-detail-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => _DetailShell(
        title: 'Timeline Detail',
        child: TimelineSurface(
          icon: Icons.error_outline,
          title: 'Timeline item unavailable',
          child: Text(
            'Timeline item failed: $error',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
      data: (item) {
        if (item == null) {
          return const _DetailShell(
            title: 'Timeline Detail',
            child: TimelineEmptyState(
              key: Key('timeline-item-detail-not-found'),
              title: 'Source not found',
              body:
                  'This source reference is not available in the current local index yet.',
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
    return _DetailShell(
      title: '${_kindTitle(item.kind)} Detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimelineSurface(
            icon: timelineIcon(item.kind),
            title: item.title,
            child: Text(
              item.body,
              key: const Key('timeline-item-detail-body'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 12),
          TimelineSurface(
            icon: Icons.info_outline,
            title: 'Status',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TimelineTag(
                  icon: Icons.category_outlined,
                  label: item.kind.name,
                ),
                TimelineTag(icon: Icons.flag_outlined, label: item.status),
                TimelineTag(
                  icon: Icons.schedule,
                  label: timeLabel(item.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TimelineSurface(
            icon: Icons.link,
            title: 'Source refs',
            child: TimelineSourceRefList(
              links: item.sourceLinks,
              onOpenLink: (link) => _openSourceLink(context, link),
            ),
          ),
          if (item.metadata.isNotEmpty) ...[
            const SizedBox(height: 12),
            TimelineSurface(
              icon: Icons.data_object_outlined,
              title: 'Metadata',
              child: _MetadataRows(metadata: item.metadata),
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
    return ListView(
      key: const Key('timeline-item-detail-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: title,
          subtitle: 'Inspect the local item, status, metadata, and sources.',
          trailing: IconButton(
            key: const Key('timeline-item-detail-back'),
            tooltip: 'Back to timeline',
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

String _kindTitle(MemoryFirstTimelineItemKind kind) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.capture => 'Capture',
    MemoryFirstTimelineItemKind.card => 'Card',
    MemoryFirstTimelineItemKind.insight => 'Insight',
    MemoryFirstTimelineItemKind.memory => 'Memory',
    MemoryFirstTimelineItemKind.todo => 'Todo',
  };
}

void _openSourceLink(BuildContext context, SourceLink link) {
  context.go('/timeline/items/${Uri.encodeComponent(link.id)}');
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/timeline');
}
