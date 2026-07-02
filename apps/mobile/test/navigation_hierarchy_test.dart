import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/app_router.dart';
import 'package:widenote_mobile/app/app_theme.dart';
import 'package:widenote_mobile/app/local_database.dart';
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

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-session-page')), findsOneWidget);

    await _pumpRoute(tester, '/todos', seed: _seedTodo);
    await tester.tap(find.byKey(const Key('todo-source-todo-nav-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todos-page')), findsOneWidget);
  });

  testWidgets('tab switches reset child stacks instead of preserving pages', (
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

    await tester.tap(find.byKey(const Key('tab-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-page')), findsOneWidget);
    expect(find.byKey(const Key('timeline-search-page')), findsNothing);

    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-page')), findsOneWidget);
  });

  testWidgets('record action returns from child page to home capture sheet', (
    tester,
  ) async {
    await _pumpWideNoteApp(tester);

    await tester.ensureVisible(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-timeline-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-record-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
  });

  testWidgets('bottom navigation highlights durable route owners', (
    tester,
  ) async {
    const cases = <_SelectedTabCase>[
      _SelectedTabCase(path: '/', selectedIndex: 0),
      _SelectedTabCase(path: '/timeline/search', selectedIndex: 0),
      _SelectedTabCase(path: '/settings/model-providers', selectedIndex: 0),
      _SelectedTabCase(path: '/settings/system-permissions', selectedIndex: 0),
      _SelectedTabCase(path: '/chat', selectedIndex: 1),
      _SelectedTabCase(path: '/todos', selectedIndex: 3),
      _SelectedTabCase(path: '/plugins/packs', selectedIndex: 4),
    ];

    for (final routeCase in cases) {
      await _pumpRoute(tester, routeCase.path);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        routeCase.selectedIndex,
        reason: routeCase.path,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
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
        path: '/settings/traces/raw/missing-trace',
        pageKey: Key('trace-raw-page'),
        firstParentKey: Key('trace-console-page'),
        secondParentKey: Key('settings-page'),
        thirdParentKey: Key('home-page'),
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

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('deep linked plugin child pages return to plugins tab root', (
    tester,
  ) async {
    const cases = <_DeepLinkCase>[
      _DeepLinkCase(
        path: '/plugins/packs',
        pageKey: Key('pack-library-page'),
        firstParentKey: Key('plugins-page'),
      ),
      _DeepLinkCase(
        path: '/plugins/permissions',
        pageKey: Key('permission-gate-page'),
        firstParentKey: Key('plugins-page'),
      ),
      _DeepLinkCase(
        path: '/plugins/model-providers',
        pageKey: Key('model-provider-settings-page'),
        firstParentKey: Key('plugins-page'),
      ),
      _DeepLinkCase(
        path: '/plugins/backup',
        pageKey: Key('backup-page'),
        firstParentKey: Key('plugins-page'),
      ),
      _DeepLinkCase(
        path: '/plugins/traces',
        pageKey: Key('trace-console-page'),
        firstParentKey: Key('plugins-page'),
      ),
      _DeepLinkCase(
        path: '/plugins/traces/agents',
        pageKey: Key('trace-agents-page'),
        firstParentKey: Key('trace-console-page'),
        secondParentKey: Key('plugins-page'),
      ),
      _DeepLinkCase(
        path: '/plugins/traces/raw/missing-trace',
        pageKey: Key('trace-raw-page'),
        firstParentKey: Key('trace-console-page'),
        secondParentKey: Key('plugins-page'),
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

      expect(
        await tester.binding.handlePopRoute(),
        isFalse,
        reason: routeCase.path,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('plugins-page')),
        findsOneWidget,
        reason: routeCase.path,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
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
}

class _DeepLinkCase {
  const _DeepLinkCase({
    required this.path,
    required this.pageKey,
    required this.firstParentKey,
    this.secondParentKey,
    this.thirdParentKey,
  });

  final String path;
  final Key pageKey;
  final Key firstParentKey;
  final Key? secondParentKey;
  final Key? thirdParentKey;
}

class _SelectedTabCase {
  const _SelectedTabCase({required this.path, required this.selectedIndex});

  final String path;
  final int selectedIndex;
}

Future<void> _pumpWideNoteApp(WidgetTester tester) async {
  final database = WideNoteLocalDatabase.inMemory();
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
}) async {
  final database = WideNoteLocalDatabase.inMemory();
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
