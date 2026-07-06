import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/presentation/backup_page.dart';
import '../features/agent_status/presentation/agent_execution_status_overlay.dart';
import '../features/capture/application/capture_sheet_request.dart';
import '../features/capture/presentation/home_page.dart';
import '../features/chat/presentation/chat_page.dart';
import '../features/insights/presentation/insights_page.dart';
import '../features/memory/presentation/memory_page.dart';
import '../features/model_providers/presentation/model_provider_settings_page.dart';
import '../features/location/presentation/location_settings_page.dart';
import '../features/plugins/presentation/pack_library_page.dart';
import '../features/plugins/presentation/permission_gate_page.dart';
import '../features/plugins/presentation/plugins_page.dart';
import '../features/recap/presentation/daily_recap_page.dart';
import '../features/retrieval/presentation/retrieval_settings_page.dart';
import '../features/settings/presentation/debugging_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/system_permissions/presentation/system_permissions_page.dart';
import '../features/timeline/presentation/card_detail_page.dart';
import '../features/timeline/presentation/timeline_item_detail_page.dart';
import '../features/timeline/presentation/timeline_page.dart';
import '../features/timeline/presentation/timeline_search_page.dart';
import '../features/todos/presentation/todo_detail_page.dart';
import '../features/todos/presentation/todos_page.dart';
import '../features/traces/presentation/trace_console_page.dart';
import '../features/transcription/presentation/voice_transcription_settings_page.dart';
import '../features/usage_stats/presentation/usage_stats_page.dart';
import '../l10n/l10n.dart';
import 'mobile_navigation.dart';

export 'mobile_navigation.dart'
    show
        mobileParentPathFor,
        mobileRouteStackFor,
        openMobileRouteWithParentStack;

GoRouter createAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
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
            routes: [
              GoRoute(
                path: 'timeline',
                name: 'timeline',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state, const TimelinePage()),
                routes: [
                  GoRoute(
                    path: 'search',
                    name: 'timeline-search',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const TimelineSearchPage()),
                  ),
                  GoRoute(
                    path: 'cards/:cardId',
                    name: 'card-detail',
                    pageBuilder: (context, state) => _noTransitionPage(
                      state,
                      CardDetailPage(
                        cardId: state.pathParameters['cardId'] ?? '',
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'items/:itemId',
                    name: 'timeline-item-detail',
                    pageBuilder: (context, state) => _noTransitionPage(
                      state,
                      TimelineItemDetailPage(
                        itemId: state.pathParameters['itemId'] ?? '',
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'memory',
                name: 'memory',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state, const MemoryPage()),
              ),
              GoRoute(
                path: 'recap',
                name: 'daily-recap',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state, const DailyRecapPage()),
              ),
              GoRoute(
                path: 'insights',
                name: 'insights',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state, const InsightsPage()),
                routes: [
                  GoRoute(
                    path: ':insightId',
                    name: 'insight-detail',
                    pageBuilder: (context, state) => _noTransitionPage(
                      state,
                      InsightDetailPage(
                        insightId: state.pathParameters['insightId'] ?? '',
                      ),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: 'settings',
                name: 'settings',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state, const SettingsPage()),
                routes: [
                  GoRoute(
                    path: 'permissions',
                    name: 'settings-permissions',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const PermissionGatePage()),
                  ),
                  GoRoute(
                    path: 'system-permissions',
                    name: 'settings-system-permissions',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const SystemPermissionsPage()),
                  ),
                  GoRoute(
                    path: 'model-providers',
                    name: 'settings-model-providers',
                    pageBuilder: (context, state) => _noTransitionPage(
                      state,
                      const ModelProviderSettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'retrieval',
                    name: 'settings-retrieval',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const RetrievalSettingsPage()),
                  ),
                  GoRoute(
                    path: 'transcription',
                    name: 'settings-transcription',
                    pageBuilder: (context, state) => _noTransitionPage(
                      state,
                      const VoiceTranscriptionSettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'location',
                    name: 'settings-location',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const LocationSettingsPage()),
                  ),
                  GoRoute(
                    path: 'backup',
                    name: 'settings-backup',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const BackupPage()),
                  ),
                  GoRoute(
                    path: 'debugging',
                    name: 'settings-debugging',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const DebuggingPage()),
                  ),
                  GoRoute(
                    path: 'usage-stats',
                    name: 'settings-usage-stats',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const UsageStatsPage()),
                  ),
                  GoRoute(
                    path: 'traces',
                    name: 'settings-traces',
                    pageBuilder: (context, state) =>
                        _noTransitionPage(state, const TraceConsolePage()),
                    routes: [
                      GoRoute(
                        path: 'events',
                        name: 'settings-trace-events',
                        redirect: (context, state) => '/settings/traces/raw',
                      ),
                      GoRoute(
                        path: 'raw',
                        name: 'settings-trace-raw-logs',
                        pageBuilder: (context, state) =>
                            _noTransitionPage(state, const TraceRawLogsPage()),
                        routes: [
                          GoRoute(
                            path: ':traceId',
                            name: 'settings-trace-raw',
                            pageBuilder: (context, state) => _noTransitionPage(
                              state,
                              TraceRawPage(
                                traceId: state.pathParameters['traceId'] ?? '',
                              ),
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: 'agents',
                        name: 'settings-trace-agents',
                        pageBuilder: (context, state) =>
                            _noTransitionPage(state, const TraceAgentsPage()),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/chat',
            name: 'chat',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const ChatPage()),
            routes: [
              GoRoute(
                path: 'session/:sessionId',
                name: 'chat-session',
                pageBuilder: (context, state) => _noTransitionPage(
                  state,
                  ChatSessionPage(
                    sessionId: state.pathParameters['sessionId'] ?? '',
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/todos',
            name: 'todos',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const TodosPage()),
            routes: [
              GoRoute(
                path: ':todoId',
                name: 'todo-detail',
                pageBuilder: (context, state) => _noTransitionPage(
                  state,
                  TodoDetailPage(todoId: state.pathParameters['todoId'] ?? ''),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/plugins',
            name: 'plugins',
            pageBuilder: (context, state) =>
                _noTransitionPage(state, const PluginsPage()),
            routes: [
              GoRoute(
                path: 'packs',
                name: 'pack-library',
                pageBuilder: (context, state) =>
                    _noTransitionPage(state, const PackLibraryPage()),
              ),
            ],
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

  // Index 2 is the center Record action; it opens capture and is not routable.
  static const _paths = ['/', '/chat', '', '/todos', '/plugins'];
  static const _bottomNavigationPaths = {'/', '/chat', '/todos', '/plugins'};
  static const _shellBackHeaderPaths = {
    '/timeline',
    '/memory',
    '/settings',
    '/settings/permissions',
    '/settings/model-providers',
    '/settings/transcription',
    '/settings/location',
    '/settings/backup',
    '/settings/traces',
    '/plugins/packs',
  };

  int get _selectedIndex {
    return switch (location) {
      '/chat' => 1,
      '/todos' => 3,
      '/plugins' => 4,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final showBottomNavigationBar = _bottomNavigationPaths.contains(location);
    final showShellBackHeader = _shellBackHeaderPaths.contains(location);
    return BackButtonListener(
      onBackButtonPressed: () => _handleBackButton(context),
      child: Scaffold(
        body: SafeArea(
          child: AgentExecutionStatusLayer(
            showBottomNavigationBar: showBottomNavigationBar,
            child: showShellBackHeader
                ? _ChildPageBackShell(
                    onBack: () => _handleVisibleBackButton(context),
                    child: child,
                  )
                : child,
          ),
        ),
        bottomNavigationBar: showBottomNavigationBar
            ? NavigationBar(
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
              )
            : null,
      ),
    );
  }

  Future<bool> _handleBackButton(BuildContext context) async {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      return false;
    }
    final parentPath = mobileParentPathFor(location);
    if (parentPath == null) {
      return false;
    }
    context.go(parentPath);
    return true;
  }

  void _handleVisibleBackButton(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final parentPath = mobileParentPathFor(location);
    if (parentPath != null) {
      context.go(parentPath);
    }
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

class _ChildPageBackShell extends StatelessWidget {
  const _ChildPageBackShell({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChildPageBackHeader(onBack: onBack),
        Expanded(child: child),
      ],
    );
  }
}

class _ChildPageBackHeader extends StatelessWidget {
  const _ChildPageBackHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('child-page-back-header'),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 52,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              key: const Key('child-page-back-button'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),
      ),
    );
  }
}
