import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/presentation/backup_page.dart';
import '../features/capture/presentation/home_page.dart';
import '../features/chat/presentation/chat_page.dart';
import '../features/memory/presentation/memory_page.dart';
import '../features/model_providers/presentation/model_provider_settings_page.dart';
import '../features/plugins/presentation/pack_library_page.dart';
import '../features/plugins/presentation/permission_gate_page.dart';
import '../features/plugins/presentation/plugins_page.dart';
import '../features/timeline/presentation/card_detail_page.dart';
import '../features/timeline/presentation/timeline_item_detail_page.dart';
import '../features/timeline/presentation/timeline_page.dart';
import '../features/timeline/presentation/timeline_search_page.dart';
import '../features/todos/presentation/todos_page.dart';
import '../features/traces/presentation/trace_console_page.dart';
import '../l10n/l10n.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return WideNoteShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/timeline',
            name: 'timeline',
            builder: (context, state) => const TimelinePage(),
          ),
          GoRoute(
            path: '/timeline/search',
            name: 'timeline-search',
            builder: (context, state) => const TimelineSearchPage(),
          ),
          GoRoute(
            path: '/timeline/cards/:cardId',
            name: 'card-detail',
            builder: (context, state) =>
                CardDetailPage(cardId: state.pathParameters['cardId'] ?? ''),
          ),
          GoRoute(
            path: '/timeline/items/:itemId',
            name: 'timeline-item-detail',
            builder: (context, state) => TimelineItemDetailPage(
              itemId: state.pathParameters['itemId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            builder: (context, state) => const ChatPage(),
          ),
          GoRoute(
            path: '/memory',
            name: 'memory',
            builder: (context, state) => const MemoryPage(),
          ),
          GoRoute(
            path: '/todos',
            name: 'todos',
            builder: (context, state) => const TodosPage(),
          ),
          GoRoute(
            path: '/plugins',
            name: 'plugins',
            builder: (context, state) => const PluginsPage(),
          ),
          GoRoute(
            path: '/plugins/packs',
            name: 'pack-library',
            builder: (context, state) => const PackLibraryPage(),
          ),
          GoRoute(
            path: '/plugins/permissions',
            name: 'permission-gate',
            builder: (context, state) => const PermissionGatePage(),
          ),
          GoRoute(
            path: '/plugins/model-providers',
            name: 'model-providers',
            builder: (context, state) => const ModelProviderSettingsPage(),
          ),
          GoRoute(
            path: '/plugins/backup',
            name: 'backup',
            builder: (context, state) => const BackupPage(),
          ),
          GoRoute(
            path: '/plugins/traces',
            name: 'trace-console',
            builder: (context, state) => const TraceConsolePage(),
          ),
        ],
      ),
    ],
  );
}

final appRouter = createAppRouter();

class WideNoteShell extends StatelessWidget {
  const WideNoteShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _paths = ['/', '/chat', '/todos', '/plugins'];

  int get _selectedIndex {
    if (location.startsWith('/chat')) {
      return 1;
    }
    if (location.startsWith('/todos')) {
      return 2;
    }
    if (location.startsWith('/plugins')) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => _openTab(context, index),
        destinations: [
          NavigationDestination(
            key: const Key('tab-home'),
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.tabHome,
          ),
          NavigationDestination(
            key: const Key('tab-chat'),
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: l10n.tabChat,
          ),
          NavigationDestination(
            key: const Key('tab-todos'),
            icon: const Icon(Icons.checklist_outlined),
            selectedIcon: const Icon(Icons.checklist),
            label: l10n.tabTodos,
          ),
          NavigationDestination(
            key: const Key('tab-plugins'),
            icon: const Icon(Icons.extension_outlined),
            selectedIcon: const Icon(Icons.extension),
            label: l10n.tabPlugins,
          ),
        ],
      ),
    );
  }

  void _openTab(BuildContext context, int index) {
    final nextPath = _paths[index];
    if (location != nextPath) {
      context.go(nextPath);
    }
  }
}
