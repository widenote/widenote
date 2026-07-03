import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../backup/application/backup_controller.dart';
import '../../location/application/location_settings_controller.dart';
import '../../location/domain/location_context.dart';
import '../../model_providers/application/model_provider_settings_controller.dart';
import '../../plugins/application/pack_catalog.dart';
import '../../traces/application/trace_console_controller.dart';
import '../../transcription/transcription_service.dart';
import '../../transcription/transcription_settings.dart';
import '../application/debugging_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('settings-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        _PageHeader(title: l10n.settingsTitle, subtitle: l10n.settingsSubtitle),
        const SizedBox(height: 16),
        const _PrivacySurface(),
        const SizedBox(height: 16),
        const _ControlSurface(),
      ],
    );
  }
}

class _PrivacySurface extends StatelessWidget {
  const _PrivacySurface();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.shield_outlined,
      title: l10n.settingsPrivacyTitle,
      child: Column(
        children: [
          _StatusRow(
            icon: Icons.phone_iphone_outlined,
            title: l10n.settingsPrivacyLocalFirstTitle,
            subtitle: l10n.settingsPrivacyLocalFirstBody,
            status: l10n.settingsPrivacyLocalFirstStatus,
          ),
          const Divider(height: 20),
          _StatusRow(
            icon: Icons.verified_user_outlined,
            title: l10n.settingsPrivacyPermissionsTitle,
            subtitle: l10n.settingsPrivacyPermissionsBody,
            status: l10n.settingsPrivacyPermissionsStatus,
          ),
          const Divider(height: 20),
          _StatusRow(
            icon: Icons.lock_outline,
            title: l10n.settingsPrivacyBackupTitle,
            subtitle: l10n.settingsPrivacyBackupBody,
            status: l10n.settingsPrivacyBackupStatus,
          ),
        ],
      ),
    );
  }
}

class _ControlSurface extends ConsumerWidget {
  const _ControlSurface();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final providerState = ref
        .watch(modelProviderSettingsControllerProvider)
        .valueOrNull;
    final voiceSettings = ref
        .watch(voiceTranscriptionSettingsControllerProvider)
        .valueOrNull;
    final locationSettings = ref
        .watch(locationSettingsControllerProvider)
        .valueOrNull
        ?.settings;
    final backupState = ref.watch(backupControllerProvider);
    final traceSnapshot = ref.watch(traceConsoleControllerProvider);
    final debuggingState = ref.watch(debuggingControllerProvider).valueOrNull;
    final packState = ref.watch(packLibraryControllerProvider);
    final permissionState = ref.watch(permissionGateControllerProvider);
    final packSettingsRows = _packSettingsRows(
      context,
      l10n,
      packState.packs,
      permissionState,
    );
    return _Surface(
      icon: Icons.tune_outlined,
      title: l10n.settingsControlsTitle,
      child: Column(
        children: [
          _ControlRow(
            key: const Key('settings-permissions-entry'),
            icon: Icons.admin_panel_settings_outlined,
            title: l10n.settingsPermissionsTitle,
            subtitle: l10n.settingsPermissionsSubtitle,
            status: l10n.settingsPermissionsStatusSummary(
              builtInPermissions.length,
              deferredHighRiskPermissions.length,
            ),
            onTap: () => context.push('/settings/permissions'),
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('settings-system-permissions-entry'),
            icon: Icons.app_settings_alt_outlined,
            title: l10n.settingsSystemPermissionsTitle,
            subtitle: l10n.settingsSystemPermissionsSubtitle,
            status: l10n.settingsSystemPermissionsStatus,
            onTap: () => context.push('/settings/system-permissions'),
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('settings-model-providers-entry'),
            icon: Icons.memory_outlined,
            title: l10n.settingsModelProvidersTitle,
            subtitle: l10n.settingsModelProvidersSubtitle,
            status: _providerStatus(l10n, providerState),
            onTap: () => context.push('/settings/model-providers'),
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('settings-transcription-entry'),
            icon: Icons.graphic_eq_outlined,
            title: l10n.settingsTranscriptionTitle,
            subtitle: l10n.settingsTranscriptionSubtitle,
            status: _transcriptionStatus(l10n, voiceSettings),
            onTap: () => context.push('/settings/transcription'),
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('settings-location-entry'),
            icon: Icons.my_location_outlined,
            title: l10n.settingsLocationTitle,
            subtitle: l10n.settingsLocationSubtitle,
            status: _locationStatus(l10n, locationSettings),
            onTap: () => context.push('/settings/location'),
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('settings-backup-entry'),
            icon: Icons.backup_outlined,
            title: l10n.settingsBackupTitle,
            subtitle: l10n.settingsBackupSubtitle,
            status: _backupStatus(l10n, backupState),
            onTap: () => context.push('/settings/backup'),
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('settings-trace-console-entry'),
            icon: Icons.account_tree_outlined,
            title: l10n.settingsTraceConsoleTitle,
            subtitle: l10n.settingsTraceConsoleSubtitle,
            status: l10n.settingsTraceConsoleStatusSummary(
              traceSnapshot.items.length,
              traceSnapshot.warningCount,
            ),
            onTap: () => context.push('/settings/traces'),
          ),
          const Divider(height: 20),
          _ControlRow(
            key: const Key('settings-debugging-entry'),
            icon: Icons.bug_report_outlined,
            title: l10n.settingsDebuggingTitle,
            subtitle: l10n.settingsDebuggingSubtitle,
            status: _debuggingStatus(l10n, debuggingState),
            onTap: () => context.push('/settings/debugging'),
          ),
          if (packSettingsRows.isNotEmpty) ...[
            const Divider(height: 20),
            ...packSettingsRows,
          ],
        ],
      ),
    );
  }

  List<Widget> _packSettingsRows(
    BuildContext context,
    AppLocalizations l10n,
    List<PackLibraryPack> packs,
    PermissionGateState permissionState,
  ) {
    final rows = <Widget>[];
    for (final pack in packs) {
      for (final contribution in pack.uiContributions) {
        if (!contribution.isSettingsContribution) {
          continue;
        }
        final missingPermissions = _missingContributionPermissions(
          pack,
          contribution,
          permissionState,
        );
        if (rows.isNotEmpty) {
          rows.add(const Divider(height: 20));
        }
        rows.add(
          _ControlRow(
            key: Key('settings-ui-contribution-${pack.id}-${contribution.id}'),
            icon: Icons.extension_outlined,
            title: _packSettingsContributionTitle(l10n, pack, contribution),
            subtitle: _packSettingsContributionSubtitle(
              l10n,
              pack,
              contribution,
            ),
            status: _packSettingsContributionStatus(
              l10n,
              pack,
              missingPermissions,
            ),
            onTap: _packSettingsContributionTap(
              context,
              pack,
              contribution,
              missingPermissions,
            ),
          ),
        );
      }
    }
    return rows;
  }

  List<String> _missingContributionPermissions(
    PackLibraryPack pack,
    PackUiContribution contribution,
    PermissionGateState permissionState,
  ) {
    if (!pack.isEnabled) {
      return contribution.requiredPermissions;
    }
    return contribution.requiredPermissions
        .where((permission) => !permissionState.isGranted(pack.id, permission))
        .toList(growable: false);
  }

  String _packSettingsContributionStatus(
    AppLocalizations l10n,
    PackLibraryPack pack,
    List<String> missingPermissions,
  ) {
    if (!pack.isEnabled) {
      return l10n.packLibraryStatusDisabled;
    }
    if (missingPermissions.isNotEmpty) {
      return l10n.settingsPackUiContributionPermissionRequired(
        missingPermissions.length,
      );
    }
    return l10n.packLibraryStatusEnabled;
  }

  String _packSettingsContributionTitle(
    AppLocalizations l10n,
    PackLibraryPack pack,
    PackUiContribution contribution,
  ) {
    if (_isUsageStatsContribution(pack, contribution)) {
      return l10n.usageStatsTitle;
    }
    return contribution.title;
  }

  String _packSettingsContributionSubtitle(
    AppLocalizations l10n,
    PackLibraryPack pack,
    PackUiContribution contribution,
  ) {
    if (_isUsageStatsContribution(pack, contribution)) {
      return l10n.usageStatsSettingsSubtitle;
    }
    return l10n.settingsPackUiContributionSubtitle(
      pack.name,
      contribution.description.isEmpty
          ? contribution.surface
          : contribution.description,
    );
  }

  VoidCallback? _packSettingsContributionTap(
    BuildContext context,
    PackLibraryPack pack,
    PackUiContribution contribution,
    List<String> missingPermissions,
  ) {
    if (!pack.isEnabled) {
      return null;
    }
    if (missingPermissions.isNotEmpty) {
      return () => context.push('/settings/permissions');
    }
    final route = _packSettingsContributionRoute(pack, contribution);
    return () => context.push(route ?? '/plugins/packs');
  }

  String? _packSettingsContributionRoute(
    PackLibraryPack pack,
    PackUiContribution contribution,
  ) {
    if (_isUsageStatsContribution(pack, contribution)) {
      return '/settings/usage-stats';
    }
    return null;
  }

  bool _isUsageStatsContribution(
    PackLibraryPack pack,
    PackUiContribution contribution,
  ) {
    return pack.id == 'pack.usage_stats' &&
        contribution.id == 'settings.usage_stats.dashboard';
  }

  String _backupStatus(AppLocalizations l10n, BackupState state) {
    return switch (state.outcome) {
      BackupOutcome.exported ||
      BackupOutcome.savedFile => l10n.settingsBackupStatusExportReady,
      BackupOutcome.importReady => l10n.settingsBackupStatusNeedsReview,
      BackupOutcome.imported => l10n.settingsBackupStatusRestored,
      BackupOutcome.failed => l10n.settingsBackupStatusNeedsReview,
      BackupOutcome.idle => l10n.settingsBackupStatusSafeOnly,
    };
  }

  String _providerStatus(
    AppLocalizations l10n,
    ModelProviderSettingsState? state,
  ) {
    if (state == null || state.providers.isEmpty) {
      return l10n.pluginsModelProviderStatus;
    }
    final connected = state.connectionResults.values.any(
      (connection) => connection.status == ProviderConnectionStatus.succeeded,
    );
    if (connected) {
      return l10n.providerConnectionConnected;
    }
    return l10n.pluginsModelProviderConfigured(state.providers.length);
  }

  String _transcriptionStatus(
    AppLocalizations l10n,
    VoiceTranscriptionSettings? settings,
  ) {
    if (settings == null) {
      return l10n.settingsTranscriptionStatusLoading;
    }
    if (settings.engine == VoiceTranscriptionEngine.xiaomiMimo &&
        settings.mimoAsrEnabled) {
      return l10n.settingsTranscriptionStatusRemote;
    }
    if (settings.engine == VoiceTranscriptionEngine.localSenseVoice &&
        settings.localModelState == LocalTranscriptionModelState.ready) {
      return l10n.settingsTranscriptionStatusLocal;
    }
    return l10n.settingsTranscriptionStatusNeedsSetup;
  }

  String _locationStatus(
    AppLocalizations l10n,
    LocationCaptureSettings? settings,
  ) {
    if (settings == null || !settings.saveGps) {
      return l10n.settingsLocationStatusOff;
    }
    if (settings.useAmapReverseGeocode) {
      return l10n.settingsLocationStatusAmap;
    }
    return l10n.settingsLocationStatusGps;
  }

  String _debuggingStatus(AppLocalizations l10n, DebuggingState? state) {
    if (state == null) {
      return l10n.debuggingStatusLoading;
    }
    return l10n.settingsDebuggingStatusSummary(
      state.snapshot.retryableAgentTasks,
      state.snapshot.matchingCaptures,
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = _StatusRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      status: status,
      trailingIcon: onTap == null ? null : Icons.chevron_right,
    );

    if (onTap == null) {
      return row;
    }

    return Semantics(
      button: true,
      enabled: true,
      excludeSemantics: true,
      label: '$title. $subtitle. $status',
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.trailingIcon,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Chip(visualDensity: VisualDensity.compact, label: Text(status)),
            if (trailingIcon != null) ...[
              const SizedBox(height: 4),
              Icon(trailingIcon, size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ],
        ),
      ],
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
          key: const Key('settings-close-button'),
          tooltip: l10n.settingsBackTooltip,
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
