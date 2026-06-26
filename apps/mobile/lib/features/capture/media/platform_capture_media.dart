import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
    final target = await _targetFile('voice', '$id.m4a');
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
    if (byteLength <= 0) {
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
      mimeType: 'audio/m4a',
      sourceUri: storageRef,
      sizeBytes: byteLength,
      previewText:
          'Voice recording captured (${_durationLabel(durationMs)}). '
          'Transcript pending.',
      rawMetadata: <String, Object?>{
        'adapter': 'record',
        'source': 'microphone',
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
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: session.path,
      );
      return session;
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
