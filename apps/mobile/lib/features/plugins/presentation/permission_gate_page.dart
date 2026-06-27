import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/pack_catalog.dart';

class PermissionGatePage extends ConsumerWidget {
  const PermissionGatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(permissionGateControllerProvider);
    final controller = ref.read(permissionGateControllerProvider.notifier);
    return ListView(
      key: const Key('permission-gate-page'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _PageHeader(
          title: l10n.permissionGateTitle,
          subtitle: l10n.permissionGateSubtitle,
        ),
        const SizedBox(height: 16),
        _PermissionSection(
          title: l10n.permissionGateGrantedTitle,
          icon: Icons.verified_user_outlined,
          permissions: state.builtInPermissions,
          onGrant: controller.grant,
          onDeny: controller.deny,
          onRevoke: controller.revoke,
        ),
        const SizedBox(height: 16),
        _PermissionSection(
          title: l10n.permissionGateDeferredTitle,
          icon: Icons.lock_outline,
          permissions: state.deferredPermissions,
          onGrant: controller.grant,
          onDeny: controller.deny,
          onRevoke: controller.revoke,
        ),
      ],
    );
  }
}

class _PermissionSection extends StatelessWidget {
  const _PermissionSection({
    required this.title,
    required this.icon,
    required this.permissions,
    required this.onGrant,
    required this.onDeny,
    required this.onRevoke,
  });

  final String title;
  final IconData icon;
  final List<PermissionGatePermission> permissions;
  final void Function(PermissionGatePermission permission) onGrant;
  final void Function(PermissionGatePermission permission) onDeny;
  final void Function(PermissionGatePermission permission) onRevoke;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      icon: icon,
      title: title,
      child: Column(
        children: [
          for (var index = 0; index < permissions.length; index++) ...[
            if (index > 0) const Divider(height: 20),
            _PermissionRow(
              permission: permissions[index],
              onGrant: onGrant,
              onDeny: onDeny,
              onRevoke: onRevoke,
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.onGrant,
    required this.onDeny,
    required this.onRevoke,
  });

  final PermissionGatePermission permission;
  final void Function(PermissionGatePermission permission) onGrant;
  final void Function(PermissionGatePermission permission) onDeny;
  final void Function(PermissionGatePermission permission) onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusLabel = _statusLabel(l10n, permission);
    return Row(
      key: Key('permission-row-${permission.permission}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          permission.isDeferred ? Icons.lock_outline : Icons.key_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                permission.permission,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(statusLabel, style: _mutedStyle(context)),
              const SizedBox(height: 4),
              Text(
                _impactLabel(l10n, permission),
                key: Key('permission-impact-${permission.permission}'),
                style: _mutedStyle(context),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _Tag(label: _packLabel(l10n, permission.packId)),
                  _Tag(label: _riskLabel(l10n, permission.risk)),
                ],
              ),
              const SizedBox(height: 8),
              _PermissionActions(
                permission: permission,
                onGrant: onGrant,
                onDeny: onDeny,
                onRevoke: onRevoke,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionActions extends StatelessWidget {
  const _PermissionActions({
    required this.permission,
    required this.onGrant,
    required this.onDeny,
    required this.onRevoke,
  });

  final PermissionGatePermission permission;
  final void Function(PermissionGatePermission permission) onGrant;
  final void Function(PermissionGatePermission permission) onDeny;
  final void Function(PermissionGatePermission permission) onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final suffix = _permissionKeySuffix(permission);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (permission.canGrant)
          _ActionButton(
            key: Key('permission-action-grant-$suffix'),
            icon: Icons.check_circle_outline,
            label: l10n.permissionGateActionGrant,
            onPressed: () => onGrant(permission),
          ),
        if (permission.canDeny)
          _ActionButton(
            key: Key('permission-action-deny-$suffix'),
            icon: Icons.block_outlined,
            label: l10n.permissionGateActionDeny,
            onPressed: () => onDeny(permission),
          ),
        if (permission.canRevoke)
          _ActionButton(
            key: Key('permission-action-revoke-$suffix'),
            icon: Icons.remove_circle_outline,
            label: l10n.permissionGateActionRevoke,
            onPressed: () => onRevoke(permission),
          ),
        if (permission.isDeferred)
          OutlinedButton.icon(
            key: Key('permission-action-deferred-$suffix'),
            onPressed: null,
            icon: const Icon(Icons.lock_clock_outlined),
            label: Text(l10n.permissionGateActionDeferred),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
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
        Text(subtitle, style: _mutedStyle(context)),
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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

TextStyle? _mutedStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

String _statusLabel(
  AppLocalizations l10n,
  PermissionGatePermission permission,
) {
  return switch (permission.decisionState) {
    PermissionGateDecisionState.available => l10n.permissionGateStatusAvailable,
    PermissionGateDecisionState.granted => l10n.permissionGateStatusGranted,
    PermissionGateDecisionState.denied => l10n.permissionGateStatusDenied,
    PermissionGateDecisionState.revoked => l10n.permissionGateStatusRevoked,
    PermissionGateDecisionState.deferred => _deferredStatusLabel(
      l10n,
      permission.permission,
    ),
  };
}

String _permissionKeySuffix(PermissionGatePermission permission) {
  return '${permission.packId}-${permission.permission}';
}

String _impactLabel(
  AppLocalizations l10n,
  PermissionGatePermission permission,
) {
  return switch (permission.decisionState) {
    PermissionGateDecisionState.available => l10n.permissionGateImpactAvailable,
    PermissionGateDecisionState.granted => l10n.permissionGateImpactGranted,
    PermissionGateDecisionState.denied => l10n.permissionGateImpactDenied,
    PermissionGateDecisionState.revoked => l10n.permissionGateImpactRevoked,
    PermissionGateDecisionState.deferred => l10n.permissionGateImpactDeferred,
  };
}

String _riskLabel(AppLocalizations l10n, String risk) {
  return switch (risk) {
    'low' => l10n.permissionGateRiskLow,
    'medium' => l10n.permissionGateRiskMedium,
    'high' => l10n.permissionGateRiskHigh,
    _ => risk,
  };
}

String _packLabel(AppLocalizations l10n, String packId) {
  return switch (packId) {
    'community packs' => l10n.permissionGateCommunityPacks,
    'media packs' => l10n.permissionGateMediaPacks,
    'context packs' => l10n.permissionGateContextPacks,
    _ => packId,
  };
}

String _deferredStatusLabel(AppLocalizations l10n, String permission) {
  return switch (permission) {
    'file.read.broad' => l10n.permissionGateDeferredSandbox,
    'network.call.arbitrary_host' => l10n.permissionGateDeferredExternalTools,
    'script.execute' => l10n.permissionGateDeferredSandbox,
    'audio.capture.continuous' => l10n.permissionGateDeferredPlatform,
    'location.read.background' => l10n.permissionGateDeferredPrivacy,
    _ => l10n.permissionGateImpactDeferred,
  };
}
