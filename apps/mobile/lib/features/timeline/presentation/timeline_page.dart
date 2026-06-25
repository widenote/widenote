import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../application/timeline_repository.dart';
import 'timeline_widgets.dart';

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(timelineSnapshotProvider);
    return snapshot.when(
      loading: () => const _TimelineLoading(),
      error: (error, _) => _TimelineError(
        message: 'Timeline failed to load: $error',
        onRetry: () => ref.invalidate(timelineSnapshotProvider),
      ),
      data: (snapshot) => _TimelineContent(snapshot: snapshot),
    );
  }
}

class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.snapshot});

  final TimelineSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('timeline-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: 'Timeline',
          subtitle: 'Browse captures, cards, Memory, insights, and todos.',
          trailing: IconButton.filledTonal(
            key: const Key('timeline-search-button'),
            tooltip: 'Search timeline',
            onPressed: () => context.go('/timeline/search'),
            icon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (snapshot.isEmpty)
          TimelineEmptyState(
            key: const Key('timeline-empty'),
            title: 'No timeline items yet',
            body: 'Capture something locally to create source-linked cards.',
            action: FilledButton.icon(
              key: const Key('timeline-empty-capture-button'),
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.flash_on_outlined),
              label: const Text('Start capture'),
            ),
          )
        else
          for (final day in snapshot.timeline()) ...[
            _TimelineDaySection(day: day),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _TimelineDaySection extends StatelessWidget {
  const _TimelineDaySection({required this.day});

  final MemoryFirstTimelineDay day;

  @override
  Widget build(BuildContext context) {
    return TimelineSurface(
      key: Key('timeline-day-${day.label}'),
      icon: Icons.calendar_month_outlined,
      title: day.label,
      child: TimelineItemRows(
        items: day.items,
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

class _TimelineLoading extends StatelessWidget {
  const _TimelineLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('timeline-loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _TimelineError extends StatelessWidget {
  const _TimelineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('timeline-error'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: 'Timeline',
          subtitle: 'Browse captures, cards, Memory, insights, and todos.',
        ),
        const SizedBox(height: 16),
        TimelineSurface(
          icon: Icons.error_outline,
          title: 'Timeline unavailable',
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
                key: const Key('timeline-retry-button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
