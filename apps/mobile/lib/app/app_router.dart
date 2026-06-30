import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/presentation/backup_page.dart';
import '../features/capture/application/capture_sheet_request.dart';
import '../features/capture/presentation/home_page.dart';
import '../features/chat/presentation/chat_page.dart';
import '../features/memory/presentation/memory_page.dart';
import '../features/model_providers/presentation/model_provider_settings_page.dart';
import '../features/plugins/presentation/pack_library_page.dart';
import '../features/plugins/presentation/permission_gate_page.dart';
import '../features/plugins/presentation/plugins_page.dart';
import '../features/recap/presentation/daily_recap_page.dart';
import '../features/settings/presentation/settings_page.dart';
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
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const HomePage()),
          ),
          GoRoute(
            path: '/timeline',
            name: 'timeline',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const TimelinePage()),
          ),
          GoRoute(
            path: '/timeline/search',
            name: 'timeline-search',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const TimelineSearchPage()),
          ),
          GoRoute(
            path: '/timeline/cards/:cardId',
            name: 'card-detail',
            pageBuilder: (context, state) => _noTransitionPage(
              state,
              CardDetailPage(cardId: state.pathParameters['cardId'] ?? ''),
            ),
          ),
          GoRoute(
            path: '/timeline/items/:itemId',
            name: 'timeline-item-detail',
            pageBuilder: (context, state) => _noTransitionPage(
              state,
              TimelineItemDetailPage(
                itemId: state.pathParameters['itemId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const ChatPage()),
          ),
          GoRoute(
            path: '/memory',
            name: 'memory',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const MemoryPage()),
          ),
          GoRoute(
            path: '/recap',
            name: 'daily-recap',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const DailyRecapPage()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const SettingsPage()),
          ),
          GoRoute(
            path: '/settings/permissions',
            name: 'settings-permissions',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const PermissionGatePage()),
          ),
          GoRoute(
            path: '/settings/model-providers',
            name: 'settings-model-providers',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const ModelProviderSettingsPage()),
          ),
          GoRoute(
            path: '/settings/backup',
            name: 'settings-backup',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const BackupPage()),
          ),
          GoRoute(
            path: '/settings/traces',
            name: 'settings-traces',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const TraceConsolePage()),
          ),
          GoRoute(
            path: '/todos',
            name: 'todos',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const TodosPage()),
          ),
          GoRoute(
            path: '/plugins',
            name: 'plugins',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const PluginsPage()),
          ),
          GoRoute(
            path: '/plugins/packs',
            name: 'pack-library',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const PackLibraryPage()),
          ),
          GoRoute(
            path: '/plugins/permissions',
            name: 'permission-gate',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const PermissionGatePage()),
          ),
          GoRoute(
            path: '/plugins/model-providers',
            name: 'model-providers',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const ModelProviderSettingsPage()),
          ),
          GoRoute(
            path: '/plugins/backup',
            name: 'backup',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const BackupPage()),
          ),
          GoRoute(
            path: '/plugins/traces',
            name: 'trace-console',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const TraceConsolePage()),
          ),
        ],
      ),
    ],
  );
}

NoTransitionPage<void> _noTransitionPage(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

final appRouter = createAppRouter();

class WideNoteShell extends ConsumerWidget {
  const WideNoteShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const _paths = ['/', '/chat', '/record', '/todos', '/plugins'];

  int get _selectedIndex {
    if (location.startsWith('/chat')) {
      return 1;
    }
    if (location.startsWith('/todos')) {
      return 3;
    }
    if (location.startsWith('/plugins')) {
      return 4;
    }
    return 0;
  }

  bool get _isPluginsChildRoute {
    return location.startsWith('/plugins/');
  }

  bool get _isSettingsChildRoute {
    return location.startsWith('/settings/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopScope<Object?>(
      canPop: !_isPluginsChildRoute && !_isSettingsChildRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isPluginsChildRoute) {
          context.go('/plugins');
          return;
        }
        if (!didPop && _isSettingsChildRoute) {
          context.go('/settings');
        }
      },
      child: Scaffold(
        body: SafeArea(child: child),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => _openTab(context, ref, index),
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
              key: const Key('tab-record-action'),
              icon: const Icon(Icons.add_circle_outline),
              selectedIcon: const Icon(Icons.add_circle),
              label: l10n.tabRecord,
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
      ),
    );
  }

  void _openTab(BuildContext context, WidgetRef ref, int index) {
    if (index == 2) {
      ref.read(captureSheetRequestProvider.notifier).request();
      if (location != '/') {
        context.go('/');
      }
      return;
    }
    final nextPath = _paths[index];
    if (location != nextPath) {
      context.go(nextPath);
    }
  }
}
