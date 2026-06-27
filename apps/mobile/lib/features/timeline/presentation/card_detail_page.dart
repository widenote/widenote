import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../../../l10n/l10n.dart';
import '../application/timeline_repository.dart';
import 'timeline_widgets.dart';

class CardDetailPage extends ConsumerWidget {
  const CardDetailPage({required this.cardId, super.key});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(timelineCardDetailProvider(cardId));
    final l10n = context.l10n;
    return detail.when(
      loading: () => const Center(
        key: Key('card-detail-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => _DetailShell(
        title: l10n.timelineCardDetailTitle,
        child: TimelineSurface(
          icon: Icons.error_outline,
          title: l10n.timelineCardUnavailableTitle,
          child: Text(
            l10n.timelineCardFailed('$error'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
      data: (detail) {
        if (detail == null) {
          return _DetailShell(
            title: l10n.timelineCardDetailTitle,
            child: TimelineEmptyState(
              key: const Key('card-detail-not-found'),
              title: l10n.timelineCardNotFoundTitle,
              body: l10n.timelineCardNotFoundBody,
            ),
          );
        }
        return _CardDetailContent(detail: detail);
      },
    );
  }
}

class _CardDetailContent extends StatelessWidget {
  const _CardDetailContent({required this.detail});

  final MemoryFirstCardDetail detail;

  @override
  Widget build(BuildContext context) {
    final card = detail.card;
    final l10n = context.l10n;
    return _DetailShell(
      title: l10n.timelineCardDetailTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimelineSurface(
            icon: Icons.dashboard_customize_outlined,
            title: card.title,
            child: Text(
              card.body,
              key: const Key('card-detail-body'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 12),
          TimelineSurface(
            icon: Icons.link,
            title: l10n.timelineSourceRefsTitle,
            child: TimelineSourceRefList(
              links: card.sourceLinks,
              onOpenLink: (link) => _openSourceLink(context, link),
            ),
          ),
          const SizedBox(height: 12),
          _RelatedSection(
            title: l10n.timelineRelatedRecordsTitle,
            icon: Icons.notes_outlined,
            items: detail.relatedRecords.toList(growable: false),
          ),
          const SizedBox(height: 12),
          _RelatedSection(
            title: l10n.timelineRelatedMemoryTitle,
            icon: Icons.psychology_alt_outlined,
            items: detail.relatedMemories.toList(growable: false),
          ),
          const SizedBox(height: 12),
          _RelatedSection(
            title: l10n.timelineRelatedTodosTitle,
            icon: Icons.task_alt_outlined,
            items: detail.relatedTodos.toList(growable: false),
          ),
        ],
      ),
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
      key: const Key('card-detail-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: title,
          subtitle: l10n.timelineCardDetailSubtitle,
          trailing: IconButton(
            key: const Key('card-detail-back'),
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

class _RelatedSection extends StatelessWidget {
  const _RelatedSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<MemoryFirstTimelineItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TimelineSurface(
      icon: icon,
      title: title,
      child: items.isEmpty
          ? Text(
              l10n.timelineNoLinkedItems,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : TimelineItemRows(
              items: items,
              onOpenItem: (item) => _openTimelineItem(context, item),
            ),
    );
  }
}

void _openTimelineItem(BuildContext context, MemoryFirstTimelineItem item) {
  if (item.kind == MemoryFirstTimelineItemKind.card) {
    context.go('/timeline/cards/${item.id}');
    return;
  }
  context.go('/timeline/items/${Uri.encodeComponent(item.id)}');
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
