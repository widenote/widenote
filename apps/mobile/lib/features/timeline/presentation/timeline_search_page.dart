import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_cards/widenote_cards.dart';
import 'package:widenote_local_db/widenote_local_db.dart' show JsonList;

import '../../../l10n/l10n.dart';
import '../../retrieval/application/local_search_service.dart';
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

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.snapshot,
    required this.query,
    required this.selectedKind,
  });

  final TimelineSnapshot snapshot;
  final String query;
  final MemoryFirstTimelineItemKind? selectedKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kinds = selectedKind == null
        ? const <MemoryFirstTimelineItemKind>{}
        : <MemoryFirstTimelineItemKind>{selectedKind!};
    final results = snapshot.search(
      MemoryFirstTimelineFilter(query: query, kinds: kinds),
    );
    final trimmedQuery = query.trim();

    if (snapshot.isEmpty) {
      return TimelineEmptyState(
        key: const Key('timeline-search-empty'),
        title: l10n.timelineSearchEmptyTitle,
        body: l10n.timelineSearchEmptyBody,
      );
    }
    if (trimmedQuery.isNotEmpty) {
      final hybrid = ref.watch(
        timelineHybridSearchProvider(
          TimelineHybridSearchRequest(query: trimmedQuery, kind: selectedKind),
        ),
      );
      return hybrid.when(
        loading: () => const Center(
          key: Key('timeline-search-hybrid-loading'),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => TimelineEmptyState(
          key: const Key('timeline-search-hybrid-error'),
          title: l10n.timelineSearchUnavailableTitle,
          body: l10n.timelineSearchFailed('$error'),
        ),
        data: (resultSet) => _HybridResults(resultSet: resultSet),
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

class _HybridResults extends StatelessWidget {
  const _HybridResults({required this.resultSet});

  final TimelineHybridSearchResultSet resultSet;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (resultSet.results.isEmpty) {
      return TimelineEmptyState(
        key: const Key('timeline-search-empty-results'),
        title: l10n.timelineSearchNoResultsTitle,
        body: l10n.timelineSearchNoResultsBody,
      );
    }
    return TimelineSurface(
      icon: resultSet.embeddingUsed
          ? Icons.travel_explore_outlined
          : Icons.manage_search_outlined,
      title: l10n.timelineSearchResultCount(resultSet.results.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              resultSet.embeddingUsed
                  ? l10n.timelineSearchHybridStatus
                  : l10n.timelineSearchKeywordStatus,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (var index = 0; index < resultSet.results.length; index += 1) ...[
            if (index > 0) const Divider(height: 20),
            _HybridResultTile(result: resultSet.results[index]),
          ],
        ],
      ),
    );
  }
}

class _HybridResultTile extends StatelessWidget {
  const _HybridResultTile({required this.result});

  final TimelineHybridSearchResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final snippet = result.snippet ?? l10n.timelineSearchSensitiveSnippetHidden;
    return InkWell(
      key: Key('timeline-search-result-${result.chunkId}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openHybridResult(context, result),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_sourceIcon(result.sourceKind), color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snippet,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _ResultChip(label: _sourceLabel(l10n, result.sourceKind)),
                      for (final match in result.matchedBy.toList()..sort())
                        _ResultChip(label: _matchLabel(l10n, match)),
                      if (result.sensitivity == 'high')
                        _ResultChip(label: l10n.timelineSearchSensitiveBadge),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
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

void _openHybridResult(
  BuildContext context,
  TimelineHybridSearchResult result,
) {
  if (result.sourceKind == 'card') {
    context.push('/timeline/cards/${Uri.encodeComponent(result.sourceId)}');
    return;
  }
  final captureId = _firstSourceId(result.sourceRefs, 'capture');
  final itemId = result.sourceKind == 'derived_artifact'
      ? captureId ?? result.sourceId
      : result.sourceId;
  context.push('/timeline/items/${Uri.encodeComponent(itemId)}');
}

String? _firstSourceId(JsonList sourceRefs, String kind) {
  for (final ref in sourceRefs) {
    if (ref is Map && ref['kind'] == kind && ref['id'] is String) {
      return ref['id']! as String;
    }
  }
  return null;
}

IconData _sourceIcon(String sourceKind) {
  return switch (sourceKind) {
    'card' => Icons.view_agenda_outlined,
    'insight' => Icons.insights_outlined,
    'memory' => Icons.psychology_alt_outlined,
    'todo' => Icons.check_circle_outline,
    'derived_artifact' => Icons.description_outlined,
    _ => Icons.notes_outlined,
  };
}

String _sourceLabel(AppLocalizations l10n, String sourceKind) {
  return switch (sourceKind) {
    'card' => l10n.timelineKindCards,
    'insight' => l10n.timelineKindInsights,
    'memory' => l10n.timelineKindMemory,
    'todo' => l10n.timelineKindTodos,
    'derived_artifact' => l10n.timelineSearchKindArtifact,
    _ => l10n.timelineKindCaptures,
  };
}

String _matchLabel(AppLocalizations l10n, String match) {
  return switch (match) {
    'semantic' => l10n.timelineSearchMatchSemantic,
    'keyword' => l10n.timelineSearchMatchKeyword,
    _ => match,
  };
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go('/timeline');
}
