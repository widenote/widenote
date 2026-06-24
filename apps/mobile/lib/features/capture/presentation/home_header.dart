import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.homeSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: [
            IconButton.filledTonal(
              key: const Key('open-timeline-button'),
              tooltip: l10n.homeOpenTimelineTooltip,
              onPressed: () => context.go('/timeline'),
              icon: const Icon(Icons.view_timeline_outlined),
            ),
            IconButton.outlined(
              key: const Key('open-timeline-search-button'),
              tooltip: l10n.homeSearchTooltip,
              onPressed: () => context.go('/timeline/search'),
              icon: const Icon(Icons.search),
            ),
          ],
        ),
      ],
    );
  }
}
