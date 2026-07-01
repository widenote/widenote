import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

import '../../../l10n/l10n.dart';
import '../application/timeline_repository.dart';
import 'timeline_widgets.dart';

class TimelineSearchPage extends ConsumerStatefulWidget {
  const TimelineSearchPage({super.key});

  @override
  ConsumerState<TimelineSearchPage> createState() => _TimelineSearchPageState();
}

class _TimelineSearchPageState extends ConsumerState<TimelineSearchPage> {
  final _controller = TextEditingController();
  MemoryFirstTimelineItemKind? _selectedKind;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(timelineSnapshotProvider);
    final l10n = context.l10n;
    return snapshot.when(
      loading: () => const Center(
        key: Key('timeline-search-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => _SearchShell(
        child: TimelineSurface(
          icon: Icons.error_outline,
          title: l10n.timelineSearchUnavailableTitle,
          child: Text(
            l10n.timelineSearchFailed('$error'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
      data: (snapshot) => _SearchShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('timeline-search-field'),
              controller: _controller,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.timelineSearchHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _KindFilter(
              selectedKind: _selectedKind,
              onChanged: (kind) => setState(() => _selectedKind = kind),
            ),
            const SizedBox(height: 16),
            _SearchResults(
              snapshot: snapshot,
              query: _controller.text,
              selectedKind: _selectedKind,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchShell extends StatelessWidget {
  const _SearchShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('timeline-search-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: l10n.timelineSearchTitle,
          subtitle: l10n.timelineSearchSubtitle,
          leading: IconButton(
            key: const Key('timeline-search-back'),
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

class _KindFilter extends StatelessWidget {
  const _KindFilter({required this.selectedKind, required this.onChanged});

  final MemoryFirstTimelineItemKind? selectedKind;
  final ValueChanged<MemoryFirstTimelineItemKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          key: const Key('timeline-filter-all'),
          label: Text(l10n.timelineFilterAll),
          selected: selectedKind == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final kind in _filterKinds)
          ChoiceChip(
            key: Key('timeline-filter-${kind.name}'),
            label: Text(_filterLabel(l10n, kind)),
            selected: selectedKind == kind,
            onSelected: (_) => onChanged(kind),
          ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.snapshot,
    required this.query,
    required this.selectedKind,
  });

  final TimelineSnapshot snapshot;
  final String query;
  final MemoryFirstTimelineItemKind? selectedKind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kinds = selectedKind == null
        ? const <MemoryFirstTimelineItemKind>{}
        : <MemoryFirstTimelineItemKind>{selectedKind!};
    final results = snapshot.search(
      MemoryFirstTimelineFilter(query: query, kinds: kinds),
    );

    if (snapshot.isEmpty) {
      return TimelineEmptyState(
        key: const Key('timeline-search-empty'),
        title: l10n.timelineSearchEmptyTitle,
        body: l10n.timelineSearchEmptyBody,
      );
    }
    if (query.trim().isNotEmpty) {
      return TimelineEmptyState(
        key: const Key('timeline-search-requires-retriever'),
        title: l10n.timelineSearchNeedsRetrieverTitle,
        body: l10n.timelineSearchNeedsRetrieverBody,
      );
    }
    if (results.isEmpty) {
      return TimelineEmptyState(
        key: const Key('timeline-search-empty-results'),
        title: l10n.timelineSearchNoResultsTitle,
        body: l10n.timelineSearchNoResultsBody,
      );
    }

    return TimelineSurface(
      icon: Icons.manage_search_outlined,
      title: l10n.timelineSearchResultCount(results.length),
      child: TimelineItemRows(
        items: results,
        onOpenItem: (item) => _openTimelineItem(context, item),
      ),
    );
  }
}

const _filterKinds = <MemoryFirstTimelineItemKind>[
  MemoryFirstTimelineItemKind.card,
  MemoryFirstTimelineItemKind.insight,
  MemoryFirstTimelineItemKind.memory,
  MemoryFirstTimelineItemKind.capture,
  MemoryFirstTimelineItemKind.todo,
];

String _filterLabel(AppLocalizations l10n, MemoryFirstTimelineItemKind kind) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.card => l10n.timelineKindCards,
    MemoryFirstTimelineItemKind.memory => l10n.timelineKindMemory,
    MemoryFirstTimelineItemKind.capture => l10n.timelineKindCaptures,
    MemoryFirstTimelineItemKind.todo => l10n.timelineKindTodos,
    MemoryFirstTimelineItemKind.insight => l10n.timelineKindInsights,
  };
}

void _openTimelineItem(BuildContext context, MemoryFirstTimelineItem item) {
  if (item.kind == MemoryFirstTimelineItemKind.card) {
    context.push('/timeline/cards/${item.id}');
    return;
  }
  context.push('/timeline/items/${Uri.encodeComponent(item.id)}');
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/timeline');
}
