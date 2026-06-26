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
  testWidgets('record button shows empty and saved feedback', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Add text or an attachment before saving.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'Feedback should confirm this capture.',
    );
    await tester.pumpAndSettle();
    expect(find.text('Add text or an attachment before saving.'), findsNothing);

    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Record saved. Local agents are organizing it now.'),
      findsOneWidget,
    );
  });

  testWidgets('camera attachment can be previewed and removed', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();

    final attachment = _readCaptureInputState(tester).attachments.single;
    expect(attachment.kind, CaptureAssetKind.photo);
    expect(find.text('Camera photo sample.jpg'), findsOneWidget);
    expect(find.textContaining('Camera photo saved locally'), findsOneWidget);
    expect(
      find.text('Photo attached. Review it, then save the record.'),
      findsOneWidget,
    );

    final semantics = tester.ensureSemantics();
    try {
      expect(
        tester
            .getSemantics(find.byKey(Key('attachment-row-${attachment.id}')))
            .label,
        contains('Camera photo sample.jpg'),
      );
    } finally {
      semantics.dispose();
    }

    final removeButton = find.byKey(Key('remove-attachment-${attachment.id}'));
    await _scrollHomeActionIntoView(tester, removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();

    expect(_readCaptureInputState(tester).attachments, isEmpty);
    expect(find.text('Camera photo sample.jpg'), findsNothing);
  });

  testWidgets('voice recording starts, blocks submit, stops, then saves', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('add-voice-recording-button')));
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    expect(inputState.isRecordingVoice, isTrue);
    expect(find.text('Recording'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(WideNoteApp)),
    ).read(captureInputControllerProvider.notifier).markSubmitBlocked();
    await tester.pumpAndSettle();
    expect(
      _readCaptureInputState(tester).errorMessage,
      'Stop or cancel the voice recording before saving.',
    );

    final recordButton = find.byKey(const Key('record-capture-button'));

    final stopButton = find.byKey(const Key('capture-voice-stop-button'));
    await _scrollHomeActionIntoView(tester, stopButton);
    await tester.tap(stopButton);
    await tester.pumpAndSettle();

    inputState = _readCaptureInputState(tester);
    final attachment = inputState.attachments.single;
    expect(inputState.isRecordingVoice, isFalse);
    expect(attachment.kind, CaptureAssetKind.voice);
    expect(find.text('Voice recording sample.m4a'), findsOneWidget);
    expect(find.textContaining('Ready'), findsOneWidget);
    expect(find.textContaining('Transcript needs review'), findsNothing);

    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();

    final state = _readCaptureState(tester);
    expect(state.records.single.body, contains('Voice recording captured'));
    expect(_readCaptureInputState(tester).attachments, isEmpty);
  });

  testWidgets('capture mode switch is UI-only until explicit voice action', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(_readCaptureInputState(tester).mode, CaptureMode.text);

    await tester.tap(find.text('Voice').first);
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    expect(inputState.mode, CaptureMode.voice);
    expect(inputState.attachments, isEmpty);
    expect(inputState.isRecordingVoice, isFalse);
    expect(find.byKey(const Key('capture-mode-voice-panel')), findsOneWidget);
    expect(
      find.textContaining('requests microphone permission'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('capture-voice-start-button')));
    await tester.pumpAndSettle();

    inputState = _readCaptureInputState(tester);
    expect(inputState.isRecordingVoice, isTrue);
    expect(inputState.attachments, isEmpty);
  });

  testWidgets('media mode foregrounds camera and gallery only', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Media').first);
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    expect(inputState.mode, CaptureMode.media);
    expect(inputState.attachments, isEmpty);
    expect(find.byKey(const Key('capture-mode-media-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture-media-gallery-button')));
    await tester.pumpAndSettle();

    inputState = _readCaptureInputState(tester);
    expect(inputState.attachments.single.kind, CaptureAssetKind.photo);
    expect(find.text('Gallery photo sample.jpg'), findsOneWidget);
    expect(find.textContaining('Gallery photo saved locally'), findsOneWidget);
    expect(
      find.text('Photo attached. Review it, then save the record.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('capture-import-share-button')), findsNothing);
    expect(find.byKey(const Key('add-share-import-button')), findsNothing);
  });

  testWidgets('permission denied and cancelled states are visible', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      photoAdapter: const FakePhotoCaptureAdapter(mode: FakePhotoMode.denied),
      voiceAdapter: const FakeVoiceCaptureAdapter(mode: FakeVoiceMode.denied),
    );

    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();
    expect(find.text('Camera permission denied.'), findsOneWidget);
    expect(_readCaptureInputState(tester).attachments, isEmpty);

    await tester.tap(find.byKey(const Key('add-voice-recording-button')));
    await tester.pumpAndSettle();
    expect(find.text('Microphone permission denied.'), findsOneWidget);
    expect(_readCaptureInputState(tester).attachments, isEmpty);

    final state = _readCaptureState(tester);
    expect(state.records, isEmpty);
  });

  testWidgets('gallery cancel is visible without phantom capture', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      photoAdapter: const FakePhotoCaptureAdapter(
        mode: FakePhotoMode.cancelled,
      ),
    );

    await tester.tap(find.byKey(const Key('add-gallery-attachment-button')));
    await tester.pumpAndSettle();

    expect(find.text('Gallery selection cancelled.'), findsOneWidget);
    expect(_readCaptureInputState(tester).attachments, isEmpty);
    expect(_readCaptureState(tester).records, isEmpty);
  });

  testWidgets('review attachment blocks submit until accepted', (tester) async {
    await _pumpApp(tester, voiceAdapter: const _ReviewVoiceAdapter());

    await tester.tap(find.byKey(const Key('add-voice-recording-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture-voice-stop-button')));
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    final attachment = inputState.attachments.single;
    expect(attachment.state, CaptureAttachmentState.needsReview);
    expect(find.textContaining('Transcript needs review'), findsOneWidget);

    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();
    expect(find.text('Review attachments before saving.'), findsOneWidget);
    expect(_readCaptureState(tester).records, isEmpty);

    await tester.tap(find.byKey(Key('review-attachment-${attachment.id}')));
    await tester.pumpAndSettle();
    inputState = _readCaptureInputState(tester);
    expect(inputState.attachments.single.state, CaptureAttachmentState.ready);

    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();

    expect(_readCaptureState(tester).records.single.body, contains('review'));
    expect(_readCaptureInputState(tester).attachments, isEmpty);
  });

  testWidgets('camera attachment persists metadata hash and source', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpApp(tester, database: database);

    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();

    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();

    final attachment = database.attachments.readAll().single;
    final rawMetadata = attachment.payload['raw_metadata']! as Map;
    final adapterMetadata = rawMetadata['adapter_metadata']! as Map;
    expect(attachment.sha256, 'fake-camera-photo-sha256');
    expect(attachment.storagePath, 'fake://camera/photo-sample.jpg');
    expect(adapterMetadata['source'], 'camera');
    expect(adapterMetadata['sha256'], 'fake-camera-photo-sha256');
  });

  testWidgets('voice cancel discards recording without a fake record', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('add-voice-recording-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture-voice-cancel-button')));
    await tester.pumpAndSettle();

    expect(find.text('Voice recording cancelled.'), findsOneWidget);
    expect(_readCaptureInputState(tester).attachments, isEmpty);

    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();
    expect(_readCaptureState(tester).records, isEmpty);
  });

  testWidgets('text capture still handles long and empty input', (
    tester,
  ) async {
    await _pumpApp(tester);

    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();
    expect(_readCaptureState(tester).records, isEmpty);

    final longText = 'Long local-first capture. ${'detail ' * 180}';
    await _scrollHomeActionIntoView(
      tester,
      find.byKey(const Key('quick-capture-field')),
    );
    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      longText,
    );
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();

    final state = _readCaptureState(tester);
    expect(state.records.single.body, longText.trim());
    expect(state.records.single.status, 'Processed locally');
  });

  testWidgets('capture console renders localized Chinese mode labels', (
    tester,
  ) async {
    await _pumpApp(tester, locale: const Locale('zh'));

    expect(find.text('文字'), findsOneWidget);
    expect(find.text('语音'), findsWidgets);
    expect(find.text('媒体'), findsOneWidget);

    await tester.tap(find.text('语音').first);
    await tester.pumpAndSettle();

    expect(find.text('开始录音'), findsOneWidget);
    expect(find.textContaining('请求麦克风权限'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  WideNoteLocalDatabase? database,
  PhotoCaptureAdapter photoAdapter = const FakePhotoCaptureAdapter(),
  VoiceCaptureAdapter voiceAdapter = const FakeVoiceCaptureAdapter(),
}) async {
  final localDatabase = database ?? WideNoteLocalDatabase.inMemory();
  addTearDown(localDatabase.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(localDatabase),
        photoCaptureAdapterProvider.overrideWithValue(photoAdapter),
        voiceCaptureAdapterProvider.overrideWithValue(voiceAdapter),
      ],
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

final class _ReviewVoiceAdapter implements VoiceCaptureAdapter {
  const _ReviewVoiceAdapter();

  @override
  Future<VoiceRecordingSession> startRecording() async {
    return VoiceRecordingSession(
      id: 'voice-review-session',
      path: 'fake://voice/review.m4a',
      startedAt: DateTime.utc(2026, 6, 24, 13),
    );
  }

  @override
  Future<RawCaptureAsset> stopRecording(VoiceRecordingSession session) async {
    return RawCaptureAsset(
      id: 'voice-review-asset',
      kind: CaptureAssetKind.voice,
      displayName: 'Voice review sample.m4a',
      mimeType: 'audio/m4a',
      sourceUri: session.path,
      createdAt: DateTime.utc(2026, 6, 24, 13, 1),
      previewText: 'Voice review transcript.',
      rawMetadata: const <String, Object?>{
        'adapter': 'fake_voice',
        'source': 'microphone',
        'sha256': 'voice-review-sha256',
        'transcript_requires_review': true,
      },
    );
  }

  @override
  Future<void> cancelRecording(VoiceRecordingSession session) async {}
}
