import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

String? mobileParentPathFor(String location) {
  final path = _normalizeMobilePath(location);
  if (path.startsWith('/settings/traces/raw/')) {
    return '/settings/traces/raw';
  }
  if (path.startsWith('/timeline/cards/')) {
    return '/timeline';
  }
  if (path.startsWith('/timeline/items/')) {
    return '/timeline';
  }
  if (path.startsWith('/insights/')) {
    return '/insights';
  }
  if (path.startsWith('/chat/session/')) {
    return '/chat';
  }
  if (_isTodoDetailPath(path)) {
    return '/todos';
  }
  return _mobileParentPaths[path];
}

void openMobileRouteWithParentStack(
  BuildContext context,
  String targetLocation,
) {
  final stack = mobileRouteStackFor(targetLocation);
  if (stack.isEmpty) {
    return;
  }

  final router = GoRouter.of(context);
  router.go(stack.first);
  for (final path in stack.skip(1)) {
    router.push(path);
  }
}

List<String> mobileRouteStackFor(String location) {
  final targetPath = _normalizeMobilePath(location);
  final reversedStack = <String>[targetPath];
  var parentPath = mobileParentPathFor(targetPath);
  while (parentPath != null) {
    reversedStack.add(parentPath);
    parentPath = mobileParentPathFor(parentPath);
  }
  return reversedStack.reversed.toList(growable: false);
}

String _normalizeMobilePath(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  if (path.length > 1 && path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path.isEmpty ? '/' : path;
}

bool _isTodoDetailPath(String path) {
  if (!path.startsWith('/todos/')) {
    return false;
  }
  return path.substring('/todos/'.length).isNotEmpty;
}

const _mobileParentPaths = <String, String>{
  '/timeline': '/',
  '/timeline/search': '/timeline',
  '/memory': '/',
  '/recap': '/',
  '/insights': '/',
  '/settings': '/',
  '/settings/permissions': '/settings',
  '/settings/system-permissions': '/settings',
  '/settings/model-providers': '/settings',
  '/settings/retrieval': '/settings',
  '/settings/transcription': '/settings',
  '/settings/location': '/settings',
  '/settings/backup': '/settings',
  '/settings/traces': '/settings',
  '/settings/traces/agents': '/settings/traces',
  '/settings/traces/events': '/settings/traces',
  '/settings/traces/raw': '/settings/traces',
  '/settings/debugging': '/settings',
  '/settings/usage-stats': '/settings',
  '/plugins/packs': '/plugins',
};
