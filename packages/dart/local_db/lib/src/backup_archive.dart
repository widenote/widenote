import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import 'backup_export.dart';
import 'json.dart';
import 'json_codec.dart';
import 'markdown_export.dart';

const _archiveRoot = 'widenote-backup';
const _archiveManifestPath = '$_archiveRoot/manifest.json';
const _restoreJsonPath = '$_archiveRoot/restore/safe-backup.json';
const _ownerExportPath = '$_archiveRoot/owner-export/owner-export.md';

abstract final class LocalBackupArchiveCodec {
  static const formatId = 'widenote.backup_archive';
  static const currentFormatVersion = 1;
  static const fileExtension = '.widenote';
  static const mimeType = 'application/x-widenote-backup';
  static const typeIdentifier = 'app.widenote.backup';

  static const rootDirectory = _archiveRoot;
  static const manifestPath = _archiveManifestPath;
  static const restoreJsonPath = _restoreJsonPath;
  static const ownerExportPath = _ownerExportPath;

  static bool hasArchiveExtension(String path) {
    return path.toLowerCase().endsWith(fileExtension);
  }

  static Future<LocalBackupArchiveWriteResult> writeArchive({
    required LocalDataBackup backup,
    required String outputPath,
    String? ownerMarkdown,
  }) async {
    if (!hasArchiveExtension(outputPath)) {
      throw const FormatException('WideNote backups must use .widenote files.');
    }

    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    final tempPath = '$outputPath.tmp';
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final restoreBytes = utf8.encode(LocalBackupCodec.encode(backup));
    final ownerBytes = utf8.encode(
      ownerMarkdown ?? const LocalMarkdownExportService().exportBackup(backup),
    );
    final entries = <LocalBackupArchiveEntry>[
      _entryForBytes(
        path: _restoreJsonPath,
        role: 'restore_json',
        bytes: restoreBytes,
      ),
      _entryForBytes(
        path: _ownerExportPath,
        role: 'owner_export_markdown',
        bytes: ownerBytes,
      ),
    ];
    final manifest = LocalBackupArchiveManifest(
      createdAt: backup.manifest.createdAt,
      backupFormat: backup.manifest.format,
      backupFormatVersion: backup.manifest.formatVersion,
      backupMode: backup.manifest.backupMode,
      includesSecrets: backup.manifest.includesSecrets,
      localDbSchemaVersion: backup.manifest.localDbSchemaVersion,
      recordCounts: backup.manifest.recordCounts,
      entries: entries,
    );
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );

    final encoder = ZipFileEncoder();
    try {
      encoder.create(tempPath, level: ZipFileEncoder.gzip);
      _addBytes(encoder, _restoreJsonPath, restoreBytes);
      _addBytes(encoder, _ownerExportPath, ownerBytes);
      _addBytes(encoder, _archiveManifestPath, manifestBytes);
      await encoder.close();
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      await tempFile.rename(outputPath);
    } catch (_) {
      try {
        await encoder.close();
      } catch (_) {}
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }

    final sizeBytes = await outputFile.length();
    return LocalBackupArchiveWriteResult(
      path: outputPath,
      sizeBytes: sizeBytes,
      manifest: manifest,
    );
  }

  static Future<LocalBackupArchiveExtractResult> extractToDirectory({
    required String archivePath,
    required String stagingDirectory,
  }) async {
    if (!hasArchiveExtension(archivePath)) {
      throw const FormatException('Invalid WideNote backup file extension.');
    }

    final archive = _decodeArchive(archivePath);
    try {
      final manifestFile = _findFile(archive, _archiveManifestPath);
      if (manifestFile == null) {
        throw const FormatException('Missing WideNote backup manifest.');
      }
      final manifest = _readManifest(manifestFile);
      final expected = <String, LocalBackupArchiveEntry>{
        for (final entry in manifest.entries) entry.path: entry,
      };
      final verified = <String>{};
      var restoreJsonFilePath = '';
      var ownerExportFilePath = '';

      final staging = Directory(stagingDirectory);
      await staging.create(recursive: true);

      for (final file in archive) {
        if (!file.isFile || file.name == _archiveManifestPath) {
          continue;
        }
        final entry = expected[file.name];
        if (entry == null) {
          continue;
        }

        final targetPath = _targetPathForEntry(staging.path, file.name);
        await _extractArchiveFile(file, targetPath);
        final actualSha = await _sha256File(targetPath);
        if (actualSha != entry.sha256) {
          throw FormatException('Backup checksum mismatch: ${entry.path}.');
        }
        verified.add(entry.path);
        if (entry.role == 'restore_json') {
          restoreJsonFilePath = targetPath;
        } else if (entry.role == 'owner_export_markdown') {
          ownerExportFilePath = targetPath;
        }
      }

      for (final entry in manifest.entries) {
        if (!verified.contains(entry.path)) {
          throw FormatException('Backup archive is missing ${entry.path}.');
        }
      }
      if (restoreJsonFilePath.isEmpty) {
        throw const FormatException('Backup archive has no restore JSON.');
      }

      return LocalBackupArchiveExtractResult(
        manifest: manifest,
        restoreJsonPath: restoreJsonFilePath,
        ownerExportPath: ownerExportFilePath.isEmpty
            ? null
            : ownerExportFilePath,
      );
    } finally {
      archive.clearSync();
    }
  }

  static Future<String> extractRestoreJson({
    required String archivePath,
    required String stagingDirectory,
  }) async {
    final result = await extractToDirectory(
      archivePath: archivePath,
      stagingDirectory: stagingDirectory,
    );
    return File(result.restoreJsonPath).readAsString();
  }

  static Future<LocalBackupArchiveManifest> readManifest(String archivePath) {
    return _readManifestFromArchive(archivePath);
  }
}

final class LocalBackupArchiveWriteResult {
  const LocalBackupArchiveWriteResult({
    required this.path,
    required this.sizeBytes,
    required this.manifest,
  });

  final String path;
  final int sizeBytes;
  final LocalBackupArchiveManifest manifest;
}

final class LocalBackupArchiveExtractResult {
  const LocalBackupArchiveExtractResult({
    required this.manifest,
    required this.restoreJsonPath,
    this.ownerExportPath,
  });

  final LocalBackupArchiveManifest manifest;
  final String restoreJsonPath;
  final String? ownerExportPath;
}

final class LocalBackupArchiveManifest {
  LocalBackupArchiveManifest({
    required this.createdAt,
    required this.backupFormat,
    required this.backupFormatVersion,
    required this.backupMode,
    required this.includesSecrets,
    required this.localDbSchemaVersion,
    required Map<String, int> recordCounts,
    required List<LocalBackupArchiveEntry> entries,
    this.format = LocalBackupArchiveCodec.formatId,
    this.formatVersion = LocalBackupArchiveCodec.currentFormatVersion,
    this.rootDirectory = LocalBackupArchiveCodec.rootDirectory,
  }) : recordCounts = Map<String, int>.unmodifiable(recordCounts),
       entries = List<LocalBackupArchiveEntry>.unmodifiable(entries) {
    if (format != LocalBackupArchiveCodec.formatId) {
      throw FormatException('Unsupported backup archive format: $format.');
    }
    if (formatVersion > LocalBackupArchiveCodec.currentFormatVersion) {
      throw UnsupportedError(
        'Backup archive format $formatVersion is newer than supported format '
        '${LocalBackupArchiveCodec.currentFormatVersion}.',
      );
    }
    if (rootDirectory != LocalBackupArchiveCodec.rootDirectory) {
      throw FormatException('Unsupported backup archive root: $rootDirectory.');
    }
    if (backupFormat != LocalBackupCodec.formatId) {
      throw FormatException('Unsupported nested backup format: $backupFormat.');
    }
    if (entries.isEmpty) {
      throw const FormatException('Backup archive manifest has no entries.');
    }
    final roles = entries.map((entry) => entry.role).toSet();
    if (!roles.contains('restore_json')) {
      throw const FormatException(
        'Backup archive manifest has no restore JSON entry.',
      );
    }
  }

  factory LocalBackupArchiveManifest.fromJson(JsonMap json) {
    return LocalBackupArchiveManifest(
      format: _requiredString(json, 'format'),
      formatVersion: _requiredInt(json, 'format_version'),
      rootDirectory: _requiredString(json, 'root_directory'),
      createdAt: _requiredDateTime(json, 'created_at'),
      backupFormat: _requiredString(json, 'backup_format'),
      backupFormatVersion: _requiredInt(json, 'backup_format_version'),
      backupMode: LocalBackupMode.fromWireName(
        _requiredString(json, 'backup_mode'),
      ),
      includesSecrets: _requiredBool(json, 'includes_secrets'),
      localDbSchemaVersion: _requiredInt(json, 'local_db_schema_version'),
      recordCounts: _recordCounts(_requiredMap(json, 'record_counts')),
      entries: _requiredList(json, 'entries')
          .map((entry) => LocalBackupArchiveEntry.fromJson(_asJsonMap(entry)))
          .toList(growable: false),
    );
  }

  final String format;
  final int formatVersion;
  final String rootDirectory;
  final DateTime createdAt;
  final String backupFormat;
  final int backupFormatVersion;
  final LocalBackupMode backupMode;
  final bool includesSecrets;
  final int localDbSchemaVersion;
  final Map<String, int> recordCounts;
  final List<LocalBackupArchiveEntry> entries;

  JsonMap toJson() {
    return <String, Object?>{
      'format': format,
      'format_version': formatVersion,
      'root_directory': rootDirectory,
      'created_at': createdAt.toUtc().toIso8601String(),
      'backup_format': backupFormat,
      'backup_format_version': backupFormatVersion,
      'backup_mode': backupMode.wireName,
      'includes_secrets': includesSecrets,
      'local_db_schema_version': localDbSchemaVersion,
      'record_counts': recordCounts,
      'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
    };
  }
}

final class LocalBackupArchiveEntry {
  LocalBackupArchiveEntry({
    required this.path,
    required this.role,
    required this.sizeBytes,
    required this.sha256,
  }) {
    _validateEntryPath(path);
    if (role.isEmpty) {
      throw const FormatException('Backup archive entry role is required.');
    }
    if (sizeBytes < 0) {
      throw const FormatException(
        'Backup archive entry size cannot be negative.',
      );
    }
    if (sha256.length != 64) {
      throw const FormatException('Backup archive entry sha256 is invalid.');
    }
  }

  factory LocalBackupArchiveEntry.fromJson(JsonMap json) {
    return LocalBackupArchiveEntry(
      path: _requiredString(json, 'path'),
      role: _requiredString(json, 'role'),
      sizeBytes: _requiredInt(json, 'size_bytes'),
      sha256: _requiredString(json, 'sha256'),
    );
  }

  final String path;
  final String role;
  final int sizeBytes;
  final String sha256;

  JsonMap toJson() {
    return <String, Object?>{
      'path': path,
      'role': role,
      'size_bytes': sizeBytes,
      'sha256': sha256,
    };
  }
}

LocalBackupArchiveEntry _entryForBytes({
  required String path,
  required String role,
  required List<int> bytes,
}) {
  return LocalBackupArchiveEntry(
    path: path,
    role: role,
    sizeBytes: bytes.length,
    sha256: sha256.convert(bytes).toString(),
  );
}

void _addBytes(ZipFileEncoder encoder, String path, List<int> bytes) {
  encoder.addArchiveFile(ArchiveFile(path, bytes.length, bytes));
}

Future<LocalBackupArchiveManifest> _readManifestFromArchive(
  String archivePath,
) async {
  if (!LocalBackupArchiveCodec.hasArchiveExtension(archivePath)) {
    throw const FormatException('Invalid WideNote backup file extension.');
  }
  final archive = _decodeArchive(archivePath);
  try {
    final manifestFile = _findFile(archive, _archiveManifestPath);
    if (manifestFile == null) {
      throw const FormatException('Missing WideNote backup manifest.');
    }
    return _readManifest(manifestFile);
  } finally {
    archive.clearSync();
  }
}

Archive _decodeArchive(String archivePath) {
  try {
    return ZipDecoder().decodeStream(InputFileStream(archivePath));
  } catch (_) {
    throw const FormatException('Invalid WideNote backup archive.');
  }
}

ArchiveFile? _findFile(Archive archive, String path) {
  for (final file in archive.files) {
    if (file.isFile && file.name == path) {
      return file;
    }
  }
  return null;
}

LocalBackupArchiveManifest _readManifest(ArchiveFile file) {
  try {
    final source = utf8.decode(file.readBytes() ?? const <int>[]);
    return LocalBackupArchiveManifest.fromJson(decodeJsonMap(source));
  } catch (error) {
    if (error is FormatException || error is UnsupportedError) {
      rethrow;
    }
    throw const FormatException('Invalid WideNote backup manifest.');
  }
}

Future<void> _extractArchiveFile(ArchiveFile file, String targetPath) async {
  final targetFile = File(targetPath);
  await targetFile.parent.create(recursive: true);
  final output = OutputFileStream(targetPath);
  try {
    file.writeContent(output);
  } finally {
    output.closeSync();
  }
}

Future<String> _sha256File(String path) async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

String _targetPathForEntry(String stagingDirectory, String archivePath) {
  final relative = _relativeArchivePath(archivePath);
  final segments = relative.split('/');
  var result = stagingDirectory;
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      throw FormatException('Unsafe backup archive path: $archivePath.');
    }
    result = _joinPath(result, segment);
  }
  return result;
}

String _relativeArchivePath(String archivePath) {
  final prefix = '$_archiveRoot/';
  if (!archivePath.startsWith(prefix)) {
    throw FormatException('Unsafe backup archive path: $archivePath.');
  }
  return archivePath.substring(prefix.length);
}

void _validateEntryPath(String path) {
  _relativeArchivePath(path);
  final segments = path.split('/');
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      throw FormatException('Unsafe backup archive path: $path.');
    }
  }
}

String _joinPath(String directory, String child) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$child';
  }
  return '$directory${Platform.pathSeparator}$child';
}

String _requiredString(JsonMap json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Expected non-empty string for $key.');
}

int _requiredInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  throw FormatException('Expected integer for $key.');
}

bool _requiredBool(JsonMap json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected boolean for $key.');
}

DateTime _requiredDateTime(JsonMap json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Expected ISO date for $key.');
  }
  return parsed.toUtc();
}

JsonMap _requiredMap(JsonMap json, String key) {
  return _asJsonMap(json[key]);
}

List<Object?> _requiredList(JsonMap json, String key) {
  final value = json[key];
  if (value is List) {
    return value.cast<Object?>();
  }
  throw FormatException('Expected list for $key.');
}

JsonMap _asJsonMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  throw const FormatException('Expected JSON object.');
}

Map<String, int> _recordCounts(JsonMap json) {
  return json.map((key, value) {
    if (value is! int) {
      throw FormatException('Expected integer count for $key.');
    }
    return MapEntry(key, value);
  });
}
