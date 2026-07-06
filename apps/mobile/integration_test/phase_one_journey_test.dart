import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/features/backup/application/backup_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_agent_prompts.dart';
import 'package:widenote_mobile/features/capture/application/capture_background_processing.dart';
import 'package:widenote_mobile/app/widenote_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('phase-one local journey works through real app routes', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    addTearDown(database.close);

    await _pumpApp(tester, database);

    const captureText = 'Integration journey captures source-linked todos.';
    await _submitCapture(tester, captureText);
    await _waitFor(
      tester,
      () => database.todos.readAll().isNotEmpty,
      description: 'initial capture todo',
      diagnostics: () => _databaseDiagnostics(database),
    );

    final capture = database.captures.readAll().single;
    final todo = database.todos.readAll().single;
    expect(capture.payload['text'], captureText);
    expect(database.memoryItems.readAll(status: 'active'), hasLength(1));
    expect(database.cards.readAll(status: 'active'), hasLength(2));
    expect(database.insights.readAll(status: 'active'), hasLength(1));
    expect(database.traceEvents.readAll(), isNotEmpty);
    expect(todo.sourceCaptureId, capture.id);
    expect(todo.payload['suggestion_kind'], 'action');
    final firstJourneyEvents = database.eventLog.readAll();
    final todoEvent = firstJourneyEvents.singleWhere(
      (event) => event.type == runtime.WnEventTypes.todoSuggested,
    );
    final insightEvent = firstJourneyEvents.singleWhere(
      (event) => event.type == runtime.WnEventTypes.insightCreated,
    );
    expect(
      _sourceRefKinds(todoEvent.payload['source_refs']),
      containsAll(<String>['capture', 'event']),
    );
    expect(
      _sourceRefKinds(insightEvent.payload['source_refs']),
      containsAll(<String>['capture', 'event']),
    );

    await tester.tap(find.byKey(const Key('tab-todos')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('todo-row-${todo.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('todo-row-${todo.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-detail-page')), findsOneWidget);
    await tester.tap(find.byKey(Key('todo-detail-source-${todo.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-item-detail-page')), findsOneWidget);
    expect(find.text('Capture Detail'), findsOneWidget);
    expect(find.text(captureText), findsWidgets);

    await tester.tap(find.byKey(const Key('timeline-item-detail-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-detail-page')), findsOneWidget);
    await tester.tap(find.byKey(Key('todo-detail-toggle-${todo.id}')));
    await tester.pumpAndSettle();
    expect(database.todos.readById(todo.id)!.status, 'completed');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todos-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('permission-gate-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('permission-gate-page')), findsOneWidget);
    expect(
      database.permissionGrants
          .readByPackAndPermission('pack.default', 'model.complete')!
          .status,
      'granted',
    );
    await tester.tap(
      find.byKey(
        const Key('permission-action-revoke-pack.default-model.complete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      database.permissionGrants
          .readByPackAndPermission('pack.default', 'model.complete')!
          .status,
      'revoked',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plugins-page')), findsOneWidget);
    final memoryCountBeforeBlockedCapture = database.memoryItems
        .readAll(status: 'active')
        .length;
    const blockedCaptureText =
        'Capture after revoking model.complete keeps raw input only.';
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    await _submitCapture(tester, blockedCaptureText);
    await _waitFor(
      tester,
      () =>
          database.captures.readAll().any(
            (record) => record.payload['text'] == blockedCaptureText,
          ) &&
          database.traceEvents.readAll().any(
            (trace) => trace.name == 'runtime.task.blocked',
          ),
      description: 'blocked capture raw record and blocked task trace',
      diagnostics: () => _databaseDiagnostics(database),
    );
    expect(
      database.captures.readAll().map((record) => record.payload['text']),
      contains(blockedCaptureText),
    );
    expect(
      database.memoryItems.readAll(status: 'active'),
      hasLength(memoryCountBeforeBlockedCapture),
    );
    expect(
      database.traceEvents.readAll().map((trace) => trace.name),
      contains('runtime.task.blocked'),
    );

    await tester.tap(find.byKey(const Key('tab-plugins')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('permission-gate-entry')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('script.execute'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('permission-action-deferred-community packs-script.execute'),
      ),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plugins-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-export-button')));
    await tester.pumpAndSettle();
    expect(find.text('captures: 2'), findsOneWidget);
    expect(find.text('todos: 1'), findsOneWidget);
    expect(
      find.byKey(const Key('backup-safe-restore-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('backup-full-secret-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('backup-open-share-file-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('backup-save-files-button')), findsOneWidget);

    final eventTypes = database.eventLog.readAll().map((event) => event.type);
    expect(
      eventTypes,
      containsAll(<String>[
        runtime.WnEventTypes.captureCreated,
        runtime.WnEventTypes.memoryProposed,
        runtime.WnEventTypes.cardCreated,
        runtime.WnEventTypes.insightCreated,
        runtime.WnEventTypes.todoSuggested,
      ]),
    );
  });

  testWidgets(
    'safe backup restores through real app route and remains usable',
    (tester) async {
      final source = WideNoteLocalDatabase.inMemory();
      addTearDown(source.close);
      await _pumpApp(tester, source);

      const restoredCaptureText =
          'Restorable backup journey keeps source-linked local context.';
      await _submitCapture(tester, restoredCaptureText);
      await _waitFor(
        tester,
        () => source.todos.readAll().isNotEmpty,
        description: 'source backup todo',
        diagnostics: () => _databaseDiagnostics(source),
      );
      final backupPayload = BackupImportPayload(
        backup: LocalBackupService(source).exportBackup(),
        sourceLabel: '/tmp/widenote-integration-safe.widenote',
      );
      final backupFileStore = _IntegrationBackupFileStore(backupPayload);

      final target = WideNoteLocalDatabase.inMemory();
      addTearDown(target.close);
      await _pumpApp(tester, target, backupFileStore: backupFileStore);

      await tester.tap(find.byKey(const Key('tab-plugins')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-entry')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('backup-import-file-button')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-import-file-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('backup-import-button')));
      await tester.tap(find.byKey(const Key('backup-import-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('backup-confirm-replace-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('backup-inline-outcome')), findsOneWidget);
      expect(target.captures.readAll(), hasLength(1));
      expect(target.memoryItems.readAll(status: 'active'), hasLength(1));
      expect(target.todos.readAll(), hasLength(1));

      await _openRootTab(
        tester,
        tabKey: const Key('tab-home'),
        pageKey: const Key('home-page'),
      );
      expect(
        target.captures.readAll().single.payload['text'],
        restoredCaptureText,
      );

      await tester.tap(find.byKey(const Key('open-daily-recap-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recap-page')), findsOneWidget);
      expect(
        target.memoryItems.readAll(status: 'active').single.body,
        isNotEmpty,
      );

      await _openRootTab(
        tester,
        tabKey: const Key('tab-todos'),
        pageKey: const Key('todos-page'),
      );
      final restoredTodo = target.todos.readAll().single;
      expect(find.byKey(Key('todo-row-${restoredTodo.id}')), findsOneWidget);

      await tester.tap(find.byKey(const Key('tab-chat')));
      await tester.pumpAndSettle();
      await _sendChat(tester, 'What local context was restored?');
      expect(target.chatMessages.readAll(), hasLength(2));
      expect(find.textContaining(restoredCaptureText), findsWidgets);

      await _openRootTab(
        tester,
        tabKey: const Key('tab-home'),
        pageKey: const Key('home-page'),
      );
      await _submitCapture(
        tester,
        'Fresh capture after safe restore still runs the local pipeline.',
      );
      await _waitFor(
        tester,
        () => target.memoryItems.readAll(status: 'active').length == 2,
        description: 'post-restore capture pipeline',
        diagnostics: () => _databaseDiagnostics(target),
      );
      expect(target.captures.readAll(), hasLength(2));
      expect(target.memoryItems.readAll(status: 'active'), hasLength(2));
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  WideNoteLocalDatabase database, {
  BackupFileStore backupFileStore = const _IntegrationBackupFileStore(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(database),
        modelClientProvider.overrideWithValue(const _IntegrationModel()),
        chatModelClientProvider.overrideWithValue(const _IntegrationModel()),
        backupFileStoreProvider.overrideWithValue(backupFileStore),
        captureBackgroundSchedulerProvider.overrideWithValue(
          const NoopCaptureBackgroundScheduler(),
        ),
      ],
      child: const WideNoteApp(locale: Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

final class _IntegrationBackupFileStore implements BackupFileStore {
  const _IntegrationBackupFileStore([this.payload]);

  final BackupImportPayload? payload;

  @override
  Future<BackupFileResult> shareExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    return const BackupFileResult(
      archivePath: '/tmp/widenote-integration-export.widenote',
      destinationLabel: 'integration test',
    );
  }

  @override
  Future<BackupFileResult> saveExport({
    required LocalDataBackup backup,
    required DateTime createdAt,
  }) async {
    return const BackupFileResult(
      archivePath: '/tmp/widenote-integration-export.widenote',
      destinationLabel: 'integration test',
    );
  }

  @override
  Future<BackupImportPayload> readLatestBackup() async => _payload();

  @override
  Future<BackupImportPayload> readArchive(String archivePath) async =>
      _payload();

  @override
  Future<BackupImportPayload> pickArchive() async => _payload();

  @override
  Future<void> restorePreparedMedia(BackupImportPayload payload) async {}

  @override
  Future<void> discardPreparedImport(BackupImportPayload payload) async {}

  BackupImportPayload _payload() {
    final selected = payload;
    if (selected == null) {
      throw const BackupPickerCanceledException();
    }
    return selected;
  }
}

final class _IntegrationModel implements runtime.ModelClient {
  const _IntegrationModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    return switch (request.context['prompt_ref']) {
      captureMemoryPromptRef => _captureMemoryResponse(request.prompt),
      todoSuggestionPromptRef => _todoSuggestionResponse(request.prompt),
      pkmProfilePromptRef => _pkmProfileResponse(request.prompt),
      insightDepthPromptRef => _insightDepthResponse(request.prompt),
      _ => runtime.ModelResponse(
        text: _captureText(request.prompt) ?? request.prompt.trim(),
      ),
    };
  }
}

runtime.ModelResponse _captureMemoryResponse(String prompt) {
  final text = _captureText(prompt) ?? 'Integration capture';
  return _jsonResponse(<String, Object?>{
    'text': _compactText(text, fallback: 'Integration capture memory'),
    'memory_type': 'task_context',
    'confidence': 'high',
    'sensitivity': 'low',
    'durability': 'durable',
  });
}

runtime.ModelResponse _todoSuggestionResponse(String prompt) {
  final text = _captureText(prompt) ?? 'Review integration capture';
  return _jsonResponse(<String, Object?>{
    'kind': 'action',
    'title': _compactText(text, fallback: 'Review integration capture'),
    'confidence': 'high',
    'reason': 'explicit_action',
    'scheduled_at_label': null,
    'due_label': null,
    'priority': null,
    'subtasks': <Object?>[],
  });
}

runtime.ModelResponse _pkmProfileResponse(String prompt) {
  final text = _captureText(prompt) ?? 'Integration capture';
  final excerpt = _compactText(text, maxLength: 120, fallback: text);
  return _jsonResponse(<String, Object?>{
    'title': 'Integration capture',
    'summary': 'A source-linked integration capture was processed locally.',
    'topics': <Object?>['capture', 'integration'],
    'people': <Object?>[],
    'projects': <Object?>[],
    'source_excerpt': excerpt,
    'confidence': 'high',
    'sensitivity': 'low',
  });
}

runtime.ModelResponse _insightDepthResponse(String prompt) {
  final entries = _insightContextEntries(prompt);
  if (entries.isEmpty) {
    return _jsonResponse(<String, Object?>{
      'kind': 'quiet',
      'title': '',
      'summary': '',
      'confidence': 0,
      'claims': <Object?>[],
      'metrics': <Object?>[],
      'evidence': <Object?>[],
      'counter_evidence': <Object?>[],
      'source_ids': <Object?>[],
      'requires_review': false,
    });
  }

  final sourceIds = entries.map((entry) => entry.sourceId).take(3).toList();
  final primary = entries.first;
  final primarySourceId = primary.sourceId;
  final evidenceText = _compactText(
    primary.text,
    maxLength: 120,
    fallback: 'The local context packet contains source-linked entries.',
  );
  return _jsonResponse(<String, Object?>{
    'kind': 'reflection',
    'title': 'Source-linked local progress',
    'summary':
        'The recent local state keeps the raw capture connected to derived memory, todo, card, or artifact outputs.',
    'confidence': 0.82,
    'sensitivity': 'low',
    'evidence_density': 'medium',
    'requires_review': false,
    'source_ids': sourceIds,
    'claims': <Object?>[
      <String, Object?>{
        'id': 'claim.1',
        'text': 'The local journey produced source-linked derived context.',
        'source_ids': <Object?>[primarySourceId],
      },
    ],
    'metrics': <Object?>[
      <String, Object?>{
        'label': 'source entries',
        'value': entries.length,
        'source_ids': sourceIds,
      },
    ],
    'evidence': <Object?>[
      <String, Object?>{
        'id': 'evidence.1',
        'text': evidenceText,
        'source_ids': <Object?>[primarySourceId],
      },
    ],
    'counter_evidence': <Object?>[],
  });
}

runtime.ModelResponse _jsonResponse(Map<String, Object?> payload) {
  return runtime.ModelResponse(text: jsonEncode(payload), raw: payload);
}

String? _captureText(String prompt) {
  final markerIndex = prompt.indexOf(captureMemoryPromptCaptureTextMarker);
  if (markerIndex == -1) {
    return null;
  }
  return prompt
      .substring(markerIndex + captureMemoryPromptCaptureTextMarker.length)
      .trim();
}

List<_InsightFixtureEntry> _insightContextEntries(String prompt) {
  const marker = 'Context JSON:';
  final markerIndex = prompt.indexOf(marker);
  if (markerIndex == -1) {
    return const <_InsightFixtureEntry>[];
  }

  try {
    final decoded = jsonDecode(
      prompt.substring(markerIndex + marker.length).trim(),
    );
    if (decoded is! Map) {
      return const <_InsightFixtureEntry>[];
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      return const <_InsightFixtureEntry>[];
    }
    return rawEntries
        .whereType<Map>()
        .map((entry) => entry.cast<String, Object?>())
        .map(_InsightFixtureEntry.fromJson)
        .whereType<_InsightFixtureEntry>()
        .toList(growable: false);
  } on FormatException {
    return const <_InsightFixtureEntry>[];
  }
}

final class _InsightFixtureEntry {
  const _InsightFixtureEntry({required this.sourceId, required this.text});

  final String sourceId;
  final String text;

  static _InsightFixtureEntry? fromJson(Map<String, Object?> json) {
    final sourceId = _stringValue(json['source_id']);
    if (sourceId == null) {
      return null;
    }
    final text = _stringValue(json['text'], fallback: sourceId)!;
    return _InsightFixtureEntry(sourceId: sourceId, text: text);
  }
}

String _compactText(String value, {int maxLength = 80, String fallback = ''}) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final effective = text.isEmpty ? fallback : text;
  if (effective.length <= maxLength) {
    return effective;
  }
  return '${effective.substring(0, maxLength - 1)}...';
}

String? _stringValue(Object? value, {String? fallback}) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

Set<String> _sourceRefKinds(Object? value) {
  if (value is! List) {
    return const <String>{};
  }
  return value
      .whereType<Map>()
      .map((ref) => _stringValue(ref['kind']))
      .whereType<String>()
      .toSet();
}

Future<void> _submitCapture(WidgetTester tester, String text) async {
  final field = find.byKey(const Key('quick-capture-field'));
  if (field.evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key('tab-record-action')));
    await tester.pumpAndSettle();
  }
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await _unfocus(tester);
  await tester.ensureVisible(find.byKey(const Key('record-capture-button')));
  await tester.tap(find.byKey(const Key('record-capture-button')));
  await tester.pump();
}

Future<void> _sendChat(WidgetTester tester, String text) async {
  if (find.byKey(const Key('chat-input-field')).evaluate().isEmpty) {
    await tester.ensureVisible(
      find.byKey(const Key('chat-new-session-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-new-session-button')));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(const Key('chat-input-field')), text);
  await _unfocus(tester);
  await tester.ensureVisible(find.byKey(const Key('chat-send-button')));
  await tester.tap(find.byKey(const Key('chat-send-button')));
  await tester.pumpAndSettle();
}

Future<void> _unfocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> _openRootTab(
  WidgetTester tester, {
  required Key tabKey,
  required Key pageKey,
}) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    if (find.byKey(pageKey).evaluate().isNotEmpty) {
      return;
    }
    final tab = find.byKey(tabKey);
    if (tab.evaluate().isNotEmpty) {
      await tester.tap(tab);
      await tester.pumpAndSettle();
      if (find.byKey(pageKey).evaluate().isNotEmpty) {
        return;
      }
    } else if (await _tapVisibleBack(tester)) {
      continue;
    } else {
      break;
    }
  }
  expect(find.byKey(pageKey), findsOneWidget);
}

Future<bool> _tapVisibleBack(WidgetTester tester) async {
  for (final key in const <Key>[
    Key('child-page-back-button'),
    Key('chat-session-back-button'),
    Key('recap-back-button'),
    Key('timeline-item-detail-back'),
  ]) {
    final button = find.byKey(key);
    if (button.evaluate().isEmpty) {
      continue;
    }
    await tester.tap(button);
    await tester.pumpAndSettle();
    return true;
  }
  return false;
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  String Function()? diagnostics,
}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      final suffix = diagnostics == null ? '' : ' ${diagnostics()}';
      throw TestFailure('Timed out waiting for $description.$suffix');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

String _databaseDiagnostics(WideNoteLocalDatabase database) {
  final captureStatuses = database.captures
      .readAll()
      .map((capture) => '${capture.id}:${capture.status}')
      .join(',');
  final eventTypes = database.eventLog
      .readAll()
      .map((event) => event.type)
      .join(',');
  final traceNames = database.traceEvents
      .readAll()
      .map((trace) => trace.name)
      .join(',');
  final permissions = database.permissionGrants
      .readAll()
      .map((grant) => '${grant.packId}:${grant.permissionId}:${grant.status}')
      .join(',');
  return 'captures=${database.captures.readAll().length} '
      'captureStatuses=[$captureStatuses] '
      'todos=${database.todos.readAll().length} '
      'memories=${database.memoryItems.readAll(status: 'active').length} '
      'cards=${database.cards.readAll(status: 'active').length} '
      'insights=${database.insights.readAll(status: 'active').length} '
      'permissions=[$permissions] '
      'events=[$eventTypes] traces=[$traceNames]';
}
