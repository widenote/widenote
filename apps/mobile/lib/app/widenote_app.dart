import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/application/chat_assistant.dart';
import '../features/chat/application/chat_controller.dart';
import '../features/chat/application/local_chat_context_source.dart';
import '../l10n/l10n.dart';
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
      title: 'WideNote / 广记',
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      locale: widget.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _buildTheme(),
      routerConfig: _router,
      builder: (context, child) {
        final l10n = context.l10n;
        return ProviderScope(
          overrides: <Override>[
            chatAssistantCopyProvider.overrideWithValue(
              ChatAssistantCopy.fromL10n(l10n),
            ),
            chatContextLabelsProvider.overrideWithValue(
              ChatContextLabels(
                memoryTitle: l10n.chatContextMemoryTitle,
                recordTitle: l10n.chatContextRecordTitle,
                todoTitle: l10n.chatContextTodoTitle,
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

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2367C9),
      surface: Colors.white,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFFF6F7F9),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD8DDE6)),
        ),
      ),
    );
  }
}
