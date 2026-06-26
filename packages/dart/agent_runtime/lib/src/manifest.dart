import 'dart:convert';
import 'dart:io';

import 'package:widenote_core/widenote_core.dart';

import 'kernel.dart';
import 'model.dart';
import 'pack.dart';

final class AgentPackManifestBridge {
  const AgentPackManifestBridge();

  AgentPackManifestSnapshot parseJsonString(
    String source, {
    String sourceName = 'manifest',
  }) {
    late final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FormatException(
        'Agent Pack manifest $sourceName is invalid JSON: ${error.message}.',
        error.source,
        error.offset,
      );
    }
    return AgentPackManifestSnapshot.fromJson(_jsonObject(decoded, sourceName));
  }

  AgentPackManifestSnapshot loadFile(String path) {
    final file = File(path);
    try {
      if (!file.existsSync()) {
        throw FormatException('Agent Pack manifest file not found: $path.');
      }
      return parseJsonString(file.readAsStringSync(), sourceName: path);
    } on FileSystemException catch (error) {
      throw FormatException(
        'Agent Pack manifest file could not be read: $path (${error.message}).',
      );
    }
  }

  List<AgentPackManifestSnapshot> loadFiles(Iterable<String> paths) {
    return List<AgentPackManifestSnapshot>.unmodifiable(paths.map(loadFile));
  }

  AgentPack buildNativePack(
    AgentPackManifestSnapshot manifest, {
    required Map<String, AgentHandler> nativeHandlers,
  }) {
    if (manifest.edition != 'official') {
      throw ArgumentError(
        'Local native Agent Pack bridge only accepts official manifests; '
        '${manifest.id} is ${manifest.edition}.',
      );
    }
    _validateNativeBindings(manifest, nativeHandlers);
    return AgentPack(
      id: manifest.id,
      name: manifest.name,
      version: manifest.version,
      requiredPermissions: manifest.requiredPermissions,
      subscriptions: manifest.subscriptions,
      agentDefinitions: manifest.agentDefinitions,
      agents: Map<String, AgentHandler>.unmodifiable(nativeHandlers),
    );
  }

  void registerNativePacks(
    RuntimeKernel kernel, {
    required Iterable<AgentPackManifestSnapshot> manifests,
    required Map<String, Map<String, AgentHandler>> nativeHandlersByPackId,
  }) {
    final packIds = <String>{};
    final packs = <AgentPack>[];
    for (final manifest in manifests) {
      if (!packIds.add(manifest.id)) {
        throw ArgumentError(
          'Duplicate Agent Pack manifest id: ${manifest.id}.',
        );
      }
      final pack = buildNativePack(
        manifest,
        nativeHandlers:
            nativeHandlersByPackId[manifest.id] ??
            const <String, AgentHandler>{},
      );
      final alignment = pack.checkManifestAlignment(manifest);
      if (!alignment.isAligned) {
        throw ArgumentError(
          'Native Agent Pack ${manifest.id} does not align with manifest: '
          '${alignment.issues.map((issue) => issue.path).join(', ')}.',
        );
      }
      packs.add(pack);
    }

    kernel.registerPacks(packs);
  }

  void loadAndRegisterNativePacks(
    RuntimeKernel kernel, {
    required Iterable<String> paths,
    required Map<String, Map<String, AgentHandler>> nativeHandlersByPackId,
  }) {
    final manifests = loadFiles(paths);
    registerNativePacks(
      kernel,
      manifests: manifests,
      nativeHandlersByPackId: nativeHandlersByPackId,
    );
  }
}

JsonMap _jsonObject(Object? value, String sourceName) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, entry) {
        if (key is! String) {
          throw FormatException(
            'Agent Pack manifest $sourceName must be a JSON object with '
            'string keys.',
          );
        }
        return MapEntry<String, Object?>(key, entry);
      }),
    );
  }
  throw FormatException(
    'Agent Pack manifest $sourceName must be a JSON object.',
  );
}

void _validateNativeBindings(
  AgentPackManifestSnapshot manifest,
  Map<String, AgentHandler> nativeHandlers,
) {
  for (final handlerId in nativeHandlers.keys) {
    final definition = manifest.agentDefinitions[handlerId];
    if (definition == null) {
      throw ArgumentError(
        'Native handler $handlerId is not declared by ${manifest.id}.',
      );
    }
    if (definition.runtimeKind != AgentRuntimeKind.native) {
      throw ArgumentError(
        'Native handler $handlerId was provided for ${manifest.id}, but the '
        'manifest runtime is ${definition.runtimeKind.name}.',
      );
    }
  }

  for (final definition in manifest.agentDefinitions.values) {
    if (definition.runtimeKind == AgentRuntimeKind.native &&
        !nativeHandlers.containsKey(definition.id)) {
      throw ArgumentError(
        'Native handler missing for ${manifest.id}/${definition.id}.',
      );
    }
  }
}
