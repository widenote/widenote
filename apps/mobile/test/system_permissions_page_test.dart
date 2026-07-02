import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_mobile/features/system_permissions/application/system_permissions_controller.dart';
import 'package:widenote_mobile/features/system_permissions/presentation/system_permissions_page.dart';
import 'package:widenote_mobile/l10n/l10n.dart';

import 'support/fake_system_permission_adapter.dart';

void main() {
  testWidgets('Android system permissions use requests and picker states', (
    tester,
  ) async {
    final adapter = FakeSystemPermissionAdapter(
      platform: SystemPermissionPlatform.android,
      statuses: {
        SystemPermissionKind.camera: SystemPermissionStatus.denied,
        SystemPermissionKind.microphone: SystemPermissionStatus.granted,
        SystemPermissionKind.location: SystemPermissionStatus.granted,
        SystemPermissionKind.photos: SystemPermissionStatus.notRequired,
        SystemPermissionKind.files: SystemPermissionStatus.notRequired,
        SystemPermissionKind.calendar: SystemPermissionStatus.notConfigured,
      },
      serviceStatuses: {
        SystemPermissionKind.location: SystemPermissionServiceStatus.disabled,
      },
    );

    await _pumpPage(tester, adapter);

    expect(find.byKey(const Key('system-permissions-page')), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
    expect(find.text('4 ready / 2 need attention'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('service off'), findsOneWidget);
    expect(
      find.textContaining('system photo picker without broad media permission'),
      findsOneWidget,
    );
    expect(find.textContaining('without broad file access'), findsOneWidget);
    expect(find.text('not enabled'), findsOneWidget);

    await tester.tap(find.byKey(const Key('system-permission-action-camera')));
    await tester.pumpAndSettle();

    expect(adapter.requestedKinds, contains(SystemPermissionKind.camera));
    expect(find.text('5 ready / 1 need attention'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('system-permission-action-location')),
    );
    await tester.pumpAndSettle();

    expect(adapter.openLocationSettingsCount, 1);
  });

  testWidgets('iOS page surfaces limited photos and settings actions', (
    tester,
  ) async {
    final adapter = FakeSystemPermissionAdapter(
      platform: SystemPermissionPlatform.ios,
      statuses: {
        SystemPermissionKind.camera: SystemPermissionStatus.permanentlyDenied,
        SystemPermissionKind.microphone: SystemPermissionStatus.denied,
        SystemPermissionKind.location: SystemPermissionStatus.restricted,
        SystemPermissionKind.photos: SystemPermissionStatus.limited,
        SystemPermissionKind.files: SystemPermissionStatus.notRequired,
        SystemPermissionKind.calendar: SystemPermissionStatus.notConfigured,
      },
    );

    await _pumpPage(tester, adapter);

    expect(find.text('iOS'), findsOneWidget);
    expect(find.text('limited'), findsOneWidget);
    expect(find.text('settings'), findsOneWidget);
    expect(find.text('restricted'), findsOneWidget);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);

    await tester.tap(find.byKey(const Key('system-permission-action-camera')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('system-permission-action-photos')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('system-permission-action-photos')));
    await tester.pumpAndSettle();

    expect(adapter.openAppSettingsCount, 2);
    expect(adapter.requestedKinds, isEmpty);
  });

  testWidgets('permission statuses refresh when the app resumes', (
    tester,
  ) async {
    final adapter = FakeSystemPermissionAdapter(
      platform: SystemPermissionPlatform.android,
      statuses: {
        SystemPermissionKind.camera: SystemPermissionStatus.denied,
        SystemPermissionKind.microphone: SystemPermissionStatus.notConfigured,
        SystemPermissionKind.location: SystemPermissionStatus.notConfigured,
        SystemPermissionKind.photos: SystemPermissionStatus.notRequired,
        SystemPermissionKind.files: SystemPermissionStatus.notRequired,
        SystemPermissionKind.calendar: SystemPermissionStatus.notConfigured,
      },
    );

    await _pumpPage(tester, adapter);
    expect(find.text('not allowed'), findsOneWidget);

    adapter.statuses[SystemPermissionKind.camera] =
        SystemPermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('allowed'), findsOneWidget);
    expect(find.text('not allowed'), findsNothing);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  FakeSystemPermissionAdapter adapter,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [systemPermissionAdapterProvider.overrideWithValue(adapter)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SystemPermissionsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
