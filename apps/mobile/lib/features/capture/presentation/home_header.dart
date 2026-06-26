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
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          children: [
            IconButton.filledTonal(
              key: const Key('open-daily-recap-button'),
              tooltip: l10n.homeOpenDailyRecapTooltip,
              onPressed: () => context.push('/recap'),
              icon: const Icon(Icons.today_outlined),
            ),
            IconButton.outlined(
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
            IconButton.outlined(
              key: const Key('open-memory-button'),
              tooltip: l10n.homeOpenMemoryTooltip,
              onPressed: () => context.go('/memory'),
              icon: const Icon(Icons.psychology_alt_outlined),
            ),
            IconButton.outlined(
              key: const Key('open-settings-button'),
              tooltip: l10n.homeOpenSettingsTooltip,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
      ],
    );
  }
}
