import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'backup_archive.dart';
import 'backup_export.dart';

const _directoryArchiveRoot = 'widenote-backup';
const _directoryManifestPath = '$_directoryArchiveRoot/manifest.properties';
const _directoryDatabasePath = '$_directoryArchiveRoot/data/widenote.sqlite';
const _directoryMediaPrefix = '$_directoryArchiveRoot/media/capture_media/';

abstract final class LocalBackupDirectoryArchiveCodec {
  static const formatId = 'widenote.directory_backup';
  static const currentFormatVersion = 1;
  static const fileExtension = LocalBackupArchiveCodec.fileExtension;
  static const mimeType = LocalBackupArchiveCodec.mimeType;
  static const typeIdentifier = LocalBackupArchiveCodec.typeIdentifier;

  static const rootDirectory = _directoryArchiveRoot;
  static const manifestPath = _directoryManifestPath;
  static const databasePath = _directoryDatabasePath;
  static const mediaPrefix = _directoryMediaPrefix;

  static bool hasArchiveExtension(String path) {
    return path.toLowerCase().endsWith(fileExtension);
  }

  static Future<LocalBackupDirectoryArchiveWriteResult> writeArchive({
    required String sourceDirectory,
    required String outputPath,
    required DateTime createdAt,
    required int localDbSchemaVersion,
    required Map<String, int> recordCounts,
    LocalBackupMode backupMode = LocalBackupMode.full,
    bool includesSecrets = true,
  }) async {
    if (!hasArchiveExtension(outputPath)) {
      throw const FormatException('WideNote backups must use .widenote files.');
    }
    if (backupMode == LocalBackupMode.safe && includesSecrets) {
      throw const FormatException(
        'Safe directory backups cannot include secrets.',
      );
    }
    if (backupMode == LocalBackupMode.full && !includesSecrets) {
      throw const FormatException(
        'Full directory backups must declare included secrets.',
      );
    }
    if (backupMode == LocalBackupMode.encryptedFull) {
      throw const FormatException(
        'Directory backups do not implement encrypted full mode.',
      );
    }

    final source = Directory(sourceDirectory);
    if (!await source.exists()) {
      throw FileSystemException(
        'Backup source directory does not exist.',
        sourceDirectory,
      );
    }
    final files = await _sourceFiles(source);
    if (!files.any(
      (file) => _archivePathFor(source.path, file.path) == databasePath,
    )) {
      throw const FormatException(
        'Directory backup source has no SQLite snapshot.',
      );
    }

    final entries = <LocalBackupDirectoryArchiveEntry>[];
    for (final file in files) {
      final archivePath = _archivePathFor(source.path, file.path);
      entries.add(
        LocalBackupDirectoryArchiveEntry(
          path: archivePath,
          role: _roleForArchivePath(archivePath),
          sizeBytes: await file.length(),
          sha256: await _sha256File(file.path),
        ),
      );
    }
    final manifest = LocalBackupDirectoryArchiveManifest(
      createdAt: createdAt,
      backupMode: backupMode,
      includesSecrets: includesSecrets,
      localDbSchemaVersion: localDbSchemaVersion,
      recordCounts: recordCounts,
      entries: entries,
    );
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    final tempPath = '$outputPath.tmp';
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final encoder = ZipFileEncoder();
    try {
      encoder.create(tempPath, level: ZipFileEncoder.gzip);
      for (final file in files) {
        await encoder.addFile(file, _archivePathFor(source.path, file.path));
      }
      _addBytes(encoder, manifestPath, utf8.encode(manifest.toProperties()));
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

    return LocalBackupDirectoryArchiveWriteResult(
      path: outputPath,
      sizeBytes: await outputFile.length(),
      manifest: manifest,
    );
  }

  static Future<LocalBackupDirectoryArchiveExtractResult> extractToDirectory({
    required String archivePath,
    required String stagingDirectory,
  }) async {
    if (!hasArchiveExtension(archivePath)) {
      throw const FormatException('Invalid WideNote backup file extension.');
    }

    final archive = _decodeArchive(archivePath);
    try {
      final manifestFile = _findFile(archive, manifestPath);
      if (manifestFile == null) {
        throw const FormatException(
          'Missing WideNote directory backup manifest.',
        );
      }
      final manifest = _readManifest(manifestFile);
      final expected = <String, LocalBackupDirectoryArchiveEntry>{
        for (final entry in manifest.entries) entry.path: entry,
      };
      final verified = <String>{};
      final mediaFiles = <LocalBackupDirectoryArchiveExtractedFile>[];
      var extractedDatabasePath = '';

      final staging = Directory(stagingDirectory);
      await staging.create(recursive: true);

      for (final file in archive) {
        if (!file.isFile) {
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
        if (entry.role == LocalBackupDirectoryArchiveEntry.sqliteDatabaseRole) {
          extractedDatabasePath = targetPath;
        } else if (entry.role ==
            LocalBackupDirectoryArchiveEntry.attachmentMediaRole) {
          mediaFiles.add(
            LocalBackupDirectoryArchiveExtractedFile(
              archivePath: entry.path,
              path: targetPath,
              role: entry.role,
            ),
          );
        }
      }

      for (final entry in manifest.entries) {
        if (!verified.contains(entry.path)) {
          throw FormatException('Backup archive is missing ${entry.path}.');
        }
      }
      if (extractedDatabasePath.isEmpty) {
        throw const FormatException('Backup archive has no SQLite snapshot.');
      }

      return LocalBackupDirectoryArchiveExtractResult(
        manifest: manifest,
        databasePath: extractedDatabasePath,
        mediaFiles: mediaFiles,
      );
    } finally {
      archive.clearSync();
    }
  }

  static Future<LocalBackupDirectoryArchiveManifest> readManifest(
    String archivePath,
  ) async {
    if (!hasArchiveExtension(archivePath)) {
      throw const FormatException('Invalid WideNote backup file extension.');
    }
    final archive = _decodeArchive(archivePath);
    try {
      final manifestFile = _findFile(archive, manifestPath);
      if (manifestFile == null) {
        throw const FormatException(
          'Missing WideNote directory backup manifest.',
        );
      }
      return _readManifest(manifestFile);
    } finally {
      archive.clearSync();
    }
  }
}

abstract final class LocalBackupDatabaseSnapshotter {
  static Future<void> writeFullSnapshot({
    required String sourceDatabasePath,
    required String outputDatabasePath,
  }) async {
    final source = File(sourceDatabasePath);
    if (!await source.exists()) {
      throw FileSystemException(
        'WideNote database file does not exist.',
        sourceDatabasePath,
      );
    }
    final output = File(outputDatabasePath);
    await output.parent.create(recursive: true);
    if (await output.exists()) {
      await output.delete();
    }

    final sourceDatabase = sqlite.sqlite3.open(sourceDatabasePath);
    try {
      sourceDatabase.execute('PRAGMA busy_timeout = 5000;');
      sourceDatabase.execute(
        'VACUUM INTO ${_sqliteString(outputDatabasePath)};',
      );
    } finally {
      sourceDatabase.dispose();
    }

    final snapshotDatabase = sqlite.sqlite3.open(outputDatabasePath);
    try {
      final foreignKeyErrors = snapshotDatabase.select(
        'PRAGMA foreign_key_check;',
      );
      if (foreignKeyErrors.isNotEmpty) {
        throw StateError(
          'Backup snapshot failed foreign key validation '
          'for ${foreignKeyErrors.length} row(s).',
        );
      }
    } finally {
      snapshotDatabase.dispose();
    }
  }
}

final class LocalBackupDirectoryArchiveWriteResult {
  const LocalBackupDirectoryArchiveWriteResult({
    required this.path,
    required this.sizeBytes,
    required this.manifest,
  });

  final String path;
  final int sizeBytes;
  final LocalBackupDirectoryArchiveManifest manifest;
}

final class LocalBackupDirectoryArchiveExtractResult {
  const LocalBackupDirectoryArchiveExtractResult({
    required this.manifest,
    required this.databasePath,
    this.mediaFiles = const <LocalBackupDirectoryArchiveExtractedFile>[],
  });

  final LocalBackupDirectoryArchiveManifest manifest;
  final String databasePath;
  final List<LocalBackupDirectoryArchiveExtractedFile> mediaFiles;
}

final class LocalBackupDirectoryArchiveExtractedFile {
  const LocalBackupDirectoryArchiveExtractedFile({
    required this.archivePath,
    required this.path,
    required this.role,
  });

  final String archivePath;
  final String path;
  final String role;
}

final class LocalBackupDirectoryArchiveManifest {
  LocalBackupDirectoryArchiveManifest({
    required this.createdAt,
    required this.backupMode,
    required this.includesSecrets,
    required this.localDbSchemaVersion,
    required Map<String, int> recordCounts,
    required List<LocalBackupDirectoryArchiveEntry> entries,
    this.format = LocalBackupDirectoryArchiveCodec.formatId,
    this.formatVersion = LocalBackupDirectoryArchiveCodec.currentFormatVersion,
    this.rootDirectory = LocalBackupDirectoryArchiveCodec.rootDirectory,
  }) : recordCounts = Map<String, int>.unmodifiable(recordCounts),
       entries = List<LocalBackupDirectoryArchiveEntry>.unmodifiable(entries) {
    if (format != LocalBackupDirectoryArchiveCodec.formatId) {
      throw FormatException('Unsupported backup archive format: $format.');
    }
    if (formatVersion > LocalBackupDirectoryArchiveCodec.currentFormatVersion) {
      throw UnsupportedError(
        'Backup archive format $formatVersion is newer than supported format '
        '${LocalBackupDirectoryArchiveCodec.currentFormatVersion}.',
      );
    }
    if (rootDirectory != LocalBackupDirectoryArchiveCodec.rootDirectory) {
      throw FormatException('Unsupported backup archive root: $rootDirectory.');
    }
    if (backupMode == LocalBackupMode.safe && includesSecrets) {
      throw const FormatException(
        'Safe directory backups cannot include secrets.',
      );
    }
    if (backupMode == LocalBackupMode.full && !includesSecrets) {
      throw const FormatException(
        'Full directory backups must declare included secrets.',
      );
    }
    if (backupMode == LocalBackupMode.encryptedFull) {
      throw const FormatException(
        'Directory backup manifests cannot use encrypted full mode.',
      );
    }
    if (entries.isEmpty) {
      throw const FormatException('Backup archive manifest has no entries.');
    }
    final roles = entries.map((entry) => entry.role).toSet();
    if (!roles.contains(LocalBackupDirectoryArchiveEntry.sqliteDatabaseRole)) {
      throw const FormatException(
        'Backup archive manifest has no SQLite snapshot.',
      );
    }
  }

  factory LocalBackupDirectoryArchiveManifest.fromProperties(String source) {
    final props = _parseProperties(source);
    final entryCount = _requiredInt(props, 'entries.count');
    final entries = <LocalBackupDirectoryArchiveEntry>[];
    for (var index = 0; index < entryCount; index += 1) {
      entries.add(
        LocalBackupDirectoryArchiveEntry(
          path: _requiredString(props, 'entries.$index.path'),
          role: _requiredString(props, 'entries.$index.role'),
          sizeBytes: _requiredInt(props, 'entries.$index.size_bytes'),
          sha256: _requiredString(props, 'entries.$index.sha256'),
        ),
      );
    }

    final recordCountCount = _requiredInt(props, 'record_counts.count');
    final recordCounts = <String, int>{};
    for (var index = 0; index < recordCountCount; index += 1) {
      recordCounts[_requiredString(props, 'record_counts.$index.section')] =
          _requiredInt(props, 'record_counts.$index.count');
    }

    return LocalBackupDirectoryArchiveManifest(
      format: _requiredString(props, 'format'),
      formatVersion: _requiredInt(props, 'format_version'),
      rootDirectory: _requiredString(props, 'root_directory'),
      createdAt: _requiredDateTime(props, 'created_at'),
      backupMode: LocalBackupMode.fromWireName(
        _requiredString(props, 'backup_mode'),
      ),
      includesSecrets: _requiredBool(props, 'includes_secrets'),
      localDbSchemaVersion: _requiredInt(props, 'local_db_schema_version'),
      recordCounts: recordCounts,
      entries: entries,
    );
  }

  final String format;
  final int formatVersion;
  final String rootDirectory;
  final DateTime createdAt;
  final LocalBackupMode backupMode;
  final bool includesSecrets;
  final int localDbSchemaVersion;
  final Map<String, int> recordCounts;
  final List<LocalBackupDirectoryArchiveEntry> entries;

  LocalBackupDirectoryArchiveManifest copyWithEntries(
    List<LocalBackupDirectoryArchiveEntry> entries,
  ) {
    return LocalBackupDirectoryArchiveManifest(
      format: format,
      formatVersion: formatVersion,
      rootDirectory: rootDirectory,
      createdAt: createdAt,
      backupMode: backupMode,
      includesSecrets: includesSecrets,
      localDbSchemaVersion: localDbSchemaVersion,
      recordCounts: recordCounts,
      entries: entries,
    );
  }

  String toProperties() {
    final lines = <String>[
      _property('format', format),
      _property('format_version', '$formatVersion'),
      _property('root_directory', rootDirectory),
      _property('created_at', createdAt.toUtc().toIso8601String()),
      _property('backup_mode', backupMode.wireName),
      _property('includes_secrets', '$includesSecrets'),
      _property('local_db_schema_version', '$localDbSchemaVersion'),
      _property('record_counts.count', '${recordCounts.length}'),
    ];
    var recordIndex = 0;
    for (final recordCount
        in recordCounts.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))) {
      lines
        ..add(_property('record_counts.$recordIndex.section', recordCount.key))
        ..add(
          _property('record_counts.$recordIndex.count', '${recordCount.value}'),
        );
      recordIndex += 1;
    }
    lines.add(_property('entries.count', '${entries.length}'));
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      lines
        ..add(_property('entries.$index.path', entry.path))
        ..add(_property('entries.$index.role', entry.role))
        ..add(_property('entries.$index.size_bytes', '${entry.sizeBytes}'))
        ..add(_property('entries.$index.sha256', entry.sha256));
    }
    return '${lines.join('\n')}\n';
  }
}

final class LocalBackupDirectoryArchiveEntry {
  LocalBackupDirectoryArchiveEntry({
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

  static const manifestRole = 'archive_manifest';
  static const sqliteDatabaseRole = 'sqlite_database';
  static const attachmentMediaRole = 'attachment_media';
  static const supportFileRole = 'support_file';

  final String path;
  final String role;
  final int sizeBytes;
  final String sha256;
}

Future<List<File>> _sourceFiles(Directory source) async {
  final files = <File>[];
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      files.add(entity);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

String _archivePathFor(String sourceDirectory, String filePath) {
  final source = Directory(sourceDirectory).absolute.path;
  final file = File(filePath).absolute.path;
  final prefix = source.endsWith(Platform.pathSeparator)
      ? source
      : '$source${Platform.pathSeparator}';
  if (!file.startsWith(prefix)) {
    throw FormatException(
      'Backup file is outside source directory: $filePath.',
    );
  }
  final relative = file
      .substring(prefix.length)
      .split(Platform.pathSeparator)
      .join('/');
  if (relative.isEmpty) {
    throw FormatException('Backup file has no relative path: $filePath.');
  }
  final archivePath = '$rootPrefix$relative';
  _validateEntryPath(archivePath);
  return archivePath;
}

String get rootPrefix => '${LocalBackupDirectoryArchiveCodec.rootDirectory}/';

String _roleForArchivePath(String archivePath) {
  if (archivePath == LocalBackupDirectoryArchiveCodec.databasePath) {
    return LocalBackupDirectoryArchiveEntry.sqliteDatabaseRole;
  }
  if (archivePath.startsWith(LocalBackupDirectoryArchiveCodec.mediaPrefix)) {
    return LocalBackupDirectoryArchiveEntry.attachmentMediaRole;
  }
  if (archivePath == LocalBackupDirectoryArchiveCodec.manifestPath) {
    return LocalBackupDirectoryArchiveEntry.manifestRole;
  }
  return LocalBackupDirectoryArchiveEntry.supportFileRole;
}

void _addBytes(ZipFileEncoder encoder, String path, List<int> bytes) {
  encoder.addArchiveFile(ArchiveFile(path, bytes.length, bytes));
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

LocalBackupDirectoryArchiveManifest _readManifest(ArchiveFile file) {
  try {
    final source = utf8.decode(file.readBytes() ?? const <int>[]);
    return LocalBackupDirectoryArchiveManifest.fromProperties(source);
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
  if (!archivePath.startsWith(rootPrefix)) {
    throw FormatException('Unsafe backup archive path: $archivePath.');
  }
  return archivePath.substring(rootPrefix.length);
}

void _validateEntryPath(String path) {
  _relativeArchivePath(path);
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.json') || lowerPath.endsWith('.md')) {
    throw FormatException(
      'Directory backups cannot contain JSON or Markdown: $path.',
    );
  }
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

String _property(String key, String value) {
  return '$key=${Uri.encodeComponent(value)}';
}

Map<String, String> _parseProperties(String source) {
  final result = <String, String>{};
  for (final rawLine in const LineSplitter().convert(source)) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final separator = line.indexOf('=');
    if (separator <= 0) {
      throw const FormatException('Invalid backup manifest property line.');
    }
    result[line.substring(0, separator)] = Uri.decodeComponent(
      line.substring(separator + 1),
    );
  }
  return result;
}

String _requiredString(Map<String, String> props, String key) {
  final value = props[key];
  if (value != null && value.isNotEmpty) {
    return value;
  }
  throw FormatException('Expected non-empty backup manifest field $key.');
}

int _requiredInt(Map<String, String> props, String key) {
  final value = int.tryParse(_requiredString(props, key));
  if (value != null) {
    return value;
  }
  throw FormatException('Expected integer backup manifest field $key.');
}

bool _requiredBool(Map<String, String> props, String key) {
  final value = _requiredString(props, key);
  if (value == 'true') {
    return true;
  }
  if (value == 'false') {
    return false;
  }
  throw FormatException('Expected boolean backup manifest field $key.');
}

DateTime _requiredDateTime(Map<String, String> props, String key) {
  final parsed = DateTime.tryParse(_requiredString(props, key));
  if (parsed == null) {
    throw FormatException('Expected ISO date backup manifest field $key.');
  }
  return parsed.toUtc();
}

String _sqliteString(String value) {
  return "'${value.replaceAll("'", "''")}'";
}
