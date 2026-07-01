import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/location_settings_controller.dart';
import '../domain/location_context.dart';

class LocationSettingsPage extends ConsumerStatefulWidget {
  const LocationSettingsPage({super.key});

  @override
  ConsumerState<LocationSettingsPage> createState() =>
      _LocationSettingsPageState();
}

class _LocationSettingsPageState extends ConsumerState<LocationSettingsPage> {
  final _apiKeyController = TextEditingController();
  String? _controllerValue;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(locationSettingsControllerProvider);
    return asyncState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          _LocationSettingsShell(child: _ErrorLine(text: '$error')),
      data: (state) {
        _syncApiKeyController(state.settings.amapApiKey);
        return _LocationSettingsShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrivacyNotice(settings: state.settings),
              const SizedBox(height: 12),
              _CaptureControls(settings: state.settings),
              const SizedBox(height: 12),
              _AmapControls(
                settings: state.settings,
                apiKeyController: _apiKeyController,
              ),
              const SizedBox(height: 12),
              _GranularityControls(settings: state.settings),
              const SizedBox(height: 12),
              _LocationTestSurface(state: state),
              const SizedBox(height: 12),
              _LocationMaintenanceSurface(state: state),
            ],
          ),
        );
      },
    );
  }

  void _syncApiKeyController(String value) {
    if (_controllerValue == value) {
      return;
    }
    _controllerValue = value;
    _apiKeyController.text = value;
  }
}

class _LocationSettingsShell extends StatelessWidget {
  const _LocationSettingsShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      key: const Key('location-settings-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        _PageHeader(
          title: l10n.locationSettingsTitle,
          subtitle: l10n.locationSettingsSubtitle,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.settings});

  final LocationCaptureSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.privacy_tip_outlined,
      title: l10n.locationPrivacyTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(
            icon: Icons.phone_iphone_outlined,
            title: l10n.locationPrivacyLocalTitle,
            body: l10n.locationPrivacyLocalBody,
          ),
          const Divider(height: 20),
          _StatusLine(
            icon: Icons.map_outlined,
            title: l10n.locationPrivacyAmapTitle,
            body: l10n.locationPrivacyAmapBody,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Tag(
                label: settings.saveGps
                    ? l10n.locationStatusGpsOn
                    : l10n.locationStatusGpsOff,
              ),
              _Tag(
                label: settings.useAmapReverseGeocode
                    ? l10n.locationStatusAmapOn
                    : l10n.locationStatusAmapOff,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaptureControls extends ConsumerWidget {
  const _CaptureControls({required this.settings});

  final LocationCaptureSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.my_location_outlined,
      title: l10n.locationCaptureTitle,
      child: SwitchListTile(
        key: const Key('location-save-gps-switch'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.locationSaveGpsTitle),
        subtitle: Text(l10n.locationSaveGpsBody),
        value: settings.saveGps,
        onChanged: (value) => unawaited(
          ref
              .read(locationSettingsControllerProvider.notifier)
              .setSaveGps(value),
        ),
      ),
    );
  }
}

class _AmapControls extends ConsumerWidget {
  const _AmapControls({required this.settings, required this.apiKeyController});

  final LocationCaptureSettings settings;
  final TextEditingController apiKeyController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final enabled = settings.saveGps;
    return _Surface(
      icon: Icons.travel_explore_outlined,
      title: l10n.locationAmapTitle,
      child: Column(
        children: [
          SwitchListTile(
            key: const Key('location-amap-switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.locationAmapSwitchTitle),
            subtitle: Text(l10n.locationAmapSwitchBody),
            value: enabled && settings.useAmapReverseGeocode,
            onChanged: enabled
                ? (value) => unawaited(
                    ref
                        .read(locationSettingsControllerProvider.notifier)
                        .setUseAmapReverseGeocode(value),
                  )
                : null,
          ),
          TextField(
            key: const Key('location-amap-key-field'),
            controller: apiKeyController,
            enabled: enabled && settings.useAmapReverseGeocode,
            obscureText: true,
            decoration: InputDecoration(
              labelText: l10n.locationAmapKeyLabel,
              helperText: l10n.locationAmapKeyHelper,
            ),
            onChanged: (value) => unawaited(
              ref
                  .read(locationSettingsControllerProvider.notifier)
                  .setAmapApiKey(value),
            ),
          ),
        ],
      ),
    );
  }
}

class _GranularityControls extends ConsumerWidget {
  const _GranularityControls({required this.settings});

  final LocationCaptureSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.visibility_outlined,
      title: l10n.locationGranularityTitle,
      description: l10n.locationGranularityBody,
      child: DropdownButtonFormField<LocationDisplayGranularity>(
        key: const Key('location-granularity-dropdown'),
        initialValue: settings.displayGranularity,
        decoration: InputDecoration(labelText: l10n.locationGranularityLabel),
        items: [
          for (final value in LocationDisplayGranularity.values)
            DropdownMenuItem(
              value: value,
              child: Text(_granularityLabel(l10n, value)),
            ),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }
          unawaited(
            ref
                .read(locationSettingsControllerProvider.notifier)
                .setDisplayGranularity(value),
          );
        },
      ),
    );
  }
}

class _LocationTestSurface extends ConsumerWidget {
  const _LocationTestSurface({required this.state});

  final LocationSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contextSnapshot = state.testContext;
    return _Surface(
      icon: Icons.fact_check_outlined,
      title: l10n.locationTestTitle,
      description: l10n.locationTestBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            key: const Key('location-test-button'),
            onPressed: state.isTesting
                ? null
                : () => unawaited(
                    ref
                        .read(locationSettingsControllerProvider.notifier)
                        .testCurrentLocation(),
                  ),
            icon: state.isTesting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.near_me_outlined),
            label: Text(
              state.isTesting
                  ? l10n.locationTestRunning
                  : l10n.locationTestAction,
            ),
          ),
          if (contextSnapshot != null) ...[
            const SizedBox(height: 12),
            _LocationStatusBox(contextSnapshot: contextSnapshot),
          ] else if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorLine(text: _locationReasonLabel(l10n, state.errorMessage!)),
          ],
        ],
      ),
    );
  }
}

class _LocationMaintenanceSurface extends ConsumerWidget {
  const _LocationMaintenanceSurface({required this.state});

  final LocationSettingsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return _Surface(
      icon: Icons.delete_sweep_outlined,
      title: l10n.locationMaintenanceTitle,
      description: l10n.locationMaintenanceBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            key: const Key('location-clear-saved-button'),
            onPressed: () => unawaited(_confirmClear(context, ref)),
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.locationClearSavedAction),
          ),
          if (state.clearedLocationCount != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.locationClearSavedResult(state.clearedLocationCount!),
              key: const Key('location-clear-saved-result'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.locationClearConfirmTitle),
        content: Text(l10n.locationClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const Key('location-clear-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.locationClearConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref
        .read(locationSettingsControllerProvider.notifier)
        .clearSavedCaptureLocations();
  }
}

class _LocationStatusBox extends StatelessWidget {
  const _LocationStatusBox({required this.contextSnapshot});

  final CapturedLocationContext contextSnapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = contextSnapshot.displaySummary(coarseOnly: true);
    final reverse = contextSnapshot.reverseGeocode;
    final labels = <String>[
      _locationContextStatusLabel(l10n, contextSnapshot),
      if (summary != null) l10n.locationStatusSummary(summary),
      if (contextSnapshot.deviceLocation != null)
        l10n.locationStatusCoordinatesSaved,
      if (reverse != null && !reverse.isSuccess)
        _locationReasonLabel(l10n, reverse.reason ?? reverse.status.name),
    ];
    return DecoratedBox(
      key: const Key('location-test-result'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0) const SizedBox(height: 4),
              Text(labels[index], style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.icon,
    required this.title,
    required this.child,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8DDE6)),
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
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

String _granularityLabel(
  AppLocalizations l10n,
  LocationDisplayGranularity granularity,
) {
  return switch (granularity) {
    LocationDisplayGranularity.city => l10n.locationGranularityCity,
    LocationDisplayGranularity.district => l10n.locationGranularityDistrict,
    LocationDisplayGranularity.neighborhood =>
      l10n.locationGranularityNeighborhood,
    LocationDisplayGranularity.street => l10n.locationGranularityStreet,
    LocationDisplayGranularity.full => l10n.locationGranularityFull,
  };
}

String _locationContextStatusLabel(
  AppLocalizations l10n,
  CapturedLocationContext context,
) {
  if (context.status == LocationCaptureStatus.available) {
    return l10n.locationStatusAvailable;
  }
  return _locationReasonLabel(l10n, context.reason ?? 'location_unavailable');
}

String _locationReasonLabel(AppLocalizations l10n, String reason) {
  return switch (reason) {
    'location_disabled' => l10n.locationStatusDisabled,
    'location_service_disabled' => l10n.locationStatusServiceDisabled,
    'location_permission_denied' => l10n.locationStatusPermissionDenied,
    'location_permission_denied_forever' =>
      l10n.locationStatusPermissionDeniedForever,
    'location_timeout' => l10n.locationStatusTimeout,
    'amap_api_key_missing' => l10n.locationStatusAmapKeyMissing,
    'amap_disabled' => l10n.locationStatusAmapDisabled,
    'amap_timeout' => l10n.locationStatusAmapTimeout,
    _ => l10n.locationStatusUnavailable,
  };
}
