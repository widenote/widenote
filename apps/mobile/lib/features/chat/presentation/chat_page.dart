import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('chat-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _PageHeader(
          title: '对话',
          subtitle: 'Conversation surfaces for local Memory and Agent Packs.',
        ),
        SizedBox(height: 16),
        _ConversationList(),
        SizedBox(height: 16),
        _InputPlaceholder(),
      ],
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: Icons.forum_outlined,
      title: 'Sessions',
      child: Column(
        children: const [
          _SessionRow(
            title: 'Daily review',
            subtitle: 'Ask about today, linked records, and pending todos.',
          ),
          Divider(height: 20),
          _SessionRow(
            title: 'Memory QA',
            subtitle: 'Query editable local Memory with visible provenance.',
          ),
          Divider(height: 20),
          _SessionRow(
            title: 'Agent Pack sandbox',
            subtitle: 'Try pack actions after permission review.',
          ),
        ],
      ),
    );
  }
}

class _InputPlaceholder extends StatelessWidget {
  const _InputPlaceholder();

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: Icons.keyboard_alt_outlined,
      title: 'Input',
      child: TextField(
        enabled: false,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'Ask WideNote about a record, Memory item, or pack run...',
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.chat_bubble_outline,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.icon,
    required this.title,
    required this.child,
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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
