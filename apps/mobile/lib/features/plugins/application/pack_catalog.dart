import 'package:flutter/foundation.dart';

@immutable
final class BuiltInPackInfo {
  const BuiltInPackInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.status,
    required this.permissions,
    required this.outputEvents,
  });

  final String id;
  final String name;
  final String description;
  final String version;
  final String status;
  final List<String> permissions;
  final List<String> outputEvents;
}

@immutable
final class PermissionInfo {
  const PermissionInfo({
    required this.permission,
    required this.packId,
    required this.risk,
    required this.status,
  });

  final String permission;
  final String packId;
  final String risk;
  final String status;
}

const builtInPacks = <BuiltInPackInfo>[
  BuiltInPackInfo(
    id: 'pack.default',
    name: 'Default Capture Loop',
    description:
        'Creates source-linked Memory proposals, cards, and lightweight insights.',
    version: '0.1.0',
    status: 'enabled',
    permissions: <String>[
      'model.complete',
      'card.write',
      'memory.propose',
      'insight.write',
    ],
    outputEvents: <String>[
      'wn.card.created',
      'wn.memory.proposed',
      'wn.insight.created',
    ],
  ),
  BuiltInPackInfo(
    id: 'pack.todo',
    name: 'Todo Extraction Loop',
    description: 'Creates source-linked todo suggestions from local captures.',
    version: '0.1.0',
    status: 'enabled',
    permissions: <String>['todo.suggest'],
    outputEvents: <String>['wn.todo.suggested'],
  ),
];

const builtInPermissions = <PermissionInfo>[
  PermissionInfo(
    permission: 'model.complete',
    packId: 'pack.default',
    risk: 'medium',
    status: 'granted for built-in pack',
  ),
  PermissionInfo(
    permission: 'memory.propose',
    packId: 'pack.default',
    risk: 'low',
    status: 'granted for built-in pack',
  ),
  PermissionInfo(
    permission: 'card.write',
    packId: 'pack.default',
    risk: 'low',
    status: 'granted for built-in pack',
  ),
  PermissionInfo(
    permission: 'insight.write',
    packId: 'pack.default',
    risk: 'low',
    status: 'granted for built-in pack',
  ),
  PermissionInfo(
    permission: 'todo.suggest',
    packId: 'pack.todo',
    risk: 'low',
    status: 'granted for built-in pack',
  ),
];

const deferredHighRiskPermissions = <PermissionInfo>[
  PermissionInfo(
    permission: 'file.read.broad',
    packId: 'community packs',
    risk: 'high',
    status: 'deferred until sandbox approval',
  ),
  PermissionInfo(
    permission: 'network.call.arbitrary_host',
    packId: 'community packs',
    risk: 'high',
    status: 'deferred until permission ADR',
  ),
  PermissionInfo(
    permission: 'script.execute',
    packId: 'community packs',
    risk: 'high',
    status: 'deferred until sandbox approval',
  ),
  PermissionInfo(
    permission: 'audio.capture.continuous',
    packId: 'media packs',
    risk: 'high',
    status: 'deferred until platform permission slice',
  ),
  PermissionInfo(
    permission: 'location.read.background',
    packId: 'context packs',
    risk: 'high',
    status: 'deferred until privacy decision',
  ),
];
