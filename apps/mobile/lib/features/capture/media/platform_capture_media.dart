import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'capture_media.dart';

typedef PickImageFromSource =
    Future<XFile?> Function(ImageSource source, {bool requestFullMetadata});
typedef SupportsImageSource = FutureOr<bool> Function(ImageSource source);

final class CaptureMediaFileStore {
  CaptureMediaFileStore({
    Future<Directory> Function()? rootDirectoryProvider,
    DateTime Function()? now,
  }) : _rootDirectoryProvider =
           rootDirectoryProvider ?? getApplicationDocumentsDirectory,
       _now = now ?? _utcNow;

  final Future<Directory> Function() _rootDirectoryProvider;
  final DateTime Function() _now;

  Future<RawCaptureAsset> storePickedImage({
    required XFile file,
    required String source,
  }) async {
    final createdAt = _now();
    final id = _assetId('photo-$source', createdAt);
    final extension = _safeExtension(file.name, fallback: '.jpg');
    final target = await _targetFile('photos', '$id$extension');

    await file.saveTo(target.path);
    final byteLength = await target.length();
    final fileHash = await _sha256Hex(target);
    final storageRef = _storageRef('photos', target);
    final mimeType = file.mimeType ?? _mimeTypeForExtension(extension);

    return RawCaptureAsset(
      id: id,
      kind: CaptureAssetKind.photo,
      displayName: _safeDisplayName(file.name, fallback: '$source$extension'),
      mimeType: mimeType,
      sourceUri: storageRef,
      sizeBytes: byteLength,
      previewText: source == 'camera'
          ? 'Camera photo saved locally.'
          : 'Gallery photo saved locally.',
      rawMetadata: <String, Object?>{
        'adapter': 'image_picker',
        'source': source,
        'user_selected': true,
        'request_full_metadata': false,
        'original_path': file.path,
        'local_path': target.path,
        'storage_ref': storageRef,
        'sha256': fileHash,
        'byte_length': byteLength,
        'original_file_name': file.name,
      },
      createdAt: createdAt,
    );
  }

  Future<VoiceRecordingSession> prepareVoiceSession() async {
    final startedAt = _now();
    final id = _assetId('voice', startedAt);
    final target = await _targetFile('voice', '$id.wav');
    return VoiceRecordingSession(
      id: id,
      path: target.path,
      startedAt: startedAt,
    );
  }

  Future<RawCaptureAsset> storeVoiceRecording(
    VoiceRecordingSession session,
    String outputPath,
  ) async {
    final source = File(outputPath);
    if (!source.existsSync()) {
      throw CaptureMediaException(
        CaptureMediaFailureReason.unavailable,
        'Voice recording file was not created.',
      );
    }

    final target = File(session.path);
    if (source.path != target.path) {
      await source.copy(target.path);
    }

    final byteLength = await target.length();
    if (!await _hasVoiceAudioData(target, byteLength)) {
      await target.delete();
      throw const CaptureMediaException(
        CaptureMediaFailureReason.unavailable,
        'Voice recording produced an empty file.',
      );
    }

    final endedAt = _now();
    final fileHash = await _sha256Hex(target);
    final durationMs = endedAt.difference(session.startedAt).inMilliseconds;
    final storageRef = _storageRef('voice', target);

    return RawCaptureAsset(
      id: session.id,
      kind: CaptureAssetKind.voice,
      displayName: p.basename(target.path),
      mimeType: 'audio/wav',
      sourceUri: storageRef,
      sizeBytes: byteLength,
      previewText:
          'Voice recording captured (${_durationLabel(durationMs)}). '
          'Transcript pending.',
      rawMetadata: <String, Object?>{
        'adapter': 'record',
        'source': 'microphone',
        'audio_format': 'wav',
        'sample_rate': session.sampleRate,
        'num_channels': session.numChannels,
        'streaming_source': session.usesStreamingSource,
        'local_path': target.path,
        'storage_ref': storageRef,
        'sha256': fileHash,
        'byte_length': byteLength,
        'duration_ms': durationMs,
        'transcript_status': 'pending',
      },
      createdAt: endedAt,
    );
  }

  Future<File> _targetFile(String bucket, String fileName) async {
    final root = await _rootDirectoryProvider();
    final directory = Directory(p.join(root.path, 'capture_media', bucket));
    await directory.create(recursive: true);
    return File(p.join(directory.path, _safeFileName(fileName)));
  }

  String _storageRef(String bucket, File file) {
    return 'local://capture_media/$bucket/${p.basename(file.path)}';
  }
}

final class ImagePickerPhotoCaptureAdapter implements PhotoCaptureAdapter {
  ImagePickerPhotoCaptureAdapter({
    ImagePicker? picker,
    CaptureMediaFileStore? fileStore,
    PickImageFromSource? pickImage,
    SupportsImageSource? supportsImageSource,
  }) : _picker = picker ?? ImagePicker(),
       _fileStore = fileStore ?? CaptureMediaFileStore(),
       _pickImage = pickImage,
       _supportsImageSource = supportsImageSource;

  final ImagePicker _picker;
  final CaptureMediaFileStore _fileStore;
  final PickImageFromSource? _pickImage;
  final SupportsImageSource? _supportsImageSource;

  @override
  Future<RawCaptureAsset> captureFromCamera() {
    return _pick(source: ImageSource.camera, sourceName: 'camera');
  }

  @override
  Future<RawCaptureAsset> pickFromGallery() {
    return _pick(source: ImageSource.gallery, sourceName: 'gallery');
  }

  Future<RawCaptureAsset> _pick({
    required ImageSource source,
    required String sourceName,
  }) async {
    try {
      final supportsSource =
          await (_supportsImageSource ?? _picker.supportsImageSource)(source);
      if (!supportsSource) {
        throw CaptureMediaException(
          CaptureMediaFailureReason.unavailable,
          sourceName == 'camera'
              ? 'Camera is unavailable on this device.'
              : 'Photo library is unavailable on this device.',
        );
      }
      final file = await (_pickImage ?? _defaultPickImage)(
        source,
        requestFullMetadata: false,
      );
      if (file == null) {
        throw CaptureMediaException(
          CaptureMediaFailureReason.cancelled,
          sourceName == 'camera'
              ? 'Camera capture cancelled.'
              : 'Gallery selection cancelled.',
        );
      }
      return _fileStore.storePickedImage(file: file, source: sourceName);
    } on CaptureMediaException {
      rethrow;
    } on PlatformException catch (error) {
      throw _imagePickerException(sourceName, error);
    } catch (error) {
      throw CaptureMediaException(
        CaptureMediaFailureReason.platformError,
        sourceName == 'camera'
            ? 'Camera capture failed.'
            : 'Gallery selection failed.',
        cause: error,
      );
    }
  }

  Future<XFile?> _defaultPickImage(
    ImageSource source, {
    required bool requestFullMetadata,
  }) {
    return _picker.pickImage(
      source: source,
      imageQuality: 95,
      requestFullMetadata: requestFullMetadata,
    );
  }
}

final class RecordVoiceCaptureAdapter implements VoiceCaptureAdapter {
  RecordVoiceCaptureAdapter({
    AudioRecorder? recorder,
    CaptureMediaFileStore? fileStore,
  }) : _recorder = recorder ?? AudioRecorder(),
       _fileStore = fileStore ?? CaptureMediaFileStore();

  final AudioRecorder _recorder;
  final CaptureMediaFileStore _fileStore;

  @override
  Future<VoiceRecordingSession> startRecording() async {
    VoiceRecordingSession? session;
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        throw const CaptureMediaException(
          CaptureMediaFailureReason.permissionDenied,
          'Microphone permission denied.',
        );
      }
      session = await _fileStore.prepareVoiceSession();
      return await _startStreamingSession(session);
    } on CaptureMediaException {
      rethrow;
    } on PlatformException catch (error) {
      await _deleteIfExists(session?.path);
      throw _voiceException(error);
    } catch (error) {
      await _deleteIfExists(session?.path);
      throw CaptureMediaException(
        CaptureMediaFailureReason.platformError,
        'Voice recording failed to start.',
        cause: error,
      );
    }
  }

  @override
  Future<RawCaptureAsset> stopRecording(VoiceRecordingSession session) async {
    try {
      final path = await _recorder.stop();
      if (session.usesStreamingSource) {
        await session.finalizeStreamingSource?.call();
        return _fileStore.storeVoiceRecording(session, session.path);
      }
      if (path == null || path.trim().isEmpty) {
        throw const CaptureMediaException(
          CaptureMediaFailureReason.unavailable,
          'Voice recording file was not returned.',
        );
      }
      return _fileStore.storeVoiceRecording(session, path);
    } on CaptureMediaException {
      rethrow;
    } on PlatformException catch (error) {
      throw _voiceException(error);
    } catch (error) {
      throw CaptureMediaException(
        CaptureMediaFailureReason.platformError,
        'Voice recording failed to stop.',
        cause: error,
      );
    }
  }

  @override
  Future<void> cancelRecording(VoiceRecordingSession session) async {
    Object? recorderFailure;
    try {
      await _recorder.cancel();
    } catch (error) {
      recorderFailure = error;
    }

    try {
      await session.cancelStreamingSource?.call();
    } catch (error) {
      recorderFailure ??= error;
    }

    try {
      final file = File(session.path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (error) {
      throw CaptureMediaException(
        CaptureMediaFailureReason.platformError,
        'Voice recording cancel failed.',
        cause: error,
      );
    }

    if (recorderFailure != null) {
      throw CaptureMediaException(
        CaptureMediaFailureReason.platformError,
        'Voice recording cancel failed.',
        cause: recorderFailure,
      );
    }
  }

  Future<VoiceRecordingSession> _startStreamingSession(
    VoiceRecordingSession session,
  ) async {
    _StreamingWavFileWriter? writer;
    StreamSubscription<Uint8List>? subscription;
    StreamController<Uint8List>? previewController;
    final streamDone = Completer<void>();
    var cancelSubscriptionAfterDrain = false;
    void markStreamDone() {
      if (!streamDone.isCompleted) {
        streamDone.complete();
      }
    }

    try {
      writer = _StreamingWavFileWriter(
        file: File(session.path),
        sampleRate: 16000,
        numChannels: 1,
      );
      await writer.open();
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          streamBufferSize: 4096,
        ),
      );
      previewController = StreamController<Uint8List>.broadcast();
      subscription = stream.listen(
        (chunk) {
          writer?.add(chunk);
          previewController?.add(chunk);
        },
        onError: (Object error, StackTrace stackTrace) {
          cancelSubscriptionAfterDrain = true;
          previewController?.addError(error, stackTrace);
          markStreamDone();
        },
        onDone: () {
          markStreamDone();
          unawaited(previewController?.close());
        },
        cancelOnError: false,
      );
      return VoiceRecordingSession(
        id: session.id,
        path: session.path,
        startedAt: session.startedAt,
        pcmStream: previewController.stream,
        sampleRate: 16000,
        numChannels: 1,
        usesStreamingSource: true,
        finalizeStreamingSource: () async {
          try {
            await streamDone.future.timeout(_streamStopDrainTimeout);
          } on TimeoutException {
            cancelSubscriptionAfterDrain = true;
          }
          if (cancelSubscriptionAfterDrain) {
            await subscription?.cancel();
          }
          await writer?.finalizeFile();
          if (!(previewController?.isClosed ?? true)) {
            await previewController?.close();
          }
        },
        cancelStreamingSource: () async {
          await subscription?.cancel();
          await writer?.cancel();
          if (!(previewController?.isClosed ?? true)) {
            await previewController?.close();
          }
        },
      );
    } catch (_) {
      await subscription?.cancel();
      await writer?.cancel();
      if (!(previewController?.isClosed ?? true)) {
        await previewController?.close();
      }
      await _deleteIfExists(session.path);
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: session.path,
      );
      return session;
    }
  }
}

const _minimumWavHeaderBytes = 44;
const _wavHeaderSampleBytes = 4096;
const _streamStopDrainTimeout = Duration(seconds: 2);

Future<bool> _hasVoiceAudioData(File file, int byteLength) async {
  if (byteLength <= _minimumWavHeaderBytes) {
    return false;
  }

  final sampleLength = byteLength < _wavHeaderSampleBytes
      ? byteLength
      : _wavHeaderSampleBytes;
  final builder = await file.openRead(0, sampleLength).fold<BytesBuilder>(
    BytesBuilder(copy: false),
    (builder, chunk) {
      builder.add(chunk);
      return builder;
    },
  );
  final header = builder.takeBytes();
  if (!_hasAscii(header, 0, 'RIFF') || !_hasAscii(header, 8, 'WAVE')) {
    return true;
  }
  final dataChunk = _wavDataChunk(header);
  return dataChunk != null &&
      dataChunk.length > 0 &&
      byteLength >= dataChunk.dataOffset + dataChunk.length;
}

_WavDataChunk? _wavDataChunk(Uint8List header) {
  var offset = 12;
  while (offset + 8 <= header.length) {
    final chunkLength = _uint32LittleEndian(header, offset + 4);
    if (_hasAscii(header, offset, 'data')) {
      return _WavDataChunk(dataOffset: offset + 8, length: chunkLength);
    }
    final paddedLength = chunkLength.isOdd ? chunkLength + 1 : chunkLength;
    final nextOffset = offset + 8 + paddedLength;
    if (nextOffset <= offset || nextOffset > header.length) {
      return null;
    }
    offset = nextOffset;
  }
  return null;
}

final class _WavDataChunk {
  const _WavDataChunk({required this.dataOffset, required this.length});

  final int dataOffset;
  final int length;
}

bool _hasAscii(Uint8List bytes, int offset, String value) {
  if (offset < 0 || offset + value.length > bytes.length) {
    return false;
  }
  for (var index = 0; index < value.length; index += 1) {
    if (bytes[offset + index] != value.codeUnitAt(index)) {
      return false;
    }
  }
  return true;
}

int _uint32LittleEndian(Uint8List bytes, int offset) {
  return ByteData.sublistView(
    bytes,
    offset,
    offset + 4,
  ).getUint32(0, Endian.little);
}

final class _StreamingWavFileWriter {
  _StreamingWavFileWriter({
    required this.file,
    required this.sampleRate,
    required this.numChannels,
  });

  final File file;
  final int sampleRate;
  final int numChannels;
  IOSink? _sink;
  var _dataLength = 0;
  var _closed = false;

  Future<void> open() async {
    await file.parent.create(recursive: true);
    _sink = file.openWrite();
    _sink!.add(Uint8List(44));
  }

  void add(Uint8List chunk) {
    if (_closed || chunk.isEmpty) {
      return;
    }
    _dataLength += chunk.length;
    _sink?.add(chunk);
  }

  Future<void> finalizeFile() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _sink?.close();
    final header = _wavHeader(
      dataLength: _dataLength,
      sampleRate: sampleRate,
      numChannels: numChannels,
    );
    final handle = await file.open(mode: FileMode.append);
    try {
      await handle.setPosition(0);
      await handle.writeFrom(header);
    } finally {
      await handle.close();
    }
  }

  Future<void> cancel() async {
    _closed = true;
    await _sink?.close();
    if (file.existsSync()) {
      await file.delete();
    }
  }
}

@visibleForTesting
Future<void> writeStreamingWavFileForTest({
  required File file,
  required Iterable<Uint8List> chunks,
  int sampleRate = 16000,
  int numChannels = 1,
}) async {
  final writer = _StreamingWavFileWriter(
    file: file,
    sampleRate: sampleRate,
    numChannels: numChannels,
  );
  await writer.open();
  for (final chunk in chunks) {
    writer.add(chunk);
  }
  await writer.finalizeFile();
}

Uint8List _wavHeader({
  required int dataLength,
  required int sampleRate,
  required int numChannels,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final header = ByteData(44);
  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i += 1) {
      header.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, numChannels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, dataLength, Endian.little);
  return header.buffer.asUint8List();
}

CaptureMediaException _imagePickerException(
  String sourceName,
  PlatformException error,
) {
  final code = error.code.toLowerCase();
  final message = (error.message ?? '').toLowerCase();
  if (code.contains('cancel') || message.contains('cancel')) {
    return CaptureMediaException(
      CaptureMediaFailureReason.cancelled,
      sourceName == 'camera'
          ? 'Camera capture cancelled.'
          : 'Gallery selection cancelled.',
      cause: error,
    );
  }
  final permissionDenied =
      code.contains('permission') ||
      code.contains('denied') ||
      code.contains('restricted') ||
      message.contains('permission') ||
      message.contains('denied') ||
      message.contains('restricted');
  if (permissionDenied) {
    return CaptureMediaException(
      CaptureMediaFailureReason.permissionDenied,
      sourceName == 'camera'
          ? 'Camera permission denied.'
          : 'Photo library permission denied.',
      cause: error,
    );
  }
  final unavailable =
      code.contains('unavailable') ||
      code.contains('not_available') ||
      message.contains('unavailable') ||
      message.contains('not available');
  if (unavailable) {
    return CaptureMediaException(
      CaptureMediaFailureReason.unavailable,
      sourceName == 'camera'
          ? 'Camera is unavailable on this device.'
          : 'Photo library is unavailable on this device.',
      cause: error,
    );
  }
  return CaptureMediaException(
    CaptureMediaFailureReason.platformError,
    sourceName == 'camera'
        ? 'Camera capture failed.'
        : 'Gallery selection failed.',
    cause: error,
  );
}

CaptureMediaException _voiceException(PlatformException error) {
  final code = error.code.toLowerCase();
  final message = (error.message ?? '').toLowerCase();
  if (code.contains('cancel') || message.contains('cancel')) {
    return CaptureMediaException(
      CaptureMediaFailureReason.cancelled,
      'Voice recording cancelled.',
      cause: error,
    );
  }
  if (code.contains('permission') ||
      code.contains('denied') ||
      code.contains('restricted') ||
      message.contains('permission') ||
      message.contains('denied') ||
      message.contains('restricted')) {
    return CaptureMediaException(
      CaptureMediaFailureReason.permissionDenied,
      'Microphone permission denied.',
      cause: error,
    );
  }
  if (code.contains('unavailable') ||
      code.contains('not_available') ||
      message.contains('unavailable') ||
      message.contains('not available')) {
    return CaptureMediaException(
      CaptureMediaFailureReason.unavailable,
      'Microphone is unavailable on this device.',
      cause: error,
    );
  }
  return CaptureMediaException(
    CaptureMediaFailureReason.platformError,
    'Voice recording failed.',
    cause: error,
  );
}

Future<String> _sha256Hex(File file) async {
  final digest = await sha256.bind(file.openRead()).single;
  return digest.toString();
}

String _assetId(String prefix, DateTime createdAt) {
  return '$prefix-${createdAt.toUtc().microsecondsSinceEpoch}';
}

String _durationLabel(int durationMs) {
  final seconds = (durationMs / 1000).clamp(0, double.infinity).round();
  return '${seconds}s';
}

String _safeExtension(String name, {required String fallback}) {
  final extension = p.extension(name).toLowerCase();
  if (extension.isEmpty || extension.length > 8) {
    return fallback;
  }
  final sanitized = extension.replaceAll(RegExp(r'[^a-z0-9.]'), '');
  if (sanitized.isEmpty || sanitized == '.') {
    return fallback;
  }
  return sanitized;
}

String _safeDisplayName(String name, {required String fallback}) {
  final sanitized = _safeFileName(name);
  return sanitized.isEmpty ? fallback : sanitized;
}

String _safeFileName(String name) {
  final base = p.basename(name).trim();
  return base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

String _mimeTypeForExtension(String extension) {
  return switch (extension.toLowerCase()) {
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.heic' => 'image/heic',
    '.webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

DateTime _utcNow() => DateTime.now().toUtc();

Future<void> _deleteIfExists(String? path) async {
  if (path == null) {
    return;
  }
  final file = File(path);
  if (file.existsSync()) {
    await file.delete();
  }
}
