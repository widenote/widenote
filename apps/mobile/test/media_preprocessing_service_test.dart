import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;
import 'package:widenote_local_db/widenote_local_db.dart' as localdb;
import 'package:widenote_mobile/app/model_client.dart';
import 'package:widenote_mobile/features/capture/application/local_capture_read_model.dart';
import 'package:widenote_mobile/features/capture/application/media_preprocessing_service.dart';
import 'package:widenote_mobile/features/capture/domain/capture_models.dart';
import 'package:widenote_mobile/features/capture/media/capture_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late localdb.WideNoteLocalDatabase database;
  late Directory tempDir;

  setUp(() async {
    database = localdb.WideNoteLocalDatabase.inMemory();
    tempDir = await Directory.systemTemp.createTemp('widenote-media-test-');
  });

  tearDown(() async {
    database.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('preprocesses a ready photo into source-linked image artifacts', () async {
    final image = await _writeTinyPng(tempDir, 'source.png');
    final now = DateTime.utc(2026, 7, 2, 10);
    final record = _record(now);
    final attachment = _attachment(now, image);
    _seedSource(database, record, attachment);
    final model = runtime.FakeModel(
      responses: const <String>[
        '{"vision_summary":"Whiteboard with launch checklist.","ocr_text":"QA docs review","labels":["whiteboard","checklist"],"confidence":"high"}',
      ],
    );
    final service = MediaPreprocessingService(
      database: database,
      modelClient: model,
    );

    final attachments = await service.preprocessPhotoAttachments(
      record,
      <CaptureAttachment>[attachment],
    );

    expect(model.requests, hasLength(1));
    final request = model.requests.single;
    expect(request.hasAttachments, isTrue);
    expect(request.attachments.single.mimeType, 'image/png');
    expect(request.attachments.single.dataBase64, isNotEmpty);
    expect(request.context['feature'], 'capture.media_semantic_agent');
    expect(request.context['agent_id'], CaptureMediaSemanticAgent.generatorId);
    expect(jsonEncode(request.context), isNot(contains(image.path)));
    expect(request.prompt, isNot(contains(image.path)));

    final updated = attachments.single;
    expect(
      updated.rawMetadata['vision_summary'],
      'Whiteboard with launch checklist.',
    );
    expect(updated.rawMetadata['ocr_text'], 'QA docs review');
    expect(updated.rawMetadata['image_preprocessing_status'], 'active');
    expect(
      updated.derivedArtifacts.map((artifact) => artifact.artifactKind),
      containsAll(<String>['vision_summary', 'ocr_text']),
    );
    expect(
      updated.derivedArtifacts
          .where((artifact) => artifact.artifactKind == 'vision_summary')
          .single
          .status,
      AttachmentDerivedArtifactStatus.ready,
    );

    final vision = database.derivedArtifacts.readById(
      'artifact.capture-image.attachment-image.vision_summary',
    )!;
    expect(vision.status, 'active');
    expect(vision.body, 'Whiteboard with launch checklist.');
    expect(vision.payload['source_sha256'], 'sha-image');
    expect(
      (vision.payload['derived_by']! as Map)['prompt_version'],
      isNotEmpty,
    );
    expect(
      (vision.payload['derived_by']! as Map)['agent_id'],
      CaptureMediaSemanticAgent.generatorId,
    );
    expect(jsonEncode(vision.payload), isNot(contains(image.path)));

    final ocr = database.derivedArtifacts.readById(
      'artifact.capture-image.attachment-image.ocr_text',
    )!;
    expect(ocr.status, 'active');
    expect(ocr.body, 'QA docs review');

    LocalCaptureReadModelStore(
      database,
    ).saveCapture(record, attachments: attachments, rawText: record.body);
    final resavedVision = database.derivedArtifacts.readById(
      'artifact.capture-image.attachment-image.vision_summary',
    )!;
    expect(resavedVision.generatorId, CaptureMediaSemanticAgent.generatorId);
    expect(resavedVision.payload['source_sha256'], 'sha-image');
    expect(
      (resavedVision.payload['derived_by']! as Map)['prompt_version'],
      isNotEmpty,
    );
    expect(jsonEncode(resavedVision.payload), isNot(contains(image.path)));

    final contextPacket =
        localdb.ContextPacketBuilder(database, clock: () => now).build(
          const localdb.ContextPacketBuildRequest(
            surface: 'chat',
            cacheKey: 'image-semantic-context',
            cacheable: false,
            sourceRefs: <localdb.JsonMap>[
              <String, Object?>{
                'kind': 'artifact',
                'id': 'artifact.capture-image.attachment-image.vision_summary',
              },
            ],
          ),
        );
    final encodedPacket = jsonEncode(contextPacket.packet);
    expect(encodedPacket, contains('Whiteboard with launch checklist.'));
    expect(encodedPacket, contains('vision_summary'));
  });

  test(
    'records failed artifacts without throwing on malformed model output',
    () async {
      final image = await _writeTinyPng(tempDir, 'source.png');
      final now = DateTime.utc(2026, 7, 2, 11);
      final record = _record(now);
      final attachment = _attachment(now, image);
      _seedSource(database, record, attachment);
      final service = MediaPreprocessingService(
        database: database,
        modelClient: runtime.FakeModel(responses: const <String>['not json']),
      );

      final attachments = await service.preprocessPhotoAttachments(
        record,
        <CaptureAttachment>[attachment],
      );

      final updated = attachments.single;
      expect(updated.rawMetadata['image_preprocessing_status'], 'failed');
      expect(
        updated.derivedArtifacts.map((artifact) => artifact.status).toSet(),
        <AttachmentDerivedArtifactStatus>{
          AttachmentDerivedArtifactStatus.failed,
        },
      );
      expect(
        database.derivedArtifacts
            .readByAttachment('attachment-image')
            .map((artifact) => artifact.status)
            .toSet(),
        <String>{'failed'},
      );
    },
  );

  test(
    'records no vision provider when image semantic agent is unavailable',
    () async {
      final image = await _writeTinyPng(tempDir, 'source.png');
      final now = DateTime.utc(2026, 7, 2, 12);
      final record = _record(now);
      final attachment = _attachment(now, image);
      _seedSource(database, record, attachment);
      final service = MediaPreprocessingService(
        database: database,
        modelClient: const ModelUnavailableModelClient(),
      );

      final attachments = await service.preprocessPhotoAttachments(
        record,
        <CaptureAttachment>[attachment],
      );

      final updated = attachments.single;
      expect(updated.rawMetadata['image_preprocessing_status'], 'failed');
      expect(
        updated.rawMetadata['image_preprocessing_error'],
        'no_vision_provider',
      );
      expect(
        updated.derivedArtifacts.map((artifact) => artifact.reason).toSet(),
        <String>{'no_vision_provider'},
      );
    },
  );
}

CaptureRecord _record(DateTime now) {
  return CaptureRecord(
    id: 'capture-image',
    body: 'Image capture',
    createdAt: now,
    status: captureStatusSavedProcessing,
  );
}

CaptureAttachment _attachment(DateTime now, File image) {
  return CaptureAttachment(
    id: 'attachment-image',
    kind: CaptureAssetKind.photo,
    displayName: 'source.png',
    mimeType: 'image/png',
    sourceUri: image.path,
    createdAt: now,
    state: CaptureAttachmentState.ready,
    rawMetadata: <String, Object?>{
      'adapter_metadata': <String, Object?>{
        'local_path': image.path,
        'sha256': 'sha-image',
      },
    },
  );
}

void _seedSource(
  localdb.WideNoteLocalDatabase database,
  CaptureRecord record,
  CaptureAttachment attachment,
) {
  database.captures.insert(
    localdb.CaptureRecord(
      id: record.id,
      sourceType: 'manual_with_attachments',
      payload: <String, Object?>{'text': record.body},
      createdAt: record.createdAt,
      updatedAt: record.createdAt,
    ),
  );
  database.attachments.insert(
    localdb.AttachmentRecord(
      id: attachment.id,
      captureId: record.id,
      assetKind: attachment.kind.wireName,
      mimeType: attachment.mimeType,
      storagePath: attachment.sourceUri,
      sha256: 'sha-image',
      status: attachment.state.wireName,
      createdAt: attachment.createdAt,
      updatedAt: attachment.createdAt,
    ),
  );
}

Future<File> _writeTinyPng(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
    ),
  );
  return file;
}
