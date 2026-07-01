import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/chat_controller.dart';
import '../domain/chat_models.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ChatPageContent(controller: _inputController);
  }
}

class _ChatPageContent extends ConsumerWidget {
  const _ChatPageContent({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatControllerProvider);
    return chatState.when(
      data: (state) => _ChatBody(
        state: state,
        controller: controller,
        onSend: () => _send(context, ref),
        onSelectSession: (sessionId) => _selectSession(ref, sessionId),
        onRetry: () => _retry(ref),
      ),
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) => _LoadErrorPage(error: error),
    );
  }

  void _send(BuildContext context, WidgetRef ref) {
    final text = controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    controller.clear();
    FocusScope.of(context).unfocus();
    unawaited(ref.read(chatControllerProvider.notifier).sendMessage(text));
  }

  void _selectSession(WidgetRef ref, String sessionId) {
    unawaited(
      ref.read(chatControllerProvider.notifier).selectSession(sessionId),
    );
  }

  void _retry(WidgetRef ref) {
    unawaited(ref.read(chatControllerProvider.notifier).retryFailedMessage());
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.state,
    required this.controller,
    required this.onSend,
    required this.onSelectSession,
    required this.onRetry,
  });

  final ChatState state;
  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('chat-page'),
      children: [
        Expanded(
          child: ListView(
            key: const Key('chat-message-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              const _PageHeader(),
              const SizedBox(height: 16),
              _SessionsPanel(
                sessions: state.sessions,
                activeSessionId: state.activeSessionId,
                isSending: state.isSending,
                onSelect: onSelectSession,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: state.errorMessage!, onRetry: onRetry),
              ],
              const SizedBox(height: 16),
              _MessagesPanel(state: state, onRetry: onRetry),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _Composer(
              controller: controller,
              isSending: state.isSending,
              onSend: onSend,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('chat-loading'),
      child: CircularProgressIndicator(),
    );
  }
}

class _LoadErrorPage extends StatelessWidget {
  const _LoadErrorPage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('chat-page'),
      padding: const EdgeInsets.all(16),
      children: [
        const _PageHeader(),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.error_outline,
          title: l10n.chatLoadErrorTitle,
          child: Text(l10n.chatLoadErrorBody),
        ),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.chatTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.chatSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SessionsPanel extends StatelessWidget {
  const _SessionsPanel({
    required this.sessions,
    required this.activeSessionId,
    required this.isSending,
    required this.onSelect,
  });

  final List<ChatSession> sessions;
  final String? activeSessionId;
  final bool isSending;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.forum_outlined,
      title: l10n.chatHistoryTitle,
      child: sessions.isEmpty
          ? _EmptyLine(
              key: Key('chat-empty-sessions'),
              text: l10n.chatEmptySessions,
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final session in sessions)
                  ChoiceChip(
                    key: Key('chat-session-${session.id}'),
                    label: Text(session.title),
                    selected: session.id == activeSessionId,
                    tooltip: isSending ? l10n.chatSessionSwitchDisabled : null,
                    onSelected: isSending ? null : (_) => onSelect(session.id),
                  ),
              ],
            ),
    );
  }
}

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({required this.state, required this.onRetry});

  final ChatState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.chat_bubble_outline,
      title: state.activeSession?.title ?? l10n.chatLocalConversationTitle,
      child: state.messages.isEmpty
          ? const _EmptyConversation()
          : Column(
              children: [
                for (final message in state.messages) ...[
                  _MessageBubble(message: message, onRetry: onRetry),
                  const SizedBox(height: 10),
                ],
                if (state.isSending) const _TypingRow(),
              ],
            ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return _EmptyLine(
      key: Key('chat-empty-state'),
      text: context.l10n.chatEmptyConversation,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onRetry});

  final ChatMessage message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser ? colors.primaryContainer : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD8DDE6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (message.status == ChatMessageStatus.failed) ...[
                  const SizedBox(height: 8),
                  _FailedLine(onRetry: onRetry),
                ],
                if (message.toolSummaries.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ToolSummaries(summaries: message.toolSummaries),
                ],
                if (message.sourceRefs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SourceRefs(refs: message.sourceRefs),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FailedLine extends StatelessWidget {
  const _FailedLine({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l10n.chatSendFailed,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        TextButton.icon(
          key: const Key('chat-message-retry-button'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.retryButton),
        ),
      ],
    );
  }
}

class _ToolSummaries extends StatelessWidget {
  const _ToolSummaries({required this.summaries});

  final List<ChatToolSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < summaries.length; index += 1)
          _StatusTag(
            key: Key('chat-tool-summary-$index'),
            icon: _iconForToolStatus(summaries[index].status),
            label:
                '${summaries[index].name} · '
                '${l10n.sourceLinkCount(summaries[index].sourceRefCount)}',
          ),
      ],
    );
  }
}

class _SourceRefs extends StatelessWidget {
  const _SourceRefs({required this.refs});

  final List<ChatSourceRef> refs;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uniqueRefs = _dedupeSourceRefs(refs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.chatSourcesTitle,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var index = 0; index < uniqueRefs.length; index++)
              _SourceTag(
                tagKey: Key(
                  'chat-source-${uniqueRefs[index].kind}-'
                  '${uniqueRefs[index].id}',
                ),
                ref: uniqueRefs[index],
              ),
          ],
        ),
      ],
    );
  }
}

List<ChatSourceRef> _dedupeSourceRefs(List<ChatSourceRef> refs) {
  final seen = <String>{};
  final unique = <ChatSourceRef>[];
  for (final ref in refs) {
    final key = '${ref.kind}\u0000${ref.id}';
    if (seen.add(key)) {
      unique.add(ref);
    }
  }
  return unique;
}

class _SourceTag extends StatelessWidget {
  const _SourceTag({required this.ref, required this.tagKey});

  final ChatSourceRef ref;
  final Key tagKey;

  @override
  Widget build(BuildContext context) {
    final target = _timelineTargetFor(ref);
    final tag = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFD7FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForKind(ref.kind), size: 14),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                '${ref.title} · ${localizedSourceLabel(context.l10n, ref.sourceLabel)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
    if (target == null) {
      return KeyedSubtree(key: tagKey, child: tag);
    }
    return GestureDetector(
      key: tagKey,
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(target),
      child: tag,
    );
  }
}

class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _StatusTag(
        key: const Key('chat-typing-indicator'),
        icon: Icons.auto_awesome,
        label: context.l10n.chatTyping,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFC4C4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${l10n.chatSendFailed}: ${localizedChatError(l10n, message)}',
              ),
            ),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  key: const Key('chat-open-log-center-button'),
                  onPressed: () => context.go('/settings/traces'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(l10n.traceConsoleOpenButton),
                ),
                TextButton.icon(
                  key: const Key('chat-retry-button'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retryButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.keyboard_alt_outlined,
      title: l10n.chatComposerTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('chat-input-field'),
            controller: controller,
            enabled: !isSending,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            autocorrect: true,
            enableSuggestions: true,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) {
              if (!isSending) {
                onSend();
              }
            },
            decoration: InputDecoration(hintText: l10n.chatComposerHint),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('chat-send-button'),
              onPressed: isSending ? null : onSend,
              icon: const Icon(Icons.send),
              label: Text(
                isSending ? l10n.chatGeneratingButton : l10n.chatSendButton,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.icon, required this.label, super.key});

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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

IconData _iconForKind(String kind) {
  return switch (kind) {
    'memory' => Icons.psychology_alt_outlined,
    'todo' => Icons.task_alt_outlined,
    'capture' => Icons.article_outlined,
    _ => Icons.link,
  };
}

IconData _iconForToolStatus(String status) {
  return switch (status) {
    'denied' => Icons.block,
    'failed' => Icons.error_outline,
    _ => Icons.manage_search,
  };
}

String? _timelineTargetFor(ChatSourceRef ref) {
  if (ref.kind == 'capture' || ref.kind == 'event') {
    return '/timeline/items/${Uri.encodeComponent(ref.id)}';
  }
  return null;
}
