import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_database.dart';

final captureDraftRepositoryProvider = Provider<CaptureDraftRepository>((ref) {
  final supportDirectory = ref.watch(appSupportDirectoryProvider);
  if (supportDirectory == null) {
    return InMemoryCaptureDraftRepository();
  }
  return FileCaptureDraftRepository(
    File(
      _joinPath(
        _joinPath(supportDirectory.path, 'local-data'),
        'capture-draft.json',
      ),
    ),
  );
});

final class CaptureDraft {
  const CaptureDraft({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CaptureDraft.fromJson(Map<String, Object?> json) {
    final now = DateTime.now().toUtc();
    return CaptureDraft(
      id: _string(json['id']) ?? 'active',
      text: _string(json['text']) ?? '',
      createdAt: DateTime.tryParse(_string(json['created_at']) ?? '') ?? now,
      updatedAt: DateTime.tryParse(_string(json['updated_at']) ?? '') ?? now,
    );
  }

  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty => text.trim().isEmpty;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': 1,
      'id': id,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

abstract interface class CaptureDraftRepository {
  Future<CaptureDraft?> loadActiveDraft();
  Future<void> saveTextDraft(String text);
  Future<void> clearActiveDraft();
}

final class InMemoryCaptureDraftRepository implements CaptureDraftRepository {
  InMemoryCaptureDraftRepository({DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  CaptureDraft? _draft;

  @override
  Future<CaptureDraft?> loadActiveDraft() async {
    final draft = _draft;
    if (draft == null || draft.isEmpty) {
      return null;
    }
    return draft;
  }

  @override
  Future<void> saveTextDraft(String text) async {
    if (text.trim().isEmpty) {
      await clearActiveDraft();
      return;
    }
    final now = _clock();
    final previous = _draft;
    _draft = CaptureDraft(
      id: previous?.id ?? 'active',
      text: text,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
  }

  @override
  Future<void> clearActiveDraft() async {
    _draft = null;
  }
}

final class FileCaptureDraftRepository implements CaptureDraftRepository {
  FileCaptureDraftRepository(this._file, {DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  final File _file;
  final DateTime Function() _clock;

  @override
  Future<CaptureDraft?> loadActiveDraft() async {
    try {
      if (!await _file.exists()) {
        return null;
      }
      final json = jsonDecode(await _file.readAsString());
      if (json is! Map) {
        return null;
      }
      final draft = CaptureDraft.fromJson(json.cast<String, Object?>());
      return draft.isEmpty ? null : draft;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveTextDraft(String text) async {
    if (text.trim().isEmpty) {
      await clearActiveDraft();
      return;
    }
    try {
      final previous = await loadActiveDraft();
      final now = _clock();
      final draft = CaptureDraft(
        id: previous?.id ?? 'active',
        text: text,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      );
      await _file.parent.create(recursive: true);
      final tempFile = File('${_file.path}.tmp');
      await tempFile.writeAsString(jsonEncode(draft.toJson()), flush: true);
      if (await _file.exists()) {
        await _file.delete();
      }
      await tempFile.rename(_file.path);
    } on Object {
      // Draft persistence should never block immediate capture.
    }
  }

  @override
  Future<void> clearActiveDraft() async {
    try {
      if (await _file.exists()) {
        await _file.delete();
      }
    } on Object {
      // Draft persistence should never block immediate capture.
    }
  }
}

String? _string(Object? value) {
  if (value is String) {
    return value;
  }
  return null;
}

String _joinPath(String directory, String child) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$child';
  }
  return '$directory${Platform.pathSeparator}$child';
}
