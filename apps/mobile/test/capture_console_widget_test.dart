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
import 'package:widenote_mobile/features/location/application/location_settings_controller.dart';
import 'package:widenote_mobile/features/transcription/transcription_service.dart';
import 'package:widenote_mobile/features/transcription/transcription_settings.dart';
import 'package:widenote_mobile/features/transcription/transcription_types.dart';

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
    expect(
      find.text('Camera photo saved locally: whiteboard snapshot'),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('attachment-${attachment.id}-artifact-vision_summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('attachment-${attachment.id}-artifact-ocr_text')),
      findsOneWidget,
    );
    expect(find.text('ready'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
    expect(find.textContaining(attachment.id), findsWidgets);

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

  testWidgets('background voice starts, blocks save, then auto-saves on stop', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpApp(
      tester,
      database: database,
      voiceAdapter: const _NoPreviewVoiceAdapter(),
    );

    await _startBackgroundRecording(tester);

    var inputState = _readCaptureInputState(tester);
    expect(inputState.isRecordingVoice, isTrue);
    await _scrollHomeActionIntoView(
      tester,
      find.byKey(const Key('background-voice-card')),
      scrollAmount: -120,
    );
    expect(find.byKey(const Key('background-voice-card')), findsOneWidget);
    expect(find.text('Recording in background'), findsOneWidget);

    await _openNewRecordSheet(tester);
    expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'This should wait for the recording to stop.',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WideNoteApp)),
    );
    container.read(captureInputControllerProvider.notifier).markSubmitBlocked();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      _readCaptureInputState(tester).errorMessage,
      'Stop or cancel the voice recording before saving.',
    );
    await tester.tap(find.byKey(const Key('capture-sheet-close-button')));
    await tester.pumpAndSettle();

    await _scrollHomeActionIntoView(
      tester,
      find.byKey(const Key('background-voice-stop-button')),
      scrollAmount: -120,
    );
    await tester.tap(find.byKey(const Key('background-voice-stop-button')));
    await tester.pumpAndSettle();

    inputState = _readCaptureInputState(tester);
    expect(inputState.isRecordingVoice, isFalse);
    expect(inputState.errorMessage, isNull);
    expect(inputState.attachments, isEmpty);
    expect(find.byKey(const Key('capture-sheet')), findsNothing);
    final attachment = database.attachments.readAll().single;
    expect(attachment.assetKind, 'voice');
    await tester.pump(const Duration(milliseconds: 500));

    final state = _readCaptureState(tester);
    expect(
      state.records.single.body,
      'This should wait for the recording to stop.',
    );
    expect(state.records.single.body, isNot(contains('Live preview text')));
    final storedCapture = database.captures.readAll().single;
    expect(
      storedCapture.payload['text'],
      'This should wait for the recording to stop.',
    );
    final transcriptArtifact = database.derivedArtifacts
        .readAll(artifactKind: 'audio_transcript')
        .single;
    expect(transcriptArtifact.body, 'Live preview text');
    expect(
      transcriptArtifact.sourceRefs.whereType<Map>().any(
        (ref) => ref['kind'] == 'capture' && ref['id'] == storedCapture.id,
      ),
      isTrue,
    );
    expect(
      transcriptArtifact.sourceRefs.whereType<Map>().any(
        (ref) => ref['kind'] == 'attachment' && ref['id'] == attachment.id,
      ),
      isTrue,
    );
    expect(
      transcriptArtifact.sourceRefs.whereType<Map>().any(
        (ref) => ref['kind'] == 'event',
      ),
      isTrue,
    );
    expect(_readCaptureInputState(tester).attachments, isEmpty);
  });

  testWidgets('voice-only capture uses transcript text as the record summary', (
    tester,
  ) async {
    final database = WideNoteLocalDatabase.inMemory();
    await _pumpApp(
      tester,
      database: database,
      voiceAdapter: const _NoPreviewVoiceAdapter(),
    );

    await _startBackgroundRecording(tester);
    await _scrollHomeActionIntoView(
      tester,
      find.byKey(const Key('background-voice-stop-button')),
      scrollAmount: -120,
    );
    await tester.tap(find.byKey(const Key('background-voice-stop-button')));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 500));

    final state = _readCaptureState(tester);
    expect(_readCaptureInputState(tester).attachments, isEmpty);
    expect(state.records.single.body, 'Live preview text');
    expect(
      database.captures.readAll().single.payload['text'],
      'Live preview text',
    );
  });

  testWidgets('background voice renders live transcript preview', (
    tester,
  ) async {
    await _pumpApp(tester);

    await _startBackgroundRecording(tester);

    await _scrollHomeActionIntoView(
      tester,
      find.byKey(const Key('background-voice-card')),
      scrollAmount: -120,
    );
    expect(find.byKey(const Key('background-voice-card')), findsOneWidget);
    expect(
      find.textContaining('Draft transcript: Live preview text'),
      findsOneWidget,
    );
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
    expect(
      find.text('Gallery photo saved locally: reference image'),
      findsOneWidget,
    );
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

    await _startBackgroundRecording(tester);
    await _scrollHomeActionIntoView(
      tester,
      find.text('Microphone permission denied.'),
      scrollAmount: -120,
    );
    expect(find.text('Microphone permission denied.'), findsOneWidget);
    expect(_readCaptureInputState(tester).attachments, isEmpty);

    final state = _readCaptureState(tester);
    expect(state.records, isEmpty);
  });

  testWidgets('failed attachment artifact redacts raw storage path', (
    tester,
  ) async {
    await _pumpApp(tester, photoAdapter: const _FailedArtifactPhotoAdapter());
    await _openNewRecordSheet(tester);

    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();

    final attachment = _readCaptureInputState(tester).attachments.single;
    expect(
      find.byKey(Key('attachment-${attachment.id}-artifact-vision_summary')),
      findsOneWidget,
    );
    expect(find.text('failed'), findsWidgets);
    expect(find.textContaining('/Users/guangmo/private'), findsNothing);
  });

  testWidgets('blocked attachment artifact hides dangerous preview', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      photoAdapter: const FakePhotoCaptureAdapter(
        mode: FakePhotoMode.dangerous,
      ),
    );
    await _openNewRecordSheet(tester);

    await tester.tap(find.byKey(const Key('add-gallery-attachment-button')));
    await tester.pumpAndSettle();

    final attachment = _readCaptureInputState(tester).attachments.single;
    expect(
      find.byKey(Key('attachment-${attachment.id}-artifact-image_derivatives')),
      findsOneWidget,
    );
    expect(find.text('blocked'), findsWidgets);
    expect(find.textContaining('DANGEROUS RAW PREVIEW'), findsNothing);
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

    await _startBackgroundRecording(tester);
    await _scrollHomeActionIntoView(
      tester,
      find.byKey(const Key('background-voice-stop-button')),
      scrollAmount: -120,
    );
    await tester.tap(find.byKey(const Key('background-voice-stop-button')));
    await tester.pumpAndSettle();

    var inputState = _readCaptureInputState(tester);
    final attachment = inputState.attachments.single;
    expect(attachment.state, CaptureAttachmentState.needsReview);
    expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
    expect(find.textContaining('Transcript needs review'), findsOneWidget);
    expect(
      find.byKey(Key('attachment-${attachment.id}-artifact-audio_transcript')),
      findsOneWidget,
    );
    expect(find.text('needs review'), findsOneWidget);

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
    expect(find.text('ready'), findsOneWidget);

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

    final artifacts = database.derivedArtifacts.readByCapture(
      attachment.captureId,
    );
    expect(
      artifacts.map((artifact) => artifact.artifactKind),
      containsAll(<String>['vision_summary', 'ocr_text']),
    );

    final vision = artifacts.singleWhere(
      (artifact) => artifact.artifactKind == 'vision_summary',
    );
    expect(vision.status, 'active');
    expect(vision.body, contains('whiteboard snapshot'));
    expect(
      vision.sourceRefs.whereType<Map>().any(
        (ref) => ref['kind'] == 'attachment' && ref['id'] == attachment.id,
      ),
      isTrue,
    );

    final ocr = artifacts.singleWhere(
      (artifact) => artifact.artifactKind == 'ocr_text',
    );
    expect(ocr.status, 'pending');
    expect(ocr.body, contains('OCR pending'));
  });

  testWidgets('voice cancel discards recording without a fake record', (
    tester,
  ) async {
    await _pumpApp(tester, voiceAdapter: const _NoPreviewVoiceAdapter());

    await _startBackgroundRecording(tester);
    await _scrollHomeActionIntoView(
      tester,
      find.byKey(const Key('background-voice-cancel-button')),
      scrollAmount: -120,
    );
    await tester.tap(find.byKey(const Key('background-voice-cancel-button')));
    await tester.pumpAndSettle();

    await _scrollHomeActionIntoView(
      tester,
      find.text('Voice recording cancelled.'),
      scrollAmount: -120,
    );
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

  testWidgets('long text and multiple attachment artifacts stay bounded', (
    tester,
  ) async {
    await _pumpApp(tester, photoAdapter: const _LongArtifactPhotoAdapter());
    await _openNewRecordSheet(tester);
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-camera-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-gallery-attachment-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-capture-field')),
      'A long capture accompanies several attachments. ${'detail ' * 120}',
    );
    await tester.pumpAndSettle();

    expect(_readCaptureInputState(tester).attachments, hasLength(2));
    expect(
      find.byKey(const Key('attachment-row-long-camera-photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('attachment-row-long-gallery-photo')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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

    await tester.scrollUntilVisible(
      find.byKey(const Key('open-new-record-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
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

    await _startBackgroundRecording(tester);
    await _scrollHomeActionIntoView(
      tester,
      find.byKey(const Key('background-voice-stop-button')),
      scrollAmount: -120,
    );
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
  List<Override> overrides = const [],
}) async {
  final localDatabase = database ?? WideNoteLocalDatabase.inMemory();
  final transcriptionService = TranscriptionService(
    database: localDatabase,
    supportDirectory: null,
    settingsRepository: MemoryVoiceTranscriptionSettingsRepository(),
    credentialStore: MemoryTranscriptionCredentialStore(),
    httpClient: null,
    modelClient: modelClient ?? const _CaptureTestModel(),
    localProvider: const _PreviewTranscriptionProvider(),
  );
  addTearDown(localDatabase.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localDatabaseProvider.overrideWithValue(localDatabase),
        photoCaptureAdapterProvider.overrideWithValue(photoAdapter),
        voiceCaptureAdapterProvider.overrideWithValue(voiceAdapter),
        if (modelClient != null)
          modelClientProvider.overrideWithValue(modelClient),
        locationSettingsRepositoryProvider.overrideWithValue(
          InMemoryLocationSettingsRepository(),
        ),
        transcriptionServiceProvider.overrideWithValue(transcriptionService),
        if (draftRepository != null)
          captureDraftRepositoryProvider.overrideWithValue(draftRepository),
        ...overrides,
      ],
      child: WideNoteApp(locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openNewRecordSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab-record-action')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('capture-sheet')), findsOneWidget);
}

Future<void> _startBackgroundRecording(WidgetTester tester) async {
  final button = find.byKey(const Key('start-background-recording-button'));
  await _scrollHomeActionIntoView(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _scrollHomeActionIntoView(
  WidgetTester tester,
  Finder finder, {
  double scrollAmount = 120,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      scrollAmount,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
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
        'durability': 'durable',
      },
    );
  }
}

final class _PreviewTranscriptionProvider
    implements AudioTranscriptionProvider {
  const _PreviewTranscriptionProvider();

  @override
  String get id => 'preview_fake';

  @override
  String get displayName => 'Preview Fake';

  @override
  TranscriptionProviderKind get kind =>
      TranscriptionProviderKind.localSenseVoice;

  @override
  bool get supportsFileTranscription => true;

  @override
  bool get supportsRemoteUpload => false;

  @override
  bool get supportsStreamingPreview => true;

  @override
  Future<void> prepare() async {}

  @override
  Future<TranscriptionResult> transcribeAttachment(
    AudioAttachmentRef attachment, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async {
    return TranscriptionResult(
      text: 'Live preview text',
      status: TranscriptStatus.active,
      providerId: id,
      providerKind: kind,
      model: 'preview-fake',
      durationMs: attachment.durationMs,
    );
  }

  @override
  Stream<TranscriptionPreview> transcribeSamples(
    Stream<AudioPcmChunk> samples, {
    TranscriptionOptions options = const TranscriptionOptions(),
  }) async* {
    yield const TranscriptionPreview(
      pendingText: 'Live preview text',
      status: TranscriptStatus.transcribing,
    );
  }

  @override
  Future<void> dispose() async {}
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
      path: 'fake://voice/review.wav',
      startedAt: DateTime.utc(2026, 6, 24, 13),
    );
  }

  @override
  Future<RawCaptureAsset> stopRecording(VoiceRecordingSession session) async {
    return RawCaptureAsset(
      id: 'voice-review-asset',
      kind: CaptureAssetKind.voice,
      displayName: 'Voice review sample.wav',
      mimeType: 'audio/wav',
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

final class _FailedArtifactPhotoAdapter implements PhotoCaptureAdapter {
  const _FailedArtifactPhotoAdapter();

  @override
  Future<RawCaptureAsset> captureFromCamera() async {
    return RawCaptureAsset(
      id: 'failed-artifact-photo',
      kind: CaptureAssetKind.photo,
      displayName: 'Failed artifact photo.jpg',
      mimeType: 'image/jpeg',
      sourceUri: '/Users/guangmo/private/raw/failed-artifact-photo.jpg',
      createdAt: DateTime.utc(2026, 6, 29, 8),
      previewText: 'Safe photo summary returned by the adapter.',
      rawMetadata: const <String, Object?>{
        'source': 'camera',
        'sha256': 'failed-artifact-sha256',
        'vision_status': 'failed',
        'ocr_status': 'failed',
        'local_path': '/Users/guangmo/private/raw/failed-artifact-photo.jpg',
      },
    );
  }

  @override
  Future<RawCaptureAsset> pickFromGallery() => captureFromCamera();
}

final class _LongArtifactPhotoAdapter implements PhotoCaptureAdapter {
  const _LongArtifactPhotoAdapter();

  @override
  Future<RawCaptureAsset> captureFromCamera() async {
    return _asset(
      id: 'long-camera-photo',
      displayName:
          'A very long camera attachment name that should never widen rows.jpg',
      source: 'camera',
    );
  }

  @override
  Future<RawCaptureAsset> pickFromGallery() async {
    return _asset(
      id: 'long-gallery-photo',
      displayName:
          'A very long gallery attachment name that should wrap safely.jpg',
      source: 'gallery',
    );
  }

  RawCaptureAsset _asset({
    required String id,
    required String displayName,
    required String source,
  }) {
    return RawCaptureAsset(
      id: id,
      kind: CaptureAssetKind.photo,
      displayName: displayName,
      mimeType: 'image/jpeg',
      sourceUri: '/Users/guangmo/private/raw/$id.jpg',
      createdAt: DateTime.utc(2026, 6, 29, 9),
      previewText:
          'A safe adapter preview with many words that should ellipsize '
          'inside the attachment artifact list instead of overflowing.',
      rawMetadata: <String, Object?>{
        'source': source,
        'sha256': '$id-sha256',
        'vision_status': 'ready',
        'ocr_status': 'pending',
        'local_path': '/Users/guangmo/private/raw/$id.jpg',
      },
    );
  }
}

final class _NoPreviewVoiceAdapter implements VoiceCaptureAdapter {
  const _NoPreviewVoiceAdapter();

  @override
  Future<VoiceRecordingSession> startRecording() async {
    return VoiceRecordingSession(
      id: 'voice-no-preview-session',
      path: 'fake://voice/no-preview.wav',
      startedAt: DateTime.utc(2026, 6, 24, 12),
    );
  }

  @override
  Future<RawCaptureAsset> stopRecording(VoiceRecordingSession session) async {
    return RawCaptureAsset(
      id: 'voice-no-preview-asset',
      kind: CaptureAssetKind.voice,
      displayName: 'Voice recording sample.wav',
      mimeType: 'audio/wav',
      sourceUri: session.path,
      sizeBytes: 96000,
      createdAt: DateTime.utc(2026, 6, 24, 12, 1),
      previewText: 'Voice saved locally. Transcript pending.',
      rawMetadata: const <String, Object?>{
        'adapter': 'fake_voice',
        'source': 'microphone',
        'local_path': 'fake://voice/no-preview.wav',
        'duration_ms': 1000,
        'sha256': 'voice-no-preview-sha256',
      },
    );
  }

  @override
  Future<void> cancelRecording(VoiceRecordingSession session) async {}
}
