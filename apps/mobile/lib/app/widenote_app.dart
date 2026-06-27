import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/application/chat_controller.dart';
import '../features/chat/application/local_chat_context_source.dart';
import '../l10n/l10n.dart';
import 'app_theme.dart';
import 'app_router.dart';

class WideNoteApp extends StatefulWidget {
  const WideNoteApp({super.key, this.locale});

  final Locale? locale;

  @override
  State<WideNoteApp> createState() => _WideNoteAppState();
}

class _WideNoteAppState extends State<WideNoteApp> {
  late final _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WideNote',
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      locale: widget.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: WideNoteAppTheme.light(),
      routerConfig: _router,
      builder: (context, child) {
        final l10n = context.l10n;
        return ProviderScope(
          overrides: <Override>[
            chatContextLabelsProvider.overrideWithValue(
              ChatContextLabels(
                memoryTitle: l10n.chatContextMemoryTitle,
                recordTitle: l10n.chatContextRecordTitle,
                todoTitle: l10n.chatContextTodoTitle,
                cardTitle: l10n.chatContextCardTitle,
                insightTitle: l10n.chatContextInsightTitle,
                redactedTitle: l10n.chatContextRedactedTitle,
                untitledCapture: l10n.chatContextUntitledCapture,
                untitledTodo: l10n.chatContextUntitledTodo,
              ),
            ),
          ],
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
