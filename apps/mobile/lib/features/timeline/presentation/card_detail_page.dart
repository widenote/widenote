import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../application/timeline_repository.dart';
import 'timeline_widgets.dart';

class CardDetailPage extends ConsumerWidget {
  const CardDetailPage({required this.cardId, super.key});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(timelineCardDetailProvider(cardId));
    return detail.when(
      loading: () => const Center(
        key: Key('card-detail-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => _DetailShell(
        title: 'Card Detail',
        child: TimelineSurface(
          icon: Icons.error_outline,
          title: 'Card unavailable',
          child: Text(
            'Card detail failed: $error',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
      data: (detail) {
        if (detail == null) {
          return const _DetailShell(
            title: 'Card Detail',
            child: TimelineEmptyState(
              key: Key('card-detail-not-found'),
              title: 'Card not found',
              body: 'The selected card is not in the current local timeline.',
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
    return _DetailShell(
      title: 'Card Detail',
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
            title: 'Source refs',
            child: TimelineSourceRefList(links: card.sourceLinks),
          ),
          const SizedBox(height: 12),
          _RelatedSection(
            title: 'Related records',
            icon: Icons.notes_outlined,
            items: detail.relatedRecords.toList(growable: false),
          ),
          const SizedBox(height: 12),
          _RelatedSection(
            title: 'Related Memory',
            icon: Icons.psychology_alt_outlined,
            items: detail.relatedMemories.toList(growable: false),
          ),
          const SizedBox(height: 12),
          _RelatedSection(
            title: 'Related todos',
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
    return ListView(
      key: const Key('card-detail-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: title,
          subtitle: 'Inspect the card body, provenance, and related items.',
          trailing: IconButton(
            key: const Key('card-detail-back'),
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
    return TimelineSurface(
      icon: icon,
      title: title,
      child: items.isEmpty
          ? Text(
              'No linked items.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : TimelineItemRows(items: items, onOpenCard: (_) {}),
    );
  }
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/timeline');
}
