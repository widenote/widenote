import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';

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
    return snapshot.when(
      loading: () => const Center(
        key: Key('timeline-search-loading'),
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => _SearchShell(
        child: TimelineSurface(
          icon: Icons.error_outline,
          title: 'Search unavailable',
          child: Text(
            'Timeline search failed: $error',
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
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter by type, or use text after retriever setup',
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
    return ListView(
      key: const Key('timeline-search-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TimelinePageHeader(
          title: 'Search',
          subtitle: 'Filter the local timeline without leaving the device.',
          trailing: IconButton(
            key: const Key('timeline-search-back'),
            tooltip: 'Back to timeline',
            onPressed: () => context.go('/timeline'),
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
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          key: const Key('timeline-filter-all'),
          label: const Text('All'),
          selected: selectedKind == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final kind in _filterKinds)
          ChoiceChip(
            key: Key('timeline-filter-${kind.name}'),
            label: Text(_filterLabel(kind)),
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
    final kinds = selectedKind == null
        ? const <MemoryFirstTimelineItemKind>{}
        : <MemoryFirstTimelineItemKind>{selectedKind!};
    final results = snapshot.search(
      MemoryFirstTimelineFilter(query: query, kinds: kinds),
    );

    if (snapshot.isEmpty) {
      return const TimelineEmptyState(
        key: Key('timeline-search-empty'),
        title: 'Nothing to search yet',
        body: 'Create a capture first, then browse cards, Memory, and todos.',
      );
    }
    if (query.trim().isNotEmpty) {
      return const TimelineEmptyState(
        key: Key('timeline-search-requires-retriever'),
        title: 'Text search needs a retriever',
        body:
            'Clear the text field to browse locally by type. Semantic search will use a model-backed retriever.',
      );
    }
    if (results.isEmpty) {
      return const TimelineEmptyState(
        key: Key('timeline-search-empty-results'),
        title: 'No matching timeline items',
        body: 'Remove the type filter to show more local items.',
      );
    }

    return TimelineSurface(
      icon: Icons.manage_search_outlined,
      title: '${results.length} result(s)',
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

String _filterLabel(MemoryFirstTimelineItemKind kind) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.card => 'Cards',
    MemoryFirstTimelineItemKind.memory => 'Memory',
    MemoryFirstTimelineItemKind.capture => 'Captures',
    MemoryFirstTimelineItemKind.todo => 'Todos',
    MemoryFirstTimelineItemKind.insight => 'Insights',
  };
}

void _openTimelineItem(BuildContext context, MemoryFirstTimelineItem item) {
  if (item.kind == MemoryFirstTimelineItemKind.card) {
    context.go('/timeline/cards/${item.id}');
    return;
  }
  context.go('/timeline/items/${Uri.encodeComponent(item.id)}');
}
