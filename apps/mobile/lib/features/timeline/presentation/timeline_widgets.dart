import 'package:flutter/material.dart';
import 'package:widenote_cards/widenote_cards.dart';

class TimelinePageHeader extends StatelessWidget {
  const TimelinePageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class TimelineSurface extends StatelessWidget {
  const TimelineSurface({
    required this.icon,
    required this.title,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class TimelineEmptyState extends StatelessWidget {
  const TimelineEmptyState({
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return TimelineSurface(
      icon: Icons.inbox_outlined,
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

class TimelineItemRows extends StatelessWidget {
  const TimelineItemRows({
    required this.items,
    required this.onOpenItem,
    super.key,
  });

  final List<MemoryFirstTimelineItem> items;
  final ValueChanged<MemoryFirstTimelineItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const Divider(height: 20),
          TimelineItemRow(item: items[index], onOpenItem: onOpenItem),
        ],
      ],
    );
  }
}

class TimelineItemRow extends StatelessWidget {
  const TimelineItemRow({
    required this.item,
    required this.onOpenItem,
    super.key,
  });

  final MemoryFirstTimelineItem item;
  final ValueChanged<MemoryFirstTimelineItem> onOpenItem;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          timelineIcon(item.kind),
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(child: _TimelineItemText(item: item)),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right, size: 20),
      ],
    );

    return Semantics(
      button: true,
      enabled: true,
      excludeSemantics: true,
      label: '${kindLabel(item)}. ${item.title}. ${item.status}',
      onTap: () => onOpenItem(item),
      child: InkWell(
        key: Key('timeline-item-${item.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOpenItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: row,
        ),
      ),
    );
  }
}

class TimelineSourceRefList extends StatelessWidget {
  const TimelineSourceRefList({
    required this.links,
    this.onOpenLink,
    super.key,
  });

  final List<SourceLink> links;
  final ValueChanged<SourceLink>? onOpenLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < links.length; index++) ...[
          if (index > 0) const Divider(height: 16),
          Row(
            key: Key('source-ref-${links[index].kind}-${links[index].id}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.link, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${links[index].kind}: ${links[index].id}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (links[index].excerpt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        links[index].excerpt!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onOpenLink != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: Key(
                    'open-source-ref-${links[index].kind}-${links[index].id}',
                  ),
                  tooltip: 'Open source',
                  onPressed: () => onOpenLink!(links[index]),
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _TimelineItemText extends StatelessWidget {
  const _TimelineItemText({required this.item});

  final MemoryFirstTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          item.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TimelineTag(icon: Icons.category_outlined, label: kindLabel(item)),
            TimelineTag(
              icon: Icons.link,
              label: '${item.sourceLinks.length} source ref(s)',
            ),
            TimelineTag(icon: Icons.schedule, label: timeLabel(item.createdAt)),
          ],
        ),
      ],
    );
  }
}

class TimelineTag extends StatelessWidget {
  const TimelineTag({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData timelineIcon(MemoryFirstTimelineItemKind kind) {
  return switch (kind) {
    MemoryFirstTimelineItemKind.capture => Icons.notes_outlined,
    MemoryFirstTimelineItemKind.card => Icons.dashboard_customize_outlined,
    MemoryFirstTimelineItemKind.insight => Icons.lightbulb_outline,
    MemoryFirstTimelineItemKind.memory => Icons.psychology_alt_outlined,
    MemoryFirstTimelineItemKind.todo => Icons.task_alt_outlined,
  };
}

String kindLabel(MemoryFirstTimelineItem item) {
  final label = switch (item.kind) {
    MemoryFirstTimelineItemKind.capture => 'Capture',
    MemoryFirstTimelineItemKind.card => 'Card',
    MemoryFirstTimelineItemKind.insight => 'Insight',
    MemoryFirstTimelineItemKind.memory => 'Memory',
    MemoryFirstTimelineItemKind.todo => 'Todo',
  };
  return '$label · ${item.status}';
}

String timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
