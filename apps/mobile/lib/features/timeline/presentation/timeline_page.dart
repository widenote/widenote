import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../../../l10n/l10n.dart';
import '../application/timeline_repository.dart';
import 'timeline_widgets.dart';

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(timelineSnapshotProvider);
    final l10n = context.l10n;
    return snapshot.when(
      loading: () => const _TimelineLoading(),
      error: (error, _) => _TimelineError(
        message: l10n.timelineLoadFailed('$error'),
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
    final l10n = context.l10n;
    return ListView(
      key: const Key('timeline-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: l10n.timelineTitle,
          subtitle: l10n.timelineSubtitle,
          trailing: IconButton.filledTonal(
            key: const Key('timeline-search-button'),
            tooltip: l10n.timelineSearchTooltip,
            onPressed: () => context.push('/timeline/search'),
            icon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        if (snapshot.isEmpty)
          TimelineEmptyState(
            key: const Key('timeline-empty'),
            title: l10n.timelineEmptyTitle,
            body: l10n.timelineEmptyBody,
            action: FilledButton.icon(
              key: const Key('timeline-empty-capture-button'),
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.flash_on_outlined),
              label: Text(l10n.timelineStartCaptureButton),
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
    context.push('/timeline/cards/${item.id}');
    return;
  }
  context.push('/timeline/items/${Uri.encodeComponent(item.id)}');
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
    final l10n = context.l10n;
    return ListView(
      key: const Key('timeline-error'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: l10n.timelineTitle,
          subtitle: l10n.timelineSubtitle,
        ),
        const SizedBox(height: 16),
        TimelineSurface(
          icon: Icons.error_outline,
          title: l10n.timelineUnavailableTitle,
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
                label: Text(l10n.retryButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
