import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/capture/application/capture_controller.dart';
import 'package:widenote_mobile/features/plugins/application/official_pack_manifests.dart';
import 'package:widenote_mobile/features/plugins/application/pack_catalog.dart';
import 'package:widenote_mobile/features/plugins/presentation/pack_library_page.dart';
import 'package:widenote_mobile/features/plugins/presentation/permission_gate_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

void main() {
  test('mobile embedded official manifests match repo official JSON', () {
    final bridge = runtime.AgentPackManifestBridge();

    for (final packId in officialPackManifestIds) {
      final mobileJson = jsonDecode(officialPackManifestSource(packId));
      final officialSource = File(
        _officialManifestPath(packId),
      ).readAsStringSync();
      final officialJson = jsonDecode(officialSource);

      expect(mobileJson, officialJson, reason: '$packId manifest drift');

      final mobile = officialPackManifestSnapshot(packId);
      final official = bridge.parseJsonString(
        officialSource,
        sourceName: _officialManifestPath(packId),
      );
      _expectManifestSnapshot(mobile, official);
    }
  });

  test('catalog entries and available permissions are manifest-derived', () {
    expect(
      builtInPacks.map((pack) => pack.id).toList(growable: false),
      <String>[
        'pack.default',
        'pack.todo',
        'pack.pkm_library',
        'pack.transcript_correction',
      ],
    );

    final defaultPack = builtInPacks.singleWhere(
      (pack) => pack.id == 'pack.default',
    );
    expect(defaultPack.name, 'Default Capture Loop');
    expect(defaultPack.version, '0.1.0');
    expect(defaultPack.permissions, <String>[
      'model.complete',
      'card.write',
      'memory.propose',
      'insight.write',
      'context_packet.build',
      'memory.read',
      'timeline.read',
      'knowledge.read',
      'semantic_search.query',
    ]);
    expect(defaultPack.outputEvents, <String>[
      'wn.card.created',
      'wn.memory.proposed',
      'wn.insight.created',
    ]);

    final todoPack = builtInPacks.singleWhere((pack) => pack.id == 'pack.todo');
    expect(todoPack.permissions, <String>['todo.suggest']);
    expect(todoPack.outputEvents, <String>['wn.todo.suggested']);

    final pkmPack = builtInPacks.singleWhere(
      (pack) => pack.id == 'pack.pkm_library',
    );
    expect(pkmPack.permissions, <String>['model.complete', 'artifact.write']);
    expect(pkmPack.outputEvents, <String>['wn.artifact.created']);

    final transcriptPack = builtInPacks.singleWhere(
      (pack) => pack.id == 'pack.transcript_correction',
    );
    expect(transcriptPack.permissions, <String>[
      'model.complete',
      'source.read.transcript',
      'memory.read',
      'source.write.transcript_correction',
    ]);
    expect(transcriptPack.outputEvents, <String>['wn.transcript.corrected']);

    expect(
      builtInPermissions
          .map((permission) => '${permission.packId}:${permission.permission}')
          .toList(growable: false),
      <String>[
        'pack.default:model.complete',
        'pack.default:card.write',
        'pack.default:memory.propose',
        'pack.default:insight.write',
        'pack.default:context_packet.build',
        'pack.default:memory.read',
        'pack.default:timeline.read',
        'pack.default:knowledge.read',
        'pack.default:semantic_search.query',
        'pack.todo:todo.suggest',
        'pack.pkm_library:model.complete',
        'pack.pkm_library:artifact.write',
        'pack.transcript_correction:model.complete',
        'pack.transcript_correction:source.read.transcript',
        'pack.transcript_correction:memory.read',
        'pack.transcript_correction:source.write.transcript_correction',
      ],
    );
    expect(
      builtInPermissions
          .singleWhere(
            (permission) =>
                permission.packId == 'pack.default' &&
                permission.permission == 'model.complete',
          )
          .risk,
      'medium',
    );
    expect(
      builtInPermissions
          .singleWhere(
            (permission) =>
                permission.packId == 'pack.pkm_library' &&
                permission.permission == 'artifact.write',
          )
          .risk,
      'low',
    );
    expect(
      builtInPermissions.map((permission) => permission.status).toSet(),
      <String>{'built-in / available'},
    );
    expect(
      deferredHighRiskPermissions
          .map((permission) => permission.permission)
          .toList(growable: false),
      containsAll(<String>[
        'file.read.broad',
        'network.call.arbitrary_host',
        'script.execute',
      ]),
    );
    expect(
      builtInPermissions
          .map((permission) => permission.permission)
          .toList(growable: false),
      isNot(contains('script.execute')),
    );
  });

  test('official manifest helper fails closed for source drift', () {
    expect(
      () => parseOfficialPackManifestSources(<String, String>{
        'pack.default': officialPackManifestSource('pack.default'),
      }),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => parseOfficialPackManifestSources(<String, String>{
        'pack.default': officialPackManifestSource('pack.default'),
        'pack.todo': '[]',
        'pack.pkm_library': officialPackManifestSource('pack.pkm_library'),
        'pack.transcript_correction': officialPackManifestSource(
          'pack.transcript_correction',
        ),
      }),
      throwsA(isA<FormatException>()),
    );

    final unsupportedSchema = _mutableManifest('pack.todo')
      ..['schema_version'] = 2;
    expect(
      () => parseOfficialPackManifestSources(<String, String>{
        'pack.default': officialPackManifestSource('pack.default'),
        'pack.todo': jsonEncode(unsupportedSchema),
        'pack.pkm_library': officialPackManifestSource('pack.pkm_library'),
        'pack.transcript_correction': officialPackManifestSource(
          'pack.transcript_correction',
        ),
      }),
      throwsA(isA<FormatException>()),
    );

    expect(
      () => parseOfficialPackManifestSources(<String, String>{
        'pack.default': officialPackManifestSource('pack.default'),
        'pack.todo': officialPackManifestSource('pack.default'),
        'pack.pkm_library': officialPackManifestSource('pack.pkm_library'),
        'pack.transcript_correction': officialPackManifestSource(
          'pack.transcript_correction',
        ),
      }),
      throwsA(
        isA<ArgumentError>().having(
          (error) => '$error',
          'message',
          contains('Duplicate official pack manifest id: pack.default'),
        ),
      ),
    );

    final duplicateAgent = _mutableManifest('pack.todo');
    final duplicateAgentList = duplicateAgent['agents']! as List<Object?>;
    duplicateAgentList.add(
      Map<String, Object?>.from(duplicateAgentList.first! as Map),
    );
    expect(
      () => officialPackManifestBridge.parseJsonString(
        jsonEncode(duplicateAgent),
      ),
      throwsA(isA<FormatException>()),
    );

    final duplicateSubscription = _mutableManifest('pack.todo');
    final duplicateSubscriptionList =
        duplicateSubscription['subscriptions']! as List<Object?>;
    duplicateSubscriptionList.add(
      Map<String, Object?>.from(duplicateSubscriptionList.first! as Map),
    );
    expect(
      () => officialPackManifestBridge.parseJsonString(
        jsonEncode(duplicateSubscription),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('official native pack builder rejects unsafe wrapper inputs', () {
    final defaultHandlers = <String, Map<String, runtime.AgentHandler>>{
      'pack.default': <String, runtime.AgentHandler>{
        'agent.capture_loop': const _NoopAgent(),
      },
    };

    expect(
      () => buildOfficialNativePacks(
        manifests: <runtime.AgentPackManifestSnapshot>[
          officialPackManifestSnapshot('pack.default'),
        ],
        nativeHandlersByPackId:
            const <String, Map<String, runtime.AgentHandler>>{},
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(
      () => buildOfficialNativePacks(
        manifests: <runtime.AgentPackManifestSnapshot>[
          officialPackManifestSnapshot('pack.default'),
        ],
        nativeHandlersByPackId: <String, Map<String, runtime.AgentHandler>>{
          'pack.default': <String, runtime.AgentHandler>{
            'agent.extra': const _NoopAgent(),
          },
        },
      ),
      throwsA(isA<ArgumentError>()),
    );

    final nonOfficial = _parseManifest(
      _mutableManifest('pack.default')..['edition'] = 'community',
    );
    expect(
      () => buildOfficialNativePacks(
        manifests: <runtime.AgentPackManifestSnapshot>[nonOfficial],
        nativeHandlersByPackId: defaultHandlers,
      ),
      throwsA(isA<ArgumentError>()),
    );

    final nonNativeManifest = _mutableManifest('pack.default');
    final agents = nonNativeManifest['agents']! as List<Object?>;
    (agents.first! as Map<String, Object?>)['runtime'] = 'remote';
    final nonNative = _parseManifest(nonNativeManifest);
    expect(
      () => buildOfficialNativePacks(
        manifests: <runtime.AgentPackManifestSnapshot>[nonNative],
        nativeHandlersByPackId: defaultHandlers,
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => '$error',
          'message',
          contains('agents.agent.capture_loop.runtime: remote'),
        ),
      ),
    );

    expect(
      () => buildOfficialNativePacks(
        manifests: <runtime.AgentPackManifestSnapshot>[
          officialPackManifestSnapshot('pack.default'),
        ],
        nativeHandlersByPackId: <String, Map<String, runtime.AgentHandler>>{
          ...defaultHandlers,
          'pack.unknown': <String, runtime.AgentHandler>{
            'agent.unknown': const _NoopAgent(),
          },
        },
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('official pack guardrails and drift paths stay visible', () {
    final defaultManifest = officialPackManifestSnapshot('pack.default');
    expect(
      defaultManifest.requiredPermissions,
      isNot(contains('todo.suggest')),
    );
    expect(
      defaultManifest.agentDefinitions.values
          .expand((definition) => definition.outputEvents)
          .toSet(),
      isNot(contains(runtime.WnEventTypes.todoSuggested)),
    );

    final todoManifest = officialPackManifestSnapshot('pack.todo');
    expect(todoManifest.requiredPermissions, <String>{'todo.suggest'});
    expect(
      todoManifest.agentDefinitions.values
          .expand((definition) => definition.outputEvents)
          .toSet(),
      <String>{runtime.WnEventTypes.todoSuggested},
    );

    final packs = buildOfficialNativePacks(
      manifests: <runtime.AgentPackManifestSnapshot>[defaultManifest],
      nativeHandlersByPackId: <String, Map<String, runtime.AgentHandler>>{
        'pack.default': <String, runtime.AgentHandler>{
          'agent.capture_loop': const _NoopAgent(),
        },
      },
    );
    final drifted = _parseManifest(
      _mutableManifest('pack.default')..['name'] = 'Drifted Capture Loop',
    );
    expect(
      () => assertOfficialNativePackAlignment(packs.single, drifted),
      throwsA(
        isA<ArgumentError>().having(
          (error) => '$error',
          'message',
          contains('name'),
        ),
      ),
    );
  });

  testWidgets('pack library and permission gate render manifest data', (
    tester,
  ) async {
    await _pumpLocalizedPage(tester, const PackLibraryPage());
    expect(find.byKey(const Key('pack-library-page')), findsOneWidget);
    expect(find.byKey(const Key('pack-row-pack.default')), findsOneWidget);
    expect(find.byKey(const Key('pack-row-pack.todo')), findsOneWidget);
    expect(find.byKey(const Key('pack-row-pack.pkm_library')), findsOneWidget);
    expect(
      find.byKey(const Key('pack-row-pack.transcript_correction')),
      findsOneWidget,
    );
    expect(find.text('Default Capture Loop'), findsOneWidget);
    expect(find.text('Todo Extraction Loop'), findsOneWidget);
    expect(find.text('PKM Personal Library'), findsOneWidget);
    expect(find.text('Transcript Correction'), findsOneWidget);
    expect(find.text('v0.1.0'), findsNWidgets(4));
    expect(find.text('9 permissions'), findsOneWidget);
    expect(find.text('4 permissions'), findsOneWidget);
    expect(find.text('3 outputs'), findsOneWidget);
    expect(find.text('1 permission'), findsOneWidget);
    expect(find.text('2 permissions'), findsOneWidget);
    expect(find.text('1 output'), findsNWidgets(3));
    expect(
      find.byKey(const Key('pack-marketplace-source-pack.pkm_library')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pack-trust-pack.pkm_library')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pack-categories-pack.pkm_library')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pack-capabilities-pack.pkm_library')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('pack-additive-slots-pack.pkm_library')),
      findsOneWidget,
    );

    await _pumpLocalizedPage(tester, const PermissionGatePage());
    expect(find.byKey(const Key('permission-gate-page')), findsOneWidget);
    expect(
      find.byKey(const Key('permission-row-pack.default-model.complete')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('permission-row-pack.pkm_library-model.complete')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('permission-row-pack.transcript_correction-model.complete'),
      ),
      findsOneWidget,
    );
    expect(find.text('pack.default'), findsWidgets);
    expect(find.text('pack.pkm_library'), findsWidgets);
    expect(find.text('pack.transcript_correction'), findsWidgets);
    expect(find.text('medium risk'), findsNWidgets(3));
    expect(find.text('low risk'), findsWidgets);
    expect(find.text('Built-in / available'), findsWidgets);
    expect(
      find.text('Grant or deny changes future local runs only.'),
      findsWidgets,
    );
    expect(find.text('Built-in and available permissions'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('permission-row-community packs-script.execute')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('permission-row-community packs-script.execute')),
      findsOneWidget,
    );
    expect(find.text('Deferred high-risk permissions'), findsOneWidget);
    expect(find.text('Deferred'), findsWidgets);
    expect(
      find.byKey(
        const Key('permission-action-deferred-community packs-script.execute'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('permission-action-grant-community packs-script.execute'),
      ),
      findsNothing,
    );
    expect(
      find.text(
        'This high-risk or external capability is disabled in the local L3 slice.',
      ),
      findsWidgets,
    );
  });

  testWidgets('pack library persists enable and disable state', (tester) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpLocalizedPage(
      tester,
      const PackLibraryPage(),
      database: database,
    );

    expect(
      database.packInstallations.readById('pack.default')!.status,
      'enabled',
    );
    expect(find.text('1 enabled'), findsNothing);
    expect(find.text('4 enabled'), findsOneWidget);
    expect(
      find.textContaining('Disabling affects future local tasks only'),
      findsOneWidget,
    );

    await _tapPermissionAction(tester, const Key('pack-toggle-pack.default'));

    expect(
      database.packInstallations.readById('pack.default')!.status,
      'disabled',
    );
    expect(find.text('1 disabled'), findsOneWidget);
    expect(find.text('3 enabled'), findsOneWidget);
    expect(find.byKey(const Key('pack-status-pack.default')), findsOneWidget);
    expect(find.text('disabled'), findsOneWidget);

    await _tapPermissionAction(tester, const Key('pack-toggle-pack.default'));

    expect(
      database.packInstallations.readById('pack.default')!.status,
      'enabled',
    );
    expect(find.text('4 enabled'), findsOneWidget);
  });

  test('pack disable rebuilds capture runtime without disabled pack', () async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: <Override>[localDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(captureOrchestratorProvider)
          .debugRegisteredPacks()
          .map((pack) => pack.id),
      contains('pack.pkm_library'),
    );

    await container
        .read(packLibraryControllerProvider.notifier)
        .setEnabled('pack.pkm_library', false);

    expect(
      database.packInstallations.readById('pack.pkm_library')!.status,
      'disabled',
    );
    expect(
      container
          .read(captureOrchestratorProvider)
          .debugRegisteredPacks()
          .map((pack) => pack.id),
      isNot(contains('pack.pkm_library')),
    );
  });

  testWidgets('permission gate persists grant deny and revoke decisions', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);
    await _pumpLocalizedPage(
      tester,
      const PermissionGatePage(),
      database: database,
    );

    expect(
      database.permissionGrants.readByPackAndPermission(
        'pack.default',
        'model.complete',
      ),
      isNull,
    );
    expect(find.text('Built-in / available'), findsWidgets);

    await _tapPermissionAction(
      tester,
      const Key('permission-action-grant-pack.default-model.complete'),
    );
    var record = database.permissionGrants.readByPackAndPermission(
      'pack.default',
      'model.complete',
    );
    expect(record, isNotNull);
    expect(record!.status, 'granted');
    expect(record.grantKind, 'user');
    expect(find.text('Granted locally'), findsOneWidget);
    expect(
      find.text(
        'Future local runs may use this permission until you revoke it.',
      ),
      findsOneWidget,
    );

    var broker = runtime.InMemoryPermissionBroker(
      store: LocalDbPermissionStore(database),
    );
    expect(await broker.isGranted('pack.default', 'model.complete'), isTrue);

    await _tapPermissionAction(
      tester,
      const Key('permission-action-revoke-pack.default-model.complete'),
    );
    record = database.permissionGrants.readByPackAndPermission(
      'pack.default',
      'model.complete',
    );
    expect(record!.status, 'revoked');
    expect(record.revokedAt, isNotNull);
    expect(find.text('Revoked locally'), findsOneWidget);
    expect(
      find.text(
        'Revocation blocks future use; existing records, traces, and derived outputs remain for review.',
      ),
      findsOneWidget,
    );

    broker = runtime.InMemoryPermissionBroker(
      store: LocalDbPermissionStore(database),
    );
    expect(await broker.isGranted('pack.default', 'model.complete'), isFalse);
    expect(
      (await broker.decisionsForPack('pack.default'))
          .singleWhere((decision) => decision.permission == 'model.complete')
          .state,
      runtime.PermissionDecisionState.revoked,
    );

    await _tapPermissionAction(
      tester,
      const Key('permission-action-deny-pack.default-card.write'),
    );
    final denied = database.permissionGrants.readByPackAndPermission(
      'pack.default',
      'card.write',
    );
    expect(denied, isNotNull);
    expect(denied!.status, 'denied');
    expect(denied.reason, 'user_denied_from_permission_gate');
    expect(find.text('Denied locally'), findsOneWidget);
    expect(
      find.text(
        'Future local runs needing this permission are blocked; existing records and traces remain.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'system back from plugin child routes returns to control entries',
    (tester) async {
      await _pumpApp(tester);

      await _openPluginsTab(tester);
      expect(find.byKey(const Key('plugins-page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('backup-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup-page')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plugins-page')), findsOneWidget);
      expect(find.byKey(const Key('backup-page')), findsNothing);

      await tester.tap(find.byKey(const Key('trace-console-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trace-console-page')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plugins-page')), findsOneWidget);
      expect(find.byKey(const Key('trace-console-page')), findsNothing);
    },
  );

  testWidgets('plugin control entries expose tappable semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpApp(tester);
      await _openPluginsTab(tester);

      _expectButtonSemantics(
        tester,
        const Key('pack-library-entry'),
        'Pack Library',
      );
      _expectButtonSemantics(
        tester,
        const Key('model-provider-entry'),
        'Model Provider',
      );
      _expectButtonSemantics(
        tester,
        const Key('trace-console-entry'),
        'Agent Console',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('system back on plugins root is delegated to the platform', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _openPluginsTab(tester);
    expect(find.byKey(const Key('plugins-page')), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isFalse);
    expect(find.byKey(const Key('plugins-page')), findsOneWidget);
  });
}

Future<void> _pumpLocalizedPage(
  WidgetTester tester,
  Widget child, {
  WideNoteLocalDatabase? database,
}) async {
  final localDatabase = database ?? WideNoteLocalDatabase.inMemory();
  if (database == null) {
    addTearDown(localDatabase.close);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(localDatabase)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPermissionAction(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
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

Future<void> _openPluginsTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab-plugins')));
  await tester.pumpAndSettle();
}

String _officialManifestPath(String packId) {
  return switch (packId) {
    'pack.default' => '../../packs/official/default/manifest.json',
    'pack.todo' => '../../packs/official/todo/manifest.json',
    'pack.pkm_library' => '../../packs/official/pkm_library/manifest.json',
    'pack.transcript_correction' =>
      '../../packs/official/transcript_correction/manifest.json',
    _ => throw ArgumentError.value(packId, 'packId', 'Unknown official pack'),
  };
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

void _expectManifestSnapshot(
  runtime.AgentPackManifestSnapshot mobile,
  runtime.AgentPackManifestSnapshot official,
) {
  expect(mobile.id, official.id);
  expect(mobile.name, official.name);
  expect(mobile.version, official.version);
  expect(mobile.schemaVersion, official.schemaVersion);
  expect(mobile.publisher, official.publisher);
  expect(mobile.edition, official.edition);
  expect(mobile.requiredPermissions, official.requiredPermissions);
  expect(
    mobile.subscriptions.map(_subscriptionShape).toList(growable: false),
    official.subscriptions.map(_subscriptionShape).toList(growable: false),
  );
  expect(
    mobile.agentDefinitions.map(
      (id, definition) =>
          MapEntry<String, Object?>(id, _agentShape(definition)),
    ),
    official.agentDefinitions.map(
      (id, definition) =>
          MapEntry<String, Object?>(id, _agentShape(definition)),
    ),
  );
}

Map<String, Object?> _subscriptionShape(runtime.Subscription subscription) {
  return <String, Object?>{
    'id': subscription.id,
    'agent_id': subscription.agentId,
    'event_types': subscription.eventTypes.toList(growable: false),
    'depends_on': subscription.dependsOn.toList(growable: false),
  };
}

Map<String, Object?> _agentShape(runtime.AgentDefinition definition) {
  return <String, Object?>{
    'id': definition.id,
    'runtime': definition.runtimeKind.name,
    'permissions': definition.requiredPermissions.toList(growable: false),
    'output_events': definition.outputEvents.toList(growable: false),
    'tools': definition.tools.toList(growable: false),
    'retry_policy': definition.retryPolicy.normalizedMaxAttempts,
    'model_profile_ref': definition.modelProfileRef,
  };
}

Map<String, Object?> _mutableManifest(String packId) {
  return (jsonDecode(officialPackManifestSource(packId)) as Map)
      .cast<String, Object?>();
}

runtime.AgentPackManifestSnapshot _parseManifest(
  Map<String, Object?> manifest,
) {
  return officialPackManifestBridge.parseJsonString(jsonEncode(manifest));
}

final class _NoopAgent implements runtime.AgentHandler {
  const _NoopAgent();

  @override
  Future<runtime.AgentHandlerResult> handle(
    runtime.AgentContext context,
    runtime.WnEvent event,
  ) async {
    return const runtime.AgentHandlerResult.empty();
  }
}
