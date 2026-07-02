import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Info.plist declares phase-one capture permission descriptions', () {
    final infoPlist = File('ios/Runner/Info.plist');

    expect(infoPlist.existsSync(), isTrue);
    final contents = infoPlist.readAsStringSync();
    expect(contents, contains('NSCameraUsageDescription'));
    expect(contents, contains('NSMicrophoneUsageDescription'));
    expect(contents, contains('NSLocationWhenInUseUsageDescription'));
    expect(contents, contains('NSPhotoLibraryUsageDescription'));
    expect(contents, contains('local raw capture attachments'));
    expect(contents, contains('source metadata'));
    expect(contents, isNot(contains('NSLocationAlwaysUsageDescription')));
  });

  test('iOS permission_handler macros stay scoped to used permissions', () {
    final podfile = File('ios/Podfile');

    expect(podfile.existsSync(), isTrue);
    final contents = podfile.readAsStringSync();
    expect(contents, contains("'PERMISSION_CAMERA=1'"));
    expect(contents, contains("'PERMISSION_MICROPHONE=1'"));
    expect(contents, contains("'PERMISSION_PHOTOS=1'"));
    expect(contents, contains("'PERMISSION_LOCATION_WHENINUSE=1'"));
    expect(contents, contains("'PERMISSION_LOCATION=0'"));
    expect(contents, contains("'PERMISSION_EVENTS=0'"));
    expect(contents, contains("'PERMISSION_EVENTS_FULL_ACCESS=0'"));
    expect(contents, contains("'PERMISSION_REMINDERS=0'"));
    expect(contents, contains("'PERMISSION_NOTIFICATIONS=0'"));
    expect(contents, contains("'PERMISSION_MEDIA_LIBRARY=0'"));
    expect(contents, contains("'PERMISSION_BLUETOOTH=0'"));
  });

  test('iOS app registers and handles .widenote backup documents', () {
    final infoPlist = File('ios/Runner/Info.plist');
    final appDelegate = File('ios/Runner/AppDelegate.swift');
    final sceneDelegate = File('ios/Runner/SceneDelegate.swift');
    final bridge = File('ios/Runner/BackupImportBridge.swift');

    expect(infoPlist.existsSync(), isTrue);
    expect(appDelegate.existsSync(), isTrue);
    expect(sceneDelegate.existsSync(), isTrue);
    expect(bridge.existsSync(), isTrue);

    final plistContents = infoPlist.readAsStringSync();
    expect(plistContents, contains('app.widenote.backup'));
    expect(plistContents, contains('application/x-widenote-backup'));
    expect(plistContents, contains('<string>widenote</string>'));
    expect(plistContents, contains('CFBundleDocumentTypes'));
    expect(plistContents, contains('UTExportedTypeDeclarations'));
    expect(plistContents, contains('LSSupportsOpeningDocumentsInPlace'));

    expect(
      appDelegate.readAsStringSync(),
      contains('BackupImportBridge.register'),
    );
    expect(
      sceneDelegate.readAsStringSync(),
      contains('BackupImportBridge.handle'),
    );
    final bridgeContents = bridge.readAsStringSync();
    expect(bridgeContents, contains('app.widenote/backup_import'));
    expect(bridgeContents, contains('app.widenote/backup_export'));
    expect(bridgeContents, contains('bufferSize = 8 * 1024'));
    expect(bridgeContents, contains('UIActivityViewController'));
    expect(bridgeContents, contains('UIDocumentPickerViewController'));
    expect(bridgeContents, contains('documentTypes:'));
  });
}
