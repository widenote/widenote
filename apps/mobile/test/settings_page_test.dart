import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/plugins/application/pack_catalog.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/features/settings/presentation/settings_page.dart';
import 'package:widenote_mobile/features/system_permissions/application/system_permissions_controller.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

import 'support/fake_system_permission_adapter.dart';

void main() {
  testWidgets('home settings button opens Settings and closes back home', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-page')), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Privacy & Permissions'), findsOneWidget);
    expect(find.text('System Permissions'), findsOneWidget);
    expect(find.text('Location Context'), findsOneWidget);
    expect(find.text('Model Providers'), findsOneWidget);
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Log Center'), findsOneWidget);
    expect(find.text('Debugging'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-page')), findsNothing);
    expect(find.byKey(const Key('open-settings-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('open-settings-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-close-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-page')), findsNothing);
    expect(find.byKey(const Key('open-settings-button')), findsOneWidget);
  });

  testWidgets('settings routes open child controls and system back returns', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    await _openChildAndReturn(
      tester,
      entryKey: const Key('settings-permissions-entry'),
      pageKey: const Key('permission-gate-page'),
    );
    await _openChildAndReturn(
      tester,
      entryKey: const Key('settings-system-permissions-entry'),
      pageKey: const Key('system-permissions-page'),
    );
    await _openChildAndReturn(
      tester,
      entryKey: const Key('settings-location-entry'),
      pageKey: const Key('location-settings-page'),
    );
    await _openChildAndReturn(
      tester,
      entryKey: const Key('settings-model-providers-entry'),
      pageKey: const Key('model-provider-settings-page'),
    );
    await _openChildAndReturn(
      tester,
      entryKey: const Key('settings-transcription-entry'),
      pageKey: const Key('voice-transcription-settings-page'),
    );
    await _openChildAndReturn(
      tester,
      entryKey: const Key('settings-backup-entry'),
      pageKey: const Key('backup-page'),
    );
    await _openChildAndReturn(
      tester,
      entryKey: const Key('settings-trace-console-entry'),
      pageKey: const Key('trace-console-page'),
    );
    await _openChildAndReturn(
      tester,
      entryKey: const Key(
        'settings-ui-contribution-pack.transcript_correction-settings.transcript_correction.glossary',
      ),
      pageKey: const Key('pack-library-page'),
    );
    await _openChildAndReturn(
      tester,
      entryKey: const Key('settings-debugging-entry'),
      pageKey: const Key('debugging-page'),
    );
  });

  testWidgets('settings contribution opens pack library after permission grant', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    ensureBuiltInPackInstallations(database);
    await LocalDbPermissionStore(database).upsert(
      runtime.PermissionDecision(
        packId: 'pack.transcript_correction',
        permission: 'source.write.transcript_correction',
        state: runtime.PermissionDecisionState.granted,
        updatedAt: DateTime.utc(2026, 7, 3, 10),
      ),
    );
    await _pumpApp(tester, database: database);
    await _openSettings(tester);

    await _openChildAndReturn(
      tester,
      entryKey: const Key(
        'settings-ui-contribution-pack.transcript_correction-settings.transcript_correction.glossary',
      ),
      pageKey: const Key('pack-library-page'),
    );
  });

  testWidgets('settings hub reflects local control state', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 6, 26, 12);
    _seedProvider(database, now: now);
    _seedTrace(database, id: 'trace-ok', severity: 'info', status: 'ok');
    _seedTrace(
      database,
      id: 'trace-warning',
      severity: 'warning',
      status: 'needs_review',
    );

    await _pumpSettingsPage(
      tester,
      database: database,
      locale: const Locale('en'),
    );

    expect(
      find.text(
        '${builtInPermissions.length} available / '
        '${deferredHighRiskPermissions.length} deferred',
      ),
      findsOneWidget,
    );
    expect(find.text('1 provider'), findsOneWidget);
    expect(find.text('full local'), findsOneWidget);
    expect(find.text('2 logs / 1 warnings'), findsOneWidget);
    expect(
      find.textContaining('Full .widenote backups include provider and'),
      findsOneWidget,
    );
    expect(find.text('Location Context'), findsOneWidget);
    expect(find.text('off'), findsOneWidget);
  });

  testWidgets('settings control entries expose tappable semantics', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    final semantics = tester.ensureSemantics();
    try {
      await _pumpSettingsPage(
        tester,
        database: database,
        locale: const Locale('en'),
      );

      _expectButtonSemantics(
        tester,
        const Key('settings-system-permissions-entry'),
        'System Permissions',
      );
      _expectButtonSemantics(
        tester,
        const Key('settings-location-entry'),
        'Location Context',
      );
      _expectButtonSemantics(
        tester,
        const Key('settings-model-providers-entry'),
        'Model Providers',
      );
      _expectButtonSemantics(
        tester,
        const Key('settings-backup-entry'),
        'Backup & Restore',
      );
      _expectButtonSemantics(
        tester,
        const Key('settings-trace-console-entry'),
        'Log Center',
      );
      _expectButtonSemantics(
        tester,
        const Key('settings-debugging-entry'),
        'Debugging',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('settings privacy copy is localized in English', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpSettingsPage(
      tester,
      database: database,
      locale: const Locale('en'),
    );

    expect(find.text('Local-first core'), findsOneWidget);
    expect(find.text('Revocable permissions'), findsOneWidget);
    expect(find.text('Backup secrets boundary'), findsOneWidget);
    expect(find.text('no account'), findsOneWidget);
    expect(find.text('full backup'), findsOneWidget);
    expect(find.text('full local'), findsOneWidget);
    expect(find.byKey(const Key('settings-display-entry')), findsNothing);
  });

  testWidgets('settings privacy copy is localized in Chinese', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpSettingsPage(
      tester,
      database: database,
      locale: const Locale('zh'),
    );

    expect(find.text('本地优先核心'), findsOneWidget);
    expect(find.text('权限可撤销'), findsOneWidget);
    expect(find.text('备份密钥边界'), findsOneWidget);
    expect(find.text('无需账号'), findsOneWidget);
    expect(find.text('完整备份'), findsOneWidget);
    expect(find.text('本地完整'), findsOneWidget);
    expect(find.byKey(const Key('settings-display-entry')), findsNothing);
  });
}

void _seedProvider(WideNoteLocalDatabase database, {required DateTime now}) {
  database.modelProviderConfigs.save(
    ModelProviderConfigRecord(
      id: 'local-fake',
      providerKind: 'openAiCompatible',
      displayName: 'Local Fake',
      endpoint: 'https://example.invalid/v1/chat/completions',
      model: 'wide-test',
      isDefault: true,
      hasApiKey: true,
      apiKey: 'test-credential',
      capabilities: const <Object?>['chat'],
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void _seedTrace(
  WideNoteLocalDatabase database, {
  required String id,
  required String severity,
  required String status,
}) {
  database.traceEvents.insert(
    TraceEventRecord(
      id: id,
      name: 'settings.test',
      level: severity,
      severityOverride: severity,
      message: 'Synthetic settings hub trace.',
      status: status,
      createdAt: DateTime.utc(2026, 6, 26, 12),
    ),
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  WideNoteLocalDatabase? database,
}) async {
  final appDatabase = database ?? WideNoteLocalDatabase.inMemory();
  addTearDown(appDatabase.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(appDatabase),
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

Future<void> _pumpSettingsPage(
  WidgetTester tester, {
  required WideNoteLocalDatabase database,
  required Locale locale,
}) async {
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
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SettingsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-settings-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('settings-page')), findsOneWidget);
}

Future<void> _openChildAndReturn(
  WidgetTester tester, {
  required Key entryKey,
  required Key pageKey,
}) async {
  await _ensureVisible(tester, entryKey);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(entryKey).hitTestable());
  await tester.pumpAndSettle();
  expect(find.byKey(pageKey), findsOneWidget);

  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('settings-page')), findsOneWidget);
  expect(find.byKey(pageKey), findsNothing);
}

Future<void> _ensureVisible(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  if (finder.evaluate().isNotEmpty) {
    Scrollable.ensureVisible(
      tester.element(finder),
      alignment: 0.35,
      duration: Duration.zero,
    );
  } else {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    Scrollable.ensureVisible(
      tester.element(finder),
      alignment: 0.35,
      duration: Duration.zero,
    );
  }
  await tester.pumpAndSettle();
}

void _expectButtonSemantics(
  WidgetTester tester,
  Key key,
  String labelFragment,
) {
  final data = tester.getSemantics(_semanticsForKey(key)).getSemanticsData();
  expect(data.flagsCollection.isButton, isTrue);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
  expect(data.label, contains(labelFragment));
}

Finder _semanticsForKey(Key key) {
  final keyed = find.byKey(key);
  final descendant = find.descendant(
    of: keyed,
    matching: find.byType(Semantics),
  );
  if (descendant.evaluate().isNotEmpty) {
    return descendant.first;
  }
  return find.ancestor(of: keyed, matching: find.byType(Semantics)).first;
}
