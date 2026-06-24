import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/capture/application/capture_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_input_controller.dart';
import 'package:widenote_mobile/features/capture/domain/capture_models.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';

void main() {
  testWidgets('photo attachment sample can be previewed and removed', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('add-photo-attachment-button')));
    await tester.pumpAndSettle();

    final attachment = _readCaptureInputState(tester).attachments.single;
    expect(attachment.kind, CaptureAssetKind.photo);
    expect(find.text('Field photo sample.jpg'), findsOneWidget);
    expect(find.textContaining('Photo sample'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester
            .getSemantics(find.byKey(Key('attachment-row-${attachment.id}')))
            .label,
        contains('Field photo sample.jpg'),
      );
    } finally {
      semantics.dispose();
    }

    final removeButton = find.byKey(Key('remove-attachment-${attachment.id}'));
    await _scrollHomeActionIntoView(tester, removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(_readCaptureInputState(tester).attachments, isEmpty);
    expect(find.text('Field photo sample.jpg'), findsNothing);
  });

  testWidgets('voice transcript sample requires review before capture', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('add-voice-attachment-button')));
    await tester.pumpAndSettle();

    final attachment = _readCaptureInputState(tester).attachments.single;
    expect(attachment.kind, CaptureAssetKind.voice);
    expect(find.text('Voice transcript sample.m4a'), findsOneWidget);
    expect(find.textContaining('Transcript needs review'), findsOneWidget);

    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pumpAndSettle();
    expect(find.text('Review attachments before saving.'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester.getSemantics(find.byKey(const Key('capture-error-line'))).label,
        contains('Review attachments before saving.'),
      );
    } finally {
      semantics.dispose();
    }

    final reviewButton = find.byKey(Key('review-attachment-${attachment.id}'));
    await _scrollHomeActionIntoView(tester, reviewButton);
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ready'), findsOneWidget);

    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();

    final state = _readCaptureState(tester);
    expect(state.records.single.body, contains('Transcript draft'));
    expect(_readCaptureInputState(tester).attachments, isEmpty);
  });

  testWidgets('capture mode switch is UI-only until explicit voice action', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(_readCaptureInputState(tester).mode, CaptureMode.text);

    await tester.tap(find.text('Voice draft').first);
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    expect(inputState.mode, CaptureMode.voice);
    expect(inputState.attachments, isEmpty);
    expect(find.byKey(const Key('capture-mode-voice-panel')), findsOneWidget);
    expect(find.textContaining('No microphone permission'), findsOneWidget);
    expect(find.textContaining('streaming'), findsNothing);

    await tester.tap(find.byKey(const Key('capture-voice-draft-button')));
    await tester.pumpAndSettle();

    inputState = _readCaptureInputState(tester);
    expect(inputState.attachments.single.kind, CaptureAssetKind.voice);
    expect(inputState.canSubmit, isFalse);
    expect(find.textContaining('Transcript needs review'), findsOneWidget);
  });

  testWidgets('import mode foregrounds share and photo actions', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Import').first);
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    expect(inputState.mode, CaptureMode.import);
    expect(inputState.attachments, isEmpty);
    expect(find.byKey(const Key('capture-mode-import-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture-import-share-button')));
    await tester.pumpAndSettle();

    inputState = _readCaptureInputState(tester);
    expect(inputState.attachments.single.kind, CaptureAssetKind.share);
    expect(find.text('Shared web note sample'), findsOneWidget);
  });

  testWidgets('capture console renders localized Chinese mode labels', (
    tester,
  ) async {
    await _pumpApp(tester, locale: const Locale('zh'));

    expect(find.text('文字'), findsOneWidget);
    expect(find.text('语音草稿'), findsOneWidget);
    expect(find.text('导入'), findsWidgets);

    await tester.tap(find.text('语音草稿').first);
    await tester.pumpAndSettle();

    expect(find.text('添加语音草稿'), findsOneWidget);
    expect(find.textContaining('不会请求麦克风权限'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  final database = WideNoteLocalDatabase.inMemory();
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDatabaseProvider.overrideWithValue(database)],
      child: WideNoteApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollHomeActionIntoView(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

CaptureState _readCaptureState(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(WideNoteApp)),
  ).read(captureControllerProvider);
}

CaptureInputState _readCaptureInputState(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(WideNoteApp)),
  ).read(captureInputControllerProvider);
}
