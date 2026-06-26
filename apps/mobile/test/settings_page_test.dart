import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/features/plugins/application/pack_catalog.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/settings/presentation/settings_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

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
    expect(find.text('Model Providers'), findsOneWidget);
    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Trace Console'), findsOneWidget);

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
      entryKey: const Key('settings-model-providers-entry'),
      pageKey: const Key('model-provider-settings-page'),
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
    expect(find.text('safe only'), findsOneWidget);
    expect(find.text('2 events / 1 warnings'), findsOneWidget);
    expect(
      find.textContaining('future secret-bearing restore path'),
      findsOneWidget,
    );
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
    expect(find.text('safe export'), findsOneWidget);
    expect(find.text('safe only'), findsOneWidget);
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
    expect(find.text('安全导出'), findsOneWidget);
    expect(find.text('仅安全备份'), findsOneWidget);
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

Future<void> _pumpApp(WidgetTester tester) async {
  final database = WideNoteLocalDatabase.inMemory();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
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
      overrides: [localDatabaseProvider.overrideWithValue(database)],
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
  await tester.ensureVisible(find.byKey(entryKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(entryKey));
  await tester.pumpAndSettle();
  expect(find.byKey(pageKey), findsOneWidget);

  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('settings-page')), findsOneWidget);
  expect(find.byKey(pageKey), findsNothing);
}
