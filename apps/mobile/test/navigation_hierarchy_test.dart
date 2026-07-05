import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/app_router.dart';
import 'package:widenote_mobile/app/app_theme.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/agent_status/application/agent_execution_status_controller.dart';
import 'package:widenote_mobile/features/agent_status/application/agent_status_platform.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/features/system_permissions/application/system_permissions_controller.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

import 'support/fake_system_permission_adapter.dart';

void main() {
  testWidgets('timeline child pages return through timeline before home', (
    tester,
  ) async {
    await _pumpWideNoteApp(tester);

    await tester.ensureVisible(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('timeline-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-search-page')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);
    expect(find.byKey(const Key('timeline-search-page')), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byKey(const Key('timeline-page')), findsNothing);
  });

  testWidgets('home search shortcut returns through timeline before home', (
    tester,
  ) async {
    await _pumpWideNoteApp(tester);

    await tester.tap(find.byKey(const Key('open-timeline-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-search-page')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
  });

  testWidgets('home detail shortcuts construct declared parent stacks', (
    tester,
  ) async {
    await _pumpRoute(tester, '/', seed: _seedHomeShortcutTargets);

    await tester.scrollUntilVisible(
      find.byKey(const Key('record-row-capture-nav-shortcut')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record-row-capture-nav-shortcut')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-open-insight-insight-nav-shortcut')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('home-open-insight-insight-nav-shortcut')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('insight-detail-page')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('insights-page')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
  });

  testWidgets('settings child pages return through settings before home', (
    tester,
  ) async {
    await _pumpWideNoteApp(tester);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('settings-model-providers-entry')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-model-providers-entry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('model-provider-settings-page')),
      findsOneWidget,
    );

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(find.byKey(const Key('model-provider-settings-page')), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byKey(const Key('settings-page')), findsNothing);
  });

  testWidgets('cross-tab child links return to their source page', (
    tester,
  ) async {
    await _pumpWideNoteApp(tester);

    await tester.tap(find.byKey(const Key('tab-chat')));
    await tester.pumpAndSettle();
    await _sendChat(tester, 'What records do you have?');
    await _ensureChatVisible(
      tester,
      find.byKey(const Key('chat-open-log-center-button')),
    );
    await tester.tap(find.byKey(const Key('chat-open-log-center-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trace-console-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-session-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await _pumpRoute(tester, '/todos', seed: _seedTodo);
    await tester.tap(find.byKey(const Key('todo-row-todo-nav-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-detail-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final sourceButton = find.byKey(const Key('todo-detail-source-todo-nav-1'));
    await tester.drag(
      find.byKey(const Key('todo-detail-scroll')),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await tester.tap(sourceButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-detail-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todos-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('child pages hide bottom tabs until returning to route roots', (
    tester,
  ) async {
    await _pumpWideNoteApp(tester);

    await tester.ensureVisible(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-search-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-page')), findsOneWidget);
  });

  testWidgets('record action opens capture sheet from a tab route root', (
    tester,
  ) async {
    await _pumpWideNoteApp(tester);

    await tester.tap(find.byKey(const Key('tab-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-record-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
  });

  testWidgets('bottom navigation only appears on tab route roots', (
    tester,
  ) async {
    const rootCases = <_SelectedTabCase>[
      _SelectedTabCase(path: '/', selectedIndex: 0),
      _SelectedTabCase(path: '/chat', selectedIndex: 1),
      _SelectedTabCase(path: '/todos', selectedIndex: 3),
      _SelectedTabCase(path: '/plugins', selectedIndex: 4),
    ];

    for (final routeCase in rootCases) {
      await _pumpRoute(tester, routeCase.path);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        routeCase.selectedIndex,
        reason: routeCase.path,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }

    const childPaths = <String>[
      '/timeline',
      '/timeline/search',
      '/timeline/cards/missing-card',
      '/timeline/items/missing-item',
      '/memory',
      '/recap',
      '/insights',
      '/insights/missing-insight',
      '/settings',
      '/settings/permissions',
      '/settings/system-permissions',
      '/settings/model-providers',
      '/settings/retrieval',
      '/settings/transcription',
      '/settings/location',
      '/settings/backup',
      '/settings/debugging',
      '/settings/usage-stats',
      '/settings/traces',
      '/settings/traces/agents',
      '/settings/traces/events',
      '/settings/traces/raw',
      '/settings/traces/raw/missing-trace',
      '/chat/session/missing-session',
      '/todos/missing-todo',
      '/plugins/packs',
    ];

    for (final childPath in childPaths) {
      await _pumpRoute(tester, childPath);
      expect(find.byType(NavigationBar), findsNothing, reason: childPath);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('agent status overlay preserves shell navigation hierarchy', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 3, 12);
    await _pumpRoute(
      tester,
      '/',
      seed: (database) => _seedAgentRuntimeTask(database, now),
      agentStatusNow: now,
    );

    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('agent-status-overlay')), findsOneWidget);

    await tester.tap(find.byKey(const Key('agent-status-open-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agent-status-open-log-center')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trace-agents-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('agent-status-overlay')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trace-console-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('deep linked home-owned pages expose parent back stacks', (
    tester,
  ) async {
    const cases = <_DeepLinkCase>[
      _DeepLinkCase(
        path: '/timeline',
        pageKey: Key('timeline-page'),
        firstParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/timeline/search',
        pageKey: Key('timeline-search-page'),
        firstParentKey: Key('timeline-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/timeline/cards/missing-card',
        pageKey: Key('card-detail-page'),
        firstParentKey: Key('timeline-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/timeline/items/missing-item',
        pageKey: Key('timeline-item-detail-page'),
        firstParentKey: Key('timeline-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/memory',
        pageKey: Key('memory-page'),
        firstParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/recap',
        pageKey: Key('recap-page'),
        firstParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/insights',
        pageKey: Key('insights-page'),
        firstParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/insights/missing-insight',
        pageKey: Key('insight-detail-missing'),
        firstParentKey: Key('insights-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings',
        pageKey: Key('settings-page'),
        firstParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/permissions',
        pageKey: Key('permission-gate-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/system-permissions',
        pageKey: Key('system-permissions-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/model-providers',
        pageKey: Key('model-provider-settings-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/retrieval',
        pageKey: Key('retrieval-settings-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/transcription',
        pageKey: Key('voice-transcription-settings-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/location',
        pageKey: Key('location-settings-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/backup',
        pageKey: Key('backup-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/debugging',
        pageKey: Key('debugging-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/usage-stats',
        pageKey: Key('usage-stats-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/traces',
        pageKey: Key('trace-console-page'),
        firstParentKey: Key('settings-page'),
        secondParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/traces/agents',
        pageKey: Key('trace-agents-page'),
        firstParentKey: Key('trace-console-page'),
        secondParentKey: Key('settings-page'),
        thirdParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/traces/events',
        pageKey: Key('trace-raw-logs-page'),
        firstParentKey: Key('trace-console-page'),
        secondParentKey: Key('settings-page'),
        thirdParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/traces/raw',
        pageKey: Key('trace-raw-logs-page'),
        firstParentKey: Key('trace-console-page'),
        secondParentKey: Key('settings-page'),
        thirdParentKey: Key('home-page'),
      ),
      _DeepLinkCase(
        path: '/settings/traces/raw/missing-trace',
        pageKey: Key('trace-raw-page'),
        firstParentKey: Key('trace-raw-logs-page'),
        secondParentKey: Key('trace-console-page'),
        thirdParentKey: Key('settings-page'),
        fourthParentKey: Key('home-page'),
      ),
    ];

    for (final routeCase in cases) {
      await _pumpRoute(tester, routeCase.path);
      expect(
        find.byKey(routeCase.pageKey),
        findsOneWidget,
        reason: routeCase.path,
      );

      expect(
        await tester.binding.handlePopRoute(),
        isTrue,
        reason: routeCase.path,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(routeCase.firstParentKey),
        findsOneWidget,
        reason: routeCase.path,
      );

      final secondParentKey = routeCase.secondParentKey;
      if (secondParentKey != null) {
        expect(
          await tester.binding.handlePopRoute(),
          isTrue,
          reason: routeCase.path,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(secondParentKey),
          findsOneWidget,
          reason: routeCase.path,
        );
      }

      final thirdParentKey = routeCase.thirdParentKey;
      if (thirdParentKey != null) {
        expect(
          await tester.binding.handlePopRoute(),
          isTrue,
          reason: routeCase.path,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(thirdParentKey),
          findsOneWidget,
          reason: routeCase.path,
        );
      }

      final fourthParentKey = routeCase.fourthParentKey;
      if (fourthParentKey != null) {
        expect(
          await tester.binding.handlePopRoute(),
          isTrue,
          reason: routeCase.path,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(fourthParentKey),
          findsOneWidget,
          reason: routeCase.path,
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('deep linked pack library returns to plugins tab root', (
    tester,
  ) async {
    const routeCase = _DeepLinkCase(
      path: '/plugins/packs',
      pageKey: Key('pack-library-page'),
      firstParentKey: Key('plugins-page'),
    );

    await _pumpRoute(tester, routeCase.path);
    expect(find.byKey(routeCase.pageKey), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(routeCase.firstParentKey), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plugins-page')), findsOneWidget);
  });

  testWidgets('plugins shortcuts construct settings parent stacks', (
    tester,
  ) async {
    const cases = <_ShortcutCase>[
      _ShortcutCase(
        entryKey: Key('permission-gate-entry'),
        pageKey: Key('permission-gate-page'),
      ),
      _ShortcutCase(
        entryKey: Key('model-provider-entry'),
        pageKey: Key('model-provider-settings-page'),
      ),
      _ShortcutCase(entryKey: Key('backup-entry'), pageKey: Key('backup-page')),
      _ShortcutCase(
        entryKey: Key('trace-console-entry'),
        pageKey: Key('trace-console-page'),
      ),
    ];

    await _pumpWideNoteApp(tester);

    for (final routeCase in cases) {
      await tester.tap(find.byKey(const Key('tab-plugins')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plugins-page')), findsOneWidget);

      await tester.ensureVisible(find.byKey(routeCase.entryKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(routeCase.entryKey));
      await tester.pumpAndSettle();
      expect(
        find.byKey(routeCase.pageKey),
        findsOneWidget,
        reason: '${routeCase.entryKey}',
      );
      expect(find.byType(NavigationBar), findsNothing);

      expect(
        await tester.binding.handlePopRoute(),
        isTrue,
        reason: '${routeCase.entryKey}',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-page')),
        findsOneWidget,
        reason: '${routeCase.entryKey}',
      );

      expect(
        await tester.binding.handlePopRoute(),
        isTrue,
        reason: '${routeCase.entryKey}',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('home-page')),
        findsOneWidget,
        reason: '${routeCase.entryKey}',
      );
      expect(find.byKey(routeCase.pageKey), findsNothing);
    }
  });

  testWidgets('deep linked chat session returns to chat list', (tester) async {
    await _pumpRoute(
      tester,
      '/chat/session/nav-session',
      seed: _seedChatSession,
    );

    expect(find.byKey(const Key('chat-session-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.byKey(const Key('chat-session-page')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('missing chat session deep link returns to chat list safely', (
    tester,
  ) async {
    await _pumpRoute(tester, '/chat/session/missing-session');

    expect(find.byKey(const Key('chat-session-missing')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('orphaned child locations fall back to declared parents', (
    tester,
  ) async {
    const cases = <_FlatRouteCase>[
      _FlatRouteCase(
        location: '/timeline',
        routePattern: '/timeline',
        pageKey: Key('timeline-page'),
        parentPath: '/',
        parentKey: Key('home-page'),
      ),
      _FlatRouteCase(
        location: '/timeline/search',
        routePattern: '/timeline/search',
        pageKey: Key('timeline-search-page'),
        parentPath: '/timeline',
        parentKey: Key('timeline-page'),
      ),
      _FlatRouteCase(
        location: '/timeline/cards/missing-card',
        routePattern: '/timeline/cards/:cardId',
        pageKey: Key('card-detail-page'),
        parentPath: '/timeline',
        parentKey: Key('timeline-page'),
      ),
      _FlatRouteCase(
        location: '/timeline/items/missing-item',
        routePattern: '/timeline/items/:itemId',
        pageKey: Key('timeline-item-detail-page'),
        parentPath: '/timeline',
        parentKey: Key('timeline-page'),
      ),
      _FlatRouteCase(
        location: '/memory',
        routePattern: '/memory',
        pageKey: Key('memory-page'),
        parentPath: '/',
        parentKey: Key('home-page'),
      ),
      _FlatRouteCase(
        location: '/recap',
        routePattern: '/recap',
        pageKey: Key('recap-page'),
        parentPath: '/',
        parentKey: Key('home-page'),
      ),
      _FlatRouteCase(
        location: '/insights',
        routePattern: '/insights',
        pageKey: Key('insights-page'),
        parentPath: '/',
        parentKey: Key('home-page'),
      ),
      _FlatRouteCase(
        location: '/insights/missing-insight',
        routePattern: '/insights/:insightId',
        pageKey: Key('insight-detail-missing'),
        parentPath: '/insights',
        parentKey: Key('insights-page'),
      ),
      _FlatRouteCase(
        location: '/settings',
        routePattern: '/settings',
        pageKey: Key('settings-page'),
        parentPath: '/',
        parentKey: Key('home-page'),
      ),
      _FlatRouteCase(
        location: '/settings/permissions',
        routePattern: '/settings/permissions',
        pageKey: Key('permission-gate-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/system-permissions',
        routePattern: '/settings/system-permissions',
        pageKey: Key('system-permissions-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/model-providers',
        routePattern: '/settings/model-providers',
        pageKey: Key('model-provider-settings-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/retrieval',
        routePattern: '/settings/retrieval',
        pageKey: Key('retrieval-settings-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/transcription',
        routePattern: '/settings/transcription',
        pageKey: Key('voice-transcription-settings-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/location',
        routePattern: '/settings/location',
        pageKey: Key('location-settings-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/backup',
        routePattern: '/settings/backup',
        pageKey: Key('backup-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/debugging',
        routePattern: '/settings/debugging',
        pageKey: Key('debugging-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/usage-stats',
        routePattern: '/settings/usage-stats',
        pageKey: Key('usage-stats-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/traces',
        routePattern: '/settings/traces',
        pageKey: Key('trace-console-page'),
        parentPath: '/settings',
        parentKey: Key('settings-page'),
      ),
      _FlatRouteCase(
        location: '/settings/traces/agents',
        routePattern: '/settings/traces/agents',
        pageKey: Key('trace-agents-page'),
        parentPath: '/settings/traces',
        parentKey: Key('trace-console-page'),
      ),
      _FlatRouteCase(
        location: '/settings/traces/events',
        routePattern: '/settings/traces/events',
        pageKey: Key('trace-raw-logs-page'),
        parentPath: '/settings/traces',
        parentKey: Key('trace-console-page'),
      ),
      _FlatRouteCase(
        location: '/settings/traces/raw',
        routePattern: '/settings/traces/raw',
        pageKey: Key('trace-raw-logs-page'),
        parentPath: '/settings/traces',
        parentKey: Key('trace-console-page'),
      ),
      _FlatRouteCase(
        location: '/settings/traces/raw/missing-trace',
        routePattern: '/settings/traces/raw/:traceId',
        pageKey: Key('trace-raw-page'),
        parentPath: '/settings/traces/raw',
        parentKey: Key('trace-raw-logs-page'),
      ),
      _FlatRouteCase(
        location: '/chat/session/missing-session',
        routePattern: '/chat/session/:sessionId',
        pageKey: Key('chat-session-page'),
        parentPath: '/chat',
        parentKey: Key('chat-page'),
      ),
      _FlatRouteCase(
        location: '/todos/missing-todo',
        routePattern: '/todos/:todoId',
        pageKey: Key('todo-detail-page'),
        parentPath: '/todos',
        parentKey: Key('todos-page'),
      ),
      _FlatRouteCase(
        location: '/plugins/packs',
        routePattern: '/plugins/packs',
        pageKey: Key('pack-library-page'),
        parentPath: '/plugins',
        parentKey: Key('plugins-page'),
      ),
    ];

    for (final routeCase in cases) {
      expect(
        mobileParentPathFor(routeCase.location),
        routeCase.parentPath,
        reason: routeCase.location,
      );
      await _pumpFlatShellRoute(tester, routeCase);
      expect(
        find.byKey(routeCase.pageKey),
        findsOneWidget,
        reason: routeCase.location,
      );

      expect(
        await tester.binding.handlePopRoute(),
        isTrue,
        reason: routeCase.location,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(routeCase.parentKey),
        findsOneWidget,
        reason: routeCase.location,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

class _DeepLinkCase {
  const _DeepLinkCase({
    required this.path,
    required this.pageKey,
    required this.firstParentKey,
    this.secondParentKey,
    this.thirdParentKey,
    this.fourthParentKey,
  });

  final String path;
  final Key pageKey;
  final Key firstParentKey;
  final Key? secondParentKey;
  final Key? thirdParentKey;
  final Key? fourthParentKey;
}

class _SelectedTabCase {
  const _SelectedTabCase({required this.path, required this.selectedIndex});

  final String path;
  final int selectedIndex;
}

class _ShortcutCase {
  const _ShortcutCase({required this.entryKey, required this.pageKey});

  final Key entryKey;
  final Key pageKey;
}

class _FlatRouteCase {
  const _FlatRouteCase({
    required this.location,
    required this.routePattern,
    required this.pageKey,
    required this.parentPath,
    required this.parentKey,
  });

  final String location;
  final String routePattern;
  final Key pageKey;
  final String parentPath;
  final Key parentKey;
}

Future<void> _pumpWideNoteApp(WidgetTester tester) async {
  final database = WideNoteLocalDatabase.inMemory();
  final agentStatusNow = DateTime.utc(2026, 7, 3, 12);
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
        systemPermissionAdapterProvider.overrideWithValue(
          FakeSystemPermissionAdapter.ready(),
        ),
        agentStatusPlatformClientProvider.overrideWithValue(
          const _NoopAgentStatusPlatformClient(),
        ),
        agentExecutionStatusNowProvider.overrideWithValue(() => agentStatusNow),
      ],
      child: const WideNoteApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRoute(
  WidgetTester tester,
  String initialLocation, {
  void Function(WideNoteLocalDatabase database)? seed,
  DateTime? agentStatusNow,
}) async {
  final database = WideNoteLocalDatabase.inMemory();
  final effectiveAgentStatusNow =
      agentStatusNow ?? DateTime.utc(2026, 7, 3, 12);
  seed?.call(database);
  final router = createAppRouter(initialLocation: initialLocation);
  addTearDown(database.close);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
        systemPermissionAdapterProvider.overrideWithValue(
          FakeSystemPermissionAdapter.ready(),
        ),
        agentStatusPlatformClientProvider.overrideWithValue(
          const _NoopAgentStatusPlatformClient(),
        ),
        agentExecutionStatusNowProvider.overrideWithValue(
          () => effectiveAgentStatusNow,
        ),
      ],
      child: MaterialApp.router(
        title: 'WideNote',
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: WideNoteAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpFlatShellRoute(
  WidgetTester tester,
  _FlatRouteCase routeCase,
) async {
  final database = WideNoteLocalDatabase.inMemory();
  final routeKeys = <String, Key>{
    '/': const Key('home-page'),
    '/chat': const Key('chat-page'),
    '/todos': const Key('todos-page'),
    '/plugins': const Key('plugins-page'),
    routeCase.parentPath: routeCase.parentKey,
    routeCase.routePattern: routeCase.pageKey,
  };
  final router = GoRouter(
    initialLocation: routeCase.location,
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          return WideNoteShell(location: state.uri.path, child: child);
        },
        routes: [
          for (final entry in routeKeys.entries)
            GoRoute(
              path: entry.key,
              pageBuilder: (context, state) => NoTransitionPage<void>(
                key: state.pageKey,
                child: SizedBox(key: entry.value),
              ),
            ),
        ],
      ),
    ],
  );
  addTearDown(database.close);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        agentStatusPlatformClientProvider.overrideWithValue(
          const _NoopAgentStatusPlatformClient(),
        ),
        agentExecutionStatusNowProvider.overrideWithValue(
          () => DateTime.utc(2026, 7, 3, 12),
        ),
      ],
      child: MaterialApp.router(
        title: 'WideNote',
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: WideNoteAppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _sendChat(WidgetTester tester, String text) async {
  if (find.byKey(const Key('chat-input-field')).evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('chat-new-session-button')));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(const Key('chat-input-field')), text);
  await tester.tap(find.byKey(const Key('chat-send-button')));
  await tester.pumpAndSettle();
}

void _seedChatSession(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 7, 2, 10);
  database.chatSessions.save(
    ChatSessionRecord(
      id: 'nav-session',
      title: 'Navigation chat',
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.chatMessages.save(
    ChatMessageRecord(
      id: 'nav-message',
      sessionId: 'nav-session',
      role: 'user',
      body: 'Check chat detail navigation.',
      createdAt: now,
    ),
  );
}

Future<void> _ensureChatVisible(WidgetTester tester, Finder finder) async {
  final scrollable = find.descendant(
    of: find.byKey(const Key('chat-message-scroll')),
    matching: find.byType(Scrollable),
  );
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 240, scrollable: scrollable);
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

void _seedTodo(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 7, 2, 10);
  database.todos.insert(
    TodoRecord(
      id: 'todo-nav-1',
      sourceCaptureId: 'capture-todo-nav',
      payload: const <String, Object?>{
        'title': 'Review navigation source link',
        'source_label': 'source: capture-todo-nav',
        'status_label': 'suggested by agent',
        'suggestion_kind': 'action',
        'suggestion_confidence': 'high',
        'suggestion_reason': 'navigation_fixture',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _seedHomeShortcutTargets(WideNoteLocalDatabase database) {
  final now = DateTime.utc(2026, 7, 2, 10);
  database.captures.insert(
    CaptureRecord(
      id: 'capture-nav-shortcut',
      sourceType: 'manual',
      status: 'processed',
      payload: const <String, Object?>{
        'text': 'Home shortcut should keep the timeline parent stack.',
      },
      createdAt: now,
      updatedAt: now,
    ),
  );
  database.insights.insert(
    InsightRecord(
      id: 'insight-nav-shortcut',
      insightKind: 'behavior_loop',
      title: 'Shortcut navigation',
      summary: 'Home shortcut should keep the insights parent stack.',
      sourceRefs: const <Object?>[
        <String, Object?>{'kind': 'capture', 'id': 'capture-nav-shortcut'},
      ],
      status: 'active',
      payload: const <String, Object?>{},
      createdAt: now.add(const Duration(minutes: 1)),
      updatedAt: now.add(const Duration(minutes: 1)),
    ),
  );
}

void _seedAgentRuntimeTask(WideNoteLocalDatabase database, DateTime now) {
  database.eventLog.append(
    EventLogEntry(
      id: 'event-agent-nav',
      type: 'wn.capture.created',
      actor: 'user',
      createdAt: now.subtract(const Duration(minutes: 1)),
    ),
  );
  database.runtimeTasks.insert(
    RuntimeTaskRecord(
      id: 'task-agent-nav',
      packId: 'pack.default',
      packVersion: '1.0.0',
      agentId: 'agent.capture_loop',
      handlerId: 'handler.capture',
      subscriptionId: 'subscription.capture',
      triggerEventId: 'event-agent-nav',
      status: 'running',
      attempts: 0,
      maxAttempts: 2,
      leasedUntil: now.add(const Duration(minutes: 5)),
      createdAt: now.subtract(const Duration(minutes: 1)),
      updatedAt: now,
    ),
  );
}

final class _NoopAgentStatusPlatformClient
    implements AgentStatusPlatformClient {
  const _NoopAgentStatusPlatformClient();

  @override
  Future<AgentStatusPlatformResult> sync(
    AgentStatusPlatformPayload payload,
  ) async {
    return const AgentStatusPlatformResult(
      notificationStatus: 'test',
      liveActivityStatus: 'test',
    );
  }
}
