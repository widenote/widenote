import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../application/system_permissions_controller.dart';

class SystemPermissionsPage extends ConsumerStatefulWidget {
  const SystemPermissionsPage({super.key});

  @override
  ConsumerState<SystemPermissionsPage> createState() =>
      _SystemPermissionsPageState();
}

class _SystemPermissionsPageState extends ConsumerState<SystemPermissionsPage> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        ref.read(systemPermissionsControllerProvider.notifier).refresh();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final permissions = ref.watch(systemPermissionsControllerProvider);
    return ListView(
      key: const Key('system-permissions-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        _PageHeader(
          title: l10n.systemPermissionsTitle,
          subtitle: l10n.systemPermissionsSubtitle,
        ),
        const SizedBox(height: 16),
        permissions.when(
          data: (state) => _SystemPermissionsBody(state: state),
          loading: () => _LoadingSurface(label: l10n.systemPermissionsLoading),
          error: (error, stackTrace) => _ErrorSurface(
            message: l10n.systemPermissionsError,
            onRetry: () {
              ref.read(systemPermissionsControllerProvider.notifier).refresh();
            },
          ),
        ),
      ],
    );
  }
}

class _SystemPermissionsBody extends ConsumerWidget {
  const _SystemPermissionsBody({required this.state});

  final SystemPermissionsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Surface(
          icon: Icons.privacy_tip_outlined,
          title: l10n.systemPermissionsSummaryTitle,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(
                  l10n.systemPermissionsSummary(
                    state.grantedCount,
                    state.reviewCount,
                  ),
                ),
              ),
              Chip(label: Text(_platformLabel(l10n, state.platform))),
              OutlinedButton.icon(
                key: const Key('system-permissions-refresh-button'),
                onPressed: state.isRefreshing
                    ? null
                    : () {
                        ref
                            .read(systemPermissionsControllerProvider.notifier)
                            .refresh();
                      },
                icon: state.isRefreshing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(l10n.systemPermissionsRefreshAction),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Surface(
          icon: Icons.app_settings_alt_outlined,
          title: l10n.systemPermissionsDeviceAccessTitle,
          child: Column(
            children: [
              for (var index = 0; index < state.items.length; index++) ...[
                _PermissionRow(item: state.items[index]),
                if (index != state.items.length - 1) const Divider(height: 20),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _platformLabel(
    AppLocalizations l10n,
    SystemPermissionPlatform platform,
  ) {
    return switch (platform) {
      SystemPermissionPlatform.android => l10n.systemPermissionsPlatformAndroid,
      SystemPermissionPlatform.ios => l10n.systemPermissionsPlatformIos,
      SystemPermissionPlatform.other => l10n.systemPermissionsPlatformOther,
    };
  }
}

class _PermissionRow extends ConsumerWidget {
  const _PermissionRow({required this.item});

  final SystemPermissionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final actionLabel = _actionLabel(l10n, item);
    return Row(
      key: Key('system-permission-row-${item.kind.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_iconFor(item.kind), color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titleFor(l10n, item.kind),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitleFor(l10n, item.kind, item.status),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_showLocationServiceWarning(item)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_disabled_outlined,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.systemPermissionsLocationServiceOffBody,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 104),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(_statusLabel(l10n, item)),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonal(
                  key: Key('system-permission-action-${item.kind.name}'),
                  onPressed: () {
                    ref
                        .read(systemPermissionsControllerProvider.notifier)
                        .activate(item.kind);
                  },
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _showLocationServiceWarning(SystemPermissionItem item) {
    return item.kind == SystemPermissionKind.location &&
        item.serviceStatus == SystemPermissionServiceStatus.disabled;
  }

  String? _actionLabel(AppLocalizations l10n, SystemPermissionItem item) {
    return switch (item.action) {
      SystemPermissionAction.request => l10n.systemPermissionsActionRequest,
      SystemPermissionAction.openAppSettings
          when item.status == SystemPermissionStatus.granted ||
              item.status == SystemPermissionStatus.limited =>
        l10n.systemPermissionsActionManage,
      SystemPermissionAction.openAppSettings ||
      SystemPermissionAction.openLocationSettings =>
        l10n.systemPermissionsActionOpenSettings,
      SystemPermissionAction.none => null,
    };
  }

  String _statusLabel(AppLocalizations l10n, SystemPermissionItem item) {
    if (_showLocationServiceWarning(item)) {
      return l10n.systemPermissionsStatusServiceOff;
    }
    return switch (item.status) {
      SystemPermissionStatus.granted => l10n.systemPermissionsStatusGranted,
      SystemPermissionStatus.limited => l10n.systemPermissionsStatusLimited,
      SystemPermissionStatus.denied => l10n.systemPermissionsStatusDenied,
      SystemPermissionStatus.permanentlyDenied =>
        l10n.systemPermissionsStatusPermanentlyDenied,
      SystemPermissionStatus.restricted =>
        l10n.systemPermissionsStatusRestricted,
      SystemPermissionStatus.notRequired =>
        l10n.systemPermissionsStatusNotRequired,
      SystemPermissionStatus.notConfigured =>
        l10n.systemPermissionsStatusNotConfigured,
      SystemPermissionStatus.notSupported =>
        l10n.systemPermissionsStatusNotSupported,
      SystemPermissionStatus.unknown => l10n.systemPermissionsStatusUnknown,
    };
  }

  String _titleFor(AppLocalizations l10n, SystemPermissionKind kind) {
    return switch (kind) {
      SystemPermissionKind.camera => l10n.systemPermissionsCameraTitle,
      SystemPermissionKind.microphone => l10n.systemPermissionsMicrophoneTitle,
      SystemPermissionKind.location => l10n.systemPermissionsLocationTitle,
      SystemPermissionKind.photos => l10n.systemPermissionsPhotosTitle,
      SystemPermissionKind.files => l10n.systemPermissionsFilesTitle,
      SystemPermissionKind.calendar => l10n.systemPermissionsCalendarTitle,
    };
  }

  String _subtitleFor(
    AppLocalizations l10n,
    SystemPermissionKind kind,
    SystemPermissionStatus status,
  ) {
    if (kind == SystemPermissionKind.photos &&
        status == SystemPermissionStatus.notRequired) {
      return l10n.systemPermissionsPhotosAndroidSubtitle;
    }
    return switch (kind) {
      SystemPermissionKind.camera => l10n.systemPermissionsCameraSubtitle,
      SystemPermissionKind.microphone =>
        l10n.systemPermissionsMicrophoneSubtitle,
      SystemPermissionKind.location => l10n.systemPermissionsLocationSubtitle,
      SystemPermissionKind.photos => l10n.systemPermissionsPhotosSubtitle,
      SystemPermissionKind.files => l10n.systemPermissionsFilesSubtitle,
      SystemPermissionKind.calendar => l10n.systemPermissionsCalendarSubtitle,
    };
  }

  IconData _iconFor(SystemPermissionKind kind) {
    return switch (kind) {
      SystemPermissionKind.camera => Icons.photo_camera_outlined,
      SystemPermissionKind.microphone => Icons.mic_none_outlined,
      SystemPermissionKind.location => Icons.my_location_outlined,
      SystemPermissionKind.photos => Icons.photo_library_outlined,
      SystemPermissionKind.files => Icons.folder_open_outlined,
      SystemPermissionKind.calendar => Icons.calendar_month_outlined,
    };
  }
}

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: Icons.hourglass_empty_outlined,
      title: label,
      child: const LinearProgressIndicator(),
    );
  }
}

class _ErrorSurface extends StatelessWidget {
  const _ErrorSurface({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.error_outline,
      title: message,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.systemPermissionsRefreshAction),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.outlined(
          key: const Key('system-permissions-close-button'),
          tooltip: l10n.systemPermissionsBackTooltip,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
