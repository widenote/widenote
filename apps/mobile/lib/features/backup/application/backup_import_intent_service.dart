import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final backupImportIntentServiceProvider = Provider<BackupImportIntentService>((
  ref,
) {
  return MethodChannelBackupImportIntentService.instance;
});

abstract interface class BackupImportIntentService {
  Future<String?> consumeInitialBackupPath();

  Stream<String> get backupPathStream;
}

final class MethodChannelBackupImportIntentService
    implements BackupImportIntentService {
  MethodChannelBackupImportIntentService._();

  static final MethodChannelBackupImportIntentService instance =
      MethodChannelBackupImportIntentService._();

  static const _methodChannel = MethodChannel('app.widenote/backup_import');
  static const _eventChannel = EventChannel(
    'app.widenote/backup_import_events',
  );

  Stream<String>? _backupPathStream;

  @override
  Future<String?> consumeInitialBackupPath() async {
    if (!_supportsPlatformImport) {
      return null;
    }
    try {
      final path = await _methodChannel.invokeMethod<String>(
        'getInitialBackupPath',
      );
      if (path == null || path.isEmpty) {
        return null;
      }
      await _methodChannel.invokeMethod<void>('clearInitialBackupPath');
      return path;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Stream<String> get backupPathStream {
    if (!_supportsPlatformImport) {
      return const Stream<String>.empty();
    }
    return _backupPathStream ??= _eventChannel
        .receiveBroadcastStream()
        .where((event) => event is String && event.isNotEmpty)
        .cast<String>()
        .handleError((Object _) {});
  }
}

bool get _supportsPlatformImport => Platform.isAndroid || Platform.isIOS;
