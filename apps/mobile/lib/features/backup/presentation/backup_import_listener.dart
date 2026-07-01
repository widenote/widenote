import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/backup_controller.dart';
import '../application/backup_import_intent_service.dart';

class BackupImportListener extends ConsumerStatefulWidget {
  const BackupImportListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BackupImportListener> createState() =>
      _BackupImportListenerState();
}

class _BackupImportListenerState extends ConsumerState<BackupImportListener> {
  final Set<String> _handledPaths = <String>{};
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeInitialPath());
    });
    _subscription = ref
        .read(backupImportIntentServiceProvider)
        .backupPathStream
        .listen(_handlePath);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  Future<void> _consumeInitialPath() async {
    final path = await ref
        .read(backupImportIntentServiceProvider)
        .consumeInitialBackupPath();
    if (path != null) {
      await _handlePath(path);
    }
  }

  Future<void> _handlePath(String path) async {
    if (!_handledPaths.add(path)) {
      return;
    }
    await ref
        .read(backupControllerProvider.notifier)
        .loadArchivePathForImport(path);
    if (mounted) {
      context.go('/settings/backup');
    }
  }
}
