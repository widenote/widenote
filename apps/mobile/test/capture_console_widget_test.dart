import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_mobile/features/capture/application/capture_agent_prompts.dart';
import 'package:widenote_local_db/widenote_local_db.dart';
import 'package:widenote_mobile/app/local_database.dart';
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/app/widenote_app.dart';
import 'package:widenote_mobile/features/capture/application/capture_controller.dart';
import 'package:widenote_mobile/features/capture/application/capture_draft_repository.dart';
import 'package:widenote_mobile/features/capture/application/capture_input_controller.dart';
import 'package:widenote_mobile/features/capture/domain/capture_models.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';

void main() {
  testWidgets('new record sheet shows empty and saved feedback', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byKey(const Key('quick-capture-field')), findsNothing);
    await _openNewRecordSheet(tester);

    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();
    expect(find.text('Add text or an attachment before saving.'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'Feedback should confirm this capture.',
    );
    await tester.pumpAndSettle();
    expect(find.text('Add text or an attachment before saving.'), findsNothing);

    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capture-sheet')), findsNothing);
    expect(
      find.text('Record saved. Local agents are organizing it now.'),
      findsOneWidget,
    );
  });

  testWidgets('new record sheet uses a regular multiline keyboard', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openNewRecordSheet(tester);

    final field = tester.widget<TextField>(
      find.byKey(const Key('quick-capture-field')),
    );

    expect(field.keyboardType, TextInputType.multiline);
    expect(field.textCapitalization, TextCapitalization.sentences);
    expect(field.autocorrect, isTrue);
    expect(field.enableSuggestions, isTrue);
    expect(field.smartDashesType, SmartDashesType.disabled);
    expect(field.smartQuotesType, SmartQuotesType.disabled);
  });

  testWidgets('camera attachment can be previewed and removed', (tester) async {
    await _pumpApp(tester);
    await _openNewRecordSheet(tester);

    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();

    final attachment = _readCaptureInputState(tester).attachments.single;
    expect(attachment.kind, CaptureAssetKind.photo);
    expect(find.text('Camera photo sample.jpg'), findsOneWidget);
    expect(find.textContaining('Camera photo saved locally'), findsOneWidget);

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

  testWidgets('background voice starts, blocks save, stops, then saves', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(
      find.byKey(const Key('start-background-recording-button')),
    );
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    expect(inputState.isRecordingVoice, isTrue);
    expect(find.byKey(const Key('background-voice-card')), findsOneWidget);
    expect(find.text('Recording in background'), findsOneWidget);

    await _openNewRecordSheet(tester);
    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'This should wait for the recording to stop.',
    );
    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pumpAndSettle();
    expect(
      _readCaptureInputState(tester).errorMessage,
      'Stop or cancel the voice recording before saving.',
    );
    await tester.tap(find.byKey(const Key('capture-sheet-close-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('background-voice-stop-button')));
    await tester.pumpAndSettle();

    inputState = _readCaptureInputState(tester);
    final attachment = inputState.attachments.single;
    expect(inputState.isRecordingVoice, isFalse);
    expect(attachment.kind, CaptureAssetKind.voice);
    expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
    expect(find.text('Voice recording sample.m4a'), findsOneWidget);
    expect(find.textContaining('Ready'), findsOneWidget);

    await tester.tap(find.byKey(const Key('record-capture-button')));
    await tester.pumpAndSettle();

    final state = _readCaptureState(tester);
    expect(
      state.records.single.body,
      contains('This should wait for the recording to stop.'),
    );
    expect(_readCaptureInputState(tester).attachments, isEmpty);
  });

  testWidgets('new record sheet foregrounds camera and gallery only', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openNewRecordSheet(tester);

    expect(find.byKey(const Key('capture-mode-selector')), findsNothing);
    expect(find.byKey(const Key('add-voice-recording-button')), findsNothing);
    expect(
      find.byKey(const Key('add-camera-attachment-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('add-gallery-attachment-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('add-gallery-attachment-button')));
    await tester.pumpAndSettle();

    final inputState = _readCaptureInputState(tester);
    expect(inputState.attachments.single.kind, CaptureAssetKind.photo);
    expect(find.text('Gallery photo sample.jpg'), findsOneWidget);
    expect(find.textContaining('Gallery photo saved locally'), findsOneWidget);
  });

  testWidgets('permission denied and cancelled states are visible', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      photoAdapter: const FakePhotoCaptureAdapter(mode: FakePhotoMode.denied),
      voiceAdapter: const FakeVoiceCaptureAdapter(mode: FakeVoiceMode.denied),
    );

    await _openNewRecordSheet(tester);
    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();
    expect(find.text('Camera permission denied.'), findsOneWidget);
    expect(_readCaptureInputState(tester).attachments, isEmpty);
    await tester.tap(find.byKey(const Key('capture-sheet-close-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('start-background-recording-button')),
    );
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

    await _openNewRecordSheet(tester);
    await tester.tap(find.byKey(const Key('add-gallery-attachment-button')));
    await tester.pumpAndSettle();

    expect(find.text('Gallery selection cancelled.'), findsOneWidget);
    expect(_readCaptureInputState(tester).attachments, isEmpty);
    expect(_readCaptureState(tester).records, isEmpty);
  });

  testWidgets('review attachment blocks submit until accepted', (tester) async {
    await _pumpApp(tester, voiceAdapter: const _ReviewVoiceAdapter());

    await tester.tap(
      find.byKey(const Key('start-background-recording-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('background-voice-stop-button')));
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    final attachment = inputState.attachments.single;
    expect(attachment.state, CaptureAttachmentState.needsReview);
    expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
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

    await _openNewRecordSheet(tester);
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

    await tester.tap(
      find.byKey(const Key('start-background-recording-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('background-voice-cancel-button')));
    await tester.pumpAndSettle();

    expect(find.text('Voice recording cancelled.'), findsOneWidget);
    expect(_readCaptureInputState(tester).attachments, isEmpty);

    await _openNewRecordSheet(tester);
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

    await _openNewRecordSheet(tester);
    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();
    expect(_readCaptureState(tester).records, isEmpty);

    final longText = 'Long local-first capture. ${'detail ' * 180}';
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

  testWidgets('text draft restores across rebuild and clears after submit', (
    tester,
  ) async {
    final draftRepository = InMemoryCaptureDraftRepository(
      clock: () => DateTime.utc(2026, 6, 27, 8),
    );
    await _pumpApp(tester, draftRepository: draftRepository);

    await _openNewRecordSheet(tester);
    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'Draft survives a rebuild.',
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      (await draftRepository.loadActiveDraft())?.text,
      'Draft survives a rebuild.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpApp(tester, draftRepository: draftRepository);
    await _openNewRecordSheet(tester);

    expect(_captureFieldText(tester), 'Draft survives a rebuild.');

    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();

    expect(await draftRepository.loadActiveDraft(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpApp(tester, draftRepository: draftRepository);
    await _openNewRecordSheet(tester);

    expect(_captureFieldText(tester), isEmpty);
  });

  testWidgets('home and new record sheet render localized Chinese labels', (
    tester,
  ) async {
    await _pumpApp(tester, locale: const Locale('zh'));

    expect(find.text('新记录'), findsOneWidget);
    expect(find.text('后台录音'), findsOneWidget);

    await _openNewRecordSheet(tester);

    expect(find.text('保存记录'), findsOneWidget);
    expect(find.textContaining('原始输入留在本地'), findsOneWidget);
  });

  testWidgets('new record sheet localizes dynamic guard messages in Chinese', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      locale: const Locale('zh'),
      voiceAdapter: const _ReviewVoiceAdapter(),
    );

    await tester.tap(
      find.byKey(const Key('start-background-recording-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('background-voice-stop-button')));
    await tester.pumpAndSettle();

    final recordButton = find.byKey(const Key('record-capture-button'));
    await _scrollHomeActionIntoView(tester, recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();

    expect(find.text('请先复核附件再保存。'), findsOneWidget);
    expect(find.text('Review attachments before saving.'), findsNothing);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  WideNoteLocalDatabase? database,
  PhotoCaptureAdapter photoAdapter = const FakePhotoCaptureAdapter(),
  VoiceCaptureAdapter voiceAdapter = const FakeVoiceCaptureAdapter(),
  CaptureDraftRepository? draftRepository,
  runtime.ModelClient? modelClient = const _CaptureTestModel(),
}) async {
  final localDatabase = database ?? WideNoteLocalDatabase.inMemory();
  addTearDown(localDatabase.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(localDatabase),
        photoCaptureAdapterProvider.overrideWithValue(photoAdapter),
        voiceCaptureAdapterProvider.overrideWithValue(voiceAdapter),
        if (modelClient != null)
          modelClientProvider.overrideWithValue(modelClient),
        if (draftRepository != null)
          captureDraftRepositoryProvider.overrideWithValue(draftRepository),
      ],
      child: WideNoteApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openNewRecordSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-new-record-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
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

String _captureFieldText(WidgetTester tester) {
  return tester
      .widget<TextField>(find.byKey(const Key('quick-capture-field')))
      .controller!
      .text;
}

final class _CaptureTestModel implements runtime.ModelClient {
  const _CaptureTestModel();

  @override
  Future<runtime.ModelResponse> complete(runtime.ModelRequest request) async {
    return runtime.ModelResponse(
      text: _captureText(request.prompt),
      raw: const <String, Object?>{
        'memory_type': 'task_context',
        'confidence': 'high',
        'sensitivity': 'low',
      },
    );
  }
}

String _captureText(String prompt) {
  final markerIndex = prompt.indexOf(captureMemoryPromptCaptureTextMarker);
  if (markerIndex == -1) {
    return prompt.replaceFirst('Summarize capture for Memory: ', '').trim();
  }
  return prompt
      .substring(markerIndex + captureMemoryPromptCaptureTextMarker.length)
      .trim();
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
